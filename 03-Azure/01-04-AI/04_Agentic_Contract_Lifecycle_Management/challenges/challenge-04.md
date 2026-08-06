# Challenge 4 · Orchestration + MCP Server

**[🏠 Home](../README.md)**  ·  [← Challenge 3: Observability](challenge-03.md)  ·  [Challenge 5: Publish to M365 →](challenge-05.md)

Welcome back! You have one grounded specialist so far. In this challenge you'll add the **second
specialist** — **Clause & Risk** on GPT-5.6 Sol — then stand up an **Orchestrator** (GPT-5.4) that routes
to both via the **agent-as-tool pattern**, and finally expose the whole workflow as an **MCP server** —
run it locally, then **host it on Azure Container Apps** and call it from a **Foundry** agent by URL.
This is where the system becomes truly **multi-agent**.

If something isn't working as expected, please let your coach know.

> **⏱️ Duration:** ~75 min (Tasks 1–4). Task 4 hosts the MCP server remotely and calls it from Foundry — that's the point of this challenge, so plan for it.

> **📋 Prerequisites:**
> - **Challenge 2 pattern understood** — you know how a grounded agent is built.
> - *Recommended:* Challenge 3 (you'll see orchestration spans in Tracing).

> 🧩 **How to use this challenge:** the code in this folder is a **complete, working reference
> implementation** — you're not building it from a blank file. **Run it, read it, and understand *why*
> it works**, then take it further with **🚀 Go Further**. Stuck? The code *is* the answer key.

## 🎯 Objective

Add the **2nd specialist** (Clause & Risk on GPT-5.6 Sol), stand up an **Orchestrator agent** (GPT-5.4)
that routes to both specialists via the **agent-as-tool pattern**, then expose the whole workflow as an **MCP
server** — locally over stdio, then **hosted on Azure Container Apps** and called from a **Foundry** agent by URL.

## 🧭 Context

- **Clause & Risk agent** reuses the Ch1 grounding pattern → fast to build. It compares a
  counterparty draft to the enterprise standard and returns a **risk score**.
- **Orchestrator** (GPT-5.4) uses the Agent Framework's **`agent.as_tool(...)`** to call each specialist as a tool. A
  **GPT-5.4 orchestrator coordinating gpt-5.4 drafting and GPT-5.6 Sol specialists** is multi-model composition in one project. It
  manages routing, hand-offs and human-in-the-loop.
- **MCP** (Model Context Protocol) lets you expose the workflow as standard tools so *any* MCP client
  can reuse it. You'll run it locally over **stdio**, then **host it on Azure Container Apps** over HTTP
  and call it from a **Foundry agent** by URL — same tools, now a network service.

```
        ┌────────────── Orchestrator (GPT-5.4) ──────────────┐
 user → │  routes + hand-offs + human-in-the-loop            │
        └───────┬───────────────────────────┬───────────────┘
                │ agent-as-tool             │ agent-as-tool
        Intake & Drafting (gpt-5.4)  Clause & Risk (GPT-5.6 Sol)
                └──────────── grounded on Foundry IQ ─────────┘
        Also exposed as an MCP server (local stdio **or** hosted on Azure Container Apps,
        callable from Foundry / another agent): draft_contract · analyze_contract · get_contract_status
```

## 🧰 Services & models in this challenge

This challenge is about **composition** — specialists behind one orchestrator, plus a standard protocol that makes the workflow reusable outside your code:

| Building block | What it is | Why it's here |
|---|---|---|
| **Agent-as-tool** (`agent.as_tool(...)`) | The Agent Framework's multi-agent primitive: wrap an agent as a *tool* and hand it to an orchestrator, which calls specialists like functions. `as_tool(name=…, description=…)` wires them into [`orchestrator.py`](../src/orchestrator.py); each specialist keeps its own model & instructions. | Lets the Orchestrator delegate *drafting* and *clause/risk* to the right specialist instead of one bloated mega-agent. → [Agent Framework](https://learn.microsoft.com/agent-framework/overview/agent-framework-overview) |
| **Model — gpt-5.4** (orchestrator) | The LLM behind the Orchestrator (`MODEL_ORCHESTRATOR`, `GlobalStandard`) — fast, deterministic tool-calling & routing; same Agents API as the specialists (only the `model` id differs). | Routing & drafting share flagship **gpt-5.4**; clause/risk uses **gpt-5.6-sol** — the right GPT deployment per job. → [Models in Foundry](https://learn.microsoft.com/azure/ai-foundry/) |
| **Model Context Protocol (MCP)** | An open standard for exposing tools/data to any LLM client. `src/mcp_server/server.py` serves `draft_contract` · `analyze_contract` · `get_contract_status` over **stdio**; any client (VS Code, Copilot) — or an agent via `src/orchestrator_mcp.py` (`MCPStdioTool`) — can discover and call them. | Turns your agents into reusable building blocks the rest of the org can call **without touching your code**. → [Model Context Protocol](https://modelcontextprotocol.io/docs/getting-started/intro) |
| **Azure SQL Database** *(optional)* | The managed store behind `get_contract_status`, provisioned only with `deploySql=true` (`Basic`, db `clmdb`, table `dbo.contracts`); queried via **pyodbc** in [`tools.py`](../src/clm_common/tools.py). Without it, the tool falls back to `contracts_seed.json`. | Structured contract facts belong in a queryable database, not the model's memory. → [Azure SQL](https://learn.microsoft.com/en-us/azure/azure-sql/database/sql-database-paas-overview?view=azuresql) |

## ✅ Tasks

### Task 1 · Build the Clause & Risk agent (~10 min)

Analyze the (deliberately red-flag) sample drafts. By
default it analyzes **both** inbound drafts (`acme_msa_draft.pdf` and `globex_nda_redline.pdf`),
reusing one agent:
```bash
python src/agents/clause_risk_agent.py
# analyze a single draft instead:
python src/agents/clause_risk_agent.py --draft src/data/counterparty_drafts/globex_nda_redline.pdf
```
Expect: per draft, a clause table, flagged deviations (e.g. uncapped liability, 60-day
auto-renew) with the negotiation-playbook fallback for items to negotiate, **High** risk with
top-3 issues and the required approver per the delegation-of-authority matrix, all cited against
the standard clause library.

✅ **You should see** (wording/format will vary — the analysis is the point):
```text
✓ Built clause-risk-agent on model 'gpt-5.6-sol'

――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
DRAFT: acme_msa_draft.pdf
Clause review:
  • Limitation of liability — UNCAPPED vs standard 12-month cap [CL-04]  → ❌ deviation
  • Auto-renewal — 60-day vs standard 30-day notice [CL-07]             → ⚠️ deviation
Risk: HIGH · Top issues: uncapped liability, long auto-renew, one-sided indemnity
Required approver: VP Legal (delegation-of-authority matrix)
```

> 📸 **Screenshot slot:** the clause table + High-risk verdict with citations.
>
> <img src="../images/challenge-04/steps/01-clause-risk.svg" alt="Screenshot slot: Clause & Risk output" width="80%">

### Task 2 · Build the Orchestrator (~10 min)

With both specialists connected, run a multi-step thread
(draft → analyze → status):
```bash
python src/orchestrator.py
```
Note which specialist the orchestrator says it used for each turn.

✅ **You should see** the orchestrator delegate each turn to the right specialist:
```text
✓ Orchestrator on 'gpt-5.4' with 2 specialists as tools

――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
USER: Draft an NDA for Northwind, review the Acme MSA draft, and give me CT-4821's status.
ORCHESTRATOR: [→ intake_drafting] Draft ready... [→ clause_risk] Acme draft is HIGH risk...
              [→ get_contract_status] CT-4821 is Active, renews 2026-09-01.
```

> 📸 **Screenshot slot:** the orchestrator thread routing across specialists.
>
> <img src="../images/challenge-04/steps/02-orchestrator.svg" alt="Screenshot slot: orchestrator thread" width="80%">

### Task 3 · Run & smoke-test the MCP server locally (~10 min)

The server speaks **two transports** from the same code: **stdio** for local dev (what VS Code
launches) and **streamable HTTP** for remote hosting (Task 4). Start locally here, then go remote next.

First **verify the tools are registered** — this needs no client and exits on its own:
```bash
python src/mcp_server/server.py --list
```
```text
clm-mcp exposes 3 tool(s):
  • draft_contract: Draft a contract from Contoso Global's approved templates.
  • analyze_contract: Extract clauses from a counterparty draft, compare to standard, and return a risk score.
  • get_contract_status: Look up a contract's status, renewal date, risk and owner by ID (e.g. "CT-4821").
```

Then (optionally) start it **over stdio** the way a client will — a quick smoke test. It just sits there
with **no output — that's success, not a hang** (a stdio server waits silently for a client); press
`Ctrl-C` to stop:
```bash
python src/mcp_server/server.py       # serves over stdio — silent = waiting for a client (Ctrl-C to stop)
```

<details>
<summary>🛠️ <b>The window looks frozen, or <code>clm-mcp</code> won't show up in VS Code? — click to expand</b></summary>

- **No output is correct.** A stdio MCP server has no console UI — it just waits silently for a client to
  connect over stdin/stdout. It isn't stuck.
- **Don't type into that window.** A stray keystroke or **Enter** isn't valid JSON, so it logs a red
  `Invalid JSON … Internal Server Error` and keeps running — that's the server rejecting your keystroke,
  not a crash. Stop it with `Ctrl-C`.
- **Running it by hand does _not_ register it with VS Code.** VS Code reads `.vscode/mcp.json` and
  launches its **own** copy. A stdio server isn't a network listener — there's no port to "connect" to;
  each client spawns its own subprocess, so the copy you ran by hand is a separate process nobody attaches to.
- **Running vs. stuck?** Don't judge from the terminal. `python src/mcp_server/server.py --list` is the
  self-check (prints the 3 tools and exits); in VS Code, *MCP: List Servers* shows `clm-mcp` as **Running**.

</details>

#### (Optional) Consume it locally

<details>
<summary>💻 <b>Prove the three tools work end-to-end before you host them</b> — one local command (click to expand)</summary>

Run the Orchestrator as a local MCP **client** — it spawns the stdio server for you, so there's no IDE
to set up and no second terminal:

```bash
python src/orchestrator_mcp.py     # MCPStdioTool launches server.py → draft → analyze → status over MCP
```

This is the exact **"an agent is an MCP client"** pattern you'll reuse against the **remote** server in
Part C below — only the transport changes (stdio here, HTTPS there).

> 💡 **Prefer an IDE?** The repo ships [`.vscode/mcp.json`](../.vscode/mcp.json), so any MCP-aware client
> discovers the same server: open the **repo root** in VS Code → Command Palette → *MCP: List Servers* →
> **clm-mcp** → **Start**, then call `#analyze_contract` in Copilot Chat (**Agent mode**).

✅ **Local check:** `orchestrator_mcp.py` (or `#analyze_contract` in VS Code) returns the **same** risk
assessment you saw in Task 1.

</details>

### Task 4 · Host it remotely + call it from Foundry (~35–45 min)

This is the production shape: **host the MCP server in Azure**, then let a **Foundry agent call it by
URL** — the same three tools, now a network service any MCP client (the Foundry Playground, another
agent, your orchestrator) can reach. No editor required.

> **Task 4 at a glance — three short parts:**
> - **A · Host it** → `bash deploy/mcp-server/deploy.sh` → you get a `https://…/mcp` URL.
> - **B · Call it from Foundry** → paste that URL as an agent's MCP tool, test `analyze_contract` in the Playground.
> - **C · Call it from your own agent** → `CLM_MCP_URL=<url> python src/orchestrator_mcp.py`.
>
> **Do this task — it's the point of the challenge.** You provisioned an Azure lab subscription back
> in Challenge 1, so you're set to host and call the server for real. (Task 3's local stdio server
> produces the identical tools and results — keep it only as a fallback if Azure is ever completely
> unavailable; otherwise the whole value of MCP is reaching the server *remotely* here.)

#### Part A · Host the server on Azure Container Apps

The server already speaks HTTP — `--http` (what the repo-root [`Dockerfile`](../Dockerfile) runs) serves
**streamable HTTP** at `/mcp` on port 8000. Deploy it (image builds **in the cloud** — no local Docker)
from the **repo root**. The script **reads your `.env`** (the same one the agents use) and
**auto-discovers** the resource group, Foundry account and region from your project endpoint — so there's
nothing to fill in:

```bash
bash deploy/mcp-server/deploy.sh            # Linux/macOS/Cloud Shell
```
```powershell
./deploy/mcp-server/deploy.ps1              # Windows PowerShell (same auto-discovery)
```

The script builds the image, creates the Container App with **external HTTPS ingress**, turns on a
**system-assigned managed identity**, and grants it a data-plane role on your Foundry account so the
server's own tools can call your models. It echoes what it discovered, then prints your endpoint:

```text
==> Using:
    resource group   = rg-clm-lab
    region           = swedencentral
    Foundry account  = /subscriptions/…/accounts/<your-account>
    project endpoint = https://<account>.services.ai.azure.com/api/projects/<project>
 clm-mcp is live. Use this MCP endpoint in Foundry / CLM_MCP_URL:
     https://clm-mcp.<region>.azurecontainerapps.io/mcp
```

> [!TIP]
> Everything is still overridable if the auto-discovery guesses wrong (e.g. multiple AI accounts in the
> subscription) — just set the value on the command line: `RESOURCE_GROUP=<rg>
> FOUNDRY_ACCOUNT_ID=<id> bash deploy/mcp-server/deploy.sh` (or `-ResourceGroup`/`-FoundryAccountId` for
> the `.ps1`). Prereq: `az login` on your lab subscription. See
> [`deploy/mcp-server/README.md`](../deploy/mcp-server/README.md) for the full override list.

> [!IMPORTANT]
> The server's tools **call Foundry agents themselves**, so the container needs its **own** Foundry
> access — that's the managed identity + role the script sets up. Without it the MCP endpoint answers but
> the tools return auth errors. Role propagation can take ~1 minute after assignment.

> [!NOTE]
> For hack simplicity the endpoint is **public with no auth** — anyone with the URL can call the tools.
> Securing it (key header, APIM, or a private endpoint) is in **🚀 Go Further**.

#### Part B · Connect it to a Foundry agent (portal Playground)

In the **[Foundry portal](https://ai.azure.com)**, give an agent the **MCP tool** pointing at your URL:

1. Open your project → **Agents** → your Orchestrator (or **+ New agent**) → **Tools** → **Add tool** →
   **Model Context Protocol (MCP)** / *Custom MCP server*.
2. Set **Server label** = `clm-mcp` and **Server URL** = `https://<your-app>.azurecontainerapps.io/mcp`.
   Authentication = **No authentication** (matches Part A). Save.
3. Open the **Playground** and ask, e.g.:
   *"Analyze this clause and score its risk: 'Contoso's liability shall be unlimited and the agreement
   auto-renews for 2-year terms unless cancelled 90 days in advance.'"*
4. **Approve** the MCP tool call when prompted — the agent invokes `analyze_contract` on **your hosted
   server** and returns the risk assessment.

> 📸 **Screenshot slot — what you'll see:** the MCP tool/connection on the agent, then the Playground
> running `analyze_contract` against your remote server.
>
> <img src="../images/challenge-04/steps/05-foundry-mcp-tool.svg" alt="Screenshot slot: add MCP tool in Foundry" width="80%">
> <img src="../images/challenge-04/steps/06-foundry-playground.svg" alt="Screenshot slot: Foundry Playground calling the remote MCP tool" width="80%">

✅ **You'll know it worked when:** the Playground shows an **MCP tool call to `clm-mcp`** and returns the
**same** risk result as Task 1 — a Foundry-hosted agent just consumed your *remote* server by URL.

#### Part C · Point your local agent at the remote server

Same `orchestrator_mcp.py`, but now over the **network** instead of stdio — just set `CLM_MCP_URL`:

```bash
CLM_MCP_URL=https://<your-app>.azurecontainerapps.io/mcp python src/orchestrator_mcp.py
```

With `CLM_MCP_URL` set, the client switches from `MCPStdioTool` (local subprocess) to
`MCPStreamableHTTPTool` (remote HTTPS) with **no code change** — the same Orchestrator now drives your
**hosted** tools. *(If you protect the endpoint with a key, also set `CLM_MCP_KEY`.)*

> 📸 **Screenshot slot:** `orchestrator_mcp.py` printing that it's calling `clm-mcp` **via https://…/mcp** and completing the run.
>
> <img src="../images/challenge-04/steps/07-orchestrator-remote.svg" alt="Screenshot slot: local orchestrator calling the remote MCP server" width="80%">

### Task 5 · (Go Further) Secure & extend (~optional)

You've now reached the workflow **in-process**, over **local stdio**, and over a **remote HTTPS**
endpoint from both Foundry and your own agent. To productionize, see **🚀 Go Further** below — add auth,
lock the endpoint down to a **private** MCP subnet, and add **approval** before high-impact tools run.

## ✔️ Success criteria

- One orchestrator thread runs **draft → extract → risk** by delegating to the two specialists.
- The Clause & Risk agent returns a structured risk assessment with citations.
- The MCP server is **discoverable and callable** from an MCP client — locally (VS Code/Copilot or
  `orchestrator_mcp.py`) **and** as a **remote** endpoint, returning the same results as the agents.
- **(Task 4)** The server is **hosted on Azure Container Apps** and a **Foundry agent calls it by URL**
  from the Playground; the same tool also works from the local orchestrator via `CLM_MCP_URL`.

## 🚀 Go Further

- **Secure the remote endpoint.** Task 4 ships it **public with no auth** for speed. Add a **key header**
  (set `CLM_MCP_KEY` on the app and pass it from clients / the Foundry MCP tool's *custom keys* auth),
  front it with **APIM**, or make it **private**: put the Container App on a VNet and add a dedicated
  MCP subnet delegated to `Microsoft.App/environments`, then reach it over a private endpoint.
- **Use a Foundry-managed MCP tool with approvals.** Attach the remote server as a hosted
  `MCPTool(server_label="clm-mcp", server_url=..., require_approval="always")` so high-impact tools
  (e.g. `draft_contract`) prompt for human approval before they run.
- Add the **Review & Negotiation** and **Signature & Repository** agents from the 5-agent vision as
  more agent-as-tool specialists.
- **Ground the Clause & Risk agent on the web** for external counterparty due-diligence (corporate
  status, adverse-media, sanctions, public regulatory references). Provision a **Grounding with Bing
  Search** resource, add it as a project connection, and set `AZURE_BING_CONNECTION_NAME` in `.env` —
  `create_agent` then attaches the tool automatically (built in `build_web_search_tool()`, the single
  place to later swap in **Web IQ**). The corpus stays the authority for Contoso standards; the web is
  public context only, and Bing search data leaves the Azure compliance boundary.

## 🛠️ Troubleshooting

| Symptom | Fix |
|---------|-----|
| `clm-mcp` not in *MCP: List Servers* | VS Code discovers a workspace MCP server only from `.vscode/mcp.json` at the **root of the opened folder** — running `python src/mcp_server/server.py` in a terminal does **not** register it. Open the **repo root** (not `src/`) and confirm the file is at `<repo>/.vscode/mcp.json`. If it's missing there, **pull the latest hack repo** (older copies shipped it under `src/.vscode/`), then reload VS Code. |
| `Invalid JSON … Internal Server Error` after starting the server | **Harmless.** You typed or pressed **Enter** in the stdio window, so the server rejected the newline as invalid JSON-RPC. It's still running — don't type into it. Use `python src/mcp_server/server.py --list` to confirm the tools without the stdio loop. |
| Orchestrator doesn't route correctly | Sharpen the routing rules in `INSTRUCTIONS`; make each specialist's `as_tool(description=...)` specific. |
| `ImportError: cannot import name 'Agent' from 'agent_framework'` (or other `agent_framework` import errors) | You have an **old/mismatched build**, or you `pip install`ed into a **different Python** than the one running the script (common with Microsoft Store Python). First see **which** interpreter actually runs the script: `python -c "import sys; print(sys.executable)"`. Then reinstall the pinned deps into **that same** interpreter — the `-U` matters, a plain install won't replace a stale version: `python -m pip install -U -r requirements.txt`. Finally verify: `python -c "import agent_framework as a; print(a.__version__)"` — you need **≥ 1.11.0**. |
| MCP server not listed in VS Code | Ensure the MCP feature is enabled and `mcp.json` path is correct; confirm the server imports cleanly first with `python src/mcp_server/server.py --list`. |
| MCP tool call times out | Each call spins up + tears down a Foundry agent (a few seconds). Keep drafts short while testing. |
| `orchestrator_mcp.py` finds no tools / hangs at startup | The stdio server failed to import. Confirm `python src/mcp_server/server.py` starts standalone; `MCPStdioTool` sets `PYTHONPATH=src`, so run from the repo root. |
| Web search tool not attaching | Confirm `AZURE_BING_CONNECTION_NAME` matches a **project connection** for your Grounding with Bing Search resource; run `python src/kb_setup.py` — it prints whether the web-grounding tool built. |
| `deploy.sh` fails / `az containerapp up` errors | Ensure `az` ≥ 2.53 and the **containerapp** extension (`az extension add -n containerapp`), you're logged in (`az login`) and on the lab subscription (`az account set -s <id>`), and you're running it from the **repo root** (build context needs `Dockerfile`, `requirements.txt`, `src/`). First run also registers the `Microsoft.App`/`Microsoft.OperationalInsights` providers — that can take a minute. |
| Foundry agent shows the MCP tool but tool calls fail / time out | Check the app is reachable: open `https://<app>.azurecontainerapps.io/mcp` — it should respond (405/JSON, not a connection error). Confirm ingress is **external** (`az containerapp ingress show`), the URL **ends with `/mcp`**, and the Server URL in Foundry matches exactly. |
| Remote tools return `401/403` / "credential" errors from Foundry | The **container's managed identity** lacks a data-plane role on your Foundry account. Re-run the role step in `deploy.sh` (or assign **Azure AI User** on `FOUNDRY_ACCOUNT_ID`), then wait ~1 min for propagation. Verify with `az containerapp identity show` + `az role assignment list --assignee <principalId>`. |
| `CLM_MCP_URL` run: connection refused / hangs | Confirm the app is running (`az containerapp show --query properties.runningStatus`) and the URL includes `/mcp`. If you added a key, set `CLM_MCP_KEY` too. Unset `CLM_MCP_URL` to fall back to the local stdio server. |

## 🔗 How this fits

**You built** the team — a second specialist (**Clause & Risk**, GPT-5.6 Sol), an **Orchestrator**
(GPT-5.4) that routes to both via the **agent-as-tool** pattern, and an **MCP server** exposing the
whole workflow (locally, then on Azure Container Apps).

- **Builds on** Challenge 2's agent pattern and Challenge 3's evaluation discipline.
- **Feeds** Challenge 5, which publishes this orchestrator to where people work.

*In the arc → this is **"orchestrate a team"**: one agent becomes a reusable set of specialists callable from anywhere.*

## 🧠 Reflection

- Specialist agents-as-tools vs one mega-agent with many tools — what do you gain (separation, per-agent
  models/eval) and what do you pay (latency, orchestration complexity)?
- MCP makes the workflow portable. Who else in the org could consume `analyze_contract` without
  touching your code?

➡️ Next: **[Challenge 5 — Publish to M365 Copilot & Teams + Alerts](challenge-05.md)**
