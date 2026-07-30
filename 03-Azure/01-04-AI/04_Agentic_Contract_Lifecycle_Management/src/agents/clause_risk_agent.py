"""Challenge 4 — Clause Extraction & Risk agent (GPT-5.6 Sol).

Ingests a counterparty draft, extracts key clauses, compares them to Contoso
Global's enterprise standard (the clause library in the corpus), flags deviations
and returns a risk score with rationale. Built with the **Microsoft Agent
Framework** and runs on GPT-5.6 Sol for structured legal reasoning. Reuses the Ch2
grounding pattern, so it's fast to build.

Run:
    python src/agents/clause_risk_agent.py            # analyze BOTH sample drafts
    python src/agents/clause_risk_agent.py --draft src/data/counterparty_drafts/globex_nda_redline.pdf  # one draft
"""
from __future__ import annotations

import argparse
import asyncio
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))  # src (clm_common, kb_setup)

import tracing_setup  # noqa: E402  (Challenge 3 — sets content-recording flag before agent_framework loads)

from clm_common.config import settings, DATA_DIR  # noqa: E402
from clm_common.documents import read_document_text  # noqa: E402
from clm_common.foundry import build_chat_client, run_agent  # noqa: E402

AGENT_NAME = "clause-risk-agent"

# Inbound counterparty drafts analyzed by default (both are full of graded red flags).
SAMPLE_DRAFTS = [
    DATA_DIR / "counterparty_drafts" / "acme_msa_draft.pdf",
    DATA_DIR / "counterparty_drafts" / "globex_nda_redline.pdf",
]

INSTRUCTIONS = """\
You are the Clause Extraction & Risk agent for Contoso Global's Legal team.

TASK
Given a counterparty contract draft, you:
1. Extract the key clauses (e.g. limitation of liability, indemnification, termination,
   auto-renewal, governing law, confidentiality, payment terms).
2. Compare each to Contoso Global's enterprise standard in your knowledge base (the clause library
   and contracting policy).
3. Flag every deviation, classify it (Acceptable / Needs negotiation / Unacceptable), and explain WHY.
4. Return an overall RISK SCORE: Low / Medium / High, with a short rationale and the top 3 issues.

RULES
- Ground your comparison in the retrieved standard clauses and policy; cite them.
- Be specific: quote the counterparty language and the standard it violates.
- For each deviation classified 'Needs negotiation', cite the negotiation playbook's recommended
  fallback position (the approved counter-position(s) to propose, in order).
- For each High-risk item, state the required approver / escalation per the delegation-of-authority
  matrix (who must sign off, by role/threshold) — never self-approve.
- You are NOT a lawyer and do NOT give legal advice or enforceability opinions — you flag risk for
  human counsel to decide. Recommend human review for anything High risk.
- Output a concise structured summary (clauses table + overall risk + top 3 issues).

WEB / EXTERNAL LOOKUP (only when a web-search tool is attached)
- Your KNOWLEDGE BASE (corpus) is the SOLE authority for Contoso's standards, clause library, policy
  and negotiation playbook — never override it with the web.
- Use web search ONLY for external, PUBLIC context that helps assess the counterparty: corporate
  status, adverse-media / litigation news, sanctions or watchlist mentions, and current public
  regulatory references. Cite each web source (title + URL) and its date.
- PRIVACY: never send the counterparty's confidential draft text to the web tool — search only public
  facts (company name, jurisdiction, regulation name). Web data leaves the Azure compliance boundary.
- Web findings are informational only; they never change a clause classification on their own — flag
  them for human counsel to weigh.
"""


def create_agent(model: str | None = None, *, connection_id: str | None = None):
    """Create the Clause & Risk agent grounded on the enterprise clause library.

    When a Grounding-with-Bing-Search connection is configured (``AZURE_BING_CONNECTION_NAME``),
    a web-search tool is also attached for external counterparty due-diligence;
    otherwise the agent runs corpus-only, unchanged.
    """
    from agent_framework import Agent
    from kb_setup import build_knowledge_tool, build_web_search_tool

    tools = [build_knowledge_tool(connection_id=connection_id)]
    web_search = build_web_search_tool()  # None unless Bing is configured
    if web_search is not None:
        tools.append(web_search)

    return Agent(
        client=build_chat_client(model or settings.model_clause_risk),  # gpt-5.6-sol
        name=AGENT_NAME,
        instructions=INSTRUCTIONS,
        tools=tools,
    )


async def _analyze_draft(agent, draft_path) -> None:
    """Read one counterparty draft and run the clause/risk analysis against it."""
    draft_text = read_document_text(str(draft_path))
    prompt = (
        "Analyze the following counterparty draft. Extract clauses, compare to our enterprise "
        "standard, flag deviations, and give an overall risk score with the top 3 issues.\n\n"
        f"=== COUNTERPARTY DRAFT ({Path(draft_path).name}) ===\n{draft_text}"
    )
    print("―" * 80)
    print(f"DRAFT: {Path(draft_path).name}")
    print(await run_agent(agent, prompt))


async def main() -> None:
    # Challenge 3 — export this run's spans to Application Insights (per-process).
    from clm_common.foundry import get_project_client
    with get_project_client() as project:
        tracing_setup.enable_tracing(project)

    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--draft",
        default=None,
        help=(
            "path to a single counterparty draft to analyze (.pdf or .md). "
            "If omitted, both sample drafts (acme_msa_draft.pdf and globex_nda_redline.pdf) "
            "are analyzed."
        ),
    )
    args = parser.parse_args()

    drafts = [args.draft] if args.draft else SAMPLE_DRAFTS

    agent = create_agent()
    print(f"✓ Built {AGENT_NAME} on model '{settings.model_clause_risk}'\n")
    for draft in drafts:
        await _analyze_draft(agent, draft)


if __name__ == "__main__":
    asyncio.run(main())
