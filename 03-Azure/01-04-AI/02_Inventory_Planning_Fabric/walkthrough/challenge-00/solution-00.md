# Challenge 0 — Solution: Get Grounded

**[Home](../../README.md)** - [Next Solution →](../challenge-01/solution-01.md)

**Duration:** 45 minutes

## Goal

Understand the inventory scenario, provision your own Fabric workspace + Data Agent, and learn the Foundry + Fabric architecture.

## Solution walkthrough

### Data model summary

| Table | Key columns | Used by |
|-------|-------------|---------|
| `Inventory` | productId, storeId, onHand, reorderPoint, safetyStock | Challenges 1, 2 |
| `DemandHistory` | productId, storeId, weekStart, unitsSold | Challenge 1 |
| `ExternalSignals` | signalType, region, headline, score, affectedCategories | Challenge 1 |
| `Products` | productId, name, category, unitCost, leadTimeDays, supplierId | Challenges 2, 3 |
| `Stores` | storeId, name, type, region, city | Challenges 1, 2 |
| `ReplenishmentOrders` | orderId, type, status, approvedBy, items | Challenge 3 |
| `Suppliers` | supplierId, name | Challenge 3 |

### Foundry portal navigation

1. Sign in at [ai.azure.com](https://ai.azure.com) with the credentials provided by your facilitator.
2. Select your project from the **Projects** list.
3. In the left navigation: **Models + endpoints** → confirm `gpt-5.4-mini` is listed with status **Succeeded**.
4. **Agents → Playground** → send "Hello" → confirm a response is returned.
5. You attach the **Fabric Data Agent** as a *tool* on each agent you build — the `inventory-hack-agent` connection is created the first time (Challenge 1) via **Tools → Add → Fabric Data Agent**, using the **Workspace ID and Agent ID your setup notebook printed** in Challenge 0. No standalone connection page is needed.

### Provision your Fabric workspace + Data Agent (Challenge 0 Task 3)

1. **Create the workspace on your capacity.** [app.fabric.microsoft.com](https://app.fabric.microsoft.com) → **Workspaces → + New workspace** → name `inventory-hack` → expand **Advanced** → **Workspace type: Fabric** → under **Details** select your **`FabricCapacityName`** (the `invcap…` value from your dashboard) → **Apply**. If the capacity isn't listed, resume it in Azure (your Fabric capacity → **Resume**) and confirm you're signed in as your lab user.
2. **Create the Lakehouse.** **+ New item → Lakehouse**, named exactly **`InventoryLakehouse`**.
3. **Import + attach.** Download **`Setup-InventoryDataAgent.ipynb`** from the repo's **`setup/`** folder (or your facilitator's link), then **Import → Notebook → From this computer → Upload** in the workspace toolbar. Open it and, in the **Explorer**, **Add → Existing Lakehouse → `InventoryLakehouse`** as the **default** — if names collide, pick the one whose **Location** is your `inventory-hack` workspace (the write cells fail without a default Lakehouse).
4. **Run all** (~5–10 min). The kernel restarts once after the `%pip` cell — expected. It writes 7 tables and publishes `inventory-hack-agent`.
5. Copy the **Workspace ID** and **Agent ID** the final cell prints — you'll use them in Challenge 1.

**Common stumbles:** capacity not in the dropdown (paused, or wrong signed-in user) · table-write cells fail (Lakehouse not attached as default) · Data Agent tool missing later in Foundry (capacity paused, or the notebook didn't finish publishing).

### Grounding questions — suggested answers

**What would go wrong if the Demand Sensing Agent only looked at web signals?**
It might recommend a reorder that the company already has stock for, wasting budget. The governed Fabric data is the source of truth for what is actually on the shelves.

**Why does the Replenishment Action Agent need a human approval step?**
Purchase orders have financial and operational consequences. The agent can propose and calculate, but a human should validate the business context (budget constraints, supplier relationships, timing) before committing.

**What does the Fabric Data Agent abstract away?**
SQL query generation, Fabric authentication, schema discovery, and result formatting. The agent sends a plain English question and receives a plain English answer — no DAX or SQL knowledge needed.
