# Lab Automation — Agentic Inventory Planning MicroHack

Everything for this hack is provisioned per attendee by [`deploy-lab.ps1`](deploy-lab.ps1) — there is **no shared Fabric backend**. Each attendee gets their own Foundry project **and** their own Fabric F2 capacity, then builds their own Fabric workspace + Data Agent by running [`Setup-InventoryDataAgent.ipynb`](../setup/Setup-InventoryDataAgent.ipynb) in Challenge 1.

## What `deploy-lab.ps1` provisions (per attendee)

| Resource | Type | Notes |
|----------|------|-------|
| Azure AI Foundry account | `Microsoft.CognitiveServices/accounts` | One per attendee (AIServices kind) |
| Foundry project | `…/projects/inventory-hack` | Within the Foundry account |
| gpt-5.4-mini model deployment | GlobalStandard, 100K TPM | Used by all three hack agents |
| Fabric **F2 capacity** | `Microsoft.Fabric/capacities` | One per attendee; attendee set as **capacity admin** |

The script sets each attendee as **admin of their own F2 capacity** (resolving their Entra object ID to a UPN via the platform `Get-MhhLabUser` helper), so they can create a workspace, assign it to the capacity, and publish their own Data Agent — no shared state, no cross-attendee contention.

## What the attendee does themselves (Challenge 1)

1. Create a Fabric **workspace** and assign it to their **F2 capacity** (`FabricCapacityName`).
2. Create a Lakehouse named **`InventoryLakehouse`** and attach it to the notebook.
3. Import and **Run All** [`Setup-InventoryDataAgent.ipynb`](../setup/Setup-InventoryDataAgent.ipynb) — it loads its **embedded** seed data, writes 7 tables, publishes their **`inventory-hack-agent`** Data Agent, and prints **their** Workspace ID + Agent ID.
4. Use those two IDs when adding the Fabric Data Agent tool to their Foundry agent (Challenge 2).

## Credentials returned to the attendee dashboard

| Key | Value |
|-----|-------|
| `FoundryProjectEndpoint` | `https://<account>.services.ai.azure.com/api/projects/inventory-hack` |
| `ModelDeploymentName` | `gpt-5.4-mini` |
| `FabricCapacityName` | The attendee's own F2 capacity (assign your workspace to it in Challenge 1) |
| `ResourceGroupName` | The attendee's resource group |

Attendees use these in the Foundry and Fabric portals — no SDK or code required.

## Prerequisites for facilitators / the platform

- The deploying identity (the platform **service principal**) needs **Owner** on each attendee resource group (creates the Foundry account, model deployment, and Fabric capacity via ARM) — the platform grants this automatically for `resourcegroup` deployments.
- **`groups: ["M365-E5-Users"]`** in [`lab-defaults.json`](lab-defaults.json) — each attendee's lab Entra user gets a **Microsoft 365 E5** license (includes **Power BI Pro**), which is what lets them sign into the Fabric portal ([app.fabric.microsoft.com](https://app.fabric.microsoft.com)) and create a workspace. Without a Fabric/Power BI license the attendee cannot open the portal.
- **The lab tenant must have Fabric enabled** — a Fabric **tenant-admin** setting (*“Users can create Fabric items”* / workspaces). This is **not** settable via `lab-defaults.json`; the tenant administrator for the lab tenant must turn it on, or attendees cannot create a workspace even with a license.
- **Fabric F-SKU quota** in a preferred region (F2 = 2 CU; a 512-CU subscription supports ~256 attendees). `swedencentral` and `norwayeast` are good defaults.
- The **`Microsoft.Fabric`** resource provider is registered on the subscription (the script registers it if needed).

> [!NOTE]
> Attendee object IDs → UPNs are resolved with the platform **`Get-MhhLabUser`** helper (served from a platform-seeded cache), so the service principal does **not** need Microsoft Graph directory-read permission.

## Cost estimate

- **Fabric F2 capacity** (~$0.36/hr pay-as-you-go) is the dominant cost — roughly **$8–9/attendee/day** if left running. Attendees (or facilitators) should **suspend** the capacity when idle.
- gpt-5.4-mini (GlobalStandard, 100K TPM) — a few cents of tokens per attendee across the hack's ~50 agent calls; Foundry account base ~$2/day.
- Total ≈ **$9/attendee/day** — reflected in [`lab-defaults.json`](lab-defaults.json) (`estimatedDailyCostsUsd`).
