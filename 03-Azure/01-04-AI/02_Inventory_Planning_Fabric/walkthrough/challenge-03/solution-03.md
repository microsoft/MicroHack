# Challenge 3 — Solution: Inventory Optimisation Agent

**[← Previous](../challenge-02/solution-02.md)** - [Home](../../README.md) - [Next Solution →](../challenge-04/solution-04.md)

**Duration:** 60 minutes

## Goal

Build the Inventory Optimisation Agent and use agent tracing to inspect its reasoning.

## Solution walkthrough

### Agent — key configuration point

Select dashboard **ModelDeploymentName** (default `gpt-5.4-mini`), including when
the facilitator has configured a fallback.

This agent should have **only Fabric IQ**, connected to the published `inventory-hack-agent` — no Web Search. Remove any default Web Search tool. Select the Data Agent by reusing the `inventoryhackagent` connection from Challenge 2 (**Tools → Add → Add tools → Configured → `inventoryhackagent`**), so no second connection is created, and save the specialist version for Challenge 5. Do not use the retiring Fabric Data Agent connector. Optimisation decisions should be traceable to authoritative internal data, not unverified web content.

### Reading the trace — what to look for

In the agent's **Traces** tab, open a run's **Trace ID**. The **Trajectories** tab shows a tree of spans:

```
Invoke Agent: invoke_agent inventory-optimisation-agent:<version>
├── Execute Tool: mcp_inventoryhackagent.DataAgent_inventory_hack_agent   (the Fabric call, tens of seconds)
└── Chat: gpt-5.4-mini                                                    (final synthesis, under a second)
```

Select a span and use **Input + Output** on the right to read the query, the data Fabric returned and the final answer. The agent may call Fabric more than once.

### Common issues

| Symptom | Cause | Fix |
|---------|-------|-----|
| Agent returns "I don't have enough information" or an empty table | Product/category words don't match Fabric values | Ask by **SKU/productId** (e.g. `P004`) or the exact snake_case category value (`outdoor_power_tools`), not a friendly label like "Outdoor Power Tools" |
| Reorder quantity seems wrong | Agent used a different formula | Remind the agent of the formula in a follow-up: "Use the rule: reorder_qty = max(0, 30-day demand - current stock)" |
| "Show me only the CRITICAL items" returns more rows than the first table | The chat was new, so the agent re-queried the data. It used the Data Agent's Challenge 1 rule (on hand below **safety stock**, five SKU/store pairs) instead of this agent's rule (below **reorder point**, 14 rows incl. warehouses) | Ask in the same chat as the table (it then returns the three rows), or name the SKUs and locations in the prompt |
| Trace not appearing | Tracing may take 30–60 seconds to update | Refresh the agent's **Traces** tab |

### Sample recommendation table

> Illustrative — exact quantities depend on the agent's rounding. `DemandHistory` is **weekly per retail store**, so `average_daily_sales = average weekly units / 7` (~0.8/day for P004). 30-day demand is then ~24, so a store with 6–8 on hand yields a small positive reorder and a **CRITICAL** flag (on hand below safety stock 30).

```
| SKU  | Product        | Location | Current Stock | Suggested Reorder Qty | Priority |
|------|----------------|----------|---------------|-----------------------|----------|
| P004 | Leaf Blower X2 | Seattle  | 6             | 18                    | CRITICAL |
| P004 | Leaf Blower X2 | Portland | 8             | 16                    | CRITICAL |
| P006 | Hedge Trimmer  | Portland | 12            | 8                     | CRITICAL |
```
