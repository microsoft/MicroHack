# Solution 04 — Orchestration + MCP Server

**[← Back to Challenge 4](../../challenges/challenge-04.md)** · [Home](../../README.md)

Add the **2nd specialist** (Clause & Risk on GPT-5.6 Sol), stand up an **Orchestrator
agent** (GPT-5.4) that delegates via the `agent.as_tool(...)` pattern, then expose the
whole workflow as an **MCP server** — locally, then **hosted on Azure Container Apps** and
called from a **Foundry** agent by URL.

## Expected end state

- [`src/agents/clause_risk_agent.py`](../../src/agents/clause_risk_agent.py) scores
  clauses against the Standard Clause Library and flags deviations.
- [`src/orchestrator.py`](../../src/orchestrator.py) routes a request to the right
  specialist(s) in-process — agents built as tools.
- [`src/mcp_server/server.py`](../../src/mcp_server/server.py) serves
  `draft_contract` · `analyze_contract` · `get_contract_status` over **stdio** (local) and
  **streamable HTTP** (`--http`, for hosting); VS Code loads the stdio server from
  [`.vscode/mcp.json`](../../.vscode/mcp.json) (repo root).
- [`Dockerfile`](../../Dockerfile) + [`deploy/mcp-server/deploy.sh`](../../deploy/mcp-server/deploy.sh)
  host it on **Azure Container Apps** as a remote `https://…/mcp` endpoint a Foundry agent can call.
- [`src/orchestrator_mcp.py`](../../src/orchestrator_mcp.py) runs the same GPT-5.4
  orchestrator as an **MCP client** — local stdio, or the remote server via `CLM_MCP_URL`.

## 🛠️ Task-by-task walkthrough

### Task 1 · Build the Clause & Risk agent
[`src/agents/clause_risk_agent.py`](../../src/agents/clause_risk_agent.py) reuses the Ch2 grounding pattern on GPT-5.6 Sol, and conditionally attaches web search for counterparty due-diligence:
```python
# src/agents/clause_risk_agent.py
def create_agent(model=None, *, connection_id=None):
    tools = [build_knowledge_tool(connection_id=connection_id)]   # clause library + policy
    web_search = build_web_search_tool()      # None unless AZURE_BING_CONNECTION_NAME is set
    if web_search is not None:
        tools.append(web_search)
    return Agent(
        client=build_chat_client(model or settings.model_clause_risk),  # gpt-5.6-sol
        name=AGENT_NAME, instructions=INSTRUCTIONS, tools=tools,
    )
```
```bash
python src/agents/clause_risk_agent.py     # analyzes BOTH sample drafts (deliberately red-flag)
```
✅ **You should see** (format varies — the analysis is the point):
```text
✓ Built clause-risk-agent on model 'gpt-5.6-sol'
DRAFT: acme_msa_draft.pdf
  • Limitation of liability — UNCAPPED vs standard 12-month cap [CL-04]  → ❌ deviation
  • Auto-renewal — 60-day vs standard 30-day notice [CL-07]             → ⚠️ deviation
Risk: HIGH · Top issues: uncapped liability, long auto-renew, one-sided indemnity
Required approver: VP Legal (delegation-of-authority matrix)
```

> 📸 **Screenshot slot:** the clause table + High-risk verdict with citations.
>
> <img src="../../images/challenge-04/steps/01-clause-risk.svg" alt="Screenshot slot: Clause & Risk output" width="80%">

### Task 2 · Build the Orchestrator
[`src/orchestrator.py`](../../src/orchestrator.py) builds both specialists once and exposes each as a tool via `agent.as_tool(...)` — the GPT-5.4 front door then routes:
```python
# src/orchestrator.py
intake_tool = intake.as_tool(name="intake_drafting", arg_name="request",
    description="Draft NDA/MSA/SOW…; answer cited questions about clauses/policies/status.")
clause_tool = clause_risk.as_tool(name="clause_risk", arg_name="request",
    description="Analyze a counterparty draft: extract clauses, compare to standard, flag deviations, score risk.")

return Agent(
    client=build_chat_client(settings.model_orchestrator),   # gpt-5.4
    name=ORCHESTRATOR_NAME, instructions=INSTRUCTIONS,
    tools=[intake_tool, clause_tool],                        # specialists as tools of a GPT agent
)
```
```bash
python src/orchestrator.py
```
```text
✓ Orchestrator on 'gpt-5.4' with 2 specialists as tools
ORCHESTRATOR: [→ intake_drafting] Draft ready... [→ clause_risk] Acme draft is HIGH risk...
              [→ get_contract_status] CT-4821 is Active, renews 2026-09-01.
```

