# Solution 04 — Orchestrate the Loop (Stretch)

**[← Back to Challenge 5](../../challenges/challenge-05.md)** · [Home](../../README.md)

## The reference implementation

[`src/workflow.py`](../../src/workflow.py) → `run_planning_workflow(scenario, approve, ...)`
runs the full loop from one entry point: `sense → plan → propose → [human] → approve`.
The `approve` callback **is** the human gate — it receives the proposal and returns
`True` to submit or `False` to cancel.

## How the console drives it

The console exposes the workflow at **`/api/run-loop`** in
[`src/ui/app.py`](../../src/ui/app.py). It calls
`run_planning_workflow(scenario, approve=lambda _p: False, orchestrator=...)` so the
loop runs `sense → plan → propose` in one request and returns all three stages —
**without** submitting. The human still approves at Step 4 via `/api/approve`.

```json
// POST /api/run-loop  { "scenario": "..." }  ->
{ "assessment": "…", "recommendation": { … }, "proposal": { … } }
```

`WorkflowResult` carries `assessment`, `recommendation`, `proposal`, and
`confirmation` (`None` when the gate returns False — which is exactly what the
endpoint uses, deferring the real decision to the human).

## The one-click UI button

Add a **Run the whole loop** button in
[`src/ui/static/index.html`](../../src/ui/static/index.html) that `POST`s the scenario
to **`/api/run-loop`**, fills Steps 1–3 from the response
(`assessment` / `recommendation` / `proposal`), then **stops** at Step 4 for the
human's Approve/Reject. Do **not** auto-call `/api/approve` — keeping the gate is the
point of the pattern.

## Optional: evaluation pass

In the portal **Evaluation**, build a 3–5 item dataset (e.g. *"Which store has the
lowest leaf blower stock?"* → *"Portland"*) and score `inventory-optimisation-agent`
on groundedness and relevance.

## Talking points

- Deterministic sequential workflow vs. a human clicking each step: automation for the
  hand-offs, human judgment only at the gate.
- Where the gate belongs once the loop is one prompt (before the acting tool — exactly
  where `APPROVAL_REQUIRED` puts it).
