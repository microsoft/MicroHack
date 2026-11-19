# Lab Automation — Agentic Inventory Planning MicroHack

Subscription providers are prepared once by [`shared-deploy-lab.ps1`](shared-deploy-lab.ps1), then resources are provisioned per attendee by [`deploy-lab.ps1`](deploy-lab.ps1) — there is **no shared Fabric backend**. Each attendee gets their own Foundry project **and** their own Fabric capacity (F4 default), then builds their own Fabric workspace + Data Agent by running [`Setup-InventoryDataAgent.ipynb`](../setup/Setup-InventoryDataAgent.ipynb) in Challenge 1.

## What `deploy-lab.ps1` provisions (per attendee)

| Resource | Type | Notes |
|----------|------|-------|
| Azure AI Foundry account | `Microsoft.CognitiveServices/accounts` | One per attendee (AIServices kind) |
| Foundry project | `…/projects/inventory-hack` | System-assigned managed identity; provisioning is verified before the lab continues |
| Model deployment (default gpt-5.4-mini) | GlobalStandard, capacity 200 by default | Used by all three agents. Configurable model/version/name/capacity; verified as Succeeded before readiness is reported. TPM/RPM per unit depend on the model. |
| Fabric capacity (default **F4**) | `Microsoft.Fabric/capacities` | One per attendee; attendee set as **capacity admin**. Rehearse F4 against F8 before an event. SKU via `-FabricSkuName`. |
| Application Insights (+ Log Analytics) | `Microsoft.Insights/components` + `Microsoft.OperationalInsights/workspaces` | Connected to the project as an `AppInsights` connection so the **Traces** tab works in Challenges 3–5 with no manual setup. Non-fatal if it fails. |

The script grants the **Foundry User** role to each attendee and to the Foundry project's managed identity at the Foundry account scope. It also sets each attendee as **admin of their own F4 capacity** (resolving their Entra object ID to a UPN via the platform `Get-MhhLabUser` helper), so they can create a workspace, assign it to the capacity, and publish their own Data Agent — no shared state, no cross-attendee contention.

## What the attendee does themselves (Challenge 1)

1. Create a Fabric **workspace** and assign it to their **F4 capacity** (`FabricCapacityName`).
2. Create a Lakehouse named **`InventoryLakehouse`** and attach it to the notebook.
3. Import and **Run All** [`Setup-InventoryDataAgent.ipynb`](../setup/Setup-InventoryDataAgent.ipynb) — it loads its **embedded** seed data, writes 7 tables, publishes their **`inventory-hack-agent`** Data Agent, and prints **their** Workspace ID + Agent ID.
4. In Foundry, add **Fabric IQ (OneLake Catalog)** and select their published Data Agent (Challenge 2). IDs remain useful for SDK/diagnostics; the portal now selects the item through the catalog.

## Optional hosted assistant (Challenge 5)

The default script above does not deploy application code. After participants
save their three Fabric IQ specialists, they use the
[Cloud Shell participant bootstrap](../orchestrator/README.md)
to fetch the event-tested workshop source from GitHub, pin their specialist
versions and deploy `inventory-planning-assistant` into their existing project.
They sign in with their lab username/TAP in the browser; Cloud Shell's Azure CLI
identity is reused by azd. No software is installed on their computers.
Budget for hosted compute and personal Bot Service publishing separately; do not
silently add these resources to every core-lab deployment.

RG Contributor plus the Foundry User assignment already created by this script
is the participant deployment baseline. Contributors cannot create missing role
assignments or register subscription providers, so keep those tasks in platform
preparation. Do not require attendee Owner. Cloud Shell storage, if required by
the tenant, must also use approved lab resources.

The hosted assistant's own runtime identity needs **no extra role assignment**. The deploy
helper reads the pinned specialists with the participant's own permissions and ships them in
the package (`specialists.json`), so nothing has to be granted after the agent is created.
This was verified with that identity holding no role beyond the platform's implicit access.

The visual workflow designer retires on **1 December 2026**, and the earlier
Foundry Fabric Data Agent connector retires on **6 November 2026**. Rehearse
Fabric IQ consent, delegated access and both Teams/M365 channels. Ontology
remains optional. Local tests do not certify this new runtime's live channels.

