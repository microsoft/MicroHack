# Challenge 1 — Demand Sensing (Hosted Agent)

**[← Previous](challenge-00.md)** - [Home](../README.md) - [Next Challenge →](challenge-02.md)

## 🎯 Objective

Build and deploy your first **hosted agent** in code. Give it **function tools**
over the governed inventory data, run it against a real-world scenario, and light
up **Step 1** of the planner console.

## 🧭 Context

Your facilitator announces a scenario, for example:

> *"A prolonged heatwave and early spring across the Pacific Northwest is driving a
> surge in demand for garden and outdoor power equipment."*

Your agent must sense that signal, reconcile it against the governed inventory
position, and produce a demand assessment planners can act on.

## ✅ Tasks

### Part A — Read the agent definition (15 min)

Open [`src/agents/__init__.py`](../src/agents/__init__.py) and study `DEMAND_SENSING`:

- **`name`** — becomes the hosted agent's name in your Foundry project.
- **`instructions`** — the system prompt; note the strict *TOOL USE* rule.
- **`functions`** — `query_inventory`, `list_low_stock`, `get_external_signals`
  from [`src/tools.py`](../src/tools.py).

Open [`src/agent_runtime.py`](../src/agent_runtime.py) and follow `AgentRuntime.ensure`:
it **creates a versioned agent** with the new Foundry agents API and routes the
agent's endpoint to it — this is what makes it a *native hosted* agent (it appears in
the portal under **Agents**, with a **Traces** tab).

### Part B — Run the agent from the console (20 min)

You run the agent straight from the planner console — there are no scripts to run.

1. Launch the console (if it isn't already running) and open the forwarded port 8000:
   ```bash
   cd src && uv run uvicorn ui.app:app --reload --port 8000
   ```
2. Pick a scenario and click **Sense demand**.

That first click does two things: `AgentRuntime.ensure()` **creates the
`demand-sensing-agent` hosted agent** in your Foundry project, then runs it. Step 1
turns green and shows an assessment that:
- cites at least one **external signal** (from `get_external_signals`),
- references at least one **governed inventory** number (from `list_low_stock` /
  `query_inventory`), and
- states whether stock is **adequate / at risk / critically exposed**.

Step 2's button unlocks once Step 1 succeeds.

![The planner console after Step 1: the demand assessment appears and Step 2 unlocks](../images/challenge-01-console.png)

Now confirm it's really hosted: open [ai.azure.com](https://ai.azure.com) → your
project → **Agents**. You'll see **`demand-sensing-agent`** listed — the hosted agent
your click just created. Edit its instructions in `src/agents/__init__.py`, save (the
server auto-reloads), and click **Sense demand** again to update it in place.

> [!NOTE]
> In the agent's **Playground** tab, its function tools may show *"Not supported by
> the selected model."* This is a **cosmetic** portal capability flag for
> `gpt-5.4-mini` — the tools **do** execute at runtime via the Responses API (the
> assessment's governed numbers come straight from those tool calls).

### Part C — (Optional) add Web Search grounding (10 min)

The `get_external_signals` tool already grounds the agent in pre-loaded market
signals, so the challenge completes without any live web tool. If your project has
the Web Search / Bing grounding tool enabled, set `ENABLE_WEB_SEARCH=true` in
`src/.env` and extend the agent to add it (see **Go further**).

## 🏁 Success criteria

- [ ] `demand-sensing-agent` appears under **Agents** in your Foundry project.
- [ ] Running the agent returns an assessment backed by a governed data point **and**
      an external signal, with a clear adequate / at-risk / exposed verdict.
- [ ] The planner console's **Step 1** turns green and unlocks Step 2.
- [ ] You can explain what each function tool contributed.

## 🛠️ Troubleshooting

| Symptom | Fix |
|---------|-----|
| `PROJECT_ENDPOINT is not set` | Fill in `src/.env` from your dashboard (Challenge 0). |
| `DefaultAzureCredential` error | Run `az login` in the same terminal. |
| Agent answers from memory | Strengthen the *TOOL USE* rule in the instructions. |
| The agent never calls a tool | Confirm the deployed model's Foundry card lists **Functions/Tools** support (e.g. `gpt-5.4-mini`); avoid the older o-series. |

## 🚀 Go further

- Add the Bing grounding tool: create a `BingGroundingTool` in `agent_runtime.ensure`
  when `config.ENABLE_WEB_SEARCH` is true, and pass a `BING_CONNECTION_ID`.
- Ask the agent to rank **all** locations by exposure, not just the worst.
- Add a second scenario (a supplier delay) and compare the assessment.

## 📚 Learning resources

- [Create and run agents with the Foundry Agents SDK](https://learn.microsoft.com/azure/ai-foundry/agents/quickstart)
- [Function tools for agents](https://learn.microsoft.com/azure/ai-foundry/agents/how-to/tools/function-calling)
