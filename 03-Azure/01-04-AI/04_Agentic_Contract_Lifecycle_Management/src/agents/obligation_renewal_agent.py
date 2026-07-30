"""Challenge 5 — Obligation & Renewal agent (GPT-5-mini).

A small, cheap, high-frequency Microsoft Agent Framework agent that scans
contract renewal dates and obligations (via the contract-status tools) and
produces alert-ready summaries of what's coming due. Its output feeds the
proactive Teams alerts in proactive_alerts.py.

Run:
    python src/agents/obligation_renewal_agent.py            # summarize upcoming renewals
    python src/agents/obligation_renewal_agent.py --days 60
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))  # src (clm_common)

import tracing_setup  # noqa: E402  (Challenge 3 — sets content-recording flag before agent_framework loads)

from clm_common.config import settings  # noqa: E402
from clm_common.foundry import build_chat_client, function_tool, run_prompt  # noqa: E402
from clm_common.tools import get_contract_status, list_upcoming_renewals  # noqa: E402

AGENT_NAME = "obligation-renewal-agent"

INSTRUCTIONS = """\
You are the Obligation & Renewal agent for Contoso Global.

TASK
- Use the `list_upcoming_renewals` tool to find contracts due for renewal in the requested window.
- Use `get_contract_status` to enrich any specific contract when needed.
- For each contract nearing renewal, produce a SHORT alert line suitable for a Teams message:
  contract id, counterparty, days until renewal, auto-renew flag, notice window, and risk level.
- Prioritize HIGH-risk and auto-renewing contracts (missing the notice window is costly).

STYLE
- Be terse and factual — these become notifications, not essays.
- Start each alert with an emoji: 🔴 High risk, 🟠 Medium, 🟢 Low.
- End with a one-line recommended action (e.g. "Send notice by <date> to avoid auto-renew").
"""


def create_agent(model: str | None = None):
    """Create the Obligation & Renewal agent with the contract function tools."""
    from agent_framework import Agent

    return Agent(
        client=build_chat_client(model or settings.model_renewal),  # gpt-5-mini
        name=AGENT_NAME,
        instructions=INSTRUCTIONS,
        tools=[function_tool(get_contract_status), function_tool(list_upcoming_renewals)],
    )


def summarize_renewals(days: int = 90) -> str:
    """Return an alert-ready summary of contracts due within `days` (sync helper)."""
    agent = create_agent()
    prompt = (
        f"List all contracts due for renewal within {days} days and produce a prioritized "
        "alert summary. Flag anything high-risk or auto-renewing."
    )
    return run_prompt(agent, prompt)


def main() -> None:
    # Challenge 3 — export this run's spans to Application Insights (per-process).
    from clm_common.foundry import get_project_client
    with get_project_client() as project:
        tracing_setup.enable_tracing(project)

    parser = argparse.ArgumentParser()
    parser.add_argument("--days", type=int, default=90, help="renewal look-ahead window")
    args = parser.parse_args()

    print(f"✓ Obligation & Renewal agent on '{settings.model_renewal}' — window {args.days}d\n")
    print(summarize_renewals(args.days))


if __name__ == "__main__":
    main()
