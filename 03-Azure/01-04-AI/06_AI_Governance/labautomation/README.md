# labautomation — Agentic Governance Hub MicroHack

This folder is the **EMEA MicroHack platform** entry point. The platform calls
[`deploy-lab.ps1`](deploy-lab.ps1) once per attendee (in parallel) to provision
their lab into a pre-created resource group.

The deployment provisions a **Citadel Agentic Governance Hub** and a sample **Spoke** (Azure AI Foundry workload) — both deployed into the same platform-provided resource group using deterministic naming to avoid collisions.

## What Gets Provisioned Per Attendee

Adapted from the Citadel workshop (`azd up`), the lab deploys:

### Hub Resources
| Resource | Purpose |
|----------|---------|
| **API Management (StandardV2)** | Unified AI gateway; all model calls route through APIM |
| **Azure AI Foundry Account (Hub)** | Primary Foundry account (`aif-hub-<hash>`) for governance backend |
| **Azure AI Foundry Project (Hub)** | Hosts hub-level agents and access-control demonstrations |
| **Log Analytics Workspace** | Hub observability backend |
| **Application Insights** | Connected to hub Foundry for agent tracing |
| **Cosmos DB (NoSQL, serverless)** | Usage tracking and telemetry storage |
| **Event Hub** | Event streaming for usage pipeline |
| **Key Vault** | Hub secrets (API keys, Foundry credentials) |
| **Storage Account** | Logic App workflow state |
| **Logic App** | Usage ingestion workflow (if deployed) |

### Spoke Resources (Folded into Same RG)
| Resource | Purpose |
|----------|---------|
| **Azure AI Foundry Account (Spoke)** | Sample workload Foundry account (`aif-spoke-<hash>`) for attendee agent development |
| **Azure AI Foundry Project (Spoke)** | Where attendees deploy their governed agents (`citadel-agents-project`) |
| **Log Analytics Workspace (Spoke)** | Spoke observability |
| **Application Insights (Spoke)** | Spoke agent tracing |
| **Key Vault (Spoke)** | Spoke secrets |
| **Azure Container Registry (Spoke)** | Spoke artifact storage |

## Platform Contract

- The parameter block matches the MicroHack platform contract exactly.
- The platform **pre-creates the resource group** and pre-sets the Azure context for the
  `resourcegroup` / `resourcegroup-with-subscriptionowner` deployment types, so the script
  does **not** call `Connect-AzAccount` or `New-AzResourceGroup` in those modes. In
  `subscription` mode the platform hands over an empty subscription instead, and the script
  creates its own `rg-citadel-microhack-<hash>` resource group.
