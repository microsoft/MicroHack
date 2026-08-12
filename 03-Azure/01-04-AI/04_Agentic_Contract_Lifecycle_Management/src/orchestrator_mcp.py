"""Challenge 4 (optional) — Orchestrator that calls the CLM MCP server as a *client*.

This is the mirror image of ``orchestrator.py``. The plain orchestrator wires the
two specialists in-process with ``agent.as_tool(...)``; this variant reaches the
**same** workflow over the **Model Context Protocol** instead. The Orchestrator
(GPT-5.4) is the natural — and only non-circular — MCP consumer: the specialists
themselves are what the server *exposes* (``draft_contract`` = Intake & Drafting,
``analyze_contract`` = Clause & Risk), so a specialist consuming the server would
call itself. The orchestrator is the front door and is never an MCP tool, so it
can safely fan out over MCP.

The Microsoft Agent Framework ships the client side as two tools that share one
API: ``MCPStdioTool`` spawns ``src/mcp_server/server.py`` over stdio (local dev),
and ``MCPStreamableHTTPTool`` connects to a **remote** server over HTTPS — the
same ``clm-mcp`` container you host on Azure in Task 4. This script picks between
them from the ``CLM_MCP_URL`` env var (unset → local stdio; set → remote HTTP), so
the exact same orchestrator can drive the workflow in-process, over local stdio,
or over the network with no code change. To use a Foundry-hosted MCP tool instead,
swap in ``MCPTool``; the orchestrator wiring below is otherwise unchanged.

Run:
    python src/orchestrator_mcp.py      # LOCAL: spawns server.py over stdio, one session
    #  REMOTE (hosted MCP): point it at the Container Apps URL from Task 4 —
    #  CLM_MCP_URL=https://<your-app>.azurecontainerapps.io/mcp python src/orchestrator_mcp.py
"""
from __future__ import annotations

import asyncio
import os
import sys
from pathlib import Path

SRC_DIR = Path(__file__).resolve().parent
REPO_ROOT = SRC_DIR.parent
SERVER_PATH = SRC_DIR / "mcp_server" / "server.py"

sys.path.insert(0, str(SRC_DIR))
sys.path.insert(0, str(SRC_DIR / "agents"))

from clm_common.config import settings  # noqa: E402
from clm_common.foundry import build_chat_client, run_agent  # noqa: E402

ORCHESTRATOR_NAME = "clm-orchestrator-mcp"

INSTRUCTIONS = """\
You are the CLM Orchestrator for Contoso Global — the single front door for Legal & Procurement.

Your capabilities are provided by the **clm-mcp** server (Model Context Protocol) as tools:
- `draft_contract(contract_type, party, term)` — draft an NDA/MSA/SOW from approved templates.
- `analyze_contract(draft_text)` — extract clauses from a counterparty draft, compare to our standard,
  flag deviations and return a risk score.
- `get_contract_status(contract_id)` — look up a contract's status, renewal date, risk and owner.

ROUTING
- A drafting request → `draft_contract`.
- Reviewing/analyzing an incoming counterparty draft or asking about its risk → `analyze_contract`.
- A question about a specific contract's status/renewal/owner (e.g. "CT-4821") → `get_contract_status`.
- A multi-step request (e.g. "draft X, then analyze the counterparty's redline") → call the tools in
  order and combine the results.

HUMAN-IN-THE-LOOP
- For anything flagged High risk or any final document, clearly recommend human review before signing.
- Never provide legal advice yourself; defer to the tools and to human counsel.
Summarize each tool's output for the user and state which tool you used.
"""


def build_mcp_tool():
    """Return the client-side MCP tool that connects to the clm-mcp server.

    Two transports, selected by the ``CLM_MCP_URL`` env var:

    * **``CLM_MCP_URL`` set** → ``MCPStreamableHTTPTool``: connect to the **remote**
      server over HTTPS at that ``/mcp`` URL (the Azure Container Apps deployment
      from Task 4). If the endpoint is key-protected, set ``CLM_MCP_KEY`` and it is
      sent as an ``x-api-key`` header.
    * **``CLM_MCP_URL`` unset** → ``MCPStdioTool``: spawn a **local** ``server.py``
      over stdio. ``PYTHONPATH`` mirrors ``.vscode/mcp.json`` so the server resolves
      ``clm_common`` regardless of the caller's working directory.

    Both are async context managers, so use inside ``async with`` before building
    the agent.
    """
    url = os.getenv("CLM_MCP_URL")
    if url:
        from agent_framework import MCPStreamableHTTPTool

        headers: dict[str, str] = {}
        key = os.getenv("CLM_MCP_KEY")
        if key:
            headers["x-api-key"] = key
        return MCPStreamableHTTPTool(name="clm-mcp", url=url, headers=headers or None)

    from agent_framework import MCPStdioTool

    return MCPStdioTool(
        name="clm-mcp",
        command=sys.executable,
        args=[str(SERVER_PATH)],
        env={"PYTHONPATH": str(SRC_DIR)},
    )


