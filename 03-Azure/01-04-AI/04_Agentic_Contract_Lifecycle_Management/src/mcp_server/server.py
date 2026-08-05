"""Challenge 4 — MCP server exposing the CLM workflow as reusable tools.

Wraps the orchestrated CLM capabilities as Model Context Protocol tools so any
MCP client (VS Code, GitHub Copilot, another Foundry agent) can call them. Uses
the official `mcp` package (FastMCP) over stdio for local dev.

Tools exposed:
  • draft_contract(contract_type, party, term)  → drafts from approved templates
  • analyze_contract(draft_text)                → clause extraction + risk score
  • get_contract_status(contract_id)            → structured status lookup

Verify the tools are registered (prints the 3 tools and exits — no client needed):
    python src/mcp_server/server.py --list

Run (stdio, for an MCP client to launch):
    python src/mcp_server/server.py

A stdio server has no console UI: once it starts it waits silently for a client
to speak JSON-RPC over stdin. Don't type into that window — a stray keystroke or
Enter is not valid JSON, so the server logs a harmless red
``Invalid JSON … Internal Server Error`` and keeps running. Use ``--list`` above
to confirm the tools, then point VS Code at it via src/.vscode/mcp.json.
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))            # src (clm_common)
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "agents"))  # agent modules

from mcp.server.fastmcp import FastMCP  # noqa: E402

from clm_common.tools import get_contract_status as _get_contract_status  # noqa: E402

mcp = FastMCP("clm-mcp")


def _run_agent(create_agent_fn, prompt: str) -> str:
    """Build a specialist Agent Framework agent, run one prompt, return the text."""
    from clm_common.foundry import run_prompt

    agent = create_agent_fn()
    return run_prompt(agent, prompt)


@mcp.tool()
def draft_contract(contract_type: str, party: str, term: str = "1 year") -> str:
    """Draft a contract from Contoso Global's approved templates.

    :param contract_type: One of NDA, MSA, SOW.
    :param party: The counterparty name, e.g. "Acme Corp".
    :param term: Contract term, e.g. "2 years".
    """
    from intake_drafting_agent import create_agent

    prompt = f"Draft a {contract_type} between Contoso Global and {party} for a {term} term."
    return _run_agent(create_agent, prompt)


@mcp.tool()
def analyze_contract(draft_text: str) -> str:
    """Extract clauses from a counterparty draft, compare to standard, and return a risk score.

    :param draft_text: The full text of the counterparty draft to analyze.
    """
    from clause_risk_agent import create_agent

    prompt = (
        "Analyze this counterparty draft. Extract clauses, compare to our standard, flag "
        "deviations, and give an overall risk score with the top 3 issues.\n\n" + draft_text
    )
    return _run_agent(create_agent, prompt)


@mcp.tool()
def get_contract_status(contract_id: str) -> str:
    """Look up a contract's status, renewal date, risk and owner by ID (e.g. "CT-4821")."""
    return _get_contract_status(contract_id)


def _list_tools() -> None:
    """Print the registered tools and exit — a client-free smoke test.

    Runs the same ``list_tools`` the protocol exposes, so it proves the tools are
    registered (and the module imports cleanly) without the stdio handshake that
    a raw ``mcp.run`` needs. No Foundry agent is created — the heavy imports stay
    lazy inside each tool.
    """
    import asyncio

    tools = asyncio.run(mcp.list_tools())
    print(f"clm-mcp exposes {len(tools)} tool(s):")
    for t in tools:
        summary = (t.description or "").strip().splitlines()[0] if t.description else ""
        print(f"  • {t.name}: {summary}")


if __name__ == "__main__":
    if "--list" in sys.argv[1:] or "--tools" in sys.argv[1:]:
        _list_tools()
    else:
        mcp.run(transport="stdio")
