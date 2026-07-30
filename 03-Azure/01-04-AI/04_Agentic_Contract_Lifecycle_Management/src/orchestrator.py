"""Challenge 4 — Orchestrator agent (GPT-5.4) with specialist agents as tools.

Builds the front-door **Orchestrator** on GPT-5.4 and attaches the two
specialists (Intake & Drafting, Clause & Risk) as **tools** using the Microsoft
Agent Framework's `agent.as_tool(...)`. The orchestrator routes each user request
to the right specialist, manages hand-offs and human-in-the-loop review.

A GPT orchestrator calling Claude- and GPT-backed specialists demonstrates multi-model
composition inside one Foundry project — the model only changes on each agent's
Foundry chat client.

Run:
    python src/orchestrator.py                 # one session: draft → analyze → risk
"""
from __future__ import annotations

import asyncio
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))             # src (clm_common, kb_setup)
sys.path.insert(0, str(Path(__file__).resolve().parent / "agents"))  # agent modules

import tracing_setup  # noqa: E402  (Challenge 3 — sets content-recording flag before agent_framework loads)

from clm_common.config import settings  # noqa: E402
from clm_common.foundry import build_chat_client, run_agent  # noqa: E402

ORCHESTRATOR_NAME = "clm-orchestrator"

INSTRUCTIONS = """\
You are the CLM Orchestrator for Contoso Global — the single front door for Legal & Procurement.

You have two specialist agents available as tools:
- `intake_drafting` — drafts NDA/MSA/SOW from approved templates and answers cited questions about
  clauses, policies and contract status.
- `clause_risk` — analyzes a counterparty draft: extracts clauses, compares to our standard, flags
  deviations and returns a risk score.

ROUTING
- Drafting a document, or a question about our templates/policies/contract status → `intake_drafting`.
- Reviewing/analyzing an incoming counterparty draft or asking about its risk → `clause_risk`.
- A multi-step request (e.g. "draft X then analyze the counterparty's redline") → call them in order
  and combine the results.

HUMAN-IN-THE-LOOP
- For anything flagged High risk or any final document, clearly recommend human review before signing.
- Never provide legal advice yourself; defer to the specialists and to human counsel.
Summarize each specialist's output for the user and state which agent you used.
"""


def build_orchestrator():
    """Create the two specialists, expose them as tools, and wire the orchestrator."""
    from intake_drafting_agent import create_agent as create_intake
    from clause_risk_agent import create_agent as create_clause_risk
    from kb_setup import get_search_connection_id
    from clm_common.foundry import get_project_client

    # Resolve the Azure AI Search connection once and share it with both specialists.
    with get_project_client() as project:
        connection_id = get_search_connection_id(project)

    intake = create_intake(connection_id=connection_id)
    clause_risk = create_clause_risk(connection_id=connection_id)

    intake_tool = intake.as_tool(
        name="intake_drafting",
        description="Draft NDA/MSA/SOW from approved templates; answer cited questions about "
        "clauses, policies and contract status.",
        arg_name="request",
        arg_description="The drafting or knowledge request to hand to the Intake & Drafting agent.",
    )
    clause_tool = clause_risk.as_tool(
        name="clause_risk",
        description="Analyze a counterparty draft: extract clauses, compare to standard, flag "
        "deviations, return a risk score.",
        arg_name="request",
        arg_description="The counterparty draft (or question about it) to hand to the Clause & Risk agent.",
    )

    from agent_framework import Agent

    return Agent(
        client=build_chat_client(settings.model_orchestrator),  # gpt-5.4
        name=ORCHESTRATOR_NAME,
        instructions=INSTRUCTIONS,
        tools=[intake_tool, clause_tool],
    )


DEMO = [
    "Draft a mutual NDA between Contoso Global and Acme Corp for a 2-year term.",
    "Now review the Acme MSA counterparty draft we received and give me its risk score.",
    "What's the renewal date and risk level of contract CT-4821?",
]


async def main() -> None:
    # Challenge 3 — export this run's spans to Application Insights (per-process).
    from clm_common.foundry import get_project_client
    with get_project_client() as project:
        tracing_setup.enable_tracing(project)

    orchestrator = build_orchestrator()
    print(f"✓ Orchestrator on '{settings.model_orchestrator}' with 2 specialists as tools\n")

    session = orchestrator.create_session()
    for prompt in DEMO:
        print("―" * 80)
        print("USER:", prompt)
        print("ORCHESTRATOR:", await run_agent(orchestrator, prompt, session=session), "\n")


if __name__ == "__main__":
    asyncio.run(main())
