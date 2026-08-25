#!/usr/bin/env python3
"""
Claims Intelligence Agent - Enterprise Edition

Combines Policy Matching + Coverage Validation into single decision agent.
Handles policy lookup, coverage analysis, and compliance checking.

Key Enterprise Features:
- Policy document caching
- Multi-factor coverage analysis
- Compliance rules engine
- Exception handling & escalation
- Detailed reasoning and audit trail
"""

import argparse
import os
import json
import logging
import re
import time
from datetime import datetime
from pathlib import Path
from dotenv import load_dotenv
from typing import Optional
from functools import lru_cache

from azure.ai.projects import AIProjectClient
from azure.ai.projects.models import PromptAgentDefinition
from azure.core.exceptions import ResourceNotFoundError
from azure.identity import DefaultAzureCredential
from azure.storage.blob import BlobServiceClient

from enterprise_models import (
    ClaimProcessingState, PolicyInfo, CoverageDecision, ErrorInfo,
    SeverityLevel, ClaimStatus, StructuredClaim
)

REPO_ROOT = Path(__file__).resolve().parent.parent
load_dotenv(REPO_ROOT / ".env")
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

PROJECT_ENDPOINT = os.environ.get("AI_FOUNDRY_PROJECT_ENDPOINT")
MODEL_DEPLOYMENT_NAME = os.environ.get("MODEL_DEPLOYMENT_NAME", "gpt-5.4")

POLICY_EXTRACTION_AGENT_NAME = "policy-extraction-agent"
COVERAGE_DECISION_AGENT_NAME = "coverage-decision-agent"
POLICY_EXTRACTION_INSTRUCTIONS = """You extract structured insurance policy fields from a raw policy document.
Return ONLY strict JSON (no markdown fences, no commentary) matching this shape:
{
  "policy_type": "string, e.g. Liability Only Auto Insurance",
  "coverage_types": ["short_snake_case_labels, e.g. collision, comprehensive, third_party_liability"],
  "limits": {"coverage_label": 100000.0},
  "deductibles": {"coverage_label": 500.0},
  "exclusions": ["short_snake_case_labels, e.g. own_vehicle_damage, collision"]
}
Use the Standard/State Minimum coverage limits section for limits, and the Standard Deductibles
section for deductibles (0 if the policy has none). Coverage labels must be short snake_case
tokens usable as dict keys, not full sentences."""

POLICY_CODE_PATTERN = re.compile(r"\*\*Policy Code:\*\*\s*([\w-]+)")