> 📸 **Screenshot slot:** the orchestrator thread routing across specialists.
>
> <img src="../../images/challenge-04/steps/02-orchestrator.svg" alt="Screenshot slot: orchestrator thread" width="80%">

### Task 3 · Run the MCP server (local)
[`src/mcp_server/server.py`](../../src/mcp_server/server.py) wraps the workflow as three MCP tools over stdio using FastMCP:
```python
# src/mcp_server/server.py
mcp = FastMCP("clm-mcp")

@mcp.tool()
def draft_contract(contract_type: str, party: str, term: str = "1 year") -> str:
    return _run_agent(create_agent,  # Intake & Drafting
        f"Draft a {contract_type} between Contoso Global and {party} for a {term} term.")

@mcp.tool()
def analyze_contract(draft_text: str) -> str: ...   # Clause & Risk
@mcp.tool()
def get_contract_status(contract_id: str) -> str: ...

if __name__ == "__main__":
    # --list prints the tools and exits; --http (or MCP_TRANSPORT=streamable-http) serves
    # streamable HTTP at /mcp for remote hosting; otherwise serve over stdio for local clients.
    mcp.run(transport="streamable-http") if _http_requested() else mcp.run(transport="stdio")
```
```bash
python src/mcp_server/server.py --list   # verify the 3 tools, then exit
python src/mcp_server/server.py          # stdio: waits for a local client (VS Code / orchestrator_mcp.py)
```

**Consume it locally (optional):** run `python src/orchestrator_mcp.py` — a terminal MCP **client** that
spawns the stdio server for you (no IDE) and runs draft → analyze → status over MCP. Same
"agent-as-MCP-client" shape as Task 4 · Part C, just over stdio instead of HTTPS. Prefer an IDE? Open the
**repo root** in VS Code (it loads [`.vscode/mcp.json`](../../.vscode/mcp.json)) → **MCP: List Servers** →
start **clm-mcp** → call `#analyze_contract` in Copilot Chat.

### Task 4 · Host it remotely + call it from Foundry
**Part A — host on Azure Container Apps.** The repo-root [`Dockerfile`](../../Dockerfile) runs
`server.py --http` (streamable HTTP at `/mcp`). Deploy from the repo root — the image builds in the
cloud, no local Docker:
```bash
bash deploy/mcp-server/deploy.sh    # reads .env, auto-discovers RG/account/region → https://clm-mcp.<region>.azurecontainerapps.io/mcp
```
The script reads the repo-root `.env` and auto-discovers the resource group, Foundry account and region
(all overridable via env vars; `deploy.ps1` is the Windows twin). It gives the app a **system-assigned
managed identity** and grants it a data-plane role on the Foundry account so the server's own tools can
call your models.

