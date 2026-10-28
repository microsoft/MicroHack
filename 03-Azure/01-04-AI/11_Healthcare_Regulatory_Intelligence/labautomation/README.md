# Lab automation

[Home](../README.md)

This folder follows the [scaffolding prompt](../.github/prompts/scaffold-lab-automation.prompt.md) and [platform instructions](../.github/instructions/labautomation.instructions.md). The Bicep template lives in [infra](../infra/main.bicep), so this folder holds only the three platform files.

## What is deployed per attendee

| Resource | Purpose |
|---|---|
| Microsoft Foundry account and project `regulatory-intelligence` | Agents, traces and model deployments |
| Chat model `gpt-5.4-mini` (version 2026-03-17, GlobalStandard, capacity 200) | Used by all four agents |
| Embedding model `text-embedding-3-small` (GlobalStandard, capacity 30) | Used by Foundry IQ to index the lake |
| Storage account with private containers `lake-raw` and `regulatory-knowledge` | The regulatory lake. Shared keys and public blob access are disabled; access is by Entra ID only. Tagged `SecurityControl: Ignore` (parameter `storageTags`) so that tenant automation in managed subscriptions does not disable public network access, which Cloud Shell and the Search indexer need |
| Azure AI Search (Basic, semantic ranker free plan) with a system-assigned identity | Foundry IQ knowledge base |
| Log Analytics and Application Insights | Monitoring |

Role assignments, all scoped to the attendee's own resources:

| Who | Role | Scope |
|---|---|---|
| Attendee | Foundry User, **Foundry Project Manager** (to add the knowledge connection) | Project |
| Attendee | Cognitive Services OpenAI User | Foundry account |
| Attendee | Storage Blob Data Contributor | Storage account |
| Attendee | Search Service Contributor, Search Index Data Contributor | Search service |
| Search identity | Storage Blob Data Reader; Cognitive Services OpenAI User | Storage account; Foundry account |
| Project identity | Search Index Data Reader, Search Index Data Contributor, Search Service Contributor; Cognitive Services OpenAI User | Search service (Foundry IQ connects with the project managed identity because Search API keys are disabled); Foundry account |

Attendees create the knowledge base, the four agents and all data themselves during the hack.

## Platform contract

The platform sets the Az context and passes `DeploymentType`, `SubscriptionId`, `ResourceGroupName`, `PreferredLocation` and `AllowedEntraUserIds`. The default mode is `resourcegroup`. Only `subscription` mode creates a resource group, named with `Get-MhhStableHash -Length 24`. The script never signs in, switches subscription, deletes resources or silently changes region. One region is accepted (default `uksouth`); a quota or capacity failure is reported, not worked around.

Dashboard outputs (not secrets): `ResourceGroupName`, `EffectiveLocation`, `FoundryProjectEndpoint`, `FoundryAccountName`, `ModelDeploymentName`, `EmbeddingDeploymentName`, `StorageAccountName`, `SearchServiceName`, `SearchEndpoint`, `ApplicationInsightsName`.

Register these resource providers before the event: Microsoft.CognitiveServices, Microsoft.Storage, Microsoft.Search, Microsoft.OperationalInsights and Microsoft.Insights.

## Capacity and cost

- Confirm `gpt-5.4-mini`, `text-embedding-3-small` and Foundry IQ (agentic retrieval) availability and quota in the chosen region before the event. Model processing with GlobalStandard is not a data-residency guarantee.
- **Azure AI Search capacity varies by region.** In October 2026 test deployments, `uksouth` worked; `swedencentral` failed with `InsufficientResourcesAvailable` for the search service only, and `westeurope` refused new Storage and Search services. Do one test deployment in the event subscription and region a few days before the event.
- Role assignments take a few minutes to apply. Give participants their lab at least 10 minutes after deployment, or the first monitor run may report a storage permission error.
- `$8/day/lab` is a **planning estimate**, not a quote: Azure AI Search Basic is the largest fixed cost; token usage across about 60 agent calls is small. Codespaces used in Challenge 6 are billed by GitHub separately.
- Four labs per subscription assumes the chat model quota allows 4 × 200K TPM; check before promising that density.
- No Microsoft 365 licence is needed (`groups: []`).

## Testing the automation outside the platform

[`dev/run-local.ps1`](../dev/run-local.ps1) runs `deploy-lab.ps1` the way the platform does: it supplies `Get-MhhStableHash`, creates the resource group, passes your Entra object ID and prints the dashboard values. Sign in with both `Connect-AzAccount` and `az login` to the same subscription, then run `./dev/run-local.ps1` from the lab folder (add `-Location <region>` to check another region). It needs the Bicep CLI; if only the Azure CLI's copy is installed, the wrapper uses it. Delete the resource group afterwards.

## Lifecycle

The platform removes the lab resources when the lab expires. Do not run recursive cleanup or delete shared resources. See the [platform helper contract](https://github.com/microsoft/MicroHack/blob/main/99-MicroHack-Template/labautomation/README.md) for running outside the MicroHack platform; standalone facilitators can deploy `infra/main.bicep` directly after approval.
