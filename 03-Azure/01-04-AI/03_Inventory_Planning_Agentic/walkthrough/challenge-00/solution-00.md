# Solution 00 — Get Grounded & Set Up

**[← Back to Challenge 0](../../challenges/challenge-00.md)** · [Home](../../README.md)

This walkthrough confirms a correct setup. There is no agent to build yet.

## Expected end state

- Codespace (or local devcontainer) built, dependencies installed.
- `az login` completed in the Codespace terminal.
- `src/.env` populated from the lab dashboard:
  ```
  PROJECT_ENDPOINT=https://inv-xxxxxxxxxxxx.services.ai.azure.com/api/projects/inventory-hack
  MODEL_DEPLOYMENT_NAME=gpt-5.4-mini
  COSMOS_ENDPOINT=https://inv-cos-xxxxxxxxxxxx.documents.azure.com:443/
  REASONING_EFFORT=minimal
  ```
- The Foundry portal shows `gpt-5.4-mini` = *Succeeded* under **Models + endpoints**.
- The planner console loads on port 8000 and shows populated **Current exposure**
  and **Order book** panels (from Cosmos, seeded on first load — no agent required).

## Verify the data layer without any agent

The console's **Current exposure** panel is served straight from the governed Cosmos
store (the `/api/state` endpoint → `list_low_stock`) — no agent required. Expect leaf
blowers (`P004`) and chainsaws (`P005`) at Portland (`ST03`) and Seattle (`ST04`)
flagged `CRITICAL`, plus a few `AT_RISK` rows. These numbers are seeded
deterministically by `inventory_store.py`, so they are stable every run.

## Why the console still works before Challenge 1

`ui/app.py` serves the page and the `/api/state` snapshot from the bundled data.
The `/api/sense|plan|propose|approve` endpoints create the orchestrator lazily and
return a friendly `503 {"error": ...}` until the agents exist — so the shell loads,
and each step lights up as you build its agent.

## Common issues

| Symptom | Cause / fix |
|---------|-------------|
| `PROJECT_ENDPOINT is not set` | `.env` missing or not in `src/` — the console reads it via `config.py`. |
| Panels empty | A Python import error — check the `uvicorn` terminal output. |
| Port 8000 not forwarded | Open the **Ports** tab and forward 8000 manually. |
