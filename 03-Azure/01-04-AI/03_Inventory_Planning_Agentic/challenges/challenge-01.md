# Challenge 1 — Get Grounded & Set Up

**[Home](../README.md)** - [Next Challenge →](challenge-02.md)

## 🎯 Objective

Understand the inventory scenario and the architecture, get your
**Codespace** running, connect to your **Foundry project**, and open the **planner
console** — the empty shell you'll light up one agent at a time.

## 🧭 Context

You are a developer at **Zava**, a retail company. The planning team always reacts
to last month's data. Your job is to build three **hosted agents** that close the
gap — in code — and surface them through a small planner console:

1. **Demand Sensing** — react to real-world changes
2. **Inventory Optimisation** — decide the right stock level
3. **Replenishment Action** — submit the order behind a human approval gate

The governed data lives **inside your code** as function tools over `src/data` — the
app seeds it into Cosmos on first run, with nothing extra to set up.

## ✅ Tasks

### Part A — Open the Codespace (10 min)

1. On the GitHub repo, click **Code → Codespaces → Create codespace on main**.
   (Prefer local? Open the folder in VS Code with the Dev Containers extension.)
2. Wait for the container to build — it installs dependencies with `uv` and seeds
   `src/.env` automatically (see `.devcontainer/post-create.sh`).

### Part B — Connect to your Foundry project (10 min)

1. In the Codespace terminal, sign in:
   ```bash
   az login --use-device-code
   ```
2. Open `src/.env` and paste the three values from your **lab dashboard**:
   ```
   PROJECT_ENDPOINT=<FoundryProjectEndpoint>
   MODEL_DEPLOYMENT_NAME=<ModelDeploymentName>   # gpt-5.4-mini
   COSMOS_ENDPOINT=<CosmosEndpoint>              # the governed data store
   ```
3. Confirm the model is deployed: open [ai.azure.com](https://ai.azure.com), select
   your project, and check **Models + endpoints** shows `gpt-5.4-mini` = *Succeeded*.

### Part C — Read the data model (15 min)

The governed data lives in a **per-attendee Azure Cosmos DB** that the lab
provisioned (serverless, keyless). `src/inventory_store.py` seeds it from `src/data`
on first run and serves these containers to the tools:

| Container | What it contains | Tool that exposes it |
|-----------|------------------|----------------------|
| `inventory` | `onHand`, `reorderPoint`, `safetyStock` per product per location | `query_inventory`, `list_low_stock` |
| `products` | `name`, `category`, `unitCost`, `leadTimeDays`, `supplierId` | `get_product` |
| `demand` | Weekly sales per product per retail store | `calc_reorder` (avg daily sales) |
| `signals` | Weather, search trends, competitor, news | `get_external_signals` |
| `orders` | Purchase orders / transfers | `submit_purchase_order` (**real write**) |

**Categories:** `garden_and_lawn`, `outdoor_power_tools`, `paint_and_supplies`, `smart_home`
**Locations:** Boston, Brooklyn, Portland, Seattle stores + Chicago, Dallas warehouses

A row is **CRITICAL** when `onHand < safetyStock`, **AT_RISK** at/below `reorderPoint`.

### Part D — Open the planner console (10 min)

1. From `src/`, launch the console:
   ```bash
   cd src && uv run uvicorn ui.app:app --reload --port 8000
   ```
2. Open the forwarded **port 8000** (Codespaces pops it automatically).
3. The **first** load seeds Cosmos from `src/data` (a few seconds), then the
   **current exposure** and **order book** panels populate from the store. The
   **Sense demand** button is already wired to the agent you build next; Steps 2–4
   stay **locked** until the previous step succeeds. (Clicking **Sense demand** now
   would create and run your first hosted agent — that *is* Challenge 2, so you can
   stop here and pick it up in the next challenge.)

## 🏁 Success criteria

- [ ] Your Codespace (or local devcontainer) is running with dependencies installed.
- [ ] `az login` succeeded and `src/.env` has your endpoint, model name, and Cosmos endpoint.
- [ ] `gpt-5.4-mini` shows *Succeeded* in your Foundry project.
- [ ] The planner console loads and shows current exposure + the order book (Cosmos seeded).
- [ ] You can name the tools each of the three agents will use.

## 🛠️ Troubleshooting

| Symptom | Fix |
|---------|-----|
| `gpt-5.4-mini` missing | Flag your facilitator — it's part of the provisioned lab. |
| Port 8000 didn't open | Open the **Ports** tab and click the globe on 8000. |
| `az login` opens no browser | Use `az login --use-device-code` and follow the URL. |
| Panels show "not connected" | Set `COSMOS_ENDPOINT` in `src/.env` and `az login`. If just provisioned, the data-plane role can take a minute to propagate — wait and reload. |
| `Forbidden` / 403 from Cosmos | Your identity's **Cosmos DB Built-in Data Contributor** role is still propagating, or you're signed into the wrong tenant — re-check `az login`. |

## 🚀 Go further

- Open `src/tools.py` and read `list_low_stock` — the console's **current exposure**
  panel is exactly what it returns.
- Predict which locations Challenge 3 will flag CRITICAL before you get there.

## 📚 Learning resources

- [What is Microsoft Foundry Agent Service?](https://learn.microsoft.com/azure/foundry/agents/overview)
- [Develop in a Codespace / devcontainer](https://code.visualstudio.com/docs/devcontainers/containers)