**Part B — Foundry Playground.** In [ai.azure.com](https://ai.azure.com): agent → **Tools → Add MCP tool**,
Server label `clm-mcp`, Server URL `https://…/mcp`, **No authentication**. In the Playground ask it to
analyze a clause, **approve** the tool call → the agent calls `analyze_contract` on your remote server.

**Part C — local agent → remote server.** Same script, tools over HTTPS instead of stdio:
```bash
CLM_MCP_URL=https://…/mcp python src/orchestrator_mcp.py   # MCPStreamableHTTPTool, no code change
```

> 📸 **Screenshot slots:** the MCP tool on the agent, the Playground calling it, and the local orchestrator against the remote URL.
>
> <img src="../../images/challenge-04/steps/05-foundry-mcp-tool.svg" alt="Screenshot slot: add MCP tool in Foundry" width="80%">
> <img src="../../images/challenge-04/steps/06-foundry-playground.svg" alt="Screenshot slot: Foundry Playground calling the remote MCP tool" width="80%">
> <img src="../../images/challenge-04/steps/07-orchestrator-remote.svg" alt="Screenshot slot: local orchestrator calling the remote MCP server" width="80%">

### Task 5 · (Go Further) One client, two transports
[`src/orchestrator_mcp.py`](../../src/orchestrator_mcp.py) is the mirror of Task 2, but the tools come
over MCP. It picks the transport from `CLM_MCP_URL` — `MCPStdioTool` (spawns `server.py`) when unset,
`MCPStreamableHTTPTool` (remote) when set:
```python
# src/orchestrator_mcp.py
def build_mcp_tool():
    url = os.getenv("CLM_MCP_URL")
    if url:                                           # remote streamable HTTP
        return MCPStreamableHTTPTool(name="clm-mcp", url=url, headers=_headers())
    return MCPStdioTool(name="clm-mcp", command=sys.executable,   # local stdio
                        args=[str(SERVER_PATH)], env={"PYTHONPATH": str(SRC_DIR)})

async with build_mcp_tool() as mcp_tool:              # local subprocess *or* remote URL
    orchestrator = build_orchestrator(mcp_tool)       # gpt-5.4, tools=[mcp_tool]
    ...
```
```bash
python src/orchestrator_mcp.py                        # local: you don't start the server yourself
CLM_MCP_URL=https://…/mcp python src/orchestrator_mcp.py   # remote: same run, over HTTPS
```

## Key files

| Path | Role |
|------|------|
| [`src/agents/clause_risk_agent.py`](../../src/agents/clause_risk_agent.py) | Clause & Risk specialist (GPT-5.6 Sol) |
| [`src/orchestrator.py`](../../src/orchestrator.py) | Orchestrator with specialists as tools |
| [`src/mcp_server/server.py`](../../src/mcp_server/server.py) | MCP server exposing the CLM workflow (stdio **and** streamable HTTP via `--http`) |
| [`.vscode/mcp.json`](../../.vscode/mcp.json) | VS Code MCP client config (`clm-mcp`, repo root) |
| [`src/orchestrator_mcp.py`](../../src/orchestrator_mcp.py) | Orchestrator as MCP client — local stdio, or remote via `CLM_MCP_URL` |
| [`Dockerfile`](../../Dockerfile) + [`deploy/mcp-server/deploy.sh`](../../deploy/mcp-server/deploy.sh) | Containerize + deploy the server to Azure Container Apps as a remote `/mcp` endpoint |

## Run it

```bash
python src/agents/clause_risk_agent.py       # analyze a counterparty draft
python src/orchestrator.py                    # route a request to specialists in-process
python src/mcp_server/server.py               # serve over stdio (Ctrl-C to stop)
python src/mcp_server/server.py --http        # serve streamable HTTP at /mcp (what the container runs)
python src/orchestrator_mcp.py                # launch the stdio server and call it as a client
bash deploy/mcp-server/deploy.sh              # host it on Azure Container Apps → https://…/mcp
CLM_MCP_URL=https://…/mcp python src/orchestrator_mcp.py   # drive the remote server
```

## Common issues

| Symptom | Cause / fix |
|---------|-------------|
| `orchestrator_mcp.py` finds no tools / hangs | The stdio server failed to import — confirm `python src/mcp_server/server.py` starts standalone; run from repo root (`PYTHONPATH=src`). |
| MCP server not listed in VS Code | VS Code reads `.vscode/mcp.json` only from the **root of the opened folder** — open the repo root (not `src/`) and confirm the file is at `<repo>/.vscode/mcp.json`. |
| Remote tools return `401/403` from Foundry | The Container App's **managed identity** needs a data-plane role (Azure AI User) on the Foundry account — `deploy.sh` sets it; allow ~1 min to propagate. |
| Foundry can't reach the server | Ingress must be **external** and the Server URL must end with `/mcp`; open `https://<app>.azurecontainerapps.io/mcp` to confirm it responds. |