- [`shared-deploy-lab.ps1`](shared-deploy-lab.ps1) is picked up automatically by file name and
  runs **once per subscription, before** the per-participant fan-out, to register the resource
  providers this lab needs (see [Subscription Scope Prerequisites](#subscription-scope-prerequisites)).
- Hub and spoke resources are deployed into **the same platform-provided ResourceGroupName**
  using deterministic suffixes to avoid name collisions.
- Foundry accounts, projects, Log Analytics, App Insights, Key Vault, and APIM are all
  provisioned with **managed identities** — no keys or secrets in logs.
- RBAC is assigned **per attendee** (via `$AllowedEntraUserIds`) across **both the hub and the
  spoke** copies of Foundry, Key Vault, Cosmos DB, APIM, ACR, and monitoring, so the notebooks
  work out-of-the-box.

## Spoke Deployment (workshop step 3.7)

The original workshop provisions the hub with `azd up` and then requires a **separate**
`scripts/deploy-spoke-foundry.ps1` run, which creates a *distinct spoke resource group*.
MicroHack gives each participant exactly **one** resource group, so that step is not run
separately here — the spoke is part of `infra/resources.bicep` and lands in the **same
platform-provided resource group** as the hub. Name collisions are avoided by the `-spoke`
infix plus the shared `resourceToken`.

| Workshop `deploy-spoke-foundry.ps1` step | Equivalent here |
|---|---|
| Create spoke resource group | *Not applicable* — hub and spoke share the participant's single RG |
| Foundry account (`allowProjectManagement`, system-assigned identity) | `spokeFoundryAccount` → `aif-spoke-<token>` |
| Foundry project (system-assigned identity) | `spokeFoundryProject` → `citadel-agents-project` |
| Log Analytics workspace | `laSpoke` → `law-spoke-<token>` |
| Application Insights | `aiSpoke` → `appi-spoke-<token>` |
| App Insights → Foundry connection (agent tracing) | `spokeFoundryAppInsightsConnection` |
| Key Vault (RBAC authorization) | `kvSpoke` → `kv-spoke-<token>` |
| Container Registry (Basic, admin disabled) | `acrSpoke` → `acrcitadel<token>` |
| **AcrPull → Foundry *project* managed identity** | `acrPullForSpokeProject` role assignment |
| `Azure AI Project Manager` / `Key Vault Secrets User` to the user | Granted by `deploy-lab.ps1` to every id in `$AllowedEntraUserIds` |
| Write `SPOKE_*` values to the azd environment | Emitted as `HackboxCredential`s, applied by `setup-notebook-env.ps1` |

Two details are load-bearing for **challenge 7**, which builds a hosted agent container:

- The Foundry **project** managed identity holds **AcrPull** on the spoke ACR. Without it the
  agent version deploys and then fails to start with an image-pull error — the notebook itself
  states this grant is expected to come from the spoke deployment.
- The ACR has **`adminUserEnabled: false`**. The notebook builds with `az acr build` (cloud
  build, no local Docker) and the agent pulls via managed identity, so admin credentials are
  never needed. `SPOKE_RESOURCE_GROUP` is emitted as the same value as `ResourceGroup`, which
  is what the notebooks read.

## What the Attendee Receives

The platform dashboard surfaces these credentials as `HackboxCredential` objects.
The **Notebook azd Key** column is what the corresponding value must be set to via
`setup-notebook-env.ps1` for the workshop notebooks to consume it via
`azd env get-value` (see [Notebook Environment Setup](#notebook-environment-setup) below).

| Credential | Used For | Notebook azd Key |
|-----------|----------|-------------------|
| `ResourceGroup` | Portal navigation, resource discovery | `AZURE_RESOURCE_GROUP` |
| `Location` | Region-aware notebook logic | `AZURE_LOCATION` |
| `SubscriptionId` | Notebooks 4, 7, 8, 9 (Foundry/agent SDK auth) | `AZURE_SUBSCRIPTION_ID` |
| `LlmBackendConfig` | Notebook 1 (LLM backend onboarding), Notebook 8 | `LLM_BACKEND_CONFIG` |
| `SpokeResourceGroup` | Notebooks 3, 4, 7 (single-RG deployment: same as `ResourceGroup`) | `SPOKE_RESOURCE_GROUP` |
| `SpokeKeyVaultName` | Notebooks 3, 4 (credential retrieval via DefaultAzureCredential) | `SPOKE_KEY_VAULT_NAME` |
| `SpokeFoundryAccountName` / `SpokeAiFoundryAccountName` (alias) | Notebooks 3, 4, 7 | `SPOKE_AI_FOUNDRY_ACCOUNT_NAME` |
| `SpokeFoundryProjectName` / `SpokeAiFoundryProjectName` (alias) | Notebooks 3, 4, 7 | `SPOKE_AI_FOUNDRY_PROJECT_NAME` |
| `SpokeAcrName` | Notebook 7 (container publishing) | `SPOKE_ACR_NAME` |
| `SpokeAcrLoginServer` | Notebook 7 (container publishing) | `SPOKE_ACR_LOGIN_SERVER` |
| `HubFoundryProjectEndpoint` | Notebook 1 (LLM Onboarding), Notebooks 3, 6 (access controls, unified API) | — |
| `SpokeFoundryProjectEndpoint` | Notebooks 7–9 (hosted agents, agent-to-agent, HR MCP) | — |
| `ApimGatewayUrl` | All notebooks (unified inference endpoint) | — |
| `CosmosEndpoint` | Notebook 2 (usage analytics) | — |
| `KeyVaultName` | All notebooks (credential retrieval via DefaultAzureCredential) | — |
| `LogAnalyticsWorkspaceId` | Challenge 3 (observability queries) | — |
| `ApplicationInsightsConnectionString` | Challenge 3 (agent traces, tracing) | — |
| `ResourceGroupName` | Portal navigation, resource discovery | — |

`SpokeAiFoundryAccountName`/`SpokeAiFoundryProjectName` are exact-name aliases of
`SpokeFoundryAccountName`/`SpokeFoundryProjectName` — both are emitted so the
dashboard label matches the `SPOKE_AI_FOUNDRY_*` key the notebooks expect.

## Notebook Environment Setup

The workshop notebooks read their settings from the environment first and fall back
to `azd env get-value <KEY>` for their
configuration — but this lab deploys with `deploy-lab.ps1` (PowerShell/Bicep), not
`azd up`, so there's no azd environment for them to read by default.

> [!NOTE]
> This script is **optional**. Because the notebooks now read `os.environ` first, the
> simpler path for attendees is to copy `challenges/workshop/.env.template` to `.env`
> and paste in their dashboard values — no `azd` install required. Use this script when
> you want the original azd-based workflow, or to provision attendees' environments
> programmatically.

Run [`setup-notebook-env.ps1`](setup-notebook-env.ps1) once per attendee, using the
`HackboxCredential` values from the dashboard, to bridge the gap:

```powershell
./setup-notebook-env.ps1 `
    -ResourceGroup "<ResourceGroup>" `
    -Location "<Location>" `
    -SubscriptionId "<SubscriptionId>" `
    -LlmBackendConfig "<LlmBackendConfig>" `
    -SpokeKeyVaultName "<SpokeKeyVaultName>" `
    -SpokeAiFoundryAccountName "<SpokeAiFoundryAccountName>" `
    -SpokeAiFoundryProjectName "<SpokeAiFoundryProjectName>" `
    -SpokeAcrName "<SpokeAcrName>" `
    -SpokeAcrLoginServer "<SpokeAcrLoginServer>"
```

This creates/selects a local azd environment (`citadel-microhack` by default) and
sets every key the notebooks read (`AZURE_RESOURCE_GROUP`, `AZURE_LOCATION`,
`AZURE_SUBSCRIPTION_ID`, `LLM_BACKEND_CONFIG`, `SPOKE_RESOURCE_GROUP`,
`SPOKE_KEY_VAULT_NAME`, `SPOKE_AI_FOUNDRY_ACCOUNT_NAME`,
`SPOKE_AI_FOUNDRY_PROJECT_NAME`, `SPOKE_ACR_NAME`, `SPOKE_ACR_LOGIN_SERVER`).
Requires `azd` to be installed (fails clearly if not found on `PATH`). Notebooks
can then be opened and run without modification.

## Deployment Robustness

The script follows MicroHack conventions:

- **Region fallback** — Retries across `$PreferredLocation` (honoring platform preference),
  falling back to [swedencentral, westeurope, norwayeast] if all fail. Retries are gated on
  `Test-MhhDeploymentFailureRetryable`: a non-retryable failure (template or permission bug)
  aborts immediately with the real error rather than being retried in every region.
- **Deterministic naming** — `Get-MhhStableHash` generates a stable suffix per attendee,
  ensuring names are DNS-safe, globally unique, and consistent across re-runs. The hash is
  computed **once** and passed to Bicep as `resourceToken`; the template is the single source
  of truth for every resource name.
- **Idempotent provisioning** — All resources are created once; re-runs skip existing resources.
- **Managed identities** — No hardcoded keys or connection strings; all auth uses Entra ID +
  Azure RBAC (DefaultAzureCredential in notebooks).
- **Multi-user RBAC** — Every ID in `$AllowedEntraUserIds` is granted the necessary data-plane
  roles (Azure AI User, Cognitive Services User, Cosmos DB Data Contributor, Key Vault Secrets
  Officer, Monitoring Reader), plus:
  - **`API Management Service Contributor`** on the APIM resource — `APIMClientTool` (Notebooks
    3–7, 9) is an ARM control-plane client that lists APIs/subscriptions and creates/updates
    products and subscriptions dynamically; this is the least-privileged built-in role that
    covers both the APIM service and its entities (the narrower `Operator`/`Reader` built-in
    roles cannot create/update products or subscriptions).
  - **`AcrPush`** on the spoke ACR — required only for Notebook 7's container publishing;
    granted by default since the ACR already exists in the core deployment.

  Grants are driven off the **template's own resource-ID outputs**, not a resource-group
  lookup, so the hub *and* spoke instances of each duplicated type (Foundry, Key Vault, Log
  Analytics, App Insights) are both covered. Every grant is classified Required or Optional:
  if any **Required** grant fails, the script throws with a per-scope summary instead of
  handing the attendee a lab whose notebooks silently 403. Optional grants (challenges 7–9)
  only warn.

  So team labs work for all members.
- **Robust output** — `[INFO]`, `[OK]`, `[WARN]` prefixes guide troubleshooting.

## Subscription Scope Prerequisites

[`shared-deploy-lab.ps1`](shared-deploy-lab.ps1) registers these providers automatically,
once per subscription, before any `deploy-lab.ps1` runs — participants only hold RG-Owner and
subscription-Reader, so they cannot self-register:

| Provider | Needed for |
|---|---|
| `Microsoft.ApiManagement` | APIM AI gateway (all challenges) |
| `Microsoft.CognitiveServices` | Foundry hub + spoke accounts, model deployments |
| `Microsoft.DocumentDB` | Cosmos DB usage tracking (challenge 2) |
| `Microsoft.KeyVault` | Hub and spoke Key Vaults |
| `Microsoft.OperationalInsights` | Log Analytics workspaces (challenge 3) |
| `Microsoft.Insights` | Application Insights / agent tracing (challenge 3) |
| `Microsoft.EventHub` | Usage event streaming pipeline |
| `Microsoft.Storage` | Usage ingestion storage account |
| `Microsoft.ManagedIdentity` | User-assigned identities for APIM backend auth |
| `Microsoft.ContainerRegistry` | Spoke ACR (challenge 7) |
| `Microsoft.App` *(optional)* | HR MCP Container App (challenge 9, instructor-led) |
| `Microsoft.AlertsManagement` *(optional)* | Governance alert rules (optional extension) |

Registration is best-effort by design: if the shared hook throws, the platform runs **no** labs
in that subscription. A provider that cannot be registered is reported with the exact
`az provider register` command for a subscription Owner to run.

## Local Dry Run

The platform injects `Get-MhhStableHash` and pre-creates the resource group, so
`deploy-lab.ps1` cannot run directly outside the platform. Use the local wrapper:

```powershell
# Requires: az login + Connect-AzAccount to the test subscription,
# and the Az.Accounts / Az.Resources modules installed.
./run-local.ps1 -SubscriptionId <sub> -ResourceGroupName <rg> `
    -Location swedencentral -AllowedEntraUserIds <your-object-id>
```

> `run-local.ps1` is a **local-only helper** (not used by the platform).
> It mirrors the `resourcegroup` deployment path.

After a successful dry run, run `setup-notebook-env.ps1` (see
[Notebook Environment Setup](#notebook-environment-setup) above) using the
`HackboxCredential` values printed by `deploy-lab.ps1` to bridge the notebooks'
`azd env get-value` calls.

## Configuration

Edit [`lab-defaults.json`](lab-defaults.json) to tune regional preferences, density, and budget.

**`estimatedDailyCostsUsd: 32.0`** — the Console uses this to size participant budgets, so it
must reflect the real burn rate. Breakdown per lab:

| Component | ~USD/day |
|---|---|
| API Management **Standard v2** (~$0.95–1.00/hr, always-on) | ~23 |
| Cosmos DB (serverless), Event Hub (Basic), Storage | ~2 |
| 2× Log Analytics + 2× Application Insights (ingestion) | ~3 |
| ACR (Basic), Key Vaults, managed identities | ~1 |
| Model inference (6 deployments, pay-per-token, workshop-scale usage) | ~3 |
| **Total** | **~32** |

> APIM Standard v2 dominates the cost. Dropping to **Basic v2** would cut the APIM line by
> roughly 7×, but it changes gateway capabilities — treat that as a functional decision, not a
> pure cost tweak.

**`labsPerSubscription: 8`** — bounded by Azure OpenAI regional quota, not cost:
`8 labs × 100 capacity units per model = 800` units, inside the typical 1 000-unit
GlobalStandard quota per model per region. **If you raise `labsPerSubscription`, or raise the
model `capacity` in `infra/resources.bicep`, re-check that product against the subscription's
quota in the target region** — exceeding it makes later labs fail to deploy their models.

`estimatedSharedDeploymentDailyCostsUsd: 0.0` — `shared-deploy-lab.ps1` only registers resource
providers and deploys nothing billable.

No credentials or secrets are stored in this folder.
