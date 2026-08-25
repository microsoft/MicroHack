#!/usr/bin/env python3
"""Run the three Foundry agents from Challenges 1 and 2 as one sequential workflow."""

import argparse
import importlib.util
import json
import os
import sys
from pathlib import Path
from types import ModuleType

from dotenv import load_dotenv

REPO_ROOT = Path(__file__).resolve().parent.parent
load_dotenv(REPO_ROOT / ".env")

FOUNDRY_PROJECT_ENDPOINT = os.environ.get(
    "FOUNDRY_PROJECT_ENDPOINT", os.environ.get("AI_FOUNDRY_PROJECT_ENDPOINT", "")
)
FOUNDRY_MODEL = os.environ.get(
    "FOUNDRY_MODEL", os.environ.get("MODEL_DEPLOYMENT_NAME", "gpt-5.4")
)
HUMAN_REVIEW_CONFIDENCE_THRESHOLD = float(
    os.environ.get("HUMAN_REVIEW_CONFIDENCE_THRESHOLD", "0.9")
)

def _load_challenge_module(module_name: str, file_name: str) -> ModuleType:
    """Load a challenge script whose filename contains hyphens."""
    module_path = Path(__file__).with_name(file_name)
    spec = importlib.util.spec_from_file_location(module_name, module_path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Could not load challenge module: {module_path}")

    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def _requires_human_review(result: dict) -> bool:
    decision = result.get("coverage_decision") or {}
    confidence_score = float(decision.get("confidence_score", 1.0) or 0.0)
    return (
        result.get("status") == "ESCALATED"
        or bool(decision.get("requires_escalation"))
        or confidence_score < HUMAN_REVIEW_CONFIDENCE_THRESHOLD
    )


def _run_human_review(result: dict) -> dict:
    decision = result.get("coverage_decision") or {}
    confidence_score = float(decision.get("confidence_score", 0.0) or 0.0)

    print("  [Step 4] Human review requested...")
    print(
        f"    Decision status: {result.get('status', 'UNKNOWN')} | "
        f"confidence: {confidence_score:.2f} | "
        f"threshold: {HUMAN_REVIEW_CONFIDENCE_THRESHOLD:.2f}"
    )

    if not sys.stdin.isatty():
        raise RuntimeError(
            "Human review is required, but the workflow is running in a non-interactive terminal."
        )

    reviewer_action = input(
        "    Type 'approve' to accept, 'escalate' for manual review, "
        "or 'deny' to override: "
    ).strip().lower()

    if reviewer_action in {"approve", "a", "yes", "y"}:
        human_status = "confirmed"
        override_status = None
    elif reviewer_action in {"escalate", "e", "review", "manual"}:
        human_status = "escalated"
        override_status = "ESCALATED"
    elif reviewer_action in {"deny", "d", "reject", "r"}:
        human_status = "overridden"
        override_status = "DENIED"
    else:
        raise RuntimeError("Human review response must be approve, escalate, or deny.")

    result["human_review"] = {
        "required": True,
        "status": human_status,
        "reviewer_action": reviewer_action,
        "confidence_threshold": HUMAN_REVIEW_CONFIDENCE_THRESHOLD,
    }
    if override_status is not None:
        result["status"] = override_status
        result["human_review"]["override_status"] = override_status

    print("  [Step 4] Human review complete.")
    return result


def run_claims_pipeline(
    image_path: Path,
    claim_id: str,
    claim_amount: float,
    policy_number: str | None,
) -> dict:
    """Run the existing intake, policy extraction, and coverage decision agents."""
    intake_module = _load_challenge_module("claims_intake_agent", "claims-intake-agent.py")
    intelligence_module = _load_challenge_module(
        "claims_intelligence_agent", "claims-intelligence-agent.py"
    )

    print("  [Step 1] claims-intake-agent running...")
    intake_result = intake_module.run_claims_intake(image_path)
    claim = intelligence_module.build_claim_from_intake(
        intake_result, claim_amount, policy_number
    )
    print("  [Step 1] Intake complete.")

    state = intelligence_module.ClaimProcessingState(claim_id=claim_id)
    state.structured_claim = claim
    intelligence = intelligence_module.ClaimsIntelligenceAgent()

    print("  [Step 2] policy-extraction-agent running...")
    state.policy_info = intelligence.retrieve_policy(claim.policy_number)
    print("  [Step 2] Policy extraction complete.")

    print("  [Step 3] coverage-decision-agent running...")
    result = intelligence.validate_coverage(state).to_result_dict()
    print("  [Step 3] Coverage decision complete.")

    if _requires_human_review(result):
        result = _run_human_review(result)

    return result


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Run the three-agent sequential claims workflow"
    )
    parser.add_argument(
        "image_path",
        help="Path to the accident statement image used by Challenge 1",
    )
    parser.add_argument(
        "--policy", default="",
        help="Optional policy number override; defaults to the intake result",
    )
    parser.add_argument(
        "--claim-id", default="CLM-2026-001",
        help="Claim identifier (default: CLM-2026-001)",
    )
    parser.add_argument(
        "--amount", type=float, default=15000.0,
        help="Claimed amount in USD (default: 15000.0)",
    )
    args = parser.parse_args()

    if not FOUNDRY_PROJECT_ENDPOINT:
        print("FOUNDRY_PROJECT_ENDPOINT is not set. Complete Challenges 1 and 2 first.")
        sys.exit(1)

    image_path = Path(args.image_path).expanduser().resolve()
    print("\nClaims Sequential Workflow")
    print(f"  Endpoint : {FOUNDRY_PROJECT_ENDPOINT}")
    print(f"  Model    : {FOUNDRY_MODEL}")
    print(f"  Image    : {image_path}")
    print(f"  Policy   : {args.policy or 'from intake'}")
    print(f"  Claim ID : {args.claim_id}\n")

    output = run_claims_pipeline(
        image_path=image_path,
        claim_id=args.claim_id,
        claim_amount=args.amount,
        policy_number=args.policy or None,
    )

    print("\n--- Final Decision ---")
    print(json.dumps(output, indent=2))

    print("\n" + "=" * 60)
    print("CHALLENGE 3 COMPLETE")
    print("=" * 60)
    print("  Step 1 - claims-intake-agent        complete")
    print("  Step 2 - policy-extraction-agent    complete")
    print("  Step 3 - coverage-decision-agent    complete")
    review_status = "complete" if "human_review" in output else "not required"
    print(f"  Step 4 - human review (conditional) {review_status}")


if __name__ == "__main__":
    main()