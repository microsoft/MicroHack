# Challenge 2 — Demand Sensing Agent

**[← Previous](challenge-01.md)** - [Home](../README.md) - [Next Challenge →](challenge-03.md)

## 🎯 Objective

Build your first Foundry prompt agent. Configure it with two tools — **Web Search** and **Fabric IQ** (connected to your published Fabric Data Agent) — and use it to sense a real-world demand change and reconcile it against the current inventory position. No code required; everything is done in the Foundry portal.

## 🧭 Context

Use this scenario throughout the challenge:

> *"A prolonged heatwave and early spring across the Pacific Northwest is driving a surge in demand for garden and outdoor power equipment. Retailer search trends and social media show spikes for leaf blowers and lawn tools. Our planning team needs to know if current stock levels can absorb this demand or if we are already exposed."*

Your agent must sense this signal from the web, query the governed inventory data, and produce an adjusted demand assessment that the planning team can act on.

## ✅ Tasks

### Part A — Create the agent (15 min)

1. In the Foundry portal, navigate to **Agents** and click **New agent**.
2. Name it `demand-sensing-agent`.
3. Select dashboard **ModelDeploymentName** (default `gpt-5.4-mini`).
4. Paste the following **system instructions** into the Instructions field:
   ```
   You are a Demand Sensing Agent for a retail inventory planning team.

   Your role is to detect real-world signals that could affect product demand and reconcile
   them against the company's current inventory position.

   IMPORTANT - tool use (non-negotiable): Fabric IQ connects inventory-hack-agent to the
   governed Zava inventory data (Inventory, Products, Stores, DemandHistory, ExternalSignals,
   Suppliers, ReplenishmentOrders). EVERY response that gives a demand assessment MUST include
   at least one Fabric Data Agent call - this is mandatory and NOT conditional on Web Search.
   For ANY inventory number (stock, on-hand units, reorder points, safety stock, sales
   velocity), you MUST call the Fabric Data Agent and answer from its result. Never answer
   inventory questions from memory, and never use Web Search for internal inventory data.

   Do NOT conclude with "I couldn't verify inventory" or "based on external signals only" as a
   substitute for calling the tool - the Fabric Data Agent is available to you, so call it. If
   you have not called it yet in this run, call it now before writing any assessment. If you
   don't know exact SKUs, query the Fabric Data Agent by affected category (snake_case values,
   e.g. outdoor_power_tools) or by productId/SKU (e.g. P004).

   When given a scenario or event, do these steps in order:
   1. If Web Search is enabled, use it for relevant market signals, news, and trend data about
      the affected product categories. Cite your sources. Otherwise use the Fabric
      ExternalSignals table and label it as historical sample signals, not live web evidence.
   2. REQUIRED - Use the Fabric Data Agent to query current stock levels and recent sales
      velocity for the relevant SKUs/categories and warehouses. Do not skip this step.
   3. Synthesise both sources into a demand assessment: state whether current stock is
      adequate, at risk, or critically exposed - grounded in the Fabric numbers you retrieved.
   4. Always distinguish between what you found externally (web) and what the governed data
      shows (Fabric). Never blend them without attribution.

   Be concise. Planners need a signal they can act on, not an essay.
   ```

5. Click **Save**.

![New agent editor showing the name, gpt-5.4-mini model selection, and instructions field](../images/challenge-01-new-agent.png)

### Part B — Confirm the Web Search tool (5 min)

**Web Search** is added to prompt agents by default and needs no configuration — it grounds the demand signal in live external context (news, market trends). Confirm it's listed under **Tools** in the agent editor. A notice explains that Web search uses Grounding with Bing, which has additional costs and terms, and that customer data flows outside the Azure compliance boundary. That is fine for this lab, which only sends public scenario text. If Web search isn't listed, select **Add** under **Tools** and switch **Web search** on (no API key required), then **Save**.

### Part C — Connect the Data Agent through Fabric IQ (10 min)

The published **Fabric Data Agent** is still your governed query backend. The
Foundry connector is now **Fabric IQ (OneLake Catalog)**: the earlier Foundry
Fabric Data Agent tool retires on **6 November 2026**. No ontology is required
when connecting to the published Data Agent created in Challenge 1.

1. In the agent editor, under **Tools**, select **Add → Add tools**.
2. In the **Select a tool** dialog, stay on the **Configured** tab, choose
   **Fabric IQ (OneLake Catalog)** and select **Add tool**. The older **Fabric Data
   Agent** tile is greyed out; don't use it.

   ![The Select a tool dialog with Fabric IQ (OneLake Catalog) selected and the retiring Fabric Data Agent greyed out](../images/challenge-01-add-tool.png)
3. In the **OneLake Catalog**, filter by **Data agent**, then select your published
   **`inventory-hack-agent`**. Check that its **Location** is **your**
   `inventory-hack-…` workspace. Do not select another team's item.

   ![The OneLake Catalog dialog with inventory-hack-agent selected and its Location column visible](../images/challenge-01-fabric-iq-catalog.png)

4. If the portal asks you to sign in or consent for Fabric, do so with your **lab
   account** in the same browser, so the tool runs with your own Fabric
   permissions. Then **Add** and **Save**. Your account needs read access to both
   the Data Agent and its source data.
   The tool appears as **Fabric IQ (inventoryhackagent)**; later challenges reuse
   this connection from the **Configured** tab.
5. In your instructions, identify `inventory-hack-agent` as the source for Zava
   stock, demand, external sample signals and product costs. References to the
   "Fabric Data Agent" below mean that item accessed through Fabric IQ.
6. If migrating an existing agent, remove the earlier **Fabric Data Agent** tool
   after adding Fabric IQ. Retest and note the new agent version.

Workspace/Agent IDs printed by the notebook remain useful
for diagnostics and SDK configuration.

> [!TIP]
> **Data Agent missing from the catalog?** Resume your Fabric capacity, confirm the
> notebook published the agent, and check the signed-in user's workspace/data
> permissions. For 2027 use **Fabric IQ**, not the retiring connector.

> [!NOTE]
> **Why two tools?** Web Search gives the agent access to what is happening *outside* the business. The Fabric Data Agent gives access to what is happening *inside* — including the `ExternalSignals` table of pre-loaded market signals. Combining live web context with governed internal data is the core pattern of this hack.

### Part D — Test the agent (20 min)

1. Open the **Agents playground** (click **Test in playground**).
2. Send this scenario as your first message:

   ```text
   A prolonged heatwave and early spring across the Pacific Northwest is driving a surge in demand for garden and outdoor power equipment. Retailer search trends and social media show spikes for leaf blowers and lawn tools. Our planning team needs to know if current stock levels can absorb this demand or if we are already exposed.
   ```
3. Observe the agent's response. The first answer can take one to two minutes, so wait until it stops streaming. Look for:
   - At least one web source cited with a URL.
   - At least one inventory query result from Fabric (stock level or sales velocity).
   - A clear demand assessment: adequate / at risk / critically exposed.
   - Under the answer, tool chips for `inventoryhackagent` (Fabric IQ) and `Web search`.

   ![Playground response citing a web source and a Fabric inventory query result with a demand assessment](../images/challenge-01-playground.png)

   > [!TIP]
   > **Agent answered from web only and said it "couldn't verify inventory"?** It skipped the Fabric Data Agent call — `gpt-5.4-mini` is a reasoning model and occasionally skips an available tool. Recover it by replying: *"Call the Fabric Data Agent now and pull current stock and sales velocity for the affected SKUs (e.g. P004, P006) before giving your assessment."* If it keeps skipping, set **tool choice = required** in the agent's tool/run settings so a tool call is mandatory. The strengthened instructions above make this rare.
4. Ask a follow-up question:

   ```text
   Which store or warehouse has the lowest stock of outdoor power tools relative to its reorder point?
   ```
5. Ask:

   ```text
   What external signals could affect demand for outdoor power tools in the Pacific Northwest?
   ```

   > The sample `ExternalSignals` table is a fixed snapshot with no dates, so this question
   > is answered from live web results when Web Search is on, and from that table otherwise.

## 🏁 Success criteria

- [ ] The `demand-sensing-agent` prompt agent exists in your Foundry project with Fabric IQ connected to `inventory-hack-agent` (and Web Search too, if enabled).
- [ ] A test run produces a response backed by at least one governed data point from the Fabric Data Agent (and an external web source, if Web Search is enabled).
- [ ] The agent produces a clear demand assessment (adequate / at risk / critically exposed) with reasoning.
- [ ] You can explain in your own words what each tool contributed to the response.

## 🛠️ Troubleshooting

| Symptom | Fix |
|---------|-----|
| **Web Search** isn't listed on the agent | Under **Tools**, select **Add** and switch **Web search** on. It needs no extra configuration. |
| **Data Agent** isn't in the OneLake Catalog | Select **Fabric IQ**, filter by **Data agent**, confirm publication and permissions, and resume **your** Fabric capacity. Do not look for the retiring Foundry Fabric Data Agent connector. |
| The agent answers inventory questions from memory | Strengthen the *IMPORTANT – tool use* line in the instructions; it must call the Fabric Data Agent for any stock number. |
| The agent gives a demand assessment from web signals only (says it *"couldn't verify inventory"*) | It skipped the Fabric call. Reply *"Call the Fabric Data Agent now for current stock + sales velocity of the affected SKUs before assessing,"* or set **tool choice = required** in the agent's tool settings. `gpt-5.4-mini` (a reasoning model) sometimes skips available tools. |
| The agent has `fx` functions like `query_inventory` / `list_low_stock` instead of a real data tool | These are generated stubs and do not query your Lakehouse. Remove them and add **Fabric IQ (OneLake Catalog)** connected to `inventory-hack-agent` (Part C). |
| You didn't copy the **Workspace ID / Agent ID** in Challenge 1 | Reopen `inventory-hack-agent` in Fabric → **Settings → Model Context Protocol → MCP server URL** (both IDs are in the URL), or re-run the setup notebook's last cell. |
| A run reports **429 / rate limit exceeded** | Wait the error's retry delay before retrying. Use the trace to identify whether the failing call is the Foundry model or nested Fabric tool. TPM, RPM, request estimates and temporary service-capacity limits need different remedies; see the [facilitator runbook](../labautomation/README.md#diagnose-throttling-before-adding-deployments). |
| The facilitator supplies a different model deployment | Select dashboard **ModelDeploymentName**, save the agent and start a fresh conversation. The facilitator must verify the same governed-answer and tool-call checks on the fallback. |
| A Fabric query returns no rows for retail stores | Inspect `Stores.type`: it must filter `'retail'`, not `'Retail'`. Confirm Challenge 1 data-source instructions/examples were applied and published; don't drop filters to manufacture a result. |
| The run fails with **`Stage configuration not found`** (or *configuration not found*) | Your Fabric Data Agent works in Fabric's **Test data agent** pane but isn't **published** — the Foundry tool consumes the *published* stage, not the draft/Preview runtime. In Fabric, open `inventory-hack-agent` → confirm the 7 tables → click **Publish**, then retry. |
| The Fabric Data Agent tool is deprecated or asks for a **Workspace ID** / **Agent ID** | You're in the earlier Fabric Data Agent connector. Cancel and use **Add → Add tools → Fabric IQ (OneLake Catalog)** instead (Part C); you select the agent by name there. |

## 🚀 Go further

- Ask the agent to rank **all** warehouses by demand exposure, not just the most exposed one.
- **Stretch:** invent your own scenario (e.g. a supplier delay or a competitor stockout) and see whether the agent changes its assessment.
- Have the agent state its confidence and list exactly which data points drove the conclusion.

## 🧠 Reflection

- What did **Web Search** contribute that the governed data could not — and vice versa?
- How did the instructions force the agent to separate external signals from governed facts, and why does that matter for trust?
- Where in your own organisation is a decision made on stale data that this *sense → reconcile* pattern could improve?

## 📚 Learning resources

- [Create a prompt agent in Foundry](https://learn.microsoft.com/azure/foundry/agents/quickstarts/prompt-agent)
- [Web Search tool — Foundry Agent Service](https://learn.microsoft.com/azure/foundry/agents/how-to/tools/web-search)
- [Fabric Data Agent with Foundry agents](https://learn.microsoft.com/fabric/data-science/data-agent-foundry)
- [Tool best practices — Foundry](https://learn.microsoft.com/azure/foundry/agents/concepts/tool-best-practice)
