# Hosted-event runbook

This runbook covers the FY27 EMEA Cloud & AI Hackathons program described in the Event Lead Guide. Confirm eligibility and access with your program lead; the Console is not a general entitlement for all Microsoft events or 1:1 customer engagements. Other delivery uses [manual setup](../manual-setup/readme.md).

## Configure the event

1. Agree the Sovereign Cloud scenario with your GEO/program lead and request an Event Lead account through the program's access process.
2. Sign in to the [Hacks Console](https://emea.microhack.cloud) with the supplied account using Entra sign-in. Complete MFA/password setup. Run the [prerequisites check](https://emea.microhack.cloud/prerequisites).
3. Create a **New Hackathon** for each event iteration and select the Sovereign Cloud content pack. Use `Country-Hack type-Date-Use case` for live events and `Test-Country-Short title` for tests.
4. Set the event time zone, start slightly before attendees arrive and end with an appropriate buffer. Enable the event. Participant access is limited to its configured window.
5. Set automatic provisioning at least **24 hours before** a Sovereign event. LocalBox preparation includes a multi-hour image download. An accepted deployment is not a ready environment.
6. Set teams and participants per team before provisioning. **Teams equal labs and the lab count is locked once provisioning starts.** Add late registrants to existing teams instead.
7. Preview content and review the live estimate, including shared LocalBox costs and licensing. The guide's Sovereign budget is **USD 2,000**; obtain program-lead approval for exceptions. Normal validation uses **exactly one lab**, not a load test. Content Leads own scale testing.

When automatic provisioning is not scheduled, use the Console's **Create Users**, content-pack license defaults and **Deploy Lab Environment** lifecycle in order. Investigate failures before continuing; do not compensate by running subscription-wide manual utilities.

## One LocalBox per event

Re-import the content pack after updating it. The Console discovers
[global-event-deploy.ps1](../../labautomation/global-event-deploy.ps1) beside the
participant hook and requires `estimatedGlobalDeploymentDailyCostsUsd` to be
**greater than 5**. This pack sets it to **USD 110/day**, with the per-subscription
shared infrastructure estimate set to **0**. A missing/mismatched global signature
or a cost of 5 or less causes the Console to skip the hook and log a warning;
verify the global deployment job actually ran before continuing.

The Console runs the global hook **once per event in the lowest-GUID event
subscription**, passing all event lab-user object IDs. It completes before
`shared-deploy-lab.ps1` runs in each subscription, followed by participant
deployments. A global failure stops the event deployment. Host-region fallback
uses the preferred regions within that selected subscription; it does not choose
a different subscription if quota or SKU availability is insufficient.

The global hook deploys/reuses one `rg-localbox-shared`, including one LocalBox
Client. It publishes **Shared LocalBox Subscription ID**, **Shared LocalBox Resource
Group ID**, the group name and lab-group metadata to **every event participant**.
It grants each participant Reader and Azure Stack HCI VM Contributor on the
LocalBox resource group, plus Security Reader on the host subscription for
reference-VM security inspection. No participant Owner, host login or password is
granted by this hook. Existing shared VM/AKS access remains a workshop trust
boundary, not per-participant isolation.

### LocalBox Bastion

New LocalBox deployments use **Azure Bastion Developer**, with no hourly Bastion
charge. It supports **one browser-based connection at a time**, intended for a
coach accessing LocalBox-Client. It does not support native-client tunnels,
concurrent sessions or peered-VNet access. Spain Central and Sweden Central are
supported; check the current [SKU and region matrix](https://learn.microsoft.com/azure/bastion/bastion-sku-comparison)
before choosing another host region. ARM validation remains authoritative; the
deployer does not silently substitute a paid SKU.

The [local network module](../../labautomation/localbox-network.bicep) replaces
only the downloaded upstream network module. It preserves the LocalBox VNet,
Client subnet/NSG and NAT Gateway outbound path, but creates no dedicated Bastion
subnet, Bastion public IP or Bastion NSG. Keep this file beside
`deploy-localbox.ps1` when importing the Console package. The interactive manual
entry point delegates to the same deployer. Other Jumpstart templates and runtime
artifacts still come from the selected upstream revision.

This change applies only to **LocalBox**. Challenge 7's separate Bastion remains
**Standard** because its K3s workflow requires `az network bastion tunnel`.
Developer avoids dedicated Bastion provisioning, but neither a deployment-time
improvement nor elimination of Azure service errors is guaranteed.

Existing successful LocalBox deployments are reused without SKU changes.
Azure does not support an in-place downgrade from Basic/Standard to Developer.
The deployer rejects an existing dedicated `LocalBox-Bastion` or legacy
`AzureBastionSubnet` rather than deleting resources or rewriting that subnet.
Use a fresh event/resource group, or arrange a separate approved migration.
Re-importing this change alone will **not** repair a failed dedicated Bastion.
In particular, the failed Basic Bastion on traininglab-44 was left unchanged.

### Participant access

Participant RBAC setup reuses an existing direct Security Reader assignment on
its subscription, including the grant made by the global hook for participants
in the LocalBox host subscription. It does not recreate the same grant under a
different role-assignment ID. If an earlier run failed with
`RoleAssignmentExists` during `lab-*` deployment, re-import the corrected branch
and retry the event deployment; do not delete the global grants or LocalBox.
An assignment lookup failure stops setup rather than treating access as absent.

Participant VMs still belong in their own assigned subscription/resource group,
using the shared custom location, image, network and storage. Keep the participant
subscription separate from the LocalBox subscription when following Challenge 6.
AKS proxy connections target the **LocalBox subscription**; team namespaces remain
unique by participant subscription plus resource group.

Portal VM creation across subscriptions was successfully tested as `labuser-0027`
on 25 October 2026, using its original RG in traininglab-12 with LocalBox in
traininglab-59. The wizard defaulted to the host subscription: remind participants
to change **Subscription** to their assigned subscription before selecting their
own RG. Keep the existing single participant-RG workflow; see
[test evidence and remaining checks](../tests/readme.md#observed-test4-integration-results).

**Capacity and migration:** one instance now carries the entire event's nested
VMs, reference VM, AKS workers and service IP allocations. Validate memory, storage
and address-pool headroom for the planned event size; the cost reduction does not
increase LocalBox capacity. Use a fresh event to validate this change, including
a participant assigned to a different subscription. Existing LocalBoxes in other
subscriptions are not moved or deleted automatically. Review their dependencies
and arrange explicit cleanup separately. Keep the global environment until all
participant VMs are removed, then verify Console teardown removes it.

## Defender for Servers configuration and costs

The [global hook](../../labautomation/global-event-deploy.ps1) calls
[hosted Defender setup](../../labautomation/hosted-defender.ps1) in the host
subscription after hosted tag-policy verification and before LocalBox deployment.
The [shared hook](../../labautomation/shared-deploy-lab.ps1) also verifies these
settings on every participant subscription before lab deployment, including an
idempotent recheck of the host subscription. Setup sets
`Microsoft.Security/pricings/VirtualMachines` to `Standard` / `P2` and
`Microsoft.Security/settings/WDATP` to `enabled=true` (the **Endpoint protection**
toggle). Existing pricing extension and enforcement settings are preserved; other
Defender plans and settings are not changed. Reruns never toggle protection off.

The Console deployment identity needs permission to read/write these subscription
settings; the hosted subscription Owner identity supplies it. Participants retain
their existing roles, including Security Reader; no participant subscription Owner
or User Access Administrator role is added. Setup verifies both settings by GET,
retrying propagation up to 12 times, 10 seconds apart. Authorization/API failures
or verification timeout stop shared setup rather than report readiness. A failure
does not roll back P2 or disable protection; inspect the settings before retrying.

**P2 is a paid subscription-wide plan**, not a per-lab-RG setting. Include its
charges for covered servers during preparation and delivery in the approved event
budget, separately from the existing infrastructure estimates. Use only dedicated
hosted lab subscriptions. Deleting lab resource groups does not reset the plan or
Endpoint integration; the subscription owner must review these settings when
releasing a subscription. This hook is not part of manual/BYOS preparation.

## Complete LocalBox preparation

The global hook now remains active through nested deployment, default Sovereign
preparation, and infrastructure health checks. No organizer login, host password
reset, or manual preparation invocation is required for a greenfield hosted event.
It does not publish LocalBox administrator credentials.

The [orchestrator](../../labautomation/localbox-automation.ps1) implements:

1. Use the validated `Get-MhhDefaultLabGroup` result (also published as **Lab
   Group ObjectId**) as `AksAdminGroupObjectId`. No guest Graph lookup is needed.
2. Package the preparation script, guest runner and health tests before making
   deployment changes. A full checkout uses local resources. Console can mount
   only `labautomation`, without its sibling `resources` directory; in that case
   download the complete guest file set from the immutable commit in
   [localbox-automation-source.json](../../labautomation/localbox-automation-source.json)
   and verify every SHA256. Never mix partial local files with downloaded files
   or fall back to a moving `main` branch. A content hash identifies the package,
   which is reused in the Managed Run Command payload after ARM completion.
3. Wait for `localbox-*` ARM completion, then `localcluster-deploy`, connected
   Azure Local, a running Arc Resource Bridge, custom location and
   `hybridaksextension`. A successful Client bootstrap extension is not sufficient.
4. Run `sovereign-localbox-prepare` asynchronously on LocalBox-Client as **SYSTEM**,
   explicitly using PowerShell 7. The [guest runner](../invoke-localbox-automation.ps1)
   prepares storage, logical networks, AKS, proxy RBAC, MetalLB, the Windows
   image and the default reference VM.

   SYSTEM does not inherit the interactive administrator's tools or profile.
   Before Kubernetes health checks, the runner reuses an available `kubectl` with
   the cluster's major/minor version, or uses `az aks install-cli` to install the
   cluster's exact version in its private automation tools directory. The CLI
   also installs its bundled `kubelogin` dependency there. Only the runner and its
   child health process receive the private tools PATH; existing installations
   and the machine PATH are not changed. Retries validate and reuse this client.
5. Wait for the reference VM to be Running, Arc Connected and MDE installation
   Succeeded. Request an Update Manager assessment and require a successful,
   timestamped result. This assesses updates; it does **not** install patches.
6. Run installed upstream Jumpstart infrastructure Pester tests, then the
   Sovereign **LocalBox Full** suite. The Client retrieves a private AKS admin
   kubeconfig for infrastructure probes using its managed identity. It is not
   shared with participants and is deleted after the run.
   During the Sovereign checks, the parent runner temporarily routes only the
   private AKS API IPv4 address (`/32`) through the configured internal gateway
   (`SDNLABRoute`) and internal switch interface. The endpoint must match
   `AKSControlPlaneIP`; no default route, subnet route, firewall or persistent
   routing setting is changed. An existing matching route is reused and left
   intact; conflicting routes fail explicitly. A newly created route uses
   Windows `ActiveStore` and is removed in `finally` after the health child
   succeeds or fails. Removal is verified before readiness can pass.
   If the parent process is forcibly terminated, its `finally` cannot run;
   inspect the API host route before retrying rather than deleting existing
   routes indiscriminately. ActiveStore routes do not survive a reboot.
7. Require a zero guest exit code, matching run/content/group/scope metadata,
   nonempty passing suites without skipped/not-run tests, and matching NUnit XML
   before publishing global discovery credentials and returning to Console.
   After these validations, Console Live Output prints **Infrastructure health:
   PASSED**, actual upstream and Sovereign passed/failed/skipped/not-run counts,
   reference-VM onboarding, the timestamped update-assessment result and the
   private reports link. This summary covers shared LocalBox, not the subsequent
   participant deployment stages. Defender cloud reporting and participant
   sign-in remain explicitly listed as manual checks.
   A failed execution, unavailable report or failed validation instead prints
   **Readiness gate: FAILED - infrastructure health is NOT VERIFIED** and
   propagates the error. For a correlated terminal guest execution, Console also
   attempts to retrieve the original run's status and NUnit reports. It displays
   the run ID, execution/exit status, last guest phase, bounded error details,
   actual suite counts, and up to ten failed test names/reasons per suite.
   Missing or invalid reports are explicitly **unavailable / NOT VERIFIED**;
   mismatched run/content/group/scope metadata suppresses all report-derived
   counts. A diagnostic-download failure never replaces the original failure.
   Output strips terminal control codes, redacts common credential formats, and
   does not dump transcripts, XML stack traces or raw guest stdout. Full reports
   remain private. These summaries do not stream guest progress.
   Result downloads suppress CLI progress and discard download-command metadata;
   validation reads the downloaded JSON/XML files themselves. Native CLI stderr
   is kept separate from JSON parsing, and nonzero CLI exits still fail the gate.

For example, the original traininglab-02 MetalLB failure now renders:

```text
[LocalBox] Last guest phase: Pester; reported state: Failed.
[LocalBox] Upstream tests: 12 passed, 0 failed, 0 skipped, 0 not run.
[LocalBox] Sovereign tests: 13 passed, 1 failed, 0 skipped, 0 not run.
[LocalBox] FAILED TEST (Sovereign): ...has an in-cluster MetalLB address pool and L2 advertisement
[LocalBox] Reason: ...ipaddresspools.metallb.io "aks-pool" not found
```

That failure also prints a suggested check of the Azure-managed pool against the
Kubernetes IPAddressPool/L2Advertisement, rather than advising an environment
rebuild. Diagnostic counts never change the overall failed readiness outcome.

`Update-MhhToken` runs in the **Console process** on each poll and before Azure
operations, including result retrieval. It refreshes Console clients, not guest
credentials or job time limits. The guest uses its own managed identity and
locally resolved nested Windows credentials. Generated reference-VM credentials
remain DPAPI-protected under SYSTEM; do not copy them into Console output or
attempt to decrypt them from a different Windows account.

### Timeouts and scheduling

The initial ARM wait allows six hours, nested readiness eight hours, and the
Managed Run Command twelve hours (with five additional minutes for host polling).
These are independent ceilings, **not** expected durations. Confirm with the
Console operator that its global-job limit accommodates the intended run; token
refresh cannot prevent a platform-enforced job timeout. Subscription and
participant jobs now start **after** this global readiness gate, rather than
overlapping nested deployment.

The subsequent preparation script took **4 hours 24 minutes 26 seconds** in the
TEST4 run reported on 25 October 2026, including reference-VM creation. This is
additional post-provisioning time, not the total event deployment duration or a
guaranteed runtime. MDE was still Pending when preparation finished; the new
automation waits separately for installation and assesses updates. See the
[timing evidence and planning guidance](../localbox/readme.md#preparation-time);
allow time for both preparation and later assessments.

For a full cold-run breakdown, see the
[test-06 timing and optimization assessment](test-06-timing-analysis.md).
The 4 November 2026 run took **10 hours 30 minutes 44 seconds** from Console
start to finish, including **5 hours 24 minutes 9 seconds** of managed guest
execution. All 26 guest tests passed, but Console result retrieval failed and
downstream shared/participant stages were skipped. This is not a successful
end-to-end event-duration benchmark; the report separates measured operations,
bounded intervals and potential optimizations.

### Diagnostics and reruns

#### Automatic Azure Local validation recovery

The Console can perform **one automatic validation retry**, after a **two-minute
delay**, for the known `UpdateDeploymentSettingsDataFailed` failure in
`Download content for deployment` with `Timeout of 7200 seconds reached for
interface`. It requires exactly one failed deployment-settings operation and
recognized error details. Other validation failures, cancellation, deployment
failures, unreadable diagnostics and ambiguous state still stop the job.

The host submits the asynchronous Managed Run Command
`sovereign-localbox-validation-retry` on LocalBox-Client. Keep
[localbox-validation-retry.ps1](../../labautomation/localbox-validation-retry.ps1)
in the imported `labautomation` directory. The recovery:

1. Rechecks the original failed validation correlation after the delay.
2. Uses the Client's managed identity and existing `C:\LocalBox\azlocal.json` and
   `azlocal.parameters.json`. Nonsecret environment identifiers must match the
   failed deployment. It does not regenerate templates or credentials,
   replay bootstrap, or export the parameter file to Console.
3. Reruns `localcluster-validate` with `deploymentMode=Validate`. Only a new,
   successful validation permits submission of `localcluster-deploy` with
   `deploymentMode=Deploy`. A concurrent/manual deployment is not overwritten.
4. Removes its temporary Azure CLI profile. Console refreshes its own tokens
   while polling, reports retry status, and continues the normal cluster,
   connectivity, bridge, extension and subsequent Full health gates.

Recovery uses the **remaining eight-hour nested-readiness budget**, not a new
eight-hour window. A retry can itself take hours, and neither its submission nor
its successful exit means the nested deployment is ready. Ensure the Console
job limit accommodates the complete workflow.

The Run Command record persists: a restarted Console job monitors an existing
recovery instead of submitting another. A failed/timed-out recovery is terminal;
there is no automatic retry loop across Console restarts. Inspect its
`instanceView` and the ARM deployment operations before manual intervention.
Once a manual repair has produced a successful cluster deployment, the normal
readiness checks can proceed without rerunning that historical recovery.
Do not manually re-trigger validation/deployment while automatic recovery is
running. Cancellation or forced guest termination may prevent CLI-profile
cleanup; inspect the Client before resetting recovery state.

If an older run failed with `Could not find a part of the path
'/content/.../resources/prepare-localbox.ps1'`, it reached ARM completion but
could not package guest automation. Re-import the corrected branch (including
the source manifest) and retry; the global hook can reuse the existing LocalBox
deployment. Do not delete the environment to repair a missing content file.
Missing manifests, unavailable downloads and checksum mismatches now fail
preflight, before provisioning or changing subscription settings.

Results use a private `microhack-automation` container in the existing LocalBox
staging storage account. The Console identity and Client identity receive
**Storage Blob Data Contributor at that container only**. No SAS tokens, account
keys or participant data-plane grants are created. Storage firewall rules are
not changed. The Console logs the authenticated result URL and run ID.

Each run has a separate prefix containing `status.json`, `automation.log`,
`upstream.xml`, `health.xml` and `health.json` when those phases produced them.
Status is updated at phase boundaries. Failures retain available diagnostics and
resources; a failed upload also fails the command. Only the listed diagnostics
are uploaded, never the AKS kubeconfig or reference-VM credential file.
Prerequisite checks run inside transcript/status capture. If failure occurs
before guest Azure authentication, diagnostics remain in the private run
directory on LocalBox-Client and the error is reported through Run Command
instanceView; no Blob upload is attempted without an authenticated guest.

An organizer with Blob data access can download a run using:

```bash
az storage blob download-batch --account-name <localbox-storage-account> \
  --source microhack-automation --pattern '<run-id>/*' \
  --destination ./localbox-results --auth-mode login
```

Inspect **LocalBox-Client > Run commands > sovereign-localbox-prepare** and its
instance view if no diagnostic blobs were uploaded. Bootstrap failures before
the guest runner starts are reported there. A matching active command is
monitored without resubmission. A different active content hash/group is rejected,
not overwritten. After a completed/failed command, retrying starts a new tracked
run and reuses preparation's resource checks; it does not delete the lab or reset
existing VM passwords. Investigate failures before retrying.

When changing any packaged guest script or health test, publish those sources
first, then update the source manifest's repository, full commit SHA and file
digests together. The offline tests require the pin's digests to match the
checkout. Re-import the final content revision, not the intermediate source
commit. The feature branch currently pins the tested guest sources in the fork;
promotion upstream must retain an accessible immutable source revision.

### Remaining event validation

The automated gate verifies **infrastructure**, MDE extension installation and
an Update Manager assessment. It explicitly reports Defender cloud device
reporting and participant sign-in as `NotVerified`; these are not inferred from
an installed extension, a resource-count check or admin kubeconfig access.

- After participant deployments, run [health checks](../tests/readme.md) for each
  selected lab; they cannot run inside the earlier global stage.
- Complete the [Defender readiness checklist](../localbox/manual-preparation.md#defender-for-servers-readiness-organizer),
  including actual device reporting and recommendation/assessment visibility.
- Verify intended lab users/coaches belong to the Console group and test a real
  participant's Entra-authenticated proxy and private application port-forward.
- Preserve the [manual preparation guide](../localbox/readme.md) for BYOS and
  deliberate recovery only. Do not run it concurrently with hosted automation.

Global setup registers `Microsoft.KubernetesRuntime`, waits for registration,
resolves its tenant service-principal object ID using the Console's existing
Graph-capable identity, and records it in the shared RG tag
`microhack-k8s-runtime-object-id`. Missing registration or identity resolution
fails setup explicitly. Organizer preparation reads that nonsecret tag; it does
not require Graph permissions on the Client managed identity. The global hook
invokes AKS and MetalLB preparation inside the Client after nested readiness.

### LocalBox registration region and location policies

If LocalBox validation reports `RequestDisallowedByAzure` with
`locationineligible` ("the selected region is currently not accepting new
customers"), identify the rejected resource and its actual region before
changing the host-region selection. This is distinct from an exercise policy's
`RequestDisallowedByPolicy`. The upstream
[LocalBox template](https://github.com/microsoft/azure_arc/blob/main/azure_jumpstart_localbox/bicep/main.bicep)
passes `azureLocalInstanceLocation` to the staging storage module, whose account
name is `localbox` plus a generated suffix. In the 4 October 2026 hosted test,
this account was rejected in West Europe while the host was selected in Spain
Central. **Host-region fallback cannot resolve a rejection in the fixed
registration/staging-storage region.** The shared setup tries
the next configured preferred host region for recognized regional failures;
it does not change the Azure Local registration region or delete the shared
resource group. The CLI wrapper retains Azure's error details in the exception
so PowerShell's generic native-command exit error cannot hide them from the
fallback check. Policy denials, authorization failures, and unrecognized errors
still stop the run. If all preferred regions fail, the final error is reported;
do not assume a region is available merely because its SKU/quota checks passed.

There are three separate locations to check: the participant resource group's
metadata location, the Azure region hosting the LocalBox simulator, and the
Azure Local/custom-location registration region. The hosted
[global hook](../../labautomation/global-event-deploy.ps1) explicitly passes
`AzureLocalInstanceLocation = australiaeast`; the
[manual deployment](../manual-setup/localbox/deploy-localbox.ps1) defaults to
`australiaeast`. Host-region fallback does not change that registration parameter.
The hosted deployer's default also matches Australia East. This changes registration
and staging storage for fresh deployments, not the Azure host-region selection. Inspect the deployed
custom location's **JSON View** for its actual `location`.

Azure Local VM management resources use the custom location's region even when
participants create them in a resource group whose location differs. Policy
permission on the shared LocalBox group therefore does not establish permission
to create the participant resources. Before the event, validate the
[Challenge 6 VM creation flow](../../walkthrough/challenge-06/solution-06.md#23-review-and-create)
in the designated test participant group, not only in the shared group.

For a policy denial, collect the exact assignment/definition IDs and rejected
resource type/location. First check whether a participant left their Challenge 1
location assignment or bonus initiative enforcing; those exercise assignments
should be **DoNotEnforce**. For an inherited or organizer-owned denial, ask the
policy owner to review the approved locations or an appropriately scoped
exception. Do not disable unrelated policies or automatically broaden the
subscription allowlist. The hosted control tags below do not override arbitrary
location-deny policies.

The lab returns to Australia East after this West Europe rejection; this is
not evidence that West Europe is universally unavailable for Azure Local.
[Service region support](https://learn.microsoft.com/azure/azure-local/concepts/system-requirements-23h2#azure-requirements)
does not guarantee subscription eligibility for every dependent resource.
Challenge 1 retains its four European regions and adds Australia East as an
explicit **lab-only exception**, not a European data-residency recommendation.
Earlier assignments must be updated by their owners; inherited policies may
still deny the region, and control tags do not bypass them. Existing Azure
assignments and resources are not updated or relocated automatically. Validate
the next event using a fresh deployment and the participant VM exercise.
Existing-environment cleanup is a separate organizer action.

### Hosted MCAPS control-tag initiative

The organizer-owned [global hook](../../labautomation/global-event-deploy.ps1) deploys and verifies the [hosted tag initiative](../../labautomation/infra/hosted-tag-policy.bicep) before LocalBox deployment. The [shared hook](../../labautomation/shared-deploy-lab.ps1) deploys/verifies the same initiative on every participant subscription before participant lab fan-out; rechecking the host subscription is idempotent. This is specific to MCAPS governance in Microsoft-internal hosted environments. **Do not deploy it for bring-your-own-subscription or manual setup.** The Console deployment identity must be authorized to create subscription-scoped policy initiatives and assignments, as well as the lab resources.

The initiative `sovereign-hosted-control-tags` and assignment `sov-hosted-control-tags` use four built-in **modify** policies:

| Target | Tag | Required value |
|--------|-----|----------------|
| Taggable resources | `SecurityControl` | `Ignore` |
| Taggable resources | `CostControl` | `Ignore` |
| Resource groups | `SecurityControl` | `Ignore` |
| Resource groups | `CostControl` | `Ignore` |

The policies add or replace only these tags during resource creation or update, preserving unrelated tags. This also covers participant-created resources such as the Challenge 2 Key Vault, without requiring participants to add hosted-only tags. Resource-group tags are not automatically inherited; the initiative applies the resource tags explicitly. Non-taggable resource types are outside its scope. The Challenge 1 `DataClassification` policy exercise is unchanged.

Assignment creation alone does not prove propagation. [Setup](../../labautomation/hosted-tag-policy.ps1) writes a temporary `rg-sov-tag-check-*` resource group and an unattached NSG without either control tag, then reads both back to verify that the policies added both `Ignore` values and preserved an unrelated tag. It retries up to 30 times, 10 seconds apart, and removes only its temporary group in a `finally` block. Deployment, permission, verification timeout, or cleanup failures stop shared setup instead of proceeding with an unprotected lab.

This setup targets newly provisioned test/event environments. Azure requires a system-assigned managed identity on the **modify** assignment, even when no remediation is planned. The assignment creates that identity in the deployment location but grants it no remediation RBAC and creates no remediation tasks. Request-time tag modification does not use the assignment identity to update existing resources. See [built-in tag policies](https://learn.microsoft.com/azure/azure-resource-manager/management/tag-policies) and [modify evaluation](https://learn.microsoft.com/azure/governance/policy/concepts/effect-modify#modify-evaluation).

The tags request exemptions from hosted governance automation; they are not Azure Policy exemption resources and do not disable Defender or other Azure security services. The readiness check verifies Azure tags, not completion of downstream MCAPS processing. Confirm hosted governance honors the tags and its exemption lifetime with the platform owner.

### Automatic shutdown

The initiative applies `CostControl=Ignore` to new or updated taggable resources and resource groups throughout the dedicated hosted subscription, including resources created by participants later in the workshop. Existing explicit deployment tags remain in place. This requests exemption from hosted cost-control shutdown automation so LocalBox and the other lab VMs remain running during preparation and delivery.

Verify that the hosted governance system honors the tag. It does not disable independent VM shutdown schedules, restart already stopped VMs or prevent the Console's scheduled teardown. Keep monitoring costs and retain the event end time and cleanup process.

### LocalBox credentials

For new hosted deployments, the wrapper uses `New-MhhStablePassword -Purpose 'localbox-admin-v1' -Length 24`. The same Console scope and purpose yield the same password on retries. The password is passed as a secure template parameter, never added to tags, deployment outputs, log messages or `HackboxCredential` outputs. Do not change the password purpose or length for an existing event.

Global-hook credentials are visible to **every lab in the event**. Only the LocalBox subscription ID, resource-group name/ID and nonsecret lab-group metadata are published by this hook. LocalBox administrator credentials must be restricted to coaches/event leads. A supported Console mechanism for restricted retrieval or secret input is pending confirmation from the Console owner and is not implemented here. It is not required for the Client-reset/local-configuration workflow above. The manual deployment path keeps its existing password handling and does not require Console helpers.

**Existing deployments:** environments are reused without password rotation. Original random passwords cannot be recovered from ARM or reconstructed by rerunning this hook, but Jumpstart's installed configuration on the Client retains `SDNAdminPassword`. After gaining host access, preparation reads that value through `$env:LocalBoxConfigFile` and uses the configured domain's Administrator account for PowerShell Direct. A Client-only reset does not alter it. If the nested account has since been rotated, supply its current credential explicitly. Do not redeploy the environment merely to recover a password.

Treat the installed configuration as a secret-bearing file: do not print it, include it in screenshots or attach it to support requests. Limit Client administrator access to authorized facilitators. If its password has been exposed, coordinate rotation with the LocalBox administrator; changing only `arcdemo` is not sufficient to rotate the nested credential.

If an earlier automation version already published an administrator password, removing its output does not erase the stored Console credential. Ask the Console owner to remove the entry and coordinate credential rotation with the LocalBox administrator.

### Console group dependency

The global hook calls the Console-supported `Get-MhhDefaultLabGroup` helper and publishes **Lab Group ObjectId**, **Lab Group GroupName** and **Lab Group DisplayName** as separate credentials to the entire event. Complete the Console's Entra user/group creation lifecycle first; missing or invalid metadata stops global deployment. The object ID is the value to supply to LocalBox preparation for AKS Entra administration.

The [platform contract](../../../../../99-MicroHack-Template/labautomation/README.md#groups-supported-values) still uses `groups` for licensing activation (`GHCPUsers`, `M365-E5-Users`), not arbitrary group creation. No new schema fields or Graph permissions are needed. The Console owns the event group, its membership and teardown; the facilitator must verify intended users/coaches and late registrations. The preparation script still prompts for the ID on the Client, where Console helpers are unavailable, and does not create groups or validate membership through Graph.

## Run and close the event

- Export Console user credentials and distribute them securely to the correct attendees/coaches. Console login credentials and Azure Temporary Access Passes (TAPs) are distinct.
- Ensure the event is **LIVE**, then select **Start Hack**. Timers are optional; coaches validate work and approve challenge advancement.
- For schedule changes, save the new times and select **Update TAPs** to refresh existing Azure access.
- Access is revoked at the scheduled end; the guide describes environment teardown approximately 15-30 minutes later. Verify completion, including the shared LocalBox resource group and the Console-owned group. Escalate retained resources instead of launching the broad manual cleanup utility.
- For forced cleanup, use both **Delete & Purge Users** and **Remove Lab Environment** in the Console lifecycle. **Retain the event record** for cost reporting.

For support, use the current program contacts/playbook supplied with Console access. Console issues go to its owner; content deployment failures go to the Sovereign Cloud content owners.