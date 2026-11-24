# labautomation — Decision Models for a Retail Marketplace

[`deploy-lab.ps1`](deploy-lab.ps1) gives each attendee one Foundry resource with two model
deployments, and the **Launch Day console** as a web app. Attendees only need a browser: no
GitHub account, no Codespace, nothing to install. (Developers on the optional Build track use
Azure Cloud Shell, or GitHub Codespaces with their **own** GitHub account — the lab doesn't
provide GitHub access.) There is no facilitator pre-setup and no
database: the listings, photos and recorded reference runs ship in `src/data/`.

## What gets provisioned per attendee

| Resource | Purpose |
|----------|---------|
| Foundry resource (`AIServices`, S0, `dm-<hash>`) | Hosts the deployments. **Keyless**: `disableLocalAuth = true` |
| Deployment `decision`: **Microsoft-Decision-1.1**, DataZoneStandard x500 | The gate's decision model (`/providers/microsoft/v1/systemone`), and the judge in Foundry evaluations (Challenge 6) |
| Deployment `gpt-6-luna`: **gpt-6-luna**, DataZoneStandard x40 | Azure OpenAI **Decisions API** (`/openai/v1/decisions`) and the generative baseline (Responses API) |
| Foundry project `marketplace-gate` | Lets attendees open the deployments and evaluations in the Foundry portal |
| App Service plan **B1 Linux** + web app `dmgate-<hash>` | The Launch Day console, built from [`../src`](../src) with `requirements.txt`. Signs in to the Foundry resource with its **system-assigned managed identity** |
| RBAC: **Cognitive Services User** + **Foundry User** for the attendee **and** the web app's identity | Call the models; run evaluations with a decision-model judge |
| Storage account `dmcs<hash>` (Standard_LRS) with file share `cloudshell` (6 GiB) + **Storage Account Contributor** for the attendee | Build track: **Azure Cloud Shell** keeps `$HOME` — the clone, `.venv` and `.env` — when a session times out after 20 idle minutes (lunch, breaks) |

## What the attendee receives on their dashboard

| Credential | Used for |
|------------|----------|
| `ConsoleUrl`, `AccessCode` | **Everyone:** open the console in a browser and enter the code |
| `DecisionEndpoint`, `OpenAIEndpoint` | Build track (Cloud Shell, a codespace or a local dev container): `src/.env` |
| `DecisionCapacity`, `LunaCapacity` | Build track: `src/.env` (the client paces itself to these) |
| `FoundryProjectEndpoint` | Optional `PROJECT_ENDPOINT`, to log evaluations to the project |
| `ResourceGroupName` | Find the resources in the portal |
| `CloudShellStorage` | Build track: the storage account to pick in Cloud Shell's **Mount storage account → Select existing storage account** (file share `cloudshell`). Not emitted if a tenant policy disables shared-key access, which Cloud Shell needs to mount the share |

`lab-defaults.json` sets `groups: []`: the hack needs no GitHub Copilot seat or Microsoft 365
licence. Developers who want to run the code use **Azure Cloud Shell** with their lab account.

## Sizing, quota and cost

One capacity unit is **1 request/min + 1,000 tokens/min** for both models. Data Zone quota is
shared by every lab in the subscription:

| Model | DataZoneStandard quota (default) | Per lab | 8 labs |
|-------|-------------------|---------|--------|
| gpt-6-luna | 333 | 40 | 320 |
| Microsoft-Decision-1.1 | 4,500 | 500 | 4,000 |

`gpt-6-luna` is the binding constraint, which is why `labsPerSubscription` is 8 and the
challenges run live on a 24-listing starter set and use **recorded runs** for the full
1,310-listing statistics. A room of 40 needs 5 subscriptions.

> [!IMPORTANT]
> Azure's rate limiter counts the **size of the request**, not the tokens you are billed for.
> A photo sent as base64 counts in full: the gate's 384 px JPEGs cost about 3,500 tokens of
> rate limit each, although usage reports a few hundred.

`estimatedDailyCostsUsd` is about **$1.5**: the B1 plan is roughly $0.45 a day, the Cloud Shell
file share a few cents a month, and the models are
pay-per-token (a full live run of the starter set on all three models costs well under one US
cent; Microsoft-Decision-1.1 is $0.042–0.050 per million input tokens and charges no output).

> [!NOTE]
> Microsoft-Decision-1 (preview) is marked **Deprecating** in the model catalog and retires on
> **4 February 2027**. This lab doesn't deploy it: Microsoft-Decision-1.1 works as the judge for
> Foundry evaluators with `azure-ai-evaluation` 1.18.11 or later (tested with 1.18.12), as the
> [Microsoft-Decision-1.1 announcement](https://techcommunity.microsoft.com/blog/azure-ai-foundry-blog/introducing-microsoft-decision-1-1-build-faster-more-efficient-ai-applications-w/4573877)
> says. The [judge article on Learn](https://learn.microsoft.com/azure/foundry/observability/how-to/decision-model-judge)
> still names Decision-1 only; re-check before an event.

## Deployment robustness

| Concern | How the script handles it |
|---------|---------------------------|
| A region without one of the models, or without quota left | Before creating anything, the script checks each preferred region's model catalog (`DataZoneStandard`, exact version) **and** remaining quota, and picks the first that fits. |
| A control-plane call fails | Every ARM call goes through `Invoke-MhhArm`, which throws on any non-2xx. |
| Two deployments on one account at once | Deployments are created one at a time; a 409 is retried. Each must reach `Succeeded`. |
| "Provisioned" isn't "working" | Step 6 calls every API the challenges use — Decision-1.1 with text **and an image**, the Decisions API and the Responses API — and checks for a typed answer. Step 7 waits for the console's build and then for `/api/health`, which calls Decision-1.1 **with the web app's own identity**. Credentials are emitted **only after all of that passes**. |
| Role assignments take time to propagate | Probes retry for up to 12 minutes; the console health check for up to 15. |
| Publishing without basic auth | The console is published to Kudu's `/api/publish` with an **Entra token**; no publishing credentials are enabled. |
| MCAPS policies disabling public network access | The resource group is tagged `SecurityControl = Ignore` and the script verifies `publicNetworkAccess = Enabled`. Local auth stays disabled. |
| Re-runs after a partial failure | Every step is idempotent; the access code is kept across re-runs. |

> [!IMPORTANT]
> The script packages the console from `../src` (relative to the script). It must run from a
> full checkout of the hack folder, as the platform does for scripts that reference files next
> to them. It fails with a clear message if `src/` is missing.

## Local dry run

The platform injects `Get-MhhStableHash` and pre-creates the resource group, so
`deploy-lab.ps1` can't run directly outside the platform. Use
[`walkthrough/run-local.ps1`](../walkthrough/run-local.ps1), which supplies the helper,
creates the resource group and passes your own object ID:

```powershell
# Requires: Connect-AzAccount to the test subscription, Az.Accounts and Az.Resources.
../walkthrough/run-local.ps1 -ResourceGroupName rg-decision-hack-test -Location swedencentral
```

## References

- [Deploy and use Microsoft-Decision-1.1](https://learn.microsoft.com/azure/foundry/foundry-models/how-to/use-foundry-models-microsoft-decision)
- [Azure OpenAI Decisions API](https://learn.microsoft.com/azure/foundry/openai/how-to/decisions)
- [Use a decision model as an evaluation judge](https://learn.microsoft.com/azure/foundry/observability/how-to/decision-model-judge)
- [Configure a Python app on Azure App Service](https://learn.microsoft.com/azure/app-service/configure-language-python)
