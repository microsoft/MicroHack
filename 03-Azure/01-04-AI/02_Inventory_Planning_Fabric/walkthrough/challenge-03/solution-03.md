# Challenge 3 — Solution: Replenishment Action Agent + Human-in-the-Loop

**[← Previous](../challenge-02/solution-02.md)** - [Home](../../README.md) - [Next Solution →](../challenge-04/solution-04.md)

**Duration:** 75 minutes

## Goal

Build the Replenishment Action Agent, implement the human approval loop, and trace the full cycle.

## Solution walkthrough

### Simulated submission (no function tool)

The current **New Foundry** portal has no no-code custom-function tool — the Custom tab offers only OpenAPI, MCP, and A2A connectors, which all need a hosted endpoint. Because the Fabric Data Agent is read-only, the "act" step is **simulated by the agent**: on `YES`, its instructions have it generate a confirmation message (`✅ Purchase order PO-... submitted`). This keeps the lab fully no-code while still demonstrating the approve → act gate. In production you'd swap this for an OpenAPI tool that writes to the `ReplenishmentOrders` table / ERP (see Challenge 3, Part E).

### The MODIFY flow

When an attendee replies `MODIFY 1 50`, the agent should:
1. Find line 1 in the current proposal.
2. Update the quantity to 50.
3. Recalculate the line total and the grand total.
4. Re-present the full updated proposal.
5. Ask for approval again.

If the agent skips the re-presentation, add to the instructions: *"After any MODIFY, always re-present the full updated table before asking for approval again."*

### Trace — what the full cycle looks like

```
run (challenge 3 approval)
├── model_call (format PO proposal from recommendation)
│   └── tool_call: Fabric Data Agent (unit-cost lookup from Products)
├── model_call (present proposal + ask for approval)
│   → user replies: MODIFY 1 50
├── model_call (update line 1, recalculate, re-present)
│   → user replies: YES
└── model_call (simulated confirmation: "✅ Purchase order PO-... submitted")
```

### Where does the human add value?

The human approval step adds value that an automated pipeline cannot replicate:
- **Business context** — budget constraints, supplier relationships, timing preferences
- **Exception handling** — unusual circumstances the model's instructions don't cover
- **Accountability** — a named human is on record as having approved the expenditure

This is why the pattern is called "human-in-the-loop" rather than "human-in-the-way" — the human is the decision-maker; the agent is the research and proposal layer.

### Monitoring in production

In a production deployment, you would add:
- **Application Insights** integration (built into Foundry) for latency and error tracking
- **Evaluation runs** to catch instruction drift over time
- **Agent versioning** so you can roll back if a model update changes behaviour
