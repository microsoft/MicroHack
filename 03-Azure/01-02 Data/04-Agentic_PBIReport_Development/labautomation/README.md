# Lab automation — Testing; event launch blocked

This is **public source, not a deployment authorization or live acceptance
result**. No OS/image/size/region/license combination, paid tool package, tenant
policy coverage, host journey, cohort size or cost has been tested by this
implementation. The deliberately incomplete
[event example](event-config.example.json) cannot pass validation.

## Audience packaging

`lab-defaults.json` uses the template's supported `contentPreparation` rules.
The repository root README remains the full source index, but is removed from
both prepared published sides because it links to both audiences and organizer
source. Student pages use `challenges\README.md` as Home; coach pages use
`walkthrough\README.md`. Default parent-README banners are disabled; the platform
download banners remain enabled. No audience page links to removed automation
or the opposite lesson tree. Both audiences share `resources\cleanup.md`.

Repository tests, `CONTRIBUTING.md` and `.gitignore` are explicitly removed from
published sides and excluded separately from both ZIPs: platform page removals
do not configure ZIP exclusions. The platform also removes `labautomation` from
both sides, `walkthrough` from students, and `challenges` from coaches. Its ZIPs
omit top-level files and audience lesson Markdown; keep the published pages open
beside downloaded source. Datasets, dictionary and briefs stay available.

The local package regression tests model these documented rules, build/read both
representative ZIPs in OS temp, and check published/download link targets and
audience contents. This is not an execution of the platform importer or a live
acceptance result. The actual platform import/banners still need pilot inspection.
Use [organizer readiness](organizer-readiness.md) to prepare/pin/install the hosts;
participant readiness is a separate verification-only checklist.

## Boundaries and platform contracts

* `shared-deploy-lab.ps1(SubscriptionId, PreferredLocation, AllowedEntraUserIds)`
  runs once per subscription before participant fan-out. It converges **one F16**
  into a dedicated, deterministic shared RG. A pre-existing different capacity
  blocks this bounded dedicated-subscription implementation. No shared password,
  workspace, data agent, SQL MI, mirroring, pipeline or participant capacity-admin
  grant is created.
* `deploy-lab.ps1(DeploymentType, SubscriptionId, ResourceGroupName,
  PreferredLocation, AllowedEntraUserIds)` supports **resourcegroup only** and
  exactly one approved participant. Other platform signature values fail explicitly.
  It deploys one Windows VM, OS disk, isolated VNet/subnet, restrictive NSG, NIC,
  explicit NAT egress/public IP and optional source-restricted public RDP IP.
  `PrivateRdp` needs a separately approved reachable private access path; this
  template does not invent VPN/peering/Bastion. VNet ranges overlap intentionally
  across isolated labs; do not peer them without a reviewed address plan.
* Platform prerequisites remain in force: isolated authenticated Az/CLI contexts,
  helper injection, pre-created participant RG and identity. The inherited
  `resourcegroup` contract grants **subscription Reader plus participant RG
  Owner**. That is not universal least privilege: Owner can change Azure RBAC
  within its RG; subscription Reader exposes shared Azure metadata. It grants no
  right to another VM's password or Fabric workspace. Organizers/platform
  administrators retain elevated access. Test effective roles and isolation.
* Separate participant identities and platform-keyed
  `New-MhhStablePassword -Purpose apbi-vm-admin` scope prevent shared passwords.
  `Get-MhhStableHash` names are identifiers, not credentials.
  Passwords enter ARM only as a SecureString/`@secure()` parameter, and appear
  only in the participant's `HackboxCredential` after success. No password is in
  Bicep outputs, shared outputs, CLI arguments, config or files.
* Participants **create and assign their own Fabric workspace with Copilot in
  Challenge 1**. There is no workspace pre-provisioner. Manual experimentation
  with allowed item types remains permitted. Capacity access is not workspace
  access, and Azure RBAC is not Fabric authorization.

## Mandatory administrator preflight (private evidence)

