# Challenge 2 — Solution: Demand Sensing Agent

**[← Previous](../challenge-01/solution-01.md)** - [Home](../../README.md) - [Next Solution →](../challenge-03/solution-03.md)

**Duration:** 60 minutes

## Goal

Build a Foundry prompt agent with Web Search + Fabric IQ connected to the published Fabric Data Agent to sense a real-world demand change.

## Solution walkthrough

### Agent creation

Navigate to **Agents → New agent**. If the portal shows a wizard, select **Prompt agent** (not Hosted agent).

Use dashboard **ModelDeploymentName** (default `gpt-5.4-mini`). On a fallback,
save the new model selection and use a fresh conversation. Confirm a Fabric tool
call, correct stock values and a grounded assessment; a model playground greeting
does not verify tool compatibility.

### Connecting the Data Agent

Use **Tools → Add → Add tools → Fabric IQ (OneLake Catalog)**, filter by **Data agent**, and select the team's `inventory-hack-agent` (check its **Location** is the attendee's own workspace). The earlier **Fabric Data Agent** tool, which asked for a Workspace ID and Agent ID, is deprecated and greyed out in the catalogue; it retires on 6 November 2026. The new connection is named after the Data Agent (`inventoryhackagent`), and Challenges 3 and 4 reuse it from the **Configured** tab.

### Common issues

Use **Tools → Add → Add tools → Fabric IQ (OneLake Catalog)**, filter by
**Data agent**, and select the team's `inventory-hack-agent`. Complete supported
OAuth consent and verify that identity's source-data access. The earlier
`fabric_dataagent_preview` connector retires on **6 November 2026**. Save the
new specialist version for Challenge 5; do not rebuild the Data Agent or create
an ontology solely for this migration.

| Symptom | Cause | Fix |
|---------|-------|-----|
| Fabric tool call returns "unauthorized" | The Fabric Data Agent isn't published, or your Fabric capacity is paused | You own this agent — confirm the setup notebook finished **publishing** it (Challenge 1) and that your Fabric capacity is **running** (Azure portal → your Fabric capacity → **Resume**) |
| Web Search returns no results | Web Search tool not enabled in the project | Go to **Project settings** and verify Web Search is listed under enabled tools |
| Agent ignores Fabric (trace shows only Web Search) | The model may treat data retrieval as optional, or the tool may be incompatible/misconfigured | Keep the mandatory tool instructions, name `inventory-hack-agent`, inspect the Fabric IQ tool trace and test supported run settings. `tool choice = required` forces a tool call, not necessarily the Fabric call when Web Search is also available. Do not dismiss tool-compatibility errors as cosmetic. |
| 429 / rate limiting | Could be TPM, RPM, request-budget estimates, service capacity, or the nested Fabric tool | Inspect the failing trace span, respect the retry delay and follow the [quota diagnostic runbook](../../labautomation/README.md#diagnose-throttling-before-adding-deployments). |
| A retail filter returns no rows | SQL used `Retail` rather than stored `retail` | Apply and publish the Challenge 1 data-source instructions/examples. Preserve requested filters; an empty P999 result is correct. |

### Expected agent response

A well-formed response includes three sections:

1. **External signals** — 2–3 web search results with URLs, describing the demand trend or event.
2. **Inventory position** — current stock levels for the relevant SKUs, sourced from Fabric.
3. **Assessment** — a clear verdict: adequate / at risk / critically exposed, with reasons.

In the playground the text before and after the tool calls can stream into one answer, so
a reply may read as two conclusions. Check the numbers, not the wording. The seed data gives:

| Question | Expected result |
|----------|-----------------|
| Leaf Blower X2 (P004) at Portland / Seattle | 8 and 6 on hand, reorder point 60 each |
| Lowest `outdoor_power_tools` stock relative to reorder point (all three products, per store) | **Portland (ST03): 25 on hand vs 135, gap -110**. Seattle (ST04) is next with 41 vs 135 |
| Single worst product and store | Leaf Blower X2 at Seattle: 6 on hand vs 60 |

An answer that names Seattle for the leaf blower and Portland for the whole category is
consistent. One that mixes the two without saying which level it uses is the usual
confusion; ask the agent to compare at category level.

### Sample test prompts

- *"A prolonged heatwave is forecast across the Pacific Northwest. What is our exposure on outdoor power tools like leaf blowers and chainsaws?"*
- *"Search trends show a spike in leaf blower demand. What is our current stock of the Leaf Blower X2 at the Portland and Seattle stores?"*
- *"Early spring is driving garden equipment demand. How are we positioned on garden and lawn products across our stores and warehouses?"*
