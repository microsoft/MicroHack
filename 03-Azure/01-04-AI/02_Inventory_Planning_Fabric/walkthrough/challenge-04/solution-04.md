# Challenge 4 — Solution: Replenishment Action Agent + Human-in-the-Loop

**[← Previous](../challenge-03/solution-03.md)** - [Home](../../README.md) - [Next Solution →](../challenge-05/solution-05.md)

**Duration:** 75 minutes

## Goal

Build the Replenishment Action Agent, implement the human approval loop, and trace the full cycle.

## Solution walkthrough

### Tools — one tool, and remove the default Web Search

This agent needs **only the Fabric IQ tool** (to look up unit costs from the `Products` table). Reuse the `inventoryhackagent` connection from Challenge 2 (**Tools → Add → Add tools → Configured**). New prompt agents may ship with **Web Search attached by default** — **remove it**, or `gpt-5.4-mini` will reach for the web instead of the governed cost data. After configuring, confirm Fabric IQ is the only tool listed.

### Simulated submission (no function tool)

The current **New Foundry** portal has no no-code custom-function tool — the Custom tab offers only OpenAPI, MCP, and A2A connectors, which all need a hosted endpoint. Because the Fabric Data Agent is read-only, the "act" step is **simulated by the agent**: on `YES`, its instructions have it generate a confirmation message (`✅ Purchase order PO-... submitted`). This keeps the lab fully no-code while still demonstrating the approve → act gate. In production you'd swap this for an OpenAPI tool that writes to the `ReplenishmentOrders` table / ERP (see Challenge 4, Part E).

### The MODIFY flow

When an attendee replies `MODIFY 1 50`, the agent should:
1. Find line 1 in the current proposal.
2. Update the quantity to 50.
3. Recalculate the line total and the grand total.
4. Re-present the full updated proposal.
5. Ask for approval again.

If the agent skips the re-presentation, add to the instructions: *"After any MODIFY, always re-present the full updated table before asking for approval again."*

### Trace — what the full cycle looks like

In the agent's **Traces** tab (or the playground's **Traces** link), one conversation shows one **Invoke Agent** span per message:

```
Conversation
├── Invoke Agent (first message: the recommendation table)
│   ├── Execute Tool: Fabric IQ (unit-cost lookup from Products)
│   └── Chat (present proposal + ask for approval)
├── Invoke Agent (user replies: MODIFY 1 50)
│   └── Chat (update line 1, recalculate, re-present)
└── Invoke Agent (user replies: YES)
    └── Chat (simulated confirmation: "✅ Purchase order PO-... submitted")
```

Only the first turn calls Fabric, because the later turns reuse the costs the agent already has.

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