Before any hook, approve all fields against
[event-config.schema.json](event-config.schema.json). Copy the example to a
private absolute path **outside the repository**, populate it, set
`MHH_EVENT_CONFIG` in both shared/participant worker environments, and keep it
private. It contains identities, source commit/hash and private evidence links,
not tokens. Never publish a filled config or an asset URL containing a SAS/token.
Evidence booleans are **administrator attestations**, not automated policy,
licensing or live-acceptance verification. Do not mark one verified without
recorded evidence for the actual event scope.

1. **Tenant/capacity permissions:** tenant admin verifies Fabric is enabled,
   workspace creation and required workloads are permitted, and participant
   identities can assign newly created workspaces to the designated F16 through
   supported capacity/workspace permissions. Capacity admin configures supported
   assignment/contributor access in the event tenant; these hooks intentionally
   make no unverified Fabric permission API calls. Only verified organizer
   administrator object IDs belong in `capacityAdministrators`; participants
   are rejected there. Document who is responsible for both permission planes.
2. **FR-10 item creation:** the official
   [ItemCreation policy](https://learn.microsoft.com/en-us/fabric/governance/fabric-policies-item-creation)
   supports an Advanced Allow rule on `item.type` with `AnyOf` containing exactly
   `Lakehouse`, `Notebook`, `SemanticModel`, `Report`. No matching allow rule
   means implicit denial for operations the policy covers; another active rule
   can widen access. Capacity/tenant administrators must configure and inspect
   actual policy scope and verify positive/negative creation tests through each
   supported portal/API/CLI route. Verify automatic Lakehouse SQL analytics
   endpoint behavior **separately**, and verify enforcement for **newly created
   workspaces** assigned during Challenge 1. Do not assert endpoint exemption,
   universal coverage or a policy API this code has not verified. Roles and
   Copilot instructions are not substitutes.
   Missing policy availability, permission setup, endpoint evidence or new-
   workspace coverage is a **launch blocker**. If configuring policy requires an
   existing capacity, an authorized administrator must stage the target capacity
   in a separate preparation phase, apply/validate policy, and establish the
   ownership/config tags described below before approving the hooks. The hooks
   do not bypass the gate to deploy an ungoverned event. No policy mutation is
   implemented or enforcement claimed.
3. **Entitlements:** `GHCPUsers` and `M365-E5-Users` request platform feature
   activation; they are not proof of available seats, enabled service plans or
   successful provisioning. License administrator verifies actual E5/Power BI
   Pro enabled service plans, available stock, usage location and effective
   author entitlement for **each participant**. GitHub organization admin verifies
   Copilot seat, approved models and organization policies. F16 supplies compute,
   **not an authoring license**; F16 is below F64, so also verify consumer licensing
   for optional RLS exercises. No license assignment/purchase is performed here.
4. **Azure:** verify approved subscription, provider registration
   (`Microsoft.Fabric`, `Microsoft.Compute`, `Microsoft.Network`), F16/VM quotas,
   exact Windows image availability, image terms and OS license rights, disk
   size, VM size, regional availability and network/download allowlists.
   `licenseType=None` omits Azure Hybrid Benefit; `Windows_Client` and
   `Windows_Server` require separately verified eligible rights. Nothing here
   claims that a hypothetical image/size/license combination works. No automatic
   provider registration, capacity SKU escalation or destructive region fallback.
5. **Access/isolation:** approve `RestrictedPublicRdp` or `PrivateRdp`; each
   participant supplies an explicit approved IPv4 `/24`–`/32` source CIDR.
   NSG denies all other inbound traffic, including default VNet inbound.
   Validate actual reachability, outbound HTTPS/DNS, Windows firewall/RDP and
   cross-participant denial. The source-range bound is intentional; larger ranges
   need a design change rather than `0.0.0.0/0`.
6. **Both hosts:** validate a complete journey separately in Copilot CLI and
   VS Code Agent with pinned tools, skills, MCP definitions and approved models.
   Record actual versions, source refs, schemas, extension versions and host
   paths privately. CLI installation is not proof of VS Code configuration.
7. **Measured envelope and budget:** record measured participants per
   subscription/concurrent notebooks, dated prices, retention, shared/per-user
   daily estimates, budget and approver. Include VM, disk, IPs, NAT gateway/data,
   F16 running hours, storage/egress and license/group surcharges. No cohort size
   or price is inferred here. The config checks base infrastructure forecast
   against budget; administrators must include all other costs in their approval.

### Critical platform default warning

`lab-defaults.json` intentionally omits unconfirmed `labsPerSubscription`,
`preferredLocation`, `estimatedDailyCostsUsd` and
`estimatedSharedDeploymentDailyCostsUsd`. **Omission does not mean zero or safe
defaults**: the platform can pack an unapproved cohort/use a default region,
defaults per-user cost to **$25/day** (also when below $1), and shared cost to
**$0/day**. That would materially understate an F16 plus NAT/IP fleet.
**Do not launch/import for event delivery with those forecasts.** Set reviewed
event-specific platform values equal to the private config before delivery;
`platformDefaultsAligned` must link evidence of that alignment. Reimport as
required by the platform. This public pack stays Testing until independently
validated and approved. The hook rejects unset/invalid config before Azure
context lookup; source checks are not a way to bypass platform UI forecasts.

## Pinned assets and bootstrap

All tools are approved **portable ZIP packages**, including dependencies, from
explicit public HTTPS URLs with SHA-256 and exact versions. No `latest`, floating
image, blind package-manager install, baked obsolete Node 18 or authentication
secret is supplied. Approved organizers must provide/test portable Git, Node
(22+), Python, Azure CLI, Copilot CLI and VS Code packages. An archive hash plus
the tool's `--version` check is required, not just a filename. Build a reviewed
portable bundle if the vendor does not ship a usable ZIP; its supply chain and
license remain a launch prerequisite, not a claimed tested configuration.
VS Code's Copilot/Chat extensions and any other runtime/plugin dependencies must
be included in and tested with the approved VS Code portable bundle. No automatic
extension-marketplace download is invoked by bootstrap.

1. Publish/review an **immutable source commit** through the normal contribution
   lifecycle outside this implementation task. Privately record its 40-character
   commit in `source.ref`, and SHA-256 of the source archive and `bootstrap.ps1`.
   Both source and bootstrap URLs must include that ref. `bootstrap.uri` must
   resolve directly to `bootstrap.ps1`; tools/source must be direct nonredirecting
   downloads (e.g. direct archive host), without query credentials. These hooks
   do not publish anything.
2. `source.root` is the relative archive root down to this MicroHack. Map
   `source.banking` and `.insurance` to the two scenario folders outside
   `labautomation`, `.manifest` to the datasets manifest, `.dictionary` to
   `datasets\dictionary.md`, `.generator` and
   `.generatorCli` to `datasets\generate_data.py` and `datasets\generate-data.py`,
   and `.briefs` to the
   **student-only** brief tree. Those are intentionally empty in the example
   until the final archive layout is pinned. Both scenario briefs link to the
   separately staged dictionary for grains/keys and KPI definitions. The reproducible generator and
   its CLI wrapper are staged alongside the manifest, not treated as coach solutions.
   No assumption is made that labautomation's sibling folders are mounted on a VM.
3. Map host payloads relative to `source.root`: separate CLI skills directory and
   `mcp-config.json` (`mcpServers` root), separate VS Code skills directory and
   `mcp.json` (`servers` root). Supply tested, secret-free, host-specific configs
   using **absolute VM executable paths** under `C:\MicroHack\tools` for stdio
   servers; pin any server dependencies in the approved bundles. Never use
   unpinned `npx`/`uvx` downloads. Config shape validation here is not an MCP
   connection test; preflight must test actual server startup and required tools.
4. Azure Custom Script Extension downloads bootstrap explicitly; its checksum is
   checked **before execution**. Bootstrap independently downloads/checks the
   source and tool ZIPs, checks archive traversal/symlinks/duplicate entries and
   expansion bounds, and extracts **only** the allowlisted student source paths.
   Any staged `coach`, `solution(s)` or `walkthrough` path is rejected.
   Both scenarios are staged to `C:\MicroHack\student\datasets`, the required
   dictionary to `C:\MicroHack\student\datasets\dictionary.md`, and briefs to
   `C:\MicroHack\student\briefs`. The dictionary is explicitly included in archive
   extraction and final copying, so both briefs' `../datasets/dictionary.md`
   links resolve without downloading another asset. Every manifest table's CSV bytes/SHA-256 must
   match before success. The source archive may contain coach files, but they are never extracted to
   disk or copied to student output; the downloaded archive is removed on success.
5. Tools live in `C:\MicroHack\tools\<name>` and their executable directories
   enter machine PATH. A logon initializer copies CLI skills and MCP config to
   `%USERPROFILE%\.copilot\skills` and `.copilot\mcp-config.json`, never SYSTEM's
   profile. VS Code uses `C:\MicroHack\student\.github\skills` and
   `.vscode\mcp.json` independently. Sign in interactively as the designated
   participant, run `C:\MicroHack\initialize-user.ps1` if Active Setup did not
   execute, open the student folder in the approved VS Code portable host and
   verify its skills/MCP registration. Approve/sign in to each host manually
   using permitted interactive flows. Hooks never call `az login`, request
   tokens, log into GitHub/Fabric, embed secrets or reuse organizer auth.

## Run (only after separately authorized preflight)

PowerShell 7+ and platform Az modules/helpers are required on the runner.
The VM bootstrap itself targets Windows PowerShell 5.1; it installs nothing on
the runner. The platform supplies its contexts; do not replace them with a
developer's cached login. Both hook processes need the same private config path.

```powershell
# Illustrative invocation only; these variables come from approved platform context.
$env:MHH_EVENT_CONFIG = $privateAbsoluteConfigPath
. .\automation-common.ps1
$config = Read-LabEventConfiguration
# Platform invokes shared once per subscription and waits for completion:
.\shared-deploy-lab.ps1 -SubscriptionId $subscriptionId `
    -PreferredLocation @($config.region) -AllowedEntraUserIds $subscriptionParticipantIds
# Platform invokes the participant hook in that participant's isolated process:
.\deploy-lab.ps1 -DeploymentType resourcegroup -SubscriptionId $subscriptionId `
    -ResourceGroupName $participantResourceGroup -PreferredLocation @($config.region) `
    -AllowedEntraUserIds @($participantObjectId)
```

Never run hooks under a transcript/debug/verbose capture that could record
credentials. Never serialize the returned deployment object or
`TemplateParameterObject`. Azure exceptions are replaced with stage-only errors,
not echoed provider bodies; inspect detailed Azure deployment failures privately
and redact before sharing. Azure CLI is not used to send passwords on argv.
Only participant-scoped `HackboxCredential` streams may carry the VM credential.
No authenticated API or live deployment is part of the offline test command.

## Ownership, idempotency and recovery

* Shared names: `rg-apbi-shared-<platform hash(subscription,12)>` and
  `apbi<same hash>` for the F16. Names do not change between events: a different
  `LabEvent` tag **blocks reuse**, not another F16. Participant names use
  `hash(eventId,subscription,RG,participant,12)`; no private identity is in a name.
  The platform serializes the shared hook once per subscription. Do not invoke
  concurrent independent shared runs outside that contract.
* RG and resources carry `LabEvent`, `LabOwner`, `LabComponent`, `LabConfig`.
  Config fingerprints prevent silently redeploying a different image, host
  payload, toolset or access setup. Shared fingerprint uses region/admin list.
  Only an **empty** platform-created participant RG may be claimed. Other
  unowned/mismatched RGs or resources cause explicit collision errors.
  Azure-created OS disks are tagged only after ARM `managedBy` confirms the
  exactly named, tagged participant VM. An unattached/orphan disk is never
  adopted; an administrator must investigate it.
* Incremental ARM deployments use fixed deployment/resource names; no role
  assignments or duplicate workspaces accumulate. There is no RG recycle,
  automatic migration, deletion fallback or success-after-catch path.
* REST helper supports ARM-only same-subscription polling, explicit failed/
  cancelled states, throttling and `Retry-After` seconds/HTTP dates. It stops
  after 120 requests or a 900-second polling deadline by default, refusing a
  delay beyond that deadline. No arbitrary polling host or invented Fabric
  policy endpoint is trusted.
* After an interrupted run, inspect private ARM deployment/extension states
  first. If tags, scope and approved config still match, rerun the same hook.
  Stable passwords remain valid. ARM errors, entitlement failures, untagged
  resources, orphan disks and config drift are **not** retryable success.
  Restore verified original tags/config or explicitly remove/rebuild only the
  owned empty lab after approval; do not simply retag unknown resources.
* Bootstrap retries rebuild only its own staging. A completed matching marker
  rechecks CSV manifests and tool presence, without overwriting participant work.
  An explicit hook retry changes the extension's force-update token so a failed
  extension can actually execute again; it does not change the pinned payload.
  A changed config or an unmarked student directory blocks bootstrap: preserve
  work and inspect/rebuild privately. A changed tool/image is a reviewed rebuild,
  not an automatic in-place upgrade.
* Fresh capacity policy preparation may require staging `shared.bicep` first
  under separate authorization. Compute the shared hash and canonical fingerprint
  with the supplied helpers and apply exactly the expected tags before hook
  adoption; never tag/adopt unrelated resources. Attest policy coverage only
  after the target policy is actually installed and tested.

## Cost control and cleanup ownership

No automatic schedule or deletion is silently installed. Before launch assign:

| Owner | Explicit responsibility |
| --- | --- |
| Participant/coaches | Save only permitted source/work; shut down/deallocate own VM when instructed. Guest shutdown is not deallocation proof. |
| Azure organizer | Approved retention/shutdown schedule, VM deallocation verification, NAT/IP/disk charges, subscription budget/alerts; delete only tagged participant RGs after checking ownership and saving work. |
| Fabric capacity admin | Pause/resume the exact shared F16 outside active exercises, check paused/resumed state; pause is not deletion and storage/other charges can remain. Delete shared capacity/RG only after all lab workspaces are removed/unassigned as appropriate. |
| Workspace owner/Fabric admin | Inventory, export permitted artifacts, delete each participant-created Fabric workspace and check retention/recovery behavior. Azure RG deletion does **not** delete those workspaces. |
| Tenant/GitHub/license admin | Revoke event access and reclaim seats/plans per approved lifecycle; no license/group cleanup is performed by these scripts. |
| Platform operator | Remove per-lab dashboard credentials, private configs and logs under approved retention. Review orphan resources and elevated platform grants. |

Never delete by a broad resource name prefix alone. Compare subscription, RG,
ownership tags and resource inventory. Do not delete the shared RG from the
participant hook, or a participant RG from the shared hook. Document actual
cleanup evidence and residual costs privately.

## Offline validation versus live acceptance

From repository root:

```powershell
& '.\03-Azure\01-02 Data\04-Agentic_PBIReport_Development\tests\test_automation.ps1'
az bicep build --file '.\03-Azure\01-02 Data\04-Agentic_PBIReport_Development\labautomation\main.bicep' --stdout
az bicep build --file '.\03-Azure\01-02 Data\04-Agentic_PBIReport_Development\labautomation\shared.bicep' --stdout
```

These are local parse/config/helper/template checks only, independent of Azure
credentials. The full PowerShell suite creates a unique
`MicroHack-automation-<GUID>` directory under the OS temporary directory, refuses
an OS temp root inside the repository, and removes only that directory in
`finally`. Synthetic configuration fixtures, ZIPs, extracted trees and final-copy
fixtures stay there; the suite writes no scratch or evidence into the repository
and never modifies `MHH_EVENT_CONFIG` or a user-owned private event config.
Its filesystem regression exercises the production source allowlist, actual ZIP
extraction and production final-copy helper, including both staged brief links
to the dataset dictionary and exclusion of coach content.

On runners where filesystem-writing tests cannot be executed, add
`-SkipFileSystem` to run a read-only subset. Its output explicitly marks the
filesystem regressions skipped; this subset is **not** evidence that the actual
archive/final-copy regression passed. No test output is persisted automatically.

Do not infer AC-03/07/08/09/10/11/12 passed: a separately authorized
disposable live environment and independent validator must demonstrate two-user
provision/retry/recovery, actual extension/bootstrap/tool execution, checksum-valid
VM datasets, both host journeys, enabled licenses, policy/endpoint/new-workspace
coverage, isolation, measured concurrency, cost and teardown. No such live
evidence is shipped here.
