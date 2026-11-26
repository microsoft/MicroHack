# Challenge 1 — Solution: Get Grounded

**[Home](../../README.md)** - [Next Solution →](../challenge-02/solution-02.md)

**Duration:** 45 minutes

## Goal

Understand the inventory scenario, provision your own Fabric workspace + Data Agent, and learn the Foundry + Fabric architecture.

## Solution walkthrough

### Data model summary

| Table | Key columns | Used by |
|-------|-------------|---------|
| `Inventory` | productId, storeId, onHand, reorderPoint, safetyStock | Challenges 2, 3 |
| `DemandHistory` | productId, storeId, weekStart, units | Challenge 2 |
| `ExternalSignals` | signalType, region, headline, score, affectedCategories | Challenge 2 |
| `Products` | productId, name, category, unitCost, leadTimeDays, supplierId | Challenges 3, 4 |
| `Stores` | storeId, name, type, region, city | Challenges 2, 3 |
| `ReplenishmentOrders` | orderId, type, status, requestedBy, approvedBy, createdDate, itemsJson | Challenge 4 |
| `Suppliers` | supplierId, name | Challenge 4 |

### Foundry portal navigation

1. Sign in at [ai.azure.com](https://ai.azure.com) with the credentials provided by your facilitator.
2. Select your project — in a shared tenant, match the **`FoundryProjectEndpoint`** from your lab dashboard (Credentials tab) to the project's **Parent resource** to be sure it's yours.
3. Open **Models → Deployments** → confirm `gpt-5.4-mini` is listed with status **Succeeded**.
4. Open a **deployed model → Playground** → send "Hello" → confirm a response is returned. (The current portal opens the Playground from a model or agent, not a top-level *Agents → Playground* menu.)
5. In Challenge 2, use **Tools → Add → Add tools → Fabric IQ (OneLake Catalog)**, filter by **Data agent** and select your published `inventory-hack-agent`. Complete OAuth consent and verify that user's Data Agent/source access. The `inventoryhackagent` connection is created here and reused by later agents; no standalone connection page is needed. The notebook's Workspace/Agent IDs remain useful for SDKs and diagnostics; the earlier ID-entry Foundry connector retires on **6 November 2026**.

### Provision your Fabric workspace + Data Agent (Challenge 1 Task 3)

1. **Create the workspace on your capacity.** [app.fabric.microsoft.com](https://app.fabric.microsoft.com) → **Workspaces → + New workspace** → name **`inventory-hack-<your-lab-user>`** (workspace names are **tenant-unique**, so plain `inventory-hack` is rejected once taken) → expand **Advanced** → **Workspace type: Fabric** → under **Details** select your **`FabricCapacityName`** (the `invcap…` value from your dashboard) → **Apply**. If the capacity isn't listed, resume it in Azure (your Fabric capacity → **Resume**) and confirm you're signed in as your lab user.
2. **Create the Lakehouse.** **+ New item → Lakehouse**, named exactly **`InventoryLakehouse`**.
3. **Import + attach.** Download **`Setup-InventoryDataAgent.ipynb`** from the repo's **`setup/`** folder (or your facilitator's link), then **Import → Notebook → From this computer → Upload** in the workspace toolbar. Open it and, in the **Explorer**, **Add data items → From OneLake catalog → `InventoryLakehouse`** as the **default** — if names collide, pick the one whose **Location** is your `inventory-hack-…` workspace (the write cells fail without a default Lakehouse).
4. **Run all** (~5–10 min). The notebook installs the tested SDK version without restarting the kernel, writes 7 tables, refreshes SQL analytics endpoint metadata, and publishes `inventory-hack-agent`. The refresh runs before adding the Lakehouse source so the agent can discover the newly created tables.
5. Copy the **Workspace ID** and **Agent ID** the final cell prints — keep them for diagnostics; Challenge 2 selects the agent by name in the Fabric IQ catalog.

The notebook also sets **Lakehouse data-source instructions and four SQL examples**.
For manual setup, apply [Challenge 1 step f2](../../challenges/challenge-01.md)
before publishing. `Stores.type` is exactly `retail` / `warehouse`; category
filters use lowercase snake_case. This belongs in query-generation context, not
only the top-level agent prompt. No preview runtime or ontology is required.

Verify Portland/ST03 has **8** P004 units, Seattle/ST04 has **6**, and both have
safety stock **30**. "How many Retail locations do we have?" must return **4**;
P999 must return no matching rows. The notebook blocks publication when even one
of the seven expected tables is missing, and surfaces smoke-test failures.

**Common stumbles:** capacity not in the dropdown (paused, or wrong signed-in user) · table-write cells fail (Lakehouse not attached as default) · Data Agent tool missing later in Foundry (capacity paused, or the notebook didn't finish publishing).

### Grounding questions — suggested answers

**What would go wrong if the Demand Sensing Agent only looked at web signals?**
It might recommend a reorder that the company already has stock for, wasting budget. The governed Fabric data is the source of truth for what is actually on the shelves.

**Why does the Replenishment Action Agent need a human approval step?**
Purchase orders have financial and operational consequences. The agent can propose and calculate, but a human should validate the business context (budget constraints, supplier relationships, timing) before committing.

**What does the Fabric Data Agent abstract away?**
SQL query generation, Fabric authentication, schema discovery, and result formatting. The agent sends a plain English question and receives a plain English answer — no DAX or SQL knowledge needed.