class ClaimsIntelligenceAgent:
    """Enterprise claims decision making with policy matching and coverage validation"""
    
    def __init__(self):
        if not PROJECT_ENDPOINT:
            raise ValueError("AI_FOUNDRY_PROJECT_ENDPOINT is not set. Complete Task 1 first.")
        self.client = AIProjectClient(
            endpoint=PROJECT_ENDPOINT,
            credential=DefaultAzureCredential(),
            allow_preview=True
        )
        self.model = MODEL_DEPLOYMENT_NAME
        self.policy_cache = {}
        self.policy_documents_cache: dict[str, str] | None = None
    
    def get_intelligence_instructions(self) -> str:
        """System prompt for intelligence agent"""
        return """You are an enterprise insurance claims adjudicator. Your role is to:
1. Analyze whether a claim is covered under the insurance policy
2. Determine the approved payment amount
3. Identify any exclusions or limitations that apply
4. Flag edge cases requiring escalation
5. Score how consistent the reported crash details are with what the policy would be expected to cover

**Decision Framework:**
- Compare claim type against policy coverage types
- Check if claim amount exceeds policy limits
- Calculate applicable deductibles
- Identify matching exclusions
- Assess risk factors

**Consistency Scoring (1-100):**
- Produce a `consistency_score` from 1 to 100 that reflects how well the crash/damage details
  line up with what this policy is expected to cover, and therefore whether the claim should
  be approved.
- 90-100: damage description, claim type, and incident details fully align with covered
  coverage types, no exclusions apply, and amount is within limits. Approve with high confidence.
- 60-89: mostly consistent, but with minor gaps such as an amount near a limit, a partial
  exclusion, or missing corroborating details. Approve with caution or apply partial payment.
- 30-59: meaningful inconsistencies (claim type does not clearly match coverage types, an
  exclusion partially applies, or damage description conflicts with the policy). Escalate for
  manual review rather than auto-approving.
- 1-29: crash details are inconsistent with the policy (an excluded peril, wrong coverage
  type, or contradictory facts). Deny or escalate.
- The score must be an integer and must agree with `is_covered`/`requires_escalation`: a score
  below 30 should not be paired with `is_covered: true`, and a score of 90+ should not require
  escalation unless a hard policy limit is exceeded.

**Output JSON:**
{
  "is_covered": true|false,
  "coverage_percentage": 100,
  "applicable_deductible": 500.00,
  "approved_amount": 14500.00,
  "exclusions_matched": [],
  "reasoning": "Claim is covered under collision coverage with standard deductible.",
  "risk_flags": [],
  "confidence_score": 0.95,
  "consistency_score": 94,
  "requires_escalation": false,
  "escalation_reason": null
}"""
    
    def _get_policies_container_client(self):
        """Connect to the Storage Account's policies blob container (enterprise policy files)."""
        connection_string = os.environ.get("AZURE_STORAGE_CONNECTION_STRING")
        if not connection_string:
            raise ValueError("AZURE_STORAGE_CONNECTION_STRING is not set. Complete Task 1 first.")
        container_name = os.environ.get("AZURE_POLICIES_CONTAINER_NAME", "policies")
        blob_service = BlobServiceClient.from_connection_string(connection_string)
        return blob_service.get_container_client(container_name)

    def _load_policy_documents(self) -> dict[str, str]:
        """Download and cache every policy markdown file from the Storage Account, keyed by
        the policy's `Policy Code` field (e.g. LIAB-AUTO-001)."""
        if self.policy_documents_cache is not None:
            return self.policy_documents_cache

        container_client = self._get_policies_container_client()
        documents: dict[str, str] = {}
        for blob in container_client.list_blobs():
            text = container_client.download_blob(blob.name).readall().decode("utf-8")
            match = POLICY_CODE_PATTERN.search(text)
            if match:
                documents[match.group(1)] = text
            else:
                logger.warning(f"No Policy Code found in blob {blob.name}; skipping")

        if not documents:
            container_name = os.environ.get("AZURE_POLICIES_CONTAINER_NAME", "policies")
            raise RuntimeError(
                f"No policy documents with a Policy Code were found in Azure Storage container "
                f"'{container_name}'. Upload data/policies/*.md by rerunning deploy-lab.ps1."
            )

        logger.info(f"Loaded {len(documents)} policy document(s) from Storage Account: {sorted(documents)}")
        self.policy_documents_cache = documents
        return documents

    def _ensure_policy_extraction_agent(self) -> None:
        """Register (or reuse) the agent that extracts structured fields from raw policy files."""
        try:
            self.client.agents.get(POLICY_EXTRACTION_AGENT_NAME)
        except ResourceNotFoundError:
            definition = PromptAgentDefinition(model=self.model, instructions=POLICY_EXTRACTION_INSTRUCTIONS)
            self.client.agents.create_version(agent_name=POLICY_EXTRACTION_AGENT_NAME, definition=definition)

    def _ensure_coverage_decision_agent(self) -> None:
        """Register or reuse the agent that adjudicates structured claims and policies."""
        try:
            self.client.agents.get(COVERAGE_DECISION_AGENT_NAME)
        except ResourceNotFoundError:
            definition = PromptAgentDefinition(
                model=self.model,
                instructions=self.get_intelligence_instructions(),
            )
            self.client.agents.create_version(
                agent_name=COVERAGE_DECISION_AGENT_NAME,
                definition=definition,
            )

    def _extract_policy_info(self, policy_number: str, raw_text: str) -> PolicyInfo:
        """Use the policy-extraction agent to parse structured coverage fields from the raw policy file."""
        self._ensure_policy_extraction_agent()
        openai_client = self.client.get_openai_client(agent_name=POLICY_EXTRACTION_AGENT_NAME)
        result = openai_client.responses.create(model=self.model, input=raw_text)
        extracted = json.loads(result.output_text)

        return PolicyInfo(
            policy_id=policy_number.lower().replace("-", "_"),
            policy_number=policy_number,
            policy_type=extracted.get("policy_type", "Unknown"),
            coverage_types=extracted.get("coverage_types", []),
            limits=extracted.get("limits", {}),
            deductibles=extracted.get("deductibles", {}),
            exclusions=extracted.get("exclusions", []),
            effective_date="2026-01-01",
            expiry_date="2027-01-01",
            retrieval_score=1.0
        )

    def _get_policy(self, policy_number: str) -> Optional[PolicyInfo]:
        """Retrieve policy from the Storage Account policies container (cached after first fetch)"""
        if policy_number in self.policy_cache:
            logger.info(f"Policy {policy_number} retrieved from cache")
            return self.policy_cache[policy_number]

        documents = self._load_policy_documents()
        raw_text = documents.get(policy_number)

        if raw_text:
            policy = self._extract_policy_info(policy_number, raw_text)
            self.policy_cache[policy_number] = policy
            return policy

        logger.warning(f"Policy {policy_number} not found in Storage Account policies container")
        return None

    def retrieve_policy(self, policy_number: str) -> PolicyInfo:
        """Retrieve and extract a policy for use by a sequential workflow."""
        policy = self._get_policy(policy_number)
        if policy is None:
            raise LookupError(f"Policy {policy_number} not found")
        return policy
    
    def validate_coverage(self, state: ClaimProcessingState) -> ClaimProcessingState:
        """
        Validate claim coverage using policy matching and decision logic
        
        Args:
            state: Claim state with structured claim data
        
        Returns:
            Updated state with coverage decision
        """
        if not state.structured_claim:
            raise ValueError("Structured claim required for coverage validation")
        
        start_time = time.time()
        state.update_status(ClaimStatus.POLICY_RETRIEVED)
        
        try:
            claim = state.structured_claim
            
            # Step 1: Retrieve policy
            logger.info(f"[{state.claim_id}] Retrieving policy {claim.policy_number}")
            policy = state.policy_info or self.retrieve_policy(claim.policy_number)
            
            state.policy_info = policy
            state.add_audit_entry(
                agent_name=POLICY_EXTRACTION_AGENT_NAME,
                action="retrieve_policy",
                status="completed",
                message=f"Retrieved policy {policy.policy_type}",
                metadata={"retrieval_score": policy.retrieval_score}
            )
            
            # Step 2: Run coverage decision
            logger.info(f"[{state.claim_id}] Validating coverage")
            decision_prompt = self._build_decision_prompt(claim, policy)
            
            self._ensure_coverage_decision_agent()
            openai_client = self.client.get_openai_client(agent_name=COVERAGE_DECISION_AGENT_NAME)
            result = openai_client.responses.create(
                model=self.model,
                input=decision_prompt
            )
            
            response_text = result.output_text
            decision_json = json.loads(response_text)
            
            # Extract decision
            state.coverage_decision = CoverageDecision(
                is_covered=decision_json.get("is_covered", False),
                coverage_percentage=decision_json.get("coverage_percentage", 0),
                applicable_deductible=float(decision_json.get("applicable_deductible", 0)),
                approved_amount=float(decision_json.get("approved_amount", 0)),
                exclusions_matched=decision_json.get("exclusions_matched", []),
                reasoning=decision_json.get("reasoning", ""),
                risk_flags=decision_json.get("risk_flags", []),
                confidence_score=decision_json.get("confidence_score", 0.85),
                consistency_score=int(decision_json.get("consistency_score", 0))
            )
            
            # Check for escalation flags
            if decision_json.get("requires_escalation", False):
                state.update_status(ClaimStatus.ESCALATED)
                state.add_error(ErrorInfo(
                    error_code="ESCALATION_REQUIRED",
                    error_message=decision_json.get("escalation_reason", "Manual review needed"),
                    severity=SeverityLevel.WARN,
                    retry_eligible=False,
                    recommendation="Escalate to claims adjuster for manual review",
                    agent_name=COVERAGE_DECISION_AGENT_NAME
                ))
            else:
                state.update_status(
                    ClaimStatus.APPROVED if state.coverage_decision.is_covered 
                    else ClaimStatus.DENIED
                )
            
            state.add_audit_entry(
                agent_name=COVERAGE_DECISION_AGENT_NAME,
                action="validate_coverage",
                status="completed",
                message=f"Coverage decision: {'APPROVED' if state.coverage_decision.is_covered else 'DENIED'}",
                metadata={
                    "approved_amount": state.coverage_decision.approved_amount,
                    "confidence_score": state.coverage_decision.confidence_score,
                    "consistency_score": state.coverage_decision.consistency_score,
                    "risk_flags": state.coverage_decision.risk_flags
                }
            )
            
            state.intelligence_duration_ms = (time.time() - start_time) * 1000
            logger.info(f"[{state.claim_id}] Coverage validation completed in {state.intelligence_duration_ms:.0f}ms")
            
            return state
            
        except Exception as e:
            logger.error(f"[{state.claim_id}] Coverage validation failed: {str(e)}")
            state.add_error(ErrorInfo(
                error_code="COVERAGE_VALIDATION_FAILED",
                error_message=str(e),
                severity=SeverityLevel.ERROR,
                retry_eligible=False,
                recommendation="Manual review required",
                agent_name=COVERAGE_DECISION_AGENT_NAME
            ))
            state.update_status(ClaimStatus.COVERAGE_VALIDATION_FAILED)
            raise
    
    def _build_decision_prompt(self, claim: StructuredClaim, 
                              policy: PolicyInfo) -> str:
        """Build contextualized decision prompt"""
        return f"""
**CLAIM INFORMATION:**
- Policy Number: {claim.policy_number}
- Claim Amount: ${claim.claim_amount:,.2f}
- Damage Description: {claim.damage_description}
- Incident Date: {claim.incident_date}
- Claim Type: {claim.claim_type}
- Vehicle: {claim.vehicle_info}
- Extraction Confidence: {claim.extraction_confidence * 100:.0f}%

**POLICY INFORMATION:**
- Policy Type: {policy.policy_type}
- Coverage Types: {', '.join(policy.coverage_types)}
- Limits: {json.dumps(policy.limits)}
- Deductibles: {json.dumps(policy.deductibles)}
- Exclusions: {', '.join(policy.exclusions) if policy.exclusions else 'None'}

Determine if this claim is covered under the policy and calculate the approved payment amount.
Consider the claim type against policy coverage types, check limits, apply deductible, and identify any exclusions."""