The hosted helper can reuse **one existing Fabric IQ connection** across the
three specialists and run hosted multi-turn checks with
`-FabricIQConnectionName '<name>' -Deploy -VerifyHosted`. It does not automate
another user's OAuth consent or silently publish tenant-wide. See the
[automation boundaries](../orchestrator/FACILITATOR.md#reduce-repeat-setup).

Participants test **Teams for web** and **Microsoft 365 Copilot for web** in
standalone Edge InPrivate/Chrome Incognito windows, not embedded browsers or
desktop clients. Before the event, verify the lab platform's Copilot license is
assigned **and provisioned**, personal app publishing policies permit the exercise,
and tenant-approved private-browser cookie/pop-up settings allow sign-in and
Fabric consent. The `M365-E5-Users` group below provides E5/Power BI Pro; it is not
by itself evidence of Microsoft 365 Copilot entitlement.

### Challenge 5 preflight

Challenge 5 publishing is optional. If you offer it, check these before admitting participants:

- **Source:** the guide clones the default branch of `https://github.com/microsoft/MicroHack`
  (only this lab's folder). Give participants a release tag only if the event needs a frozen
  version, and check that the source contains this lab's `orchestrator` folder.
- **Provider:** `Microsoft.BotService` is registered, using the lab's
  [subscription preparation hook](shared-deploy-lab.ps1).
- **Permissions:** participants hold Foundry publishing permissions and Azure Bot Service
  resource/channel write permissions. Provider registration alone grants neither.
- **Tenant:** app policies allow personal ("Just you") agents; Fabric licenses and Data
  Agent access are in place; each lab account's Microsoft 365 Copilot license is provisioned.
- **Licences (check each lab account):** Microsoft Teams and Microsoft 365 Copilot are both
  licensed and provisioned. A Fabric/Power BI-only account cannot open Teams, and the portal's
  **Publish successful** message does not prove the account can use the app. Rehearse with
  one real lab account: sign in to Teams for the web, open **Apps → Manage your apps**, and
  confirm Copilot shows as licensed, not **Copilot Chat (Basic)**.
- **Browsers:** rehearse in the exact private-window browser the event will use, including
  the Fabric consent prompt and any cookie or pop-up settings your tenant needs.
- **Isolation:** test two separate users and a user without Fabric access before release.
- **Scope:** organization-wide publishing is a separate Microsoft 365 admin step; "Just you"
  is not a substitute for it.

> [!NOTE]
> **Status of this check (20 Oct 2026):** the Foundry side of publishing was verified. The
> Bot Service `inventory-planning-assista57069` (S1) was created, **Just you** needs no
> approval and the portal reported **Publish successful**. Using the published assistant in
> Teams and Microsoft 365 Copilot was **not verified**, because the test account only held a
> Power BI licence and Teams would not open. Treat Part E as untested until you rehearse it
> with a licensed lab account.

Coach procedure for the browser checks: [Challenge 5 solution](../walkthrough/challenge-05/solution-05.md#publishing-checks-coach).

## Credentials returned to the attendee dashboard

| Key | Value |
|-----|-------|
| `FoundryProjectUrl` | Clickable deep-link to the attendee's `inventory-hack` project in the Foundry portal (`ai.azure.com`) — where they build the agents in Challenges 2-5 |
| `FoundryProjectEndpoint` | `https://<account>.services.ai.azure.com/api/projects/inventory-hack` (SDK/API endpoint; optional — the hack is done in the portal) |
| `ModelDeploymentName` | `gpt-5.4-mini` |
| `FabricCapacityName` | The attendee's own F4 capacity (assign your workspace to it in Challenge 1) |
| `FabricPortalUrl` | Link to the Fabric portal (`app.fabric.microsoft.com`) to create the workspace on `FabricCapacityName` — the workspace URL itself only exists once the attendee creates it in Challenge 1 |
| `ResourceGroupName` | The attendee's resource group |

Attendees use these in the Foundry and Fabric portals — no SDK or code required.

## Prerequisites for facilitators / the platform

- The deploying identity (the platform **service principal**) needs **Owner** on each attendee resource group so it can create resources and assign the **Foundry User** role to the attendee and project managed identity — the platform grants this automatically for `resourcegroup` deployments.
- **`groups: ["M365-E5-Users"]`** in [`lab-defaults.json`](lab-defaults.json) — each attendee's lab Entra user gets a **Microsoft 365 E5** license (includes **Power BI Pro**), which is what lets them sign into the Fabric portal ([app.fabric.microsoft.com](https://app.fabric.microsoft.com)) and create a workspace. Without a Fabric/Power BI license the attendee cannot open the portal.
- **The lab tenant must have Fabric enabled** — a Fabric **tenant-admin** setting (*“Users can create Fabric items”* / workspaces). This is **not** settable via `lab-defaults.json`; the tenant administrator for the lab tenant must turn it on, or attendees cannot create a workspace even with a license.
- **Fabric F-SKU quota** in a preferred region (F4 = 4 CU → ~128 attendees per 512-CU subscription; drop to F2 = 2 CU to double that). `swedencentral` and `norwayeast` are good defaults.
- **Model quota vs. subscription packing** — [`lab-defaults.json`](lab-defaults.json) packs **`labsPerSubscription: 5`**, each requesting capacity **200**. Confirm actual model/region/GlobalStandard quota and existing allocations before the event; no fixed subscription quota ceiling is guaranteed. Lower packing alone does not increase a deployment's TPM/RPM.
- The shared hook registers **`Microsoft.CognitiveServices`**, **`Microsoft.Fabric`**, **`Microsoft.Insights`**, **`Microsoft.OperationalInsights`**, and **`Microsoft.BotService`**, waiting up to five minutes per provider. The deploying identity needs subscription-level `Microsoft.Resources/subscriptions/providers/register/action`; resource-group Owner alone is insufficient. Registration failure blocks participant deployments. BotService is needed for the optional Teams publishing showcase, even though no shared bot is provisioned.

> [!NOTE]
> Attendee object IDs → UPNs are resolved with the platform **`Get-MhhLabUser`** helper (served from a platform-seeded cache), so the service principal does **not** need Microsoft Graph directory-read permission.

## Cost estimate

- **Fabric capacity** (default **F4**, ~$0.72/hr pay-as-you-go) is the dominant cost — roughly **$16–17/attendee/day** if left running. Attendees (or facilitators) should **suspend** the capacity when idle. Dropping to **F2** (`-FabricSkuName F2`) roughly **halves** this — update `estimatedDailyCostsUsd` in [`lab-defaults.json`](lab-defaults.json) accordingly.
- gpt-5.4-mini (GlobalStandard, 200K TPM) — a few cents of tokens per attendee across the hack's ~50 agent calls; Foundry account base ~$2/day.
- **Application Insights + Log Analytics** — trace ingestion for the hack's ~50 agent calls is a few MB; effectively **negligible** (well within the Log Analytics free ingestion allowance).
- Total ≈ **$18/attendee/day** — reflected in [`lab-defaults.json`](lab-defaults.json) (`estimatedDailyCostsUsd`).

## Deployment configuration

The five platform-supplied parameters are unchanged. Like the existing optional
`FabricSkuName`, the following optional parameters are available to facilitators
and the [local wrapper](../dev/run-local.ps1); the platform uses their defaults
unless its invocation explicitly supplies overrides.

| Parameter | Default | Purpose |
|-----------|---------|---------|
| `ModelName` | `gpt-5.4-mini` | Underlying model |
| `ModelVersion` | `2026-03-17` | Explicit version; change with the model |
| `ModelDeploymentName` | `gpt-5.4-mini` | Name attendees select in every agent |
| `ModelCapacity` | `200` | GlobalStandard units, **not** a model-independent TPM count |
| `FabricSkuName` | `F4` | SKU for a newly created capacity |

Rerunning verifies an existing model deployment and updates its requested capacity
if different. A different model/version/SKU under the same name is rejected: use a
new deployment name for a fallback. Existing Fabric capacities are **not resized**
automatically; a different actual SKU is reported, and a paused/not-ready capacity
blocks readiness. Model and Fabric failures do not produce a successful dashboard.

If using a fallback, deploy an explicitly supported version with sufficient quota,
then select its **deployment name in all three agents** and run the same grounding,
tool-call and approval checks. `gpt-4.1-mini` is a candidate to rehearse, **not a
certified fallback** until the complete lab has passed on it. The lab's references
to `gpt-5.4-mini` describe the default; use dashboard `ModelDeploymentName` when
your facilitator configured another model.

## Workshop readiness and rehearsal

### Before admitting participants

- Confirm attendee licenses, Fabric item creation and Data Agent tenant settings.
- Run the shared provider hook with subscription-level permissions.
- Verify actual model/version availability, allocated capacity and remaining
  quota in each target region. Leave room for existing deployments.
- Confirm capacity state/admin access and a model playground response.
- Set the portal language to English to match the screenshots; keep object names unchanged.
- Verify **all seven named tables**, source instructions, example queries and the
  **published** Data Agent, not just the draft.
- For the optional Teams showcase, check BotService registration, publishing
  permissions and tenant app policies. Provider registration does not grant these.
- Keep preview runtime descriptions and ontology disabled for the core-path rehearsal.

### Query regression set

Run each question **three times**, in a fresh conversation, directly in Fabric
and through the Foundry Fabric tool. Inspect generated filters when results differ.
Natural-language behavior must be verified live; offline SQL tests are not a proxy.

| Question | Expected result from the notebook seed |
|----------|----------------------------------------|
| How many retail stores do we have? | 4 |
| How many Retail locations do we have? | 4 |
| Count our retail stores, excluding warehouses. | 4 |
| Show Leaf Blower X2 stock and safety stock at retail stores in the Pacific Northwest. | ST03 Portland: 8, safety 30; ST04 Seattle: 6, safety 30; both CRITICAL |
| What is the total outdoor power tools stock at retail stores? | 232 units |
| Show inventory for product P999. | No matching rows; no invented substitutes |

Keep existing joins and filters when investigating an empty result. Use the source
instructions and verified examples rather than changing data casing/collation.

### Throughput and capacity rehearsal

1. Start with a **fresh workspace/Lakehouse** on F4. Measure time from notebook Run
   All to seven tables visible in the SQL endpoint and a published agent answer.
   Record Spark startup, table writes, schema sync and query latency separately.
2. Reproduce the reported stall: loads that hang on F4 while capacity use is about
   1%. It reproduced on a fresh F4 after four sequential loads. The reported cause is the
   concurrent Spark core limit, with finished
   **TableLoad** jobs left **In progress** and holding cores. Confirm that cancelling
   the job in the Monitor hub (**Job runs -> Last run details -> Cancel**) lets the next
   load run. It did on that run. If it does, F8 is not needed for loading. Otherwise repeat on a fresh
   workspace on F8. Target **15 minutes to a verified answer** for the workshop profile.
3. Run the Challenge 2 heatwave prompt, its two follow-ups, then the full approval
   loop at the expected number of **concurrent attendees per subscription**. Run
   three rounds, keeping realistic tool output and conversation history.
4. Record model/version, deployed capacity, TPM/RPM limits, concurrency, elapsed
   time, tool-call count, failures and 429 retry delays. Require **no unrecovered
   429s**, correct governed answers and a preserved human approval gate.
5. Choose F4 only if it passes; use F8 for the event if F4 does not. F8 doubles
   Fabric CU consumption (8 per attendee) and roughly doubles the Fabric portion
   of cost: approximately $35/day total rather than $18/day at illustrative
   F4 pricing. A 512-CU quota fits at most 64 F8 capacities before other usage.
   Confirm current regional pricing and quota. If changing the committed default,
   update `FabricSkuName`, `estimatedDailyCostsUsd` and packing guidance together.
6. Suspend idle capacities. Keep measured results and tenant-specific details out
   of reusable defaults; do not describe a profile as tested without evidence.

### Diagnose throttling before adding deployments

| Evidence | Next action |
|----------|-------------|
| Deployment TPM/RPM exhausted | Respect the retry delay; reduce burst/conversation size or increase allocation within available quota |
| Billed tokens low but rate-limited | Inspect estimated request budget and output-token settings, not billed tokens alone |
| Temporary service-capacity 429 | Back off using `retry-after-ms`; more quota is not necessarily a fix |
| Only the nested Fabric tool fails | Inspect that tool's error and capacity/runtime; don't assume the Foundry deployment is responsible |

Use Foundry traces and, where available, `x-ratelimit-*` response headers. Portal
users should wait the reported delay before retrying, not repeatedly click Run.
Additional deployments of the same model use the same applicable subscription/
region/deployment-type quota pool. A new subscription helps allocation only when
it also enables an appropriately sized deployment.

See [Microsoft's quota and rate-limit guidance](https://learn.microsoft.com/azure/foundry/openai/how-to/quota).

## Offline verification

From the repository root (Python standard library and PowerShell 7 only):

```powershell
python -m unittest discover -s '03-Azure\01-04-AI\02_Inventory_Planning_Fabric\tests' -p 'test_*.py' -v
& '.\03-Azure\01-04-AI\02_Inventory_Planning_Fabric\tests\Test-LabAutomation.ps1'
```

These tests execute the notebook's seed and configuration logic with fake SDK
objects, exercise case-sensitive reference SQL, reject partial-table publication,
and mock deployment failures/provider registration. They do **not** certify SDK
compatibility, live natural-language query quality, F4/F8 performance or Teams.

## Live notebook acceptance

The setup notebook pins `fabric-data-agent-sdk==0.1.33a0` and installs it with
the notebook's Python interpreter before importing the SDK. It refreshes SQL
analytics endpoint metadata without recreating tables before adding the Lakehouse
source, including support for schema-enabled Lakehouses (`dbo.table` names).

For setup changes, require a successful **Run all** / `RunNotebook` execution of
the actual deliverable notebook before committing or pushing. Confirm that all
seven tables are selected, the agent is published, and the published MCP endpoint
returns the expected answers in the [query regression set](#query-regression-set).
Record the job ID, timestamps, tested source revision/hash and answers. A passing
dependency-only or instrumented diagnostic notebook is not end-to-end acceptance.
