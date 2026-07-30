# Solution 04 — Orchestration + MCP Server

**[← Back to Challenge 4](../../challenges/challenge-04.md)** · [Home](../../README.md)

Add the **2nd specialist** (Clause & Risk on GPT-5.6 Sol), stand up an **Orchestrator
agent** (GPT-5.4) that delegates via the `agent.as_tool(...)` pattern, then expose the
whole workflow as an **MCP server** any client can call.

## Expected end state

- [`src/agents/clause_risk_agent.py`](../../src/agents/clause_risk_agent.py) scores
  clauses against the Standard Clause Library and flags deviations.
- [`src/orchestrator.py`](../../src/orchestrator.py) routes a request to the right
  specialist(s) in-process — agents built as tools.
- [`src/mcp_server/server.py`](../../src/mcp_server/server.py) serves
  `draft_contract` · `analyze_contract` · `get_contract_status` over **stdio**;
  VS Code loads it from [`src/.vscode/mcp.json`](../../src/.vscode/mcp.json).
- [`src/orchestrator_mcp.py`](../../src/orchestrator_mcp.py) runs the same GPT-5.4
  orchestrator as an **MCP client**, consuming the workflow over MCP instead of
  in-process.

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

### Task 3 · Run the MCP server
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
    mcp.run(transport="stdio")
```
```bash
python src/mcp_server/server.py     # looks like it hangs — correct: it's waiting for a client on stdio
```

### Task 4 · Consume it from VS Code
VS Code launches the server from [`src/.vscode/mcp.json`](../../src/.vscode/mcp.json):
```json
{ "servers": { "clm-mcp": {
    "type": "stdio", "command": "python",
    "args": ["${workspaceFolder}/src/mcp_server/server.py"],
    "env": { "PYTHONPATH": "${workspaceFolder}/src" } } } }
```
Command Palette → **MCP: List Servers** → start **clm-mcp**, then in Copilot Chat (Agent mode) call `#draft_contract` / `#analyze_contract` / `#get_contract_status`. ✅ It worked when `clm-mcp` shows **Running** and `#analyze_contract` returns the **same** risk assessment as Task 1.

> 📸 **Screenshot slot:** **MCP: List Servers** with `clm-mcp`, then Copilot Chat calling `#analyze_contract`.
>
> <img src="../../images/challenge-04/steps/03-mcp-list.svg" alt="Screenshot slot: VS Code MCP list" width="80%">
> <img src="../../images/challenge-04/steps/04-copilot-tool.svg" alt="Screenshot slot: Copilot tool call" width="80%">

### Task 5 · (Go Further) Consume it from an agent
[`src/orchestrator_mcp.py`](../../src/orchestrator_mcp.py) is the mirror of Task 2, but the tools come over MCP. `MCPStdioTool` spawns the server for you:
```python
# src/orchestrator_mcp.py
def build_mcp_tool():
    return MCPStdioTool(name="clm-mcp", command=sys.executable,
                        args=[str(SERVER_PATH)], env={"PYTHONPATH": str(SRC_DIR)})

async with build_mcp_tool() as mcp_tool:          # launches server.py over stdio
    orchestrator = build_orchestrator(mcp_tool)   # gpt-5.4, tools=[mcp_tool]
    ...
```
```bash
python src/orchestrator_mcp.py      # you don't start the server yourself
```

## Key files

| Path | Role |
|------|------|
| [`src/agents/clause_risk_agent.py`](../../src/agents/clause_risk_agent.py) | Clause & Risk specialist (GPT-5.6 Sol) |
| [`src/orchestrator.py`](../../src/orchestrator.py) | Orchestrator with specialists as tools |
| [`src/mcp_server/server.py`](../../src/mcp_server/server.py) | MCP server exposing the CLM workflow over stdio |
| [`src/.vscode/mcp.json`](../../src/.vscode/mcp.json) | VS Code MCP client config (`clm-mcp`) |
| [`src/orchestrator_mcp.py`](../../src/orchestrator_mcp.py) | Orchestrator consuming the MCP server as a client |

## Run it

```bash
python src/agents/clause_risk_agent.py       # analyze a counterparty draft
python src/orchestrator.py                    # route a request to specialists in-process
python src/mcp_server/server.py               # serve over stdio (Ctrl-C to stop)
python src/orchestrator_mcp.py                # launch the stdio server and call it as a client
```

## Common issues

| Symptom | Cause / fix |
|---------|-------------|
| `orchestrator_mcp.py` finds no tools / hangs | The stdio server failed to import — confirm `python src/mcp_server/server.py` starts standalone; run from repo root (`PYTHONPATH=src`). |
| MCP server not listed in VS Code | Ensure the MCP feature is on and `src/.vscode/mcp.json` is picked up. |
