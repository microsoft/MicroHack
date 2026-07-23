# Solution 05 — The Loop Reacts (Event-Driven, Stretch)

**[← Back to Challenge 6](../../challenges/challenge-06.md)** · [Home](../../README.md)

## The idea

The manual console has a human click Sense → Plan → Approve → Act. This challenge makes
the loop **reactive**: an independent write to the Cosmos `signals` container triggers
the agents automatically, and the console shows it live — while the **human-approval
gate is preserved** (automation runs everything *except* the decision).

No new Azure infrastructure: Cosmos' **change feed** is intrinsic, and the watcher runs
inside the existing FastAPI process.

## The reactive layer — [`src/live.py`](../../src/live.py)

Three pieces:

- **`start_watcher(store, orchestrator_factory)`** — a daemon thread that tails the
  `signals` change feed with the **pull model**. It primes from `start_time="Now"`
  (so the one-time seed never triggers a run), then polls with the continuation token
  returned in the `etag` response header. Each new document calls `_auto_run`.
- **`_auto_run(signal, ...)`** — runs `orch.sense → orch.plan → orch.propose` (the same
  `HackOrchestrator` the console uses), publishing a `step` event at each stage, then
  emits `awaiting_approval` and **stops**. It never calls `approve`.
- **`EventBus`** — a tiny fan-out that pushes JSON events to every connected SSE client.
  Because it's called from the watcher thread, it hops back onto the event loop with
  `call_soon_threadsafe`.

## The wiring — [`src/ui/app.py`](../../src/ui/app.py)

```python
@app.on_event("startup")
async def _start_live_layer():
    bus.bind_loop(asyncio.get_running_loop())
    if config.COSMOS_ENDPOINT:
        start_watcher(get_store(), get_orchestrator)   # tail the change feed

@app.post("/api/signal")      # writes the signal only — the change feed triggers the loop
@app.get("/api/events")       # SSE stream the console subscribes to
```

The key design choice: **`/api/signal` never calls an agent.** It only writes to Cosmos.
The change-feed watcher is the *single* trigger path, so the reactive behaviour is
identical no matter who does the insert — the console, an MCP client, or any other
system. That decoupling is the whole point.

## The console — [`src/ui/static/index.html`](../../src/ui/static/index.html)

An **Event trigger** panel injects a signal (`POST /api/signal`) and an `EventSource`
on `/api/events` drives Steps 1–3 as the events arrive, then enables **Approve / Reject**
at Step 4. The manual buttons still work — the SSE path reuses the same `renderPlan` /
`renderProposal` helpers.

## The MCP edge — [`src/mcp_server.py`](../../src/mcp_server.py)

A one-tool **FastMCP** server:

```python
@mcp.tool()
def inject_signal(headline, category="outdoor_power_tools", region="Pacific Northwest") -> str:
    doc = get_store().append_signal({"headline": headline, "category": category,
                                     "region": region, "type": "market"})
    return f"Injected signal {doc['signalId']} — the planner loop will react automatically."
```

Run it with `uv run python mcp_server.py` (stdio) and point any MCP client at it. Calling
`inject_signal` writes to Cosmos → the console's watcher reacts → the loop runs → it stops
at the gate. An external system, speaking a standard protocol, drove your inventory loop.

## Interactive planning & the informed gate

The reactive loop produces a **draft**; the planner refines it in natural language before
approving. Two "refine" endpoints re-run the relevant agent with the current artifact plus
the instruction (see [`src/orchestrator.py`](../../src/orchestrator.py)):

- `POST /api/plan/refine` → `refine_plan(recommendation, instruction)` re-runs the
  **Inventory Optimisation** agent (*"only the CRITICAL SKUs"*, *"halve the leaf blowers"*).
- `POST /api/propose/refine` → `refine_proposal(proposal, instruction)` re-runs the
  **Replenishment** agent (*"drop the warehouse line"*, *"cut chainsaws to 40"*), returning
  the updated proposal **and** `submitItems`.

Both are agentic (not regex): the agent regenerates the artifact honoring the instruction,
and both still only **propose** — the gate is unchanged. Step 4 then renders exactly what
will be written (every PO line + total), so the human approves with full context.

**The signal queue:** the watcher is a producer/consumer pair — the producer tails the
change feed and enqueues; a single consumer drains one signal at a time. A burst shows up
as a visible backlog (`queue` SSE events) in the Sense step and drains as each run completes.

## Why this preserves the lesson

The reactivity is new; the **human-in-the-loop** teaching is untouched. `_auto_run` stops
at `propose` and emits `awaiting_approval`; only a person calling `/api/approve` triggers
`submit_purchase_order`. Even a signal injected over MCP reaches the gate and waits.

## Talking points

- **Event-driven vs. request-driven**: the loop reacts to *data changing*, not to a user
  clicking — the same shift that makes real operations scalable.
- **Decoupling**: the producer (UI / MCP / job) knows nothing about the agents; it just
  writes a signal. The change feed is the seam.
- **The gate still holds**: automation is safe precisely because the one side effect stays
  behind a human — no matter how the loop was triggered.
