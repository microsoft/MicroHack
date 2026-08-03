"""Challenge 2 — Intake & Drafting agent (gpt-5.4).

Builds a grounded, cited, tool-enabled, guard-railed agent with the **Microsoft
Agent Framework** that:
  • drafts NDA/MSA/SOW from APPROVED templates in the corpus,
  • answers questions about clauses/policies with citations (Foundry IQ),
  • calls the `get_contract_status` function tool for structured lookups,
  • REFUSES to give legal advice (guardrail).

The agent runs on the **gpt-5.4** deployment (MODEL_DRAFTING) — the highest-quota
flagship in the Foundry project. Note how the Agent Framework code is identical
across models — only the `model` on the Foundry chat client changes.

Run:
    python src/agents/intake_drafting_agent.py            # interactive demo
"""
from __future__ import annotations

import asyncio
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))          # src (clm_common, kb_setup)
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "agents"))  # sibling agent modules

import tracing_setup  # noqa: E402  (Challenge 3 — sets content-recording flag before agent_framework loads)

from clm_common.config import settings  # noqa: E402
from clm_common.foundry import build_chat_client, function_tool, run_agent_with_retry  # noqa: E402
from clm_common.tools import get_contract_status  # noqa: E402

AGENT_NAME = "intake-drafting-agent"

INSTRUCTIONS = """\
You are the Intake & Drafting agent for Contoso Global's Legal & Procurement team.

WHAT YOU DO
- Draft NDAs, MSAs and SOWs using ONLY the approved templates and clause library in your knowledge
  base. Fill placeholders with the details the user provides; never invent legal terms.
- Answer questions about clauses, policies and standards using your knowledge base, and ALWAYS cite
  the source documents you used.
- When asked about a specific contract's status, renewal date, risk or owner, call the
  `get_contract_status` tool. Do not guess these facts.

NEGOTIATION FALLBACKS
- When a requested term deviates from an approved template or standard clause, consult the
  negotiation playbook in your knowledge base and offer the approved fallback positions IN ORDER
  (from the preferred position down to the walk-away position). Always cite the negotiation playbook.

APPROVAL AUTHORITY (delegation of authority)
- When a draft or requested term needs sign-off — e.g. a liability cap above a threshold, a
  non-standard or off-template term, or an unusual commercial commitment — consult the
  delegation-of-authority matrix in your knowledge base and state WHO must approve it by
  role/threshold. Cite the matrix. Never self-approve and never tell the user a term is approved on
  your own authority; route it to the correct approver for human sign-off.

GROUNDING & CITATIONS
- Base every substantive answer on retrieved corpus content. If the corpus does not contain the
  answer, say so plainly rather than speculating.

GUARDRAILS (must follow)
- You are NOT a lawyer and must NOT provide legal advice, legal opinions, or predictions about
  litigation/enforceability. If asked, refuse briefly and recommend review by qualified counsel.
- Do not disclose personal data or content outside the approved corpus.
- Keep a professional, concise tone. Flag anything that deviates from company policy for human review.
"""


def create_agent(model: str | None = None, *, connection_id: str | None = None):
    """Create the Intake & Drafting agent with knowledge grounding + a function tool.

    :param model: model deployment to run on (defaults to MODEL_DRAFTING / gpt-5.4).
        Override it to run the same agent on another deployment (e.g. Ch3 bake-off).
    :param connection_id: optional Azure AI Search connection id to reuse instead of
        resolving the project's default connection again.
    """
    from agent_framework import Agent
    from kb_setup import build_knowledge_tool

    knowledge = build_knowledge_tool(connection_id=connection_id)

    return Agent(
        client=build_chat_client(model or settings.model_drafting),  # gpt-5.4
        name=AGENT_NAME,
        instructions=INSTRUCTIONS,
        tools=[knowledge, function_tool(get_contract_status)],
    )


DEMO_PROMPTS = [
    "Draft a mutual NDA between Contoso Global and Acme Corp for a 2-year term.",
    "What does our standard limitation-of-liability clause say, and what's the cap?",
    "The counterparty demands unlimited liability. What fallback positions can we offer, in order, "
    "per our negotiation playbook?",
    "We're about to sign a $5M MSA with a liability cap well above our standard. Who must approve "
    "this under our delegation-of-authority matrix?",
    "What is the status and renewal date of contract CT-4821?",
    "Should we sue Acme for breach — will we win in court?",  # must be refused
]


async def main() -> None:
    # Challenge 3 — export this run's OpenTelemetry spans to Application Insights
    # (and the Foundry portal Tracing tab). Tracing is per-process, so every demo
    # entry point must enable it; without this the run emits no spans.
    from clm_common.foundry import get_project_client
    with get_project_client() as project:
        tracing_setup.enable_tracing(project)

    agent = create_agent()
    print(f"✓ Built {AGENT_NAME} on model '{settings.model_drafting}'\n")

    session = agent.create_session()  # one session → the demo prompts share context
    for prompt in DEMO_PROMPTS:
        print("―" * 80)
        print("USER:", prompt)
        # Retry rate-limit (429) throttling with backoff, and isolate each prompt so
        # one failure doesn't abort the whole demo — the run continues with the next.
        try:
            answer = await run_agent_with_retry(agent, prompt, session=session)
            print("AGENT:", answer, "\n")
        except Exception as exc:  # noqa: BLE001 — keep the demo going past a failed prompt
            print(f"AGENT: ⚠️  Skipped after error: {exc}\n")


if __name__ == "__main__":
    asyncio.run(main())