def build_orchestrator(mcp_tool):
    """Wire the GPT-5.4 orchestrator to the CLM workflow via the (connected) MCP tool."""
    from agent_framework import Agent

    return Agent(
        client=build_chat_client(settings.model_orchestrator),  # gpt-5.4
        name=ORCHESTRATOR_NAME,
        instructions=INSTRUCTIONS,
        tools=[mcp_tool],
    )


DEMO = [
    "Draft a mutual NDA between Contoso Global and Acme Corp for a 2-year term.",
    "Analyze this counterparty clause and score its risk: 'Contoso's liability under this "
    "Agreement shall be unlimited, and the Agreement auto-renews for successive 2-year terms "
    "unless cancelled 90 days in advance.'",
    "What's the renewal date and risk level of contract CT-4821?",
]


def _diagnose_remote_mcp(url: str) -> str:
    """Best-effort probe of a remote clm-mcp URL to explain a failed connection.

    The most common cause is a server still running the pre-fix image: it rejects
    the request's Host header with HTTP 421 ("Invalid Host header"), so the MCP
    handshake never completes and Agent Framework surfaces it as an opaque
    "MCP server failed to initialize: Cancelled via cancel scope".
    """
    body = {
        "jsonrpc": "2.0",
        "id": 1,
        "method": "initialize",
        "params": {
            "protocolVersion": "2025-06-18",
            "capabilities": {},
            "clientInfo": {"name": "clm-preflight", "version": "0"},
        },
    }
    headers = {"Content-Type": "application/json", "Accept": "application/json, text/event-stream"}
    try:
        import httpx

        # Stream so we read only the status line (a healthy server answers with a
        # long-lived SSE body that a plain GET/read would hang on).
        with httpx.stream(
            "POST", url, json=body, headers=headers, timeout=httpx.Timeout(15.0, read=5.0)
        ) as resp:
            code = resp.status_code
    except Exception as probe_exc:  # DNS / TLS / timeout / connection refused
        return f"the server could not be reached ({type(probe_exc).__name__}: {probe_exc})."
    if code == 421:
        return (
            "the server returned HTTP 421 'Invalid Host header' — it is running an OLD image from "
            "before the Host-header fix. Redeploy it with the latest code."
        )
    return f"the server answered HTTP {code}; the MCP handshake still failed (see the error above)."


async def main() -> None:
    url = os.getenv("CLM_MCP_URL")
    # The MCP server is launched for the lifetime of this `async with`; the orchestrator
    # calls it as a standard tool client (the same workflow as orchestrator.py, over MCP).
    try:
        async with build_mcp_tool() as mcp_tool:
            orchestrator = build_orchestrator(mcp_tool)
            target = url or f"local stdio ({SERVER_PATH.name})"
            print(
                f"✓ Orchestrator on '{settings.model_orchestrator}' calling the clm-mcp server "
                f"as an MCP client via {target}\n"
            )

            session = orchestrator.create_session()
            for prompt in DEMO:
                print("―" * 80)
                print("USER:", prompt)
                print("ORCHESTRATOR:", await run_agent(orchestrator, prompt, session=session), "\n")
    except Exception as exc:
        if not url:  # local stdio failure — let the real traceback surface
            raise
        print(
            "\n".join(
                [
                    "",
                    f"✗ Could not connect to the remote clm-mcp server at {url}",
                    f"    ({type(exc).__name__}: {exc})",
                    f"  Diagnosis: {_diagnose_remote_mcp(url)}",
                    "  Fix — redeploy the server with the latest code, then retry:",
                    "      bash deploy/mcp-server/deploy.sh",
                    f"      curl -s -o /dev/null -w '%{{http_code}}\\n' {url}   # must NOT be 421",
                    "",
                ]
            ),
            file=sys.stderr,
        )
        raise SystemExit(1)


if __name__ == "__main__":
    asyncio.run(main())
