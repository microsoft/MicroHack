# Challenge 3 — Solution: Inventory Optimisation Agent

**[← Previous](../challenge-02/solution-02.md)** - [Home](../../README.md) - [Next Solution →](../challenge-04/solution-04.md)

**Duration:** 60 minutes

## Goal

Build the Inventory Optimisation Agent and use agent tracing to inspect its reasoning.

## Solution walkthrough

### Agent — key configuration point

This agent should have **only the Fabric Data Agent tool** — no Web Search. If attendees add Web Search, the agent may use it unnecessarily. The instructions say "governed data only" for a reason: optimisation decisions should be traceable to authoritative internal data, not unverified web content.

### Reading the trace — what to look for

In **Tracing**, each run shows a tree of spans:

```
run
├── model_call (instructions + user message sent to gpt-5.4-mini)
├── tool_call: Fabric Data Agent
│   ├── input: { query: "current stock and reorder point for Leaf Blower X2 (P004) across all locations" }
│   └── output: { ... table of rows ... }
├── tool_call: Fabric Data Agent   ← agent may call multiple times
│   ├── input: { query: "average weekly sales for outdoor power tools over the last 8 weeks" }
│   └── output: { ... }
└── model_call (final synthesis → recommendation table)
```

### Common issues

| Symptom | Cause | Fix |
|---------|-------|-----|
| Agent returns "I don't have enough information" | Product/category words don't match Fabric values | Ask by the real product name or category, e.g. "Leaf Blower X2" or "outdoor power tools" |
| Reorder quantity seems wrong | Agent used a different formula | Remind the agent of the formula in a follow-up: "Use the rule: reorder_qty = max(0, 30-day demand - current stock)" |
| Trace not appearing | Tracing may take 30–60 seconds to update | Refresh the Tracing page |

### Sample recommendation table

```
| SKU  | Product        | Location  | Current Stock | Suggested Reorder Qty | Priority |
|------|----------------|-----------|---------------|-----------------------|----------|
| P004 | Leaf Blower X2 | Seattle   | 6             | 54                    | CRITICAL |
| P004 | Leaf Blower X2 | Portland  | 8             | 52                    | CRITICAL |
| P005 | Chainsaw 16in  | Portland  | 5             | 31                    | CRITICAL |
| P004 | Leaf Blower X2 | Chicago   | 45            | 15                    | At Risk  |
```
