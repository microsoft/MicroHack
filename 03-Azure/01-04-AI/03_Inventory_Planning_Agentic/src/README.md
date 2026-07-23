# src — developer guide

Everything the participant builds lives here. It runs unchanged in a Codespace or
locally.

## Run it

Everything runs through one surface: the **planner console**. There is no CLI.

```bash
# 0. Install dependencies (the devcontainer / Codespace does this for you)
uv sync

# 1. Authenticate (the agents use DefaultAzureCredential)
az login

# 2. Configure — copy the three values from your lab dashboard
cp ../.env.example .env        # then edit PROJECT_ENDPOINT + MODEL_DEPLOYMENT_NAME + COSMOS_ENDPOINT

# 3. Launch the planner console, then open the forwarded port 8000
uv run uvicorn ui.app:app --reload --port 8000
```

Click through **Sense → Plan → Approve → Act** in the browser. The first time you
click a step, its hosted agent is created in your Foundry project and run. Editing
agent code and saving auto-reloads the server (`--reload`), so just refresh and click
again.

> [!TIP]
> The default model `gpt-5.4-mini` is a GPT-5 *reasoning* model. `.env` sets
> `REASONING_EFFORT=minimal` so runs stay fast for the interactive console. The
> runtime (`agent_runtime._respond`) applies it when the SDK/model supports it
> and silently falls back otherwise, so any model still works.

> [!NOTE]
> The runtime uses the **new Microsoft Foundry agents API** (`azure-ai-projects` 2.x):
> each agent is a versioned `PromptAgentDefinition` served over the **Responses**
> protocol (`client.agents.create_version` + `get_openai_client().responses`). That
> makes the agents **native** in the Foundry portal — they appear under **Agents**
> with a **Traces** tab and no "update your agents" migration prompt — and their runs
> are **traced server-side** (labautomation connects Application Insights for you).
> `uv sync` installs the right versions.

## How the pieces fit

| File | Role |
|------|------|
| `data/*.json` | Zava **seed** data — loaded into Cosmos on first run |
| `inventory_store.py` | Cosmos-backed store: connects keyless (`DefaultAzureCredential`), seeds containers once, derives `Inventory` + `DemandHistory`, serves the tools |
| `tools.py` | The function tools agents call; `submit_purchase_order` is the only side effect (a real Cosmos write) |
| `agents/__init__.py` | The three `AgentSpec`s (name, instructions, tools) |
| `agent_runtime.py` | Creates the **native** (versioned) Foundry agents and runs them over the Responses API; pauses on approval-gated tools |
| `orchestrator.py` | `sense → plan → propose → approve` for the UI (plus `refine_plan` / `refine_proposal` for natural-language edits) |
| `workflow.py` | Stretch: the whole loop as one callable (used by `/api/run-loop`) |
| `live.py` | Stretch (Challenge 6): Cosmos change-feed watcher — auto-runs the loop when a signal is written, streamed to the UI over SSE, stopping at the human gate |
| `mcp_server.py` | Stretch (Challenge 6): MCP server exposing `inject_signal` so an external client can trigger the loop |
| `ui/` | Minimal FastAPI + static-HTML planner console — the only way in |

> The store is provisioned by `labautomation` (per-attendee Cosmos DB, keyless). The
> app **seeds** it from `data/` on the first console action, so `src/.env` needs
> `COSMOS_ENDPOINT` and you must `az login` first.

## The human-in-the-loop gate

`submit_purchase_order` is listed in `agent_runtime.APPROVAL_REQUIRED`. When an
agent asks to call it, the runtime **does not execute it** — it returns a
`ToolApprovalRequest`. Only a human (via the console's *Approve* button) triggers
the actual submission through `orchestrator.approve(...)` — which performs a **real,
durable write** to the Cosmos `orders` container (it survives restarts).
