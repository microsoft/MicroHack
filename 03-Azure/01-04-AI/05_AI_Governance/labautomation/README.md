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
- The platform **pre-creates the resource group** and pre-sets the Azure context.
  The script does **not** call `Connect-AzAccount` or `New-AzResourceGroup`.
- Hub and spoke resources are deployed into **the same platform-provided ResourceGroupName**
  using deterministic suffixes to avoid name collisions.
- Foundry accounts, projects, Log Analytics, App Insights, Key Vault, and APIM are all
  provisioned with **managed identities** — no keys or secrets in logs.
- RBAC is assigned **per attendee** (via `$AllowedEntraUserIds`) across Foundry, Key Vault,
  Cosmos DB, and monitoring services, so the notebooks work out-of-the-box.

## What the Attendee Receives

The platform dashboard surfaces these credentials as `HackboxCredential` objects.
The **Notebook azd Key** column is what the corresponding value must be set to via
`setup-notebook-env.ps1` for the unchanged workshop notebooks to consume it via
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

The workshop notebooks are unchanged and call `azd env get-value <KEY>` for their
configuration — but this lab deploys with `deploy-lab.ps1` (PowerShell/Bicep), not
`azd up`, so there's no azd environment for them to read by default.

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
  falling back to [swedencentral, westeurope, norwayeast] if all fail.
- **Deterministic naming** — `Get-MhhStableHash` generates a stable suffix per attendee,
  ensuring names are DNS-safe, globally unique, and consistent across re-runs.
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
  
  So team labs work for all members.
- **Robust output** — `[INFO]`, `[OK]`, `[WARN]` prefixes guide troubleshooting.

## Subscription Scope Prerequisites

Before the platform runs `deploy-lab.ps1`, these must be pre-registered at the subscription level:

- `Microsoft.ApiManagement`
- `Microsoft.CognitiveServices`
- `Microsoft.EventHub`
- `Microsoft.KeyVault`
- `Microsoft.OperationalInsights`
- `Microsoft.DocumentDB`
- `Microsoft.Insights`
- `Microsoft.Storage`
- `Microsoft.ContainerRegistry`
- `Microsoft.Logic` (if Logic App is deployed)

If a provider is not registered, the script will fail with a clear message: *"Provider X must be registered at subscription scope before lab deployment."*

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

Edit [`lab-defaults.json`](lab-defaults.json) to tune:
- Regional preferences (adjust for availability)
- Labs per subscription (8 labs × ~15 USD/day = ~120 USD/day per subscription)
- Estimated daily cost estimate

No credentials or secrets are stored in this folder.
