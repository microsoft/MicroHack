"""Challenge 1 — smoke test.

Verifies the environment is wired up before you start building agents:
  1. `.env` is loaded and required variables are present.
  2. The Foundry project is reachable and the Microsoft Agent Framework can build
     and run a tiny agent on each GPT deployment in the fleet (orchestrator +
     drafting + Clause & Risk + renewal), proving the multi-model GPT fleet.

Run:  python src/scripts/smoke_test.py
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from clm_common.config import settings  # noqa: E402
from clm_common.foundry import build_chat_client, run_prompt  # noqa: E402


def check_env() -> bool:
    ok = True
    print("1) Checking environment…")
    required = {
        "AZURE_AI_PROJECT_ENDPOINT": settings.project_endpoint,
        "MODEL_ORCHESTRATOR": settings.model_orchestrator,
        "MODEL_DRAFTING": settings.model_drafting,
        "MODEL_CLAUSE_RISK": settings.model_clause_risk,
        "MODEL_RENEWAL": settings.model_renewal,
    }
    for name, value in required.items():
        status = "✓" if value else "✗ MISSING"
        print(f"   {status} {name} = {value or ''}")
        ok = ok and bool(value)
    return ok


def ping_model(model: str, label: str) -> bool:
    print(f"2) Pinging {label} deployment '{model}'…")
    try:
        from agent_framework import Agent

        agent = Agent(
            client=build_chat_client(model),
            name=f"smoke-{label}",
            instructions="Reply with exactly one word: OK.",
        )
        reply = run_prompt(agent, "Say OK.")
        print(f"   ✓ {label} replied: {reply.strip()[:60]}")
        return bool(reply.strip())
    except Exception as exc:  # noqa: BLE001
        print(f"   ✗ {label} failed: {exc}")
        return False


def main() -> int:
    if not check_env():
        print("\n✗ Environment incomplete. Run labautomation/deploy.sh or fill .env, then retry.")
        return 1

    # Ping each DISTINCT model deployment once. The drafting agent shares the
    # gpt-5.4 orchestrator deployment, so it dedupes automatically — this proves
    # the multi-model GPT fleet is reachable via the Foundry chat client.
    fleet = [
        (settings.model_orchestrator, "orchestrator"),
        (settings.model_drafting, "drafting"),
        (settings.model_clause_risk, "clause-risk"),
        (settings.model_renewal, "renewal"),
    ]
    seen: dict[str, str] = {}
    results: list[bool] = []
    for model, label in fleet:
        if not model:
            continue
        if model in seen:
            print(f"   · {label} shares deployment '{model}' with {seen[model]} — already verified.")
            continue
        seen[model] = label
        results.append(ping_model(model, label))

    all_ok = bool(results) and all(results)
    print("\nSmoke test:", "✅ PASS" if all_ok else "⚠️  PARTIAL (see notes above)")
    return 0 if all_ok else 2


if __name__ == "__main__":
    raise SystemExit(main())
