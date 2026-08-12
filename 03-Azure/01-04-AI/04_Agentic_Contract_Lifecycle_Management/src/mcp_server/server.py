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

Run locally over stdio (for an MCP client — e.g. VS Code — to launch):
    python src/mcp_server/server.py

Run as a *remote* server over streamable HTTP (for Azure Container Apps / Foundry):
    python src/mcp_server/server.py --http        # serves POST/GET on http://0.0.0.0:8000/mcp
    #  or set MCP_TRANSPORT=streamable-http (what the Dockerfile does)
    #  MCP_HOST / MCP_PORT override the bind address (default 0.0.0.0:8000)

A stdio server has no console UI: once it starts it waits silently for a client
to speak JSON-RPC over stdin. Don't type into that window — a stray keystroke or
Enter is not valid JSON, so the server logs a harmless red
``Invalid JSON … Internal Server Error`` and keeps running. Use ``--list`` above
to confirm the tools, then point VS Code at it via .vscode/mcp.json (repo root).

The HTTP transport is what makes the workflow **remotely** consumable: host this
container in Azure, and a Foundry agent (portal Playground or ``orchestrator_mcp.py``
with ``CLM_MCP_URL``) reaches the exact same tools over ``https://<host>/mcp``.
"""
from __future__ import annotations

import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))            # src (clm_common)
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "agents"))  # agent modules

from mcp.server.fastmcp import FastMCP  # noqa: E402
from mcp.server.transport_security import TransportSecuritySettings  # noqa: E402

from clm_common.tools import get_contract_status as _get_contract_status  # noqa: E402

mcp = FastMCP("clm-mcp")


async def _run_agent(create_agent_fn, prompt: str) -> str:
    """Build a specialist Agent Framework agent, run one prompt, return the text.

    This is ``async`` on purpose. FastMCP invokes a *synchronous* tool function
    directly inside its own already-running event loop, so a sync tool that
    blocked on the agent (``run_prompt`` → ``loop.run_until_complete``) crashed
    with ``RuntimeError: Cannot run the event loop while another loop is
    running`` the moment a client actually called it over HTTP. Awaiting the
    async agent (``run_agent_with_retry``) on the loop FastMCP is already running
    avoids the nested loop entirely — and adds transient-error retry for free.
    """
    from clm_common.foundry import run_agent_with_retry

    agent = create_agent_fn()
    return await run_agent_with_retry(agent, prompt)


@mcp.tool()
async def draft_contract(contract_type: str, party: str, term: str = "1 year") -> str:
    """Draft a contract from Contoso Global's approved templates.

    :param contract_type: One of NDA, MSA, SOW.
    :param party: The counterparty name, e.g. "Acme Corp".
    :param term: Contract term, e.g. "2 years".
    """
    from intake_drafting_agent import create_agent

    prompt = f"Draft a {contract_type} between Contoso Global and {party} for a {term} term."
    return await _run_agent(create_agent, prompt)


@mcp.tool()
async def analyze_contract(draft_text: str) -> str:
    """Extract clauses from a counterparty draft, compare to standard, and return a risk score.

    :param draft_text: The full text of the counterparty draft to analyze.
    """
    from clause_risk_agent import create_agent

    prompt = (
        "Analyze this counterparty draft. Extract clauses, compare to our standard, flag "
        "deviations, and give an overall risk score with the top 3 issues.\n\n" + draft_text
    )
    return await _run_agent(create_agent, prompt)


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


def _run_http() -> None:
    """Serve the tools over **streamable HTTP** so a remote client can reach them.

    This is the transport used when the server is containerized and hosted (e.g.
    Azure Container Apps): a Foundry agent connects to ``https://<host>/mcp``.
    Bind address is configurable via ``MCP_HOST`` / ``MCP_PORT`` (the Dockerfile
    sets ``0.0.0.0:8000``); the MCP endpoint path is ``/mcp``.
    """
    mcp.settings.host = os.getenv("MCP_HOST", "0.0.0.0")
    mcp.settings.port = int(os.getenv("MCP_PORT", "8000"))

    # --- Accept the public (container) Host header --------------------------------
    # FastMCP is constructed with its default host (127.0.0.1), so it auto-enables
    # DNS-rebinding protection with a *localhost-only* Host allowlist. Behind Azure
    # Container Apps ingress the incoming Host header is the public FQDN, which that
    # allowlist rejects with **421 "Invalid Host header"** — so a Foundry agent
    # can't even enumerate the tools. DNS-rebinding protection only guards servers
    # reachable at localhost from a victim's browser; it's inapplicable to an
    # intentionally public, hosted endpoint, so we relax it here. To lock the server
    # down to specific hostnames instead, set MCP_ALLOWED_HOSTS to a comma-separated
    # allowlist (e.g. "clm-mcp.<hash>.<region>.azurecontainerapps.io").
    allowed_hosts = [h.strip() for h in os.getenv("MCP_ALLOWED_HOSTS", "").split(",") if h.strip()]
    if allowed_hosts:
        mcp.settings.transport_security = TransportSecuritySettings(
            enable_dns_rebinding_protection=True,
            allowed_hosts=allowed_hosts,
            allowed_origins=[f"https://{h}" for h in allowed_hosts],
        )
    else:
        mcp.settings.transport_security = TransportSecuritySettings(
            enable_dns_rebinding_protection=False,
        )

    print(
        f"clm-mcp serving over streamable HTTP on "
        f"http://{mcp.settings.host}:{mcp.settings.port}{mcp.settings.streamable_http_path}",
        flush=True,
    )
    mcp.run(transport="streamable-http")


def _http_requested() -> bool:
    """True when HTTP transport is asked for via a flag or MCP_TRANSPORT env."""
    argv = sys.argv[1:]
    if "--http" in argv or "--streamable-http" in argv:
        return True
    return os.getenv("MCP_TRANSPORT", "").strip().lower() in {"streamable-http", "http", "sse"}


if __name__ == "__main__":
    if "--list" in sys.argv[1:] or "--tools" in sys.argv[1:]:
        _list_tools()
    elif _http_requested():
        _run_http()
    else:
        mcp.run(transport="stdio")
