# labautomation — Agentic Inventory hack

This folder is the **EMEA MicroHack platform** entry point. The platform calls
[`deploy-lab.ps1`](deploy-lab.ps1) once per attendee (in parallel) to provision
their lab. Everything works out of the box — there is **no facilitator pre-setup**:
each attendee gets a per-user Foundry project and Cosmos DB, provisioned in parallel.

## What gets provisioned per attendee

| Resource | Purpose |
|----------|---------|
| Azure AI Services account (`AIServices` kind) | The Foundry account (custom subdomain `inv-<hash>`) |
| Azure AI Foundry project (`inventory-hack`) | Hosts the attendee's agents |
| `gpt-5.4-mini` deployment (GlobalStandard) | Low-cost GPT-5 model with Functions/Tools + Structured Outputs; longest support horizon among the low-cost GPT-5 tier (retires 2027-03-18) |
| Log Analytics workspace + Application Insights | Observability backend, connected to the Foundry account so the native agents' runs are **traced server-side** (Agents → Traces) |
| Azure Cosmos DB for NoSQL (serverless, keyless) | The governed data store (`inventory` DB + containers pre-created); local auth disabled |
| RBAC: **Azure AI User** + **Cognitive Services User** (Foundry) | Lets the attendee create/deploy hosted agents from their Codespace |
| RBAC: **Cosmos DB Built-in Data Contributor** (Cosmos) | Lets the attendee read/write the governed data keylessly (`DefaultAzureCredential`) |

The Zava data is **seeded into Cosmos by the app on first run** (idempotent,
data-plane upserts using the attendee's identity) — no keys or connection strings.

## Platform contract (why this "just works")

- The parameter block matches the platform contract exactly, so the platform runs it.
- The platform pre-sets the Az context and pre-creates the resource group — the
  script does **not** call `Connect-AzAccount` or `New-AzResourceGroup`.
- Foundry, Cosmos, the database and containers are created via ARM REST
  (`Invoke-AzRestMethod`) so there is **no dependency on extra Az modules**; only
  standard `Az.Accounts` / `Az.Resources` are required. RBAC is standard.
- Cosmos uses **local auth disabled** — no keys anywhere; access is purely Entra
  data-plane RBAC.

## What the attendee receives on their dashboard

| Credential | Goes into |
|------------|-----------|
| `FoundryProjectEndpoint` | `src/.env` → `PROJECT_ENDPOINT` |
| `ModelDeploymentName` | `src/.env` → `MODEL_DEPLOYMENT_NAME` |
| `CosmosEndpoint` | `src/.env` → `COSMOS_ENDPOINT` |
| `ResourceGroupName` | Where to find their resources in the portal |

## Configuration

Edit [`lab-defaults.json`](lab-defaults.json) to tune region priority, labs per
subscription, and the per-user daily cost estimate. No IDs or secrets are stored
in this folder.

## Deployment robustness

`deploy-lab.ps1` is defensive about the failure modes that could otherwise produce a
silently-empty lab — a "successful" run with no project, database, or data-plane role:

| Concern | How the script handles it |
|---------|---------------------------|
| A control-plane call fails but returns a non-2xx status | Every ARM call goes through the `Invoke-MhhArm` helper, which **throws on any non-2xx** (with `-AllowNotFound` for existence probes) instead of printing a false `[OK] … created`. |
| `Invoke-AzRestMethod -Path` can drop `?api-version` on some PUT/PATCH calls | The helper uses the full `-Uri https://management.azure.com…` form, which passes the api-version reliably. |
| PowerShell 7 parses `"$var?api-version=…"` as a null-conditional and eats the value | All such URLs brace the variable — `"${var}?api-version=…"` — so the project, Cosmos, container, and role-assignment URLs stay well-formed. |
| Foundry project creation requires a managed identity | The project body includes `identity = @{ type = "SystemAssigned" }`, and the script enables `allowProjectManagement` on the account and confirms it reads back before creating the project. |
| MCAPS subscriptions force Cosmos `publicNetworkAccess=Disabled` via a management-group `Modify` policy | Before creating Cosmos, the script merges the tag `SecurityControl = Ignore` onto the resource group (the standard MCAPS exemption) and sets `publicNetworkAccess = Enabled` in the account body, so the endpoint comes up reachable. It also reconciles an existing account back to `Enabled` best-effort. Security is unchanged — the account stays keyless (`disableLocalAuth = true`), so the reachable endpoint still requires an Entra token with the data role. On non-MCAPS subscriptions the tag is a harmless no-op. |

**Environment note:** The demo/attendee subscriptions this hack runs on are
Microsoft-internal (MCAPS) subscriptions, which apply the Cosmos public-access policy
described in the last row above. **The script handles this automatically — no manual
tagging or portal step is required.** A normal (non-MCAPS) lab subscription simply
ignores the extra tag.

## Local dry run

The platform injects helpers such as `Get-MhhStableHash` and pre-creates the resource
group, so `deploy-lab.ps1` **cannot** be run directly outside the platform — it will
fail at the first `Get-MhhStableHash` call. Use the local wrapper instead, which
supplies a `Get-MhhStableHash` shim, pre-creates the RG, and passes your signed-in
user id:

```powershell
# Requires: az login + Connect-AzAccount to the test subscription,
# and the Az.Accounts / Az.Resources modules installed.
./run-local.ps1 -SubscriptionId <sub> -ResourceGroupName <rg> `
    -Location swedencentral -AllowedEntraUserIds <your-object-id>
```

> `run-local.ps1` is a **local-only helper** (not used by the platform). It mirrors
> the `resourcegroup` deployment path.

