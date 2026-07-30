"""Challenge 1 — smoke test.

Verifies the environment is wired up before you start building agents:
  1. `.env` is loaded and required variables are present.
  2. The Foundry project is reachable and the Microsoft Agent Framework can build
     and run a tiny agent on the GPT deployments (orchestrator + Clause & Risk)
     AND on the Claude deployment (proving the multi-model fleet).

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
        if label == "claude":
            print("     → If Claude isn't served via the Foundry chat client in your region,")
            print("       see challenges/challenge-02.md for the Anthropic-SDK fallback.")
        return False


def main() -> int:
    if not check_env():
        print("\n✗ Environment incomplete. Run labautomation/deploy.sh or fill .env, then retry.")
        return 1

    gpt_ok = ping_model(settings.model_orchestrator, "gpt")

    # Clause & Risk runs on its own GPT deployment (gpt-5.6-sol) — always present,
    # independent of the Claude gate. Skip only if it equals a model already pinged.
    if settings.model_clause_risk and settings.model_clause_risk != settings.model_orchestrator:
        clause_ok = ping_model(settings.model_clause_risk, "clause-risk")
    else:
        clause_ok = gpt_ok

    # When Claude was skipped at deploy time (DEPLOY_CLAUDE_MODEL=false), the
    # drafting deployment falls back to the orchestrator model, so
    # MODEL_DRAFTING == MODEL_ORCHESTRATOR. Don't ping (or require) Claude then.
    # (Clause & Risk always runs on its own gpt-5.6-sol deployment.)
    claude_skipped = settings.model_drafting == settings.model_orchestrator
    if claude_skipped:
        print(
            "2) Claude skipped (MODEL_DRAFTING == MODEL_ORCHESTRATOR) — the drafting\n"
            "   agent runs on the orchestrator model. Skipping Claude ping."
        )
        claude_ok = gpt_ok
    else:
        claude_ok = ping_model(settings.model_drafting, "claude")

    all_ok = gpt_ok and clause_ok and claude_ok
    print("\nSmoke test:", "✅ PASS" if all_ok else "⚠️  PARTIAL (see notes above)")
    return 0 if all_ok else 2


if __name__ == "__main__":
    raise SystemExit(main())
