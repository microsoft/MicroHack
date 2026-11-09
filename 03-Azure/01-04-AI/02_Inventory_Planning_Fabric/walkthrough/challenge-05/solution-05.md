# Challenge 5 — Solution: Orchestrate the Loop (Stretch)

**[← Previous](../challenge-04/solution-04.md)** - [Home](../../README.md)

**Duration:** ~45 minutes (optional)

## Goal

Chain the three agents in a Foundry **Workflow** (Sequential template) with a human approval gate on the last node, run the loop from one prompt, and read the node-by-node trace.

> The visual designer is supported in the portal until **30 November 2026**; Foundry retires in-portal workflows on **1 December 2026**.

## Solution walkthrough

### Why it is simpler than it looks

All nodes run in **one shared conversation** (`System.ConversationId`), so each agent reads the previous agent's reply from the conversation history. **No data wiring between nodes is needed.** The only node that needs configuration is the last one.

### The finished workflow

| Node | Agent | Settings |
|------|-------|----------|
| 1 | `demand-sensing-agent` | Defaults |
| 2 | `inventory-optimisation-agent` | Defaults |
| 3 | `replenishment-action-agent` | **Input message** = `Local.LatestMessage` (default) · **Allow multi-turn conversation** = on · **Loop condition** = formula below |

```powerfx
And(
  IsBlank(Find("submitted to ERP", Last(Local.LatestMessage).Text)),
  IsBlank(Find("Order cancelled", Last(Local.LatestMessage).Text))
)
```

The node keeps waiting for the human **while** the formula is true. `MODIFY` re-presents the proposal (neither phrase present), while `YES` (`✅ … submitted to ERP.`) or `NO` (`❌ Order cancelled…`) ends the node. `Find` is case-sensitive, so the Challenge 4 confirmation wording must stay exactly as written.

### What a good run looks like

```
workflow run (inventory-planning-workflow)
├── node: demand-sensing-agent
│   └── tool_call: Fabric IQ (stock + velocity)
│   → "Outdoor power tools critically exposed at Portland/Seattle."
├── node: inventory-optimisation-agent
│   └── tool_call: Fabric IQ (reorder point + demand)
│   → recommendation table with CRITICAL items
└── node: replenishment-action-agent   (multi-turn)
    ├── tool_call: Fabric IQ (unit costs: P004 $95, P005 $140, P006 $85)
    ├── model_call → PO proposal + "Do you approve…?"
    │   → user replies: YES
    └── model_call → "✅ Purchase order PO-<date>-001 submitted to ERP."  (loop ends → End)
```

### Coaching tips

- **Run the pre-flight check first.** Most failures come from an agent name that doesn't match or a changed confirmation phrase in `replenishment-action-agent`.
- **Remind teams to Save after every change** — the designer doesn't save automatically, and only saves a valid workflow (template notes deleted, **End** node added). Refresh the page after saving before using **Preview**.
- **Always retry in a new conversation.** A failed run leaves its messages in the shared conversation, which confuses the next attempt.
- **Use the trace to locate a bad step**, then fix that agent in its own playground before re-running the workflow.

### Common issues

| Symptom | Fix |
|---|---|
| Loop condition error *"Name isn't valid"* | Keep **Input message** = `Local.LatestMessage` (the default) on the replenishment node and re-paste the formula. |
| **Save** fails | Delete the template's yellow notes and add an **End** node (**+ → Basics → End**). |
| **Preview** disabled or chat won't accept input | **Save**, refresh the page, then open **Preview**. |
| The run ends at the proposal without waiting | **Allow multi-turn conversation** is off on the replenishment node. |
| The node never stops asking | The confirmation wording in the Challenge 4 instructions was changed; restore `submitted to ERP` / `Order cancelled`. |
| A later agent has no data or asks for a table | An earlier node failed (often the collation-conflict query). Start a new conversation and name the SKU and stores in the prompt. |
| `$20` unit costs | The replenishment agent skipped the Fabric cost lookup. Reply `NO` and re-run in a new conversation. |
| A node uses the wrong model or skips its tool | Each node runs its underlying agent — confirm the agent is on `gpt-5.4-mini` with Fabric IQ connected. |
| No **Workflows** option | Use the new Foundry portal (**Build**) and check the attendee has **Contributor** on the project. |

### Discussion points

- **Deterministic workflow vs. three human-driven agents:** the workflow is faster and hands-free, but the human loses the natural checkpoints between steps. The approval gate becomes the *only* control point — so it matters even more.
- **Where would you add guardrails** in a production version? (e.g. a spend cap that requires escalation, and an audit review of the trace.)
- **After 1 December 2026:** point teams to the note at the end of the challenge — copy the workflow YAML, then use Microsoft Agent Framework (hosted agent), Azure Logic Apps, or A2A to reuse the same pattern in their own scenarios.