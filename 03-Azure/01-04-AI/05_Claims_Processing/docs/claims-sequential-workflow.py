#!/usr/bin/env python3
"""Run the two Foundry agents from Challenges 2 and 3 as one sequential workflow."""

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
    agent_status = result.get("status", "UNKNOWN")

    print("  [Step 3] Human review requested...")
    print(
        f"    Decision status: {agent_status} | "
        f"confidence: {confidence_score:.2f} | "
        f"threshold: {HUMAN_REVIEW_CONFIDENCE_THRESHOLD:.2f}"
    )

    if not sys.stdin.isatty():
        raise RuntimeError(
            "Human review is required, but the workflow is running in a non-interactive terminal."
        )

    result["status"] = "PENDING_HUMAN_REVIEW"
    result["human_review"] = {
        "required": True,
        "status": "pending",
        "agent_status": agent_status,
        "confidence_threshold": HUMAN_REVIEW_CONFIDENCE_THRESHOLD,
    }
    print("    Workflow paused. Waiting for human-in-the-loop input.", flush=True)

    while True:
        reviewer_action = input(
            "    Type 'approve' to accept, 'escalate' for manual review, "
            "or 'deny' to override: "
        ).strip().lower()

        if reviewer_action in {"approve", "a", "yes", "y"}:
            human_status = "confirmed"
            final_status = agent_status
            break
        if reviewer_action in {"escalate", "e", "review", "manual"}:
            human_status = "escalated"
            final_status = "ESCALATED"
            break
        if reviewer_action in {"deny", "d", "reject", "r"}:
            human_status = "overridden"
            final_status = "DENIED"
            break

        print("    Invalid response. Enter approve, escalate, or deny.", flush=True)

    result["status"] = final_status
    result["human_review"].update(
        {
            "status": human_status,
            "reviewer_action": reviewer_action,
            "final_status": final_status,
        }
    )

    print("  [Step 3] Human review complete.")
    return result


def run_claims_pipeline(
    image_path: Path | None,
    claim_id: str,
    claim_amount: float,
    policy_number: str | None,
    indexed_claim: str | None = None,
) -> dict:
    """Run the existing intake and unified claims intelligence agents."""
    intake_module = _load_challenge_module("claims_intake_agent", "claims-intake-agent.py")
    intelligence_module = _load_challenge_module(
        "claims_intelligence_agent", "claims-intelligence-agent.py"
    )

    print("  [Step 1] claims-intake-agent running...")
    if indexed_claim:
        intake_result = intake_module.run_indexed_claim_intake(indexed_claim)
    elif image_path:
        intake_result = intake_module.run_claims_intake(image_path)
    else:
        raise ValueError("An image path or indexed claim reference is required.")
    claim = intelligence_module.build_claim_from_intake(
        intake_result, claim_amount, policy_number
    )
    print("  [Step 1] Intake complete.")

    state = intelligence_module.ClaimProcessingState(claim_id=claim_id)
    state.structured_claim = claim
    intelligence = intelligence_module.ClaimsIntelligenceAgent()

    print("  [Step 2] claims-intelligence-agent running...")
    result = intelligence.validate_coverage(state).to_result_dict()
    print("  [Step 2] Intelligence complete.")

    if _requires_human_review(result):
        result = _run_human_review(result)

    return result


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Run the two-agent sequential claims workflow"
    )
    parser.add_argument(
        "image_path",
        nargs="?",
        help="Path to the accident statement image used by Challenge 2",
    )
    parser.add_argument(
        "--indexed-claim",
        default="",
        help="Retrieve an existing front statement from Foundry IQ and skip OCR",
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
        print("FOUNDRY_PROJECT_ENDPOINT is not set. Complete Challenges 2 and 3 first.")
        sys.exit(1)
    if bool(args.image_path) == bool(args.indexed_claim):
        parser.error("provide either image_path or --indexed-claim, but not both")

    image_path = Path(args.image_path).expanduser().resolve() if args.image_path else None
    print("\nClaims Sequential Workflow")
    print(f"  Endpoint : {FOUNDRY_PROJECT_ENDPOINT}")
    print(f"  Model    : {FOUNDRY_MODEL}")
    print(f"  Input    : {image_path or f'Foundry IQ claim {args.indexed_claim}'}")
    print(f"  Policy   : {args.policy or 'from intake'}")
    print(f"  Claim ID : {args.claim_id}\n")

    output = run_claims_pipeline(
        image_path=image_path,
        claim_id=args.claim_id,
        claim_amount=args.amount,
        policy_number=args.policy or None,
        indexed_claim=args.indexed_claim or None,
    )

    print("\n--- Final Decision ---")
    print(json.dumps(output, indent=2))

    print("\n" + "=" * 60)
    print("CHALLENGE 4 COMPLETE")
    print("=" * 60)
    print("  Step 1 - claims-intake-agent        complete")
    print("  Step 2 - claims-intelligence-agent  complete")
    review_status = "complete" if "human_review" in output else "not required"
    print(f"  Step 3 - human review (conditional) {review_status}")


if __name__ == "__main__":
    main()