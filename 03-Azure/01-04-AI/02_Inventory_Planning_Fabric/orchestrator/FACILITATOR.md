# Hosted Inventory Planning Assistant: facilitator and developer guide

> **Participants:** use the short [deployment guide](README.md) instead. This page is for
> facilitators, coaches and developers.

This optional Challenge 5 runtime replaces the Foundry visual workflow designer,
which retires on **1 December 2026**. Participants work in a browser and deploy
this starter themselves through **Azure Cloud Shell**, into their own lab project.
The original deployment automation remains responsible for the model and Fabric
capacity. This folder does not replace that automation.

## Runtime and approval design

An Agent Framework graph runs the team's pinned prompt-agent versions in order:
`demand -> optimisation -> replenishment`. Each stage uses the participant's saved
instructions and model, receives the scenario plus all earlier stage output, and
queries the published Fabric Data Agent through a Foundry toolbox (see
[Fabric access through the toolbox](#fabric-access-through-the-toolbox)). The last
stage returns validated JSON
proposal lines using Fabric-derived unit costs, not a fallback price. Invalid
JSON, missing costs and permission errors stop planning; no approval state is saved.

The hosted Responses adapter stores the proposal in `AgentSession.state`, using
Foundry's scoped session store. Between turns there is no running workflow waiting
for input and no process-global approval state. A new request creates fresh
clients, credentials and specialists. It forwards the platform's opaque call ID
to Foundry; it never stores user tokens or substitutes a facilitator's credentials.

The approval commands are deterministic, not interpreted by an LLM:

```text
STATUS
MODIFY <proposal-id> <revision> <line-number> <positive-integer-quantity>
YES <proposal-id> <revision>
NO <proposal-id> <revision>
NEW
```

The assistant prints the exact commands. A modification increments the revision
and requires fresh approval. `NEW` is allowed only after approval/cancellation.
Old revisions and duplicate approvals do not submit again. The result is
**SIMULATED**: no real ERP write or external side effect exists.

The host persists the completed proposal between turns, not in-flight specialist
work. A failed planning turn must be retried. Host session-store concurrency
checks protect saved state, but are not exactly-once delivery to an ERP. A real
ERP integration would additionally require a transactional approval ledger and
idempotency keys.

## Lab prerequisites

- A standalone browser and Azure Cloud Shell **PowerShell**. The bootstrap
  prepares any missing `azd`/extensions and an isolated SDK environment **inside
  Cloud Shell**. Nothing is installed on the participant's computer.
- The platform-provided username and **Temporary Access Pass (TAP)** for portal
  sign-in. Enter the TAP only on the Microsoft sign-in page, never in chat,
  scripts, command arguments, environment variables or source control.
- **Contributor** on the lab resource group plus **Foundry User** on the Foundry
  account/project. The platform deployment grants Foundry User to participants
  and the project identity. Contributor alone does not grant Foundry data-plane
  agent operations. Provider registration and missing role assignments remain
  platform/admin preparation, not attendee Owner privileges.
- A supported hosted-agent region, existing Foundry project/model and suitable
  deployment permissions. Budget for hosted compute separately from Fabric.
- Three prompt specialists completed in Challenges 2-4, with pinned version
  numbers. Their **Fabric IQ** tool must target the team's published
  `inventory-hack-agent`; the old `fabric_dataagent_preview` tool retires on
  **6 November 2026**.
- Fabric capacity running; calling users need permission to the published Data
  Agent and underlying data. Configure delegated OAuth through the supported
  Fabric IQ connection. Do not grant the whole workshop access through a shared
  facilitator identity.
- For personal publishing, `Microsoft.BotService` registered, Foundry publishing
  permissions, Azure Bot Service resource/channel write permissions and compatible
  tenant app policies. Organization-wide publication is a separate admin step.

## How the Cloud Shell bootstrap works

Participants follow the short [participant guide](README.md). This section describes
what its commands do, so you can support and rehearse them.

Only `-ResourceGroupName` is required. The script uses the subscription Cloud Shell is
signed in to, the single Foundry project in that resource group and the single Fabric IQ
connection in the project (a connection whose type is `fabric_iq_preview`). It stops with a
clear message when there is none, or more than one. Pass `-SubscriptionId`,
`-ProjectEndpoint` or `-FabricIQConnectionName` to override. The checks it runs first fail
fast if the subscription is not the one Cloud Shell is using.

The participant download is a sparse checkout of only this lab's folder (about 8 MB and a
few seconds), not the whole 900 MB repository. It needs no branch, because the guide clones
the default branch of `microsoft/MicroHack`. Give participants a **release tag** only when an
event needs a frozen version.

The bootstrap uses Cloud Shell's existing Python **3.10+** only for SDK tooling.
It creates `.venv-tools`, installs the three pinned tooling dependencies, and
prepares a user-local `azd` if missing/too old. **Python 3.13 application builds
run remotely in Foundry**; no local runtime installation, Docker or ACR is needed.
The script isolates azd configuration under `.azure/bootstrap`, delegates azd
authentication to the existing Azure CLI identity, and never requests the TAP.
If sign-in expires, refresh Cloud Shell's lab-user sign-in and rerun.

It looks up the actual project ARM ID in the supplied lab RG, resolves the latest
**saved** specialist versions once, then records concrete pins. Connection reuse,
versioning, deployment and hosted verification are described below. It does not
assign permissions, register providers, create models/capacities or run
`azd provision`. `-ConfigureOnly` prepares tooling/configuration without deploying
code; it still wires the explicitly supplied Fabric IQ connection.

Only after the hosted checks pass, continue with
[Challenge 5, Part E](../challenges/challenge-05.md) to publish and test the assistant.
A deployment success message alone does not certify planning or channels.
Each new Cloud Shell session might require rerunning the bootstrap; private
browser logout does not delete server-side deployments or conversations.

### Advanced/local configuration

From this folder, use a local Python 3.13 virtual environment:

```powershell
py -3.13 -m venv .venv
& '.\.venv\Scripts\python.exe' -m pip install -r requirements.txt
$env:FOUNDRY_PROJECT_ENDPOINT = 'https://<account>.services.ai.azure.com/api/projects/<project>'
$env:DEMAND_AGENT_NAME = 'demand-sensing-agent'
$env:DEMAND_AGENT_VERSION = '<tested-version>'
$env:OPTIMISATION_AGENT_NAME = 'inventory-optimisation-agent'
$env:OPTIMISATION_AGENT_VERSION = '<tested-version>'
$env:REPLENISHMENT_AGENT_NAME = 'replenishment-action-agent'
$env:REPLENISHMENT_AGENT_VERSION = '<tested-version>'
& '.\.venv\Scripts\python.exe' verify_configuration.py
```

The checker rejects the retired connector. It does not certify OAuth consent or
Fabric data access: test each specialist in the playground before deploying.
Then run:

```powershell
.\Deploy-Orchestrator.ps1 `
  -SubscriptionId '<subscription-id>' `
  -ProjectResourceId '<existing-project-ARM-id>' `
  -ProjectEndpoint $env:FOUNDRY_PROJECT_ENDPOINT `
  -DemandAgentName $env:DEMAND_AGENT_NAME -DemandAgentVersion $env:DEMAND_AGENT_VERSION `
  -OptimisationAgentName $env:OPTIMISATION_AGENT_NAME -OptimisationAgentVersion $env:OPTIMISATION_AGENT_VERSION `
  -ReplenishmentAgentName $env:REPLENISHMENT_AGENT_NAME -ReplenishmentAgentVersion $env:REPLENISHMENT_AGENT_VERSION `
  -Deploy
```

The helper checks that endpoint and ARM ID identify the same project. With
`-Deploy` it also runs the specialist configuration checker using
`.venv\Scripts\python.exe` (override with `-PythonExecutable` if needed).

### Reduce repeat setup

Create **one** supported Fabric IQ connection in the project's Foundry portal,
targeting the team's published Data Agent. Use a standalone browser and complete
the lab user's OAuth consent there, not in VS Code's embedded browser. Then add
these options to the deployment command above:

```powershell
  -FabricIQConnectionName '<existing-project-connection-name>' -Deploy -VerifyHosted
```

Do not specify `-Deploy` twice. The options have separate effects:

| Option | Automated work |
| --- | --- |
| `-FabricIQConnectionName` | Validates the connection belongs to this project and targets a published Data Agent, replaces only the Fabric tool in all three supplied prompt specialists, creates new versions when needed, and saves their resulting pins to azd. Preserves instructions, model and other tools. |
| `-Deploy` | Validates the pinned specialists, then deploys the hosted assistant into the existing project. |
| `-VerifyHosted` | After deployment, runs two real planning requests and deterministic multi-turn checks: proposal, MODIFY, stale approval, approval, replay, STATUS, NEW, cancellation and separate-conversation isolation. This is billed model/Fabric/hosted usage. |

Without `-FabricIQConnectionName`, existing specialists are not modified. With
it, the **named specialists** get new versions; use isolated test names for a
rehearsal. Supplying stale source versions when newer unrelated edits exist
fails instead of overwriting them. Identical already-configured latest versions
are reused. If interrupted after some versions were created, rerun with the same
inputs; successful writes are reused, not rolled back.

The hosted checker saves pass/fail and turn evidence under the ignored
`.azure/<environment>/hosted-check-<timestamp>.json` and deletes only the two
conversations it creates. It also stops only sandbox IDs returned by those test
responses, including failed responses. If a request fails before returning its
sandbox ID, inspect the test sessions separately as described below. Cleanup
errors fail the check rather than being ignored. A failed test stops the helper
and does not publish an app.

The automation deliberately does not create a guessed OAuth connector, store
user tokens, consent as another user, or submit an organization-wide app. Initial
supported connection creation, per-user consent and tenant policy approval stay
explicit. Foundry's [Microsoft 365 publishing API](https://learn.microsoft.com/azure/foundry/agents/how-to/publish-copilot-virtual-network)
can automate package/catalog submission after runtime acceptance, but publishing
as a facilitator does not install a personal app for every attendee or verify
their license, permissions or browser sign-in.

Without `-Deploy` the script configures azd and, only if requested, the specialists.
It does not run `azd provision`
or create new accounts/models. Direct code deployment uses Python 3.13; no local
Docker/ACR is required. Don't reuse the assistant name for unrelated deployments:
a new deployment creates a new version of that named agent.

For local development only, set `INVENTORY_LOCAL_DEVELOPMENT=1` and run `main.py`;
this explicitly uses the signed-in Azure CLI developer identity. Never set that
flag on the hosted service. Local testing is not a substitute for channel identity
and isolation tests.

## Tests and live release gate

```powershell
& '.\.venv\Scripts\python.exe' -m unittest discover -s tests -v
& '.\tests\Test-ParticipantDeployment.ps1'
```

The PowerShell test uses mocked CLIs; it does not certify an actual Cloud Shell
deployment.

Before committing/pushing a migration:

1. Run the actual setup notebook successfully if it changed.
2. Verify the three **Fabric IQ** specialists against real data and inspect tool
   calls. Check retail/Retail = 4, P004 Portland 8/Seattle 6 below safety stock 30,
   Outdoor Power Tools retail stock = 232, and nonexistent P999 has no rows.
3. Run the deployed assistant end to end. Confirm all three specialist stages.
4. Test MODIFY, cancellation, approval, stale revisions, duplicate approval,
   persisted state after idle/restart, and two distinct users/conversations.
5. Publish personal scope and repeat the conversation in **Teams for web and
   Microsoft 365 Copilot for web** in external InPrivate/Incognito tabs using the
   lab account, including OAuth consent. Test a user without Fabric access.
6. Record source revision/hash, agent versions, responses/traces and outstanding
   failures. API-only or mock tests do not certify Teams/M365.

Until these checks pass, this migration is **not live-certified**. Keep the branch
uncommitted/unpushed if live verification is blocked.

If planning fails while reaching Fabric, the checker records the response and
request IDs as a failure, not a completed conversation. Do not replace delegated
access with a shared facilitator token or approve a fabricated proposal.

### Fabric access through the toolbox

The assistant does **not** call the three specialist agents as nested agents.
Nested calls from a hosted agent to a prompt agent with its own Fabric IQ tool
failed live with HTTP 403 during tool enumeration, even though the same
specialist worked directly. Instead:

- Challenges 2-4 stay as written: participants author the three prompt agents
  and give each the Fabric IQ tool for the published `inventory-hack-agent`.
- The assistant reads each pinned specialist version's **instructions and model**
  and runs them itself, so participant-authored behavior is preserved. The deploy
  helper saves those definitions to `specialists.json` (git-ignored) and ships them
  with the package, so the running assistant needs no permission to read agents.
  Changing a specialist therefore requires rerunning the deploy helper.
- Fabric is reached through a Foundry **toolbox** (`inventory-fabric-iq`) created
  from the same Fabric IQ connection. The toolbox is the documented path for
  hosted agents; the platform resolves the caller from the opaque call ID.
- The helper creates the toolbox idempotently (`configure_specialists.py`), pins its
  version in `TOOLBOX_ENDPOINT`, and the assistant calls it with MCP **task mode**.
  A plain call to the Data Agent tool failed with "response completed without a
  reply"; task mode completes.

If the toolbox call fails, check in this order: Fabric capacity is running, the
caller can read the published Data Agent, the connection exists in the same
project, then the failed request ID. A role assignment, a successful direct
specialist call or a created connection record is not proof of working
delegation. The first failed hosted run is the right check, not a mock.

Authentication mode: the lab uses the existing `UserEntraToken` connection that
the OneLake Catalog creates. Per-user enforcement was verified only for the
lab owner. Before relying on it for attendees, test a second user and a user
without Fabric access. Do not create tenant apps, grant tenant consent or use a
shared token to make this pass; those are platform decisions.

For a managed OAuth connection, a created ARM record is not proof of OAuth:
verify that consent-link discovery succeeds and a real tool call succeeds.
`ConnectorNamespaceConnectionNotFound` or `TokenIsMissing` means authentication
was not established. The BYO Entra route is documented in the
[Fabric IQ authentication guide](https://learn.microsoft.com/azure/foundry/agents/how-to/tools/fabric-iq#authentication-and-security).

## Troubleshooting for coaches

| Symptom | Cause and fix |
| --- | --- |
| `Project not found` (HTTP 404) the first time the check or the playground calls `inventory-planning-assistant`, although the deploy printed `SUCCESS` | The hosted-agent endpoint can reject a project whose Foundry account **name was used and deleted earlier**, even after the account is purged. Seen on 20 Oct 2026: a re-created account with the same name failed, a redeploy did not help, and a new account name worked first time with identical code. Provision the attendee with a **new resource group and account name** instead of reusing a deleted one, and don't spend time redeploying. |
| Cloud Shell prints nothing for several minutes after `SUCCESS: Your application was deployed` | The hosted check is running 12 planning turns. A full run took under 8 minutes on 20 Oct 2026. Tell participants to wait for the `PASS: hosted multi-turn checks` line. |
| The three prompt agents show **new versions** after the deploy (for example v3, v4, v3 instead of v2, v3, v2) | Expected. The helper saves new versions that use the supplied Fabric IQ connection, keeping instructions, model and other tools. |
| A trace shows `raiPostToolAnnotations ... Error during output moderation for tool ... for general harms` in a Fabric tool result | A content-filter annotation on the Data Agent output. The run still completed with correct data in every test, so it can be ignored. |
| The proposal has only one or two lines | The model chooses how many lines to propose. Check the unit costs and quantities, not the line count. |
| Planning fails and mentions Fabric | Check in this order: the Fabric capacity is **running**, the Data Agent is **published**, the participant can read it, then the failed request ID. See [Fabric access through the toolbox](#fabric-access-through-the-toolbox). |

## Cleanup

Keep resource retention aligned with the event policy. Pause only the team's
Fabric capacity. Hosted sandboxes idle out automatically; use Foundry session
management to stop/delete test sessions when available. Do **not** run `azd down`
against this existing-project integration: it must not delete shared lab resources.
Deleting a session loses that session's approval proposal.

Use `azd ai agent sessions list --help` and `azd ai agent sessions stop --help`
for the installed extension's supported flags. Select only the test session IDs;
never stop every session in a shared project. Verify Fabric is **Paused** after
live testing even if an invocation fails. The deploy helper does not resume or
suspend capacity implicitly.

## References

- [Workflow retirement and migration](https://learn.microsoft.com/azure/foundry/agents/concepts/workflow#migration-guide)
- [Foundry hosted agents](https://learn.microsoft.com/agent-framework/hosting/foundry-hosted-agent?pivots=programming-language-python)
- [Fabric IQ migration](https://learn.microsoft.com/azure/foundry/agents/how-to/tools/fabric-iq#migrate-from-the-fabric-data-agent-tool)
- [Teams/M365 publishing](https://learn.microsoft.com/azure/foundry/agents/how-to/publish-copilot)
