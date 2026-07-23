# Challenge 4 — Solution: Orchestrate the Loop (Stretch)

**[← Previous](../challenge-03/solution-03.md)** - [Home](../../README.md)

**Duration:** ~45 minutes (optional)

## Goal

Chain the three agents in a Foundry **Workflow** (Sequential pattern + human-in-the-loop), then read the node-by-node trace.

## Solution walkthrough

### Why a workflow, not connected agents

The classic **connected agents** tool (one agent added as another's tool) is **not available** in the New Foundry portal — Microsoft replaced it with **Workflows** for multi-agent orchestration. A workflow is a *deterministic* graph: each agent is a **node**, and edges pass one node's output to the next. That's a better fit than an LLM-driven orchestrator for this hack's fixed sense → plan → approve → act chain, and it keeps everything no-code.

Wire the three specialists in order and name each node's output so the next node can consume it:
- `demand-sensing-agent` → output `demandAssessment`
- `inventory-optimisation-agent` → input `demandAssessment`, output `reorderTable`
- `replenishment-action-agent` → input `reorderTable`, **Allow multi-turn conversation** ON for the approval gate

> The visual designer is supported in-portal until **1 December 2026**; after that, export the workflow **YAML** and run it via Microsoft Agent Framework / a hosted agent. The orchestration logic carries over unchanged.

### What a good run looks like

The orchestrator should narrate its delegation and stop at the approval gate:

```
run (challenge 4 workflow)
├── node: demand-sensing-agent
│   └── tool_call: Fabric Data Agent (stock + velocity)
│   → "Outdoor power tools critically exposed at Portland/Seattle."
├── node: inventory-optimisation-agent
│   └── tool_call: Fabric Data Agent (reorder point + demand)
│   → recommendation table with CRITICAL items
└── node: replenishment-action-agent
    ├── model_call (present PO, ask for approval)
    │   → user replies: YES
    └── model_call (simulated PO confirmation)
```

### Common issues

| Symptom | Fix |
|---|---|
| A node gets empty input | Wire it: set the node's **Input message** to the upstream node's **Save agent output message as** variable. |
| A specialist node uses the wrong model | Each node runs its underlying agent — confirm that agent is on `gpt-5.4-mini` with **tool choice = required** so it always calls the Fabric tool. |
| Approval gate is skipped | Enable **Allow multi-turn conversation** on the `replenishment-action-agent` node, and keep the Challenge 3 instructions that require explicit `YES`. |
| No **Workflows** tab / designer | Preview rollout — use the Part D evaluation alternative instead. |

### Discussion points

- **Deterministic workflow vs. three human-driven agents:** the workflow is faster and hands-free, but the human loses the natural checkpoints between steps. The approval gate becomes the *only* control point — so it matters even more.
- **Where would you add guardrails** in a production version? (e.g. a spend cap the orchestrator can't exceed without escalation.)
