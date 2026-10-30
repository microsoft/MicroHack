# Lab automation

[Home](../README.md)

The Bicep template lives in [infra](../infra/main.bicep). This folder holds the platform files: [deploy-lab.ps1](deploy-lab.ps1) and [lab-defaults.json](lab-defaults.json).

## What is deployed per attendee

| Resource | Purpose |
|---|---|
| Microsoft Foundry account and project `contact-center` | Agents (voice and text), traces, Content Understanding and model deployments |
| Chat model `gpt-5.4-mini` (GlobalStandard, capacity 200) | Used by the chat, agent-assist and supervisor agents, Foundry IQ and Content Understanding. The voice agent uses a managed realtime model, so nothing is deployed for it |
| Analysis model `gpt-5.4` (GlobalStandard, capacity 30) | Used by the Content Understanding **Call center** analyzer in Challenge 6, which needs a full-size chat model |
| Embedding model `text-embedding-3-large` (GlobalStandard, capacity 50) | Used by Foundry IQ to index the knowledge and insights containers |
| Storage account with private containers `knowledge`, `insights`, `calls`, `evaluation`, `crm-state`, `crm-package` and `cu-projects` | The industry pack, the CRM's state, the Content Understanding Studio project files and the CRM's deployment package. Shared keys and public blob access are disabled; access is by Entra ID only. Tagged `SecurityControl: Ignore` so that tenant automation in managed subscriptions does not disable public network access, which Cloud Shell and the Search indexer need |
| Azure AI Search (Basic) with a system-assigned identity | Foundry IQ knowledge bases |
| Azure Functions app on **Flex Consumption** (FC1, Python 3.12) with a system-assigned identity | The mock CRM (`CrmUrl`). Basic publishing credentials are disabled; `deploy-lab.ps1` publishes the code with an Entra token |
| Log Analytics and Application Insights, connected to the project (connection `appinsights`) | Agent traces for the **Traces** tab, and the CRM's own telemetry |

Role assignments, all scoped to the attendee's own resources:

| Who | Role | Scope |
|---|---|---|
| Attendee | Foundry User, **Foundry Project Manager** (to add knowledge and tool connections) | Project |
| Attendee | Cognitive Services OpenAI User, **Cognitive Services User** (Content Understanding, PII detection and voice sessions) | Foundry account |
| Attendee | Storage Blob Data Contributor | Storage account |
| Attendee | Log Analytics Reader (to read agent traces) | Application Insights and its Log Analytics workspace |
| Attendee | Search Service Contributor, Search Index Data Contributor | Search service |
| Search identity | Storage Blob Data Reader; Cognitive Services OpenAI User | Storage account; Foundry account |
| Project identity | Search Index Data Reader, Search Index Data Contributor, Search Service Contributor; Cognitive Services OpenAI User | Search service; Foundry account |
| Foundry account identity | Storage Blob Data Reader | Storage account (Content Understanding reads recorded calls) |
| CRM identity | Storage Blob Data Owner | Storage account (the Functions host keeps its leases there; the CRM keeps its state in `crm-state`) |

Attendees load their industry pack, and create the knowledge bases, the four agents, the guardrail and the call analyzer themselves.

## Platform contract

The platform sets the Az context and passes `DeploymentType`, `SubscriptionId`, `ResourceGroupName`, `PreferredLocation` and `AllowedEntraUserIds`. The default mode is `resourcegroup`. Only `subscription` mode creates a resource group, named with `Get-MhhStableHash -Length 24`. The script never signs in, switches subscription, deletes resources or silently changes region. One region is accepted (default `uksouth`); a quota or capacity failure is reported, not worked around.

After the template, the script zips the CRM (`crm/` plus each pack's `pack.json` and `crm.json`) and publishes it to the Functions app's `/api/publish` endpoint with an ARM token, then waits until `/health` reports all five packs.

Dashboard outputs (not secrets): `ResourceGroupName`, `EffectiveLocation`, `FoundryProjectEndpoint`, `FoundryAccountName`, `ModelDeploymentName`, `EmbeddingDeploymentName`, `AnalysisModelDeploymentName`, `StorageAccountName`, `SearchServiceName`, `SearchEndpoint`, `CrmUrl`, `ApplicationInsightsName`.

Register these resource providers before the event: Microsoft.CognitiveServices, Microsoft.Storage, Microsoft.Search, Microsoft.Web, Microsoft.OperationalInsights and Microsoft.Insights.

## Capacity and cost

- **Region.** Voice agents (Voice Live), Content Understanding and Azure AI Search Basic were all available in `uksouth` in October 2026, and a full deployment there took about 11 minutes. Do one test deployment in the event subscription and region a few days before the event.
- **Why Flex Consumption for the CRM?** Some subscriptions have no App Service plan quota at all (every tier, including Free, at 0). Flex Consumption does not use that quota.
- **Model quota.** `gpt-5.4-mini` GlobalStandard quota is shared across the subscription. Four labs need 4 × 200K TPM of `gpt-5.4-mini` and 4 × 30K TPM of `gpt-5.4`. **Soft-deleted Foundry accounts keep their model quota** until they are purged, so purge test accounts after a dry run: `az cognitiveservices account purge -l <location> -n <account> -g <resource group>`.
- Role assignments take a few minutes to apply. Give participants their lab at least 10 minutes after deployment.
- `$10/day/lab` is a **planning estimate**, not a quote: Azure AI Search Basic is the largest fixed cost. Voice sessions, Content Understanding on three short calls and the agent tests are small. Codespaces used in Challenge 8 are billed by GitHub separately.
- No Microsoft 365 licence is needed (`groups: []`).

## Testing the automation outside the platform

[`dev/run-local.ps1`](../dev/run-local.ps1) runs `deploy-lab.ps1` the way the platform does: it supplies `Get-MhhStableHash`, creates the resource group, passes your Entra object ID and prints the dashboard values. Sign in with both `Connect-AzAccount` and `az login` to the same subscription, then run it from the lab folder:

```powershell
./dev/run-local.ps1 -AllowedEntraUserIds (az ad signed-in-user show --query id -o tsv)
```

Add `-Location <region>` to check another region. A re-run against the same resource group takes about a minute and republishes the CRM. Afterwards delete the resource group and purge the Foundry account.

## Lifecycle

The platform removes the lab resources when the lab expires. Do not run recursive cleanup or delete shared resources. See the [platform helper contract](https://github.com/microsoft/MicroHack/blob/main/99-MicroHack-Template/labautomation/README.md) for running outside the MicroHack platform; standalone facilitators can deploy `infra/main.bicep` directly after approval and then run the publish step from `deploy-lab.ps1`.