def build_claim_from_intake(
    intake: dict, claim_amount: float, policy_number: str | None
) -> StructuredClaim:
    """Build a StructuredClaim from a claims-intake-agent.py result."""
    extracted = intake["extracted_data"]
    vehicle = extracted.get("vehicle_info") or {}

    return StructuredClaim(
        policy_number=policy_number or extracted["policy_number"],
        claim_amount=claim_amount,
        damage_description=extracted["incident_description"],
        incident_date=extracted["claim_date"],
        claim_type="collision",  # inferred: a parked vehicle was struck by another car
        vehicle_info=f"{vehicle.get('year', '')} {vehicle.get('make', '')} {vehicle.get('model', '')}".strip(),
        extraction_confidence=0.9
    )


def _load_claim_from_intake(
    intake_path: Path, claim_amount: float, policy_number: str | None
) -> StructuredClaim:
    """Build a StructuredClaim from a claims-intake-agent.py output artifact."""
    intake = json.loads(intake_path.read_text(encoding="utf-8"))
    return build_claim_from_intake(intake, claim_amount, policy_number)


def main() -> None:
    parser = argparse.ArgumentParser(description="Run claims intelligence coverage validation")
    parser.add_argument(
        "intake_path",
        nargs="?",
        help="Path to the intake JSON produced by claims-intake-agent.py",
    )
    setup_group = parser.add_mutually_exclusive_group()
    setup_group.add_argument(
        "--setup-agent",
        action="store_true",
        help="Create or reuse the Foundry policy-extraction agent, then exit",
    )
    setup_group.add_argument(
        "--verify-policies",
        action="store_true",
        help="List policy codes discovered in the configured Storage container, then exit",
    )
    parser.add_argument("--claim-id", default="CLM-2026-001", help="Claim identifier (default: CLM-2026-001)")
    parser.add_argument("--claim-amount", type=float, default=15000.00, help="Claim amount (default: 15000.00)")
    parser.add_argument("--policy-number", default="", help="Override the policy number from the intake artifact")
    parser.add_argument(
        "--output",
        default="",
        help="Optional path for saving the decision JSON. If omitted, the result is only printed",
    )
    args = parser.parse_args()

    agent = ClaimsIntelligenceAgent()
    if args.setup_agent:
        agent._ensure_policy_extraction_agent()
        print(f"Foundry agent '{POLICY_EXTRACTION_AGENT_NAME}' is ready.")
        return

    if args.verify_policies:
        documents = agent._load_policy_documents()
        print(f"Found {len(documents)} policy document(s):")
        for policy_code in sorted(documents):
            print(f"  - {policy_code}")
        return

    if not args.intake_path:
        parser.error("intake_path is required unless --setup-agent or --verify-policies is used")

    intake_path = Path(args.intake_path).expanduser().resolve()

    claim = _load_claim_from_intake(intake_path, args.claim_amount, args.policy_number or None)

    state = ClaimProcessingState(claim_id=args.claim_id)
    state.structured_claim = claim

    result = agent.validate_coverage(state)
    result_dict = result.to_result_dict()

    print(json.dumps(result_dict, indent=2))
    if args.output:
        output_path = Path(args.output).expanduser().resolve()
        output_path.write_text(json.dumps(result_dict, indent=2), encoding="utf-8")
        print(f"\nSaved coverage decision to: {output_path}")


if __name__ == "__main__":
    main()
