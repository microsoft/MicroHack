# Lab automation

[Home](../README.md)

The Bicep template lives in [infra](../infra/main.bicep). This folder holds the platform files: [deploy-lab.ps1](deploy-lab.ps1) and [lab-defaults.json](lab-defaults.json).

## What is deployed per attendee

| Resource | Purpose |
|---|---|
| Microsoft Foundry account and project `frontier-operations` | Harness agents, skills, toolboxes, guardrails and traces |
| Chat model `gpt-5.4-mini` (GlobalStandard, capacity 200) | The default model for every agent |
| Comparison model `gpt-5.4` (GlobalStandard, capacity 50) | Challenge 7 compares it with `gpt-5.4-mini` on one partner |
| Connection `appinsights` to Log Analytics and Application Insights | Agent traces for the **Traces** tab, and the back office's own telemetry |
| Connection `erp` (category *Custom keys*, header `x-api-key`) | The ERP's API key. The OpenAPI tool uses it; participants never see the key |
| Playwright workspace `pw-frontier-<suffix>` in `browserLocation` (default `switzerlandnorth`) and connection `browser` (*Project managed identity*) | The managed browser for Browser Automation (Challenge 5). Local authentication is disabled |
| Storage account with private containers `packs`, `ops-state` and `app-package` | The industry pack, the state of the ERP notes and the partner portal, and the app's deployment package. Shared keys and public blob access are disabled; access is by Entra ID only. Tagged `SecurityControl: Ignore` so that tenant automation in managed subscriptions does not disable public network access, which Cloud Shell needs |
| Azure Functions app on **Flex Consumption** (FC1, Python 3.12) with a system-assigned identity | The back office (`BackOfficeUrl`): the ERP API (needs the key), the partner portal (HTML only, no API) and the activity page. Basic publishing credentials are disabled; `deploy-lab.ps1` publishes the code with an Entra token |

Role assignments, all scoped to the attendee's own resources:

| Who | Role | Scope |
|---|---|---|
| Attendee | Foundry User, **Foundry Project Manager** (to add connections, toolboxes and guardrails) | Project |
| Attendee | Cognitive Services OpenAI User | Foundry account |
| Attendee | **Role Based Access Control Administrator, with a condition**: may assign or remove only the Foundry User role | Project |
| Attendee | Storage Blob Data Contributor | Storage account |
| Attendee | Log Analytics Reader (to read agent traces) | Application Insights and its Log Analytics workspace |
| Attendee | Playwright Workspace Contributor (to watch browser sessions) | Playwright workspace |
| Project identity | Playwright Workspace Contributor | Playwright workspace (Browser Automation signs in as the project) |
| App identity | Storage Blob Data Owner | Storage account (the Functions host keeps its leases there; the app keeps its state in `ops-state`) |

**Why the conditional RBAC role?** A harness agent returns files and calls toolboxes with its **own** identity, which needs Foundry User on the project. That identity exists only after the participant creates the agent, so the role can't be assigned in advance. The condition lets participants assign exactly that role, on their own project, with `python3 -m frontierops grant-agent`, and nothing else.

Attendees load their industry pack, and create the agents, skills, toolboxes and guardrails themselves.

## Platform contract

The platform sets the Az context and passes `DeploymentType`, `SubscriptionId`, `ResourceGroupName`, `PreferredLocation` and `AllowedEntraUserIds`. The default mode is `resourcegroup`. Only `subscription` mode creates a resource group, named with `Get-MhhStableHash -Length 24`. The script never signs in, switches subscription, deletes resources or silently changes region. One region is accepted (default `uksouth`); a quota or capacity failure is reported, not worked around.

The ERP key is derived with `Get-MhhStableHash` from the subscription, resource group and attendees, so a re-run keeps the same key. It is passed to the template as a secure parameter and never written to the outputs.

After the template, the script zips the back office (`app/` plus each pack's `pack.json` and `ledger.csv`) and publishes it to the Functions app's `/api/publish` endpoint with an ARM token, then waits until `/health` reports all five packs.

Dashboard outputs (not secrets): `ResourceGroupName`, `EffectiveLocation`, `FoundryAccountName`, `FoundryProjectEndpoint`, `FoundryProjectResourceId`, `ModelDeploymentName`, `CompareModelDeploymentName`, `StorageAccountName`, `BackOfficeAppName`, `BackOfficeUrl`, `PlaywrightWorkspaceName`, `BrowserConnectionName`, `ErpConnectionName`, `ApplicationInsightsName`.

Register these resource providers before the event: Microsoft.CognitiveServices, Microsoft.Storage, Microsoft.Web, Microsoft.OperationalInsights, Microsoft.Insights and **Microsoft.LoadTestService** (Playwright Workspaces).

## Capacity and cost

- **Region.** The Copilot harness was available in `uksouth` in October 2026. Playwright Workspaces are in fewer regions and West Europe was closed to new customers, so the browser workspace has its own parameter, `browserLocation`, defaulting to `switzerlandnorth`. Do one test deployment in the event subscription a few days before the event.
- **Why Flex Consumption for the back office?** Some subscriptions have no App Service plan quota at all. Flex Consumption doesn't use that quota.
- **Model quota.** GlobalStandard quota is shared across the subscription. Four labs need 4 × 200K TPM of `gpt-5.4-mini` and 4 × 50K TPM of `gpt-5.4`. A five-partner run with subagents reads about a million tokens (mostly cached) in under four minutes; on `gpt-5.4` at 50K TPM it failed, which is why Challenge 7 compares one partner. **Soft-deleted Foundry accounts keep their model quota** until they are purged: `az cognitiveservices account purge -l <location> -n <account> -g <resource group>`.
- Role assignments take a few minutes to apply. Give participants their lab at least 10 minutes after deployment.
- `$8/day/lab` is a **planning estimate**, not a quote. An idle lab costs very little: there is no fixed-price service (Flex Consumption, Playwright Workspaces and the models are billed by use). The cost is the day's agent runs: model tokens, browser minutes in Challenge 5, and, from 1 December 2026, the Copilot harness's compute (billed per vCPU-hour and GiB-hour while sessions run; free during the preview until then). **Browser sessions stay open and billed until the agent closes them or they time out**: in our test lab, runs of one or two minutes were billed 15 to 31 minutes each. Challenge 5 has participants add *close the browser when you've finished* to the agent's instructions.
- No Microsoft 365 licence is needed (`groups: []`).

## Testing the automation outside the platform

[`dev/run-local.ps1`](../dev/run-local.ps1) runs `deploy-lab.ps1` the way the platform does: it supplies `Get-MhhStableHash`, creates the resource group, passes your Entra object ID and prints the dashboard values. Sign in with both `Connect-AzAccount` and `az login` to the same subscription, then run it from the lab folder:

```powershell
./dev/run-local.ps1 -AllowedEntraUserIds (az ad signed-in-user show --query id -o tsv)
```

Add `-Location <region>` to check another region. A re-run against the same resource group republishes the back office. Afterwards delete the resource group and purge the Foundry account.

## Lifecycle

The platform removes the lab resources when the lab expires. Do not run recursive cleanup or delete shared resources. Agents created during the day are removed with the Foundry account. See the [platform helper contract](https://github.com/microsoft/MicroHack/blob/main/99-MicroHack-Template/labautomation/README.md) for running outside the MicroHack platform; standalone facilitators can deploy `infra/main.bicep` directly after approval and then run the publish step from `deploy-lab.ps1`.
