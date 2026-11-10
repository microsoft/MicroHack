# Challenge 1 — Get Grounded & Set Up

**[Home](../README.md)** - [Next Challenge →](challenge-02.md)

## 🎯 Objective

Sign in with your assigned lab credentials, fork the hack repository and get your
**Codespace** running, connect to your **Foundry project**, understand the inventory
scenario, and open the **planner console** — the empty shell you'll light up one agent
at a time.

## 🧭 Context

You are a developer at **Zava**, a retail company. The planning team always reacts
to last month's data. Your job is to build three **hosted agents** that close the
gap — in code — and surface them through a small planner console:

1. **Demand Sensing** — react to real-world changes
2. **Inventory Optimisation** — decide the right stock level
3. **Replenishment Action** — submit the order behind a human approval gate

The governed data lives **inside your code** as function tools over `src/data` — the
app seeds it into Cosmos on first run, with nothing extra to set up.

Complete this setup with the credentials provided in your **Hackbox** (see the
**Credentials** section at the top of the Hackbox page). Use the assigned lab account
— not a personal or work account — so that you have access to the correct Azure
subscription, resource group, GitHub organization, and repository.

## ✅ Tasks

### Part A — Sign in to Azure (5 min)

1. Open the [Azure portal](https://portal.azure.com) and sign in with your Hackbox
   credentials. When prompted to choose an account, select **Use another account** —
   do not use your personal or work account.

   ![Sign in to the Azure portal with another account](../images/setup-azureportal.png)

2. Select **Resource groups** and open the resource group assigned to you.

   ![Resource groups in the Azure portal navigation menu](../images/setup-resource-groups.png)

3. Confirm it contains your lab resources: an **Azure AI Services / Foundry** account
   (`inv-…`) with the `inventory-hack` project, an **Azure Cosmos DB** account
   (`inv-cos-…`), a **Log Analytics** workspace, and **Application Insights**.

### Part B — Sign in to GitHub and fork the repository (10 min)

1. Open [GitHub](https://github.com) and select **Sign in**. There is **no separate
   GitHub username or password** — GitHub uses single sign-on with the **same lab
   account** you used for the Azure portal. When prompted to choose an account,
   select **Use another account**, then select **Sign in with your identity
   provider** and authenticate with the lab account.

   ![Sign in to GitHub with another account](../images/setup-github-login.png)

2. Open your profile menu → **Organizations** and select the lab organization
   assigned to your account.

   ![GitHub organization selector](../images/setup-github-organization.png)

3. Open the `microhack` repository and click **Fork** (top-right). You need your own
   fork before you can create a Codespace.

   ![Create fork](../images/setup-create-fork-1.png)

4. Give the fork a **unique name** so it doesn't clash with other attendees — for
   example append your lab username (`microhack-labuser-0001`) — then select
   **Create fork**.

   ![Fork repository with a unique name](../images/setup-create-fork-2.png)

5. You should now see your fork with all files and folders from the original
   repository.

   ![Files and folders in the forked GitHub repository](../images/setup-github-repository.png)

### Part C — Create the development environment (10 min)

**Option 1 — GitHub Codespaces (recommended)**

1. On your fork, select **Code → Codespaces**, open the `...` menu and choose
   **New with options...** (do **not** use *Create codespace on main* — that picks a
   different dev container).

   ![Create a GitHub Codespace with options](../images/setup-github-codespaces.png)

2. Set **Dev container configuration** to
   **Azure / AI / Inventory Planning Agentic** (scroll the list — configurations are
   grouped by MicroHack area).

   ![Dev container configuration list with Azure / AI / Inventory Planning Agentic highlighted](../images/setup-dev-container-list.png)

   Keep the **2-core** machine type and select **Create codespace**.

   ![Create codespace with the Azure / AI / Inventory Planning Agentic configuration selected](../images/setup-select-dev-container.png)

3. GitHub opens the Codespace in a new tab. The first build takes a few minutes: the
   container installs Python 3.12, `uv`, the Azure CLI, and `azd`, then
   `.devcontainer/post-create.sh` runs `uv sync` and seeds `src/.env`. The Explorer
   opens directly on the `03_Inventory_Planning_Agentic` folder, the README opens as a
   rendered preview, and new terminals start in the project's Python environment
   (`(agentic-inventory-hack)` in the prompt):

   ![Codespace ready: Explorer on the 03_Inventory_Planning_Agentic folder, README rendered, terminal in the agentic-inventory-hack environment](../images/setup-codespace-ready.png)

   > [!IMPORTANT]
   > When VS Code asks whether to open the git repository found in the parent folders,
   > select **Never** — you only need the hack folder.
   >
   > ![Select Never when asked to open the repository](../images/setup-never-open-repository.png)

   > [!IMPORTANT]
   > If VS Code asks **Do you trust the authors of the files in this folder?** (for
   > example when you open a terminal), select **Trust Folder & Continue** — otherwise
   > the terminal and the Python extension stay in Restricted Mode.
   >
   > ![Select Trust Folder & Continue in the workspace trust dialog](../images/setup-trust-folder.png)

**Option 2 — Local VS Code Dev Containers**

Prerequisites: [Docker Desktop](https://www.docker.com/products/docker-desktop/) (running)
and the [Dev Containers](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)
extension.

1. Clone your fork and open the **repository root** folder in VS Code:
   ```bash
   git clone https://github.com/<your-org>/<your-fork>.git
   code <your-fork>
   ```
2. Run **Dev Containers: Reopen in Container** from the Command Palette
   (`Ctrl/Cmd+Shift+P`) and select **Azure / AI / Inventory Planning Agentic**. The
   same image and `post-create.sh` run as in Codespaces.

**Verify the environment** (either option) — in a new terminal:

```bash
python --version   # 3.12.x
uv --version
az --version
ls src/.env src/.venv
```

The setup log ends with **Ready. Next steps**. If any check fails, re-run the setup
script from the hack folder: `bash .devcontainer/post-create.sh`.

### Part D — Connect to your Foundry project (10 min)

1. In the terminal, sign in with your Hackbox credentials:
   ```bash
   az login --use-device-code
   ```
   Open the URL shown, enter the code, and sign in with the lab account. If prompted
   to choose a subscription, pick the one that contains your resource group.
2. Open `src/.env` and paste the three values from your **Hackbox** credentials:
   ```
   PROJECT_ENDPOINT=<FoundryProjectEndpoint>
   MODEL_DEPLOYMENT_NAME=<ModelDeploymentName>   # gpt-5.4-mini
   COSMOS_ENDPOINT=<CosmosEndpoint>              # the governed data store
   ```
3. Confirm the model is deployed: open [ai.azure.com](https://ai.azure.com), select
   your project, and check **Models + endpoints** shows `gpt-5.4-mini` = *Succeeded*.

### Part E — Read the data model (15 min)

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

### Part F — Open the planner console (10 min)

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

- [ ] You can see your lab resource group (Foundry, Cosmos DB, Application Insights) in the Azure portal.
- [ ] You forked the `microhack` repository in the lab GitHub organization under a unique name.
- [ ] Your Codespace (or local Dev Container) runs the **Azure / AI / Inventory Planning Agentic** configuration and `python`, `uv`, `az` all work.
- [ ] `az login` succeeded and `src/.env` has your endpoint, model name, and Cosmos endpoint.
- [ ] `gpt-5.4-mini` shows *Succeeded* in your Foundry project.
- [ ] The planner console loads and shows current exposure + the order book (Cosmos seeded).
- [ ] You can name the tools each of the three agents will use.

## 🛠️ Troubleshooting

| Symptom | Fix |
|---------|-----|
| GitHub organization or `microhack` repository missing | Sign out of GitHub and sign in again via **Sign in with your identity provider** using the lab account (the same one as the Azure portal). If the organization is still missing, ask your facilitator — the lab user needs GitHub access (`GHCPUsers`). |
| **Azure / AI / Inventory Planning Agentic** not in the dev container list | Make sure you're on your **fork** of the `microhack` repository and used **New with options...**. |
| `python: command not found` / `uv: command not found` / `src/.venv` missing | The Codespace was created with the wrong dev container (e.g. *Create codespace on main*). Delete it and recreate it with **New with options...** → **Azure / AI / Inventory Planning Agentic**. If the config is right, open a new terminal or re-run `bash .devcontainer/post-create.sh`. |
| `post-create.sh` fails locally with `$'\r': command not found` | The script was checked out with Windows line endings before the LF rule applied. In the container terminal run `sed -i 's/\r$//' .devcontainer/post-create.sh && bash .devcontainer/post-create.sh`. |
| Local Dev Container: `uv sync` fails with SSL / connection errors | Your network blocks direct access to PyPI (corporate proxy). Codespaces is not affected. Set your company's proxy (`export HTTPS_PROXY=...`) or package mirror (`export UV_DEFAULT_INDEX=...`) in the container terminal and re-run `bash .devcontainer/post-create.sh` — or use Codespaces. |
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
