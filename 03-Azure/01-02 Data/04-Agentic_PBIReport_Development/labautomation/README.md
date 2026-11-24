# Lab automation - Testing

The two hooks use the documented MicroHack platform contract. **No private file,
custom environment variable, mounted approval document or extra hook parameter is
required.** The previous `MHH_EVENT_CONFIG` dependency was a lab integration bug;
it has been removed from both hooks, not replaced with the incomplete example.

This is deployment source, not a live acceptance result. Local checks do not prove
Azure region/quota availability, successful Windows installation, tenant policy,
licenses or the complete learner journey.

## Runtime inputs and repository settings

The platform supplies authenticated, isolated Az/CLI contexts and helpers:

| Hook | Inputs |
| --- | --- |
| `shared-deploy-lab.ps1` | `SubscriptionId`, `PreferredLocation`, subscription-scoped `AllowedEntraUserIds` |
| `deploy-lab.ps1` | `DeploymentType`, `SubscriptionId`, `ResourceGroupName`, `PreferredLocation`, one participant's `AllowedEntraUserIds` |

The participant hook supports `resourcegroup` only, and uses the existing
platform-created RG. It does not authenticate, switch subscription, create users,
buy/assign licenses or grant participants capacity administration. The platform
grants subscription Reader and participant-RG Owner; this exposes shared Azure
metadata but is not access to other participants' VM credentials or Fabric data.

[lab-settings.psd1](lab-settings.psd1) holds **nonsecret implementation defaults**:
Windows Server 2022 Datacenter Gen2 (Azure license included, no Hybrid Benefit),
`Standard_D4s_v5`, 128 GB OS disk, shared Standard Bastion with two scale units,
immutable student/skill sources and explicit tool/VSIX versions and SHA256 hashes.
These are source defaults, not measured cohort, budget or performance approvals.
Review changes to this file normally; never add credentials or private identities.

The platform default in `lab-defaults.json` is **Switzerland North**
(`switzerlandnorth`), matching the hook's fallback when no preference is supplied.
Explicit platform region overrides remain supported. The shared hook tries the
supplied region order against F16 and Bastion provider metadata, then resolves
an available exact Windows image version. The chosen region and image
version are retained on the owned shared resources and reused on retries; `latest`
is not passed to ARM. VM SKU availability, quota, Azure Policy and paid-service
capacity can still reject deployment. Both hooks check `Microsoft.Fabric`,
`Microsoft.Compute` and `Microsoft.Network` before provisioning. They register a
missing provider and wait for `Registered` with a ten-minute budget and at most
120 five-second polling waits per provider. An existing `Registering` state is
waited on without another registration request. Denied or incomplete registration
stops deployment explicitly; no missing-provider error is silently ignored.
An RG's metadata location need not equal its resources' region.

The shared capacity administrator is the **deployment principal's object ID**,
read from its existing ARM token's `oid` claim without Graph lookup or token
output. Participant IDs are rejected as capacity administrators. An authorized
Fabric administrator must still arrange workspace assignment permissions and
governance; ARM ownership does not imply Fabric workspace access.

## Infrastructure and private VM access

The shared hook provisions once per subscription:

- One F16 at `rg-apbi-shared-<hash(subscription)>`.
- A shared `10.90.0.0/16` VNet, a reserved `10.90.0.0/26` Bastion subnet,
  one stable-named `/26` per supplied participant, and explicit NAT egress.
- One Standard Azure Bastion and its public HTTPS endpoint. Participants connect
  from the Azure portal using their own VM credentials. No VM has a public IP.

The participant hook provisions a private NIC, NIC-level NSG, Windows VM and OS
disk in that participant's RG, then a managed Run Command for bootstrap.
The NSG allows RDP only from the Bastion subnet and denies all other inbound
traffic, including default VNet inbound. Shared subnets are created **before**
parallel participant fan-out, avoiding concurrent shared-VNet updates.

Bastion, NAT, public endpoint IPs, traffic, VM/disks and F16 all incur costs.
Two Bastion scale units and the address-plan ceiling of 1000 identities are
**not** a supported F16 cohort size. Measure the actual cohort and concurrent
notebook/desktop load. Change the reviewed scale/address plan if necessary.
The subnet roster is fingerprinted: adding/removing participants after deployment
requires explicit migration/rebuild review, not automatic subnet renumbering.

## Bootstrap and two independently configured agent hosts

`main.bicep` embeds the local `bootstrap.ps1` into managed Run Command. There is
no separately hosted bootstrap URL, source ZIP, seven-kilobyte shell argument or
requirement for custom portable bundles. Run Command waits for completion and
treats script failure as ARM deployment failure. Its configuration uses protected
parameters; it carries no participant/cloud authentication secrets.

[student-files.json](student-files.json) lists 25 exact source files and hashes:
both sets of eight CSVs, manifest, dictionary, generator/module and five shared
brief/guidance files. They are fetched individually from immutable MicroHack
commit `679f03ec391f2b8adfac4b1fdf58878f8674c272`; coach files and the repository
archive are never downloaded. This intentionally pins the original dataset and
brief revision. Update the ref/descriptors together after publishing any source
change that should reach VMs. The selected bytes and manifest are verified.
Descriptor SHA256 values describe immutable **Git blob bytes**, not Windows
working-tree text after CRLF conversion. The VM also receives a generated
exercise README with current host and shared-resource cleanup guidance.

Tools are fetched from official release hosts and checked before use: PowerShell,
MinGit, Node, VS Code and Copilot are ZIPs; Python uses its all-user installer and
Azure CLI its all-user MSI. Redirects to release CDNs are allowed, bounded, and
still checked against the pinned final-byte digest. Extracted ZIPs reject
traversal, symbolic links, duplicate paths and excessive expansion. Tool versions
are checked after installation. Python and portable tools live under
`C:\MicroHack\tools`; Azure CLI uses its vendor's Program Files directory.

The report authoring CLI and all transitive npm dependencies use
[package.json](npm-runtime/package.json) and
[package-lock.json](npm-runtime/package-lock.json), installed with `npm ci`,
SHA512 integrity and lifecycle scripts disabled. The public Microsoft npm feed
URLs were checked anonymously; no employee feed credentials are required.

The pinned official Fabric skills archive supplies `spark-cli`,
`semantic-model-authoring`, `powerbi-report-cli` and their shared references.
These current names replace the older split authoring-skill names.
Both hosts use CLI/REST authoring tools; no consumption-only or fictitious MCP
server registration is presented as an authoring capability.

- **Copilot CLI:** the per-user initializer installs skills and common references
  into that user's `.copilot` profile, not SYSTEM's profile.
- **VS Code Agent:** separate project skills/common references are staged in
  `C:\MicroHack\student\.github`; pinned Copilot and Chat VSIX files are installed
  and their versions checked in the interactive user's VS Code profile.

Active Setup invokes `C:\MicroHack\initialize-user.ps1` on first login. Run it
manually if needed. It refuses to overwrite an unrelated existing skill profile;
an interrupted initializer retries its own marked installation. Sign in
interactively as the assigned participant, select an entitled approved model,
then verify each chosen host's skills, authoring commands and authentication.
No organizer tokens are copied and no sign-in is automated.

Both scenarios are at `C:\MicroHack\student\datasets`; briefs are at
`C:\MicroHack\student\briefs`. Open that exercise folder, not the source repository.
Run `python datasets\generate-data.py --validate` before Challenge 1.
Workspace creation/assignment remains the first learner task.

## Organizer release gates are not runtime configuration

Complete [organizer readiness](organizer-readiness.md) and the private evidence
behind [release gates](../resources/release-gates.md) before participant admission:
Fabric availability and assignment rights; enabled Power BI author service
plans/stock; Copilot seats/models; ItemCreation coverage for the four allowed
types, managed SQL endpoint and newly created workspaces; both host journeys;
VM/Bastion isolation; regional quota; measured F16 load; budget and cleanup.
No code here claims that Contributor permissions enforce allowed item types.
If enforcement is unavailable, stop admission until an explicit exception is
approved. No private approval flag is invented or silently set to true.

`Quality` remains `Testing`. The platform settings still need reviewed
`labsPerSubscription`, costs and any region overrides for the actual event. Omission is
not zero cost: platform defaults can use $25/day per participant and $0 shared,
which do not describe an F16 plus Bastion/NAT fleet. Approve actual estimates
and reimport the event settings before offering the lab to participants.
Reimport these defaults (or update the existing event's region setting) to apply
Switzerland North to an event created before this change; an already stored
region override is not replaced by the hook.
This does not relocate an existing deployment. Previously owned resources with
different configuration/region tags still require explicit migration or rebuild
review; do not delete or retag them just to bypass the ownership checks.

## Retries, ownership and diagnostics

Shared names are derived from subscription; participant names from lab version,
subscription, RG and identity. All owned resources carry configuration/ownership
tags. Empty participant RGs can be claimed while preserving platform tags;
foreign resources, configuration changes and a changed roster are rejected.
Implicit OS disks are tagged only after verifying their owning tagged VM.
No resource group recycling, destructive region fallback or automatic migration
is performed. Failed deployments are not returned as successful credentials.

A matching completed guest marker rechecks data and required tool presence.
An incomplete bootstrap retries its staging; an unmarked student directory or a
changed guest configuration blocks overwrite of learner work. A hook retry
changes Run Command's run token while preserving stable credentials.
Inspect sanitized ARM/Run Command status privately on failure. Do not enable
transcripts/debugging around credential output or serialize parameter objects.
Guest failures retain a timestamp and error message in
`C:\MicroHack\bootstrap-error.txt` for private VM-side diagnosis.

The platform invokes shared first, waits, then invokes participant hooks. No
launcher environment customization is needed. The [offline tests](../tests/README.md)
invoke both full scripts with provider-boundary doubles, no private config,
two identities, reruns and explicit failure cases. They are not live cloud proof.

## Audience packaging

`contentPreparation` in `lab-defaults.json` removes the repository-only root
README, tests, contributor guide and `.gitignore` from both published sides;
the platform excludes `labautomation` itself. ZIP exclusions are configured
separately. Students use `challenges\README.md` for Home; coaches use
`walkthrough\README.md`. Parent-README banners are disabled, download banners
retained, and both audiences share `resources\cleanup.md`.
ZIPs omit top-level files and audience lesson Markdown; keep published lessons
open beside downloaded supporting source. Local package tests model this
contract; actual import, banners and downloads still need pilot inspection.
