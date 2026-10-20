# Challenge 2 — Solution: Demand Sensing Agent

**[← Previous](../challenge-01/solution-01.md)** - [Home](../../README.md) - [Next Solution →](../challenge-03/solution-03.md)

**Duration:** 60 minutes

## Goal

Build a Foundry prompt agent with Web Search + Fabric IQ (connected to your published Fabric Data Agent) to sense a real-world demand change.

## Solution walkthrough

### Agent creation

Navigate to **Agents → New agent**. If the portal shows a wizard, select **Prompt agent** (not Hosted agent).

### Connecting the Data Agent

Use **Tools → Add → Add tools → Fabric IQ (OneLake Catalog)**, filter by **Data agent**, and select the team's `inventory-hack-agent` (check its **Location** is the attendee's own workspace). The earlier **Fabric Data Agent** tool, which asked for a Workspace ID and Agent ID, is deprecated and greyed out in the catalogue; it retires on 6 November 2026. The new connection is named after the Data Agent (`inventoryhackagent`), and Challenges 3 and 4 reuse it from the **Configured** tab.

### Common issues

| Symptom | Cause | Fix |
|---------|-------|-----|
| Fabric tool call returns "unauthorized" | The Fabric Data Agent isn't published, or your Fabric capacity is paused | You own this agent — confirm the setup notebook finished **publishing** it (Challenge 1) and that your Fabric capacity is **running** (Azure portal → your Fabric capacity → **Resume**) |
| Web Search returns no results | Web Search tool not enabled in the project | Go to **Project settings** and verify Web Search is listed under enabled tools |
| Agent ignores the Fabric tool (trace shows only Web Search, or it replies "I can't access your data") | `gpt-5.4-mini` is a GPT-5 reasoning model and may skip a tool it treats as optional; the portal may also flag the Fabric tool as "not supported" (cosmetic — it still runs via the Responses API) | Keep the **IMPORTANT - tool use** block in the instructions **and set tool choice = required** in the run settings so the Fabric Data Agent tool is always invoked. |

### Expected agent response

A well-formed response includes three sections:

1. **External signals** — 2–3 web search results with URLs, describing the demand trend or event.
2. **Inventory position** — current stock levels for the relevant SKUs, sourced from Fabric.
3. **Assessment** — a clear verdict: adequate / at risk / critically exposed, with reasons.

### Sample test prompts

- *"A prolonged heatwave is forecast across the Pacific Northwest. What is our exposure on outdoor power tools like leaf blowers and chainsaws?"*
- *"Search trends show a spike in leaf blower demand. What is our current stock of the Leaf Blower X2 at the Portland and Seattle stores?"*
- *"Early spring is driving garden equipment demand. How are we positioned on garden and lawn products across our stores and warehouses?"*
