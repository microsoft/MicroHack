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

The global hook submits `localbox-*` in `rg-localbox-shared` in the published **Shared LocalBox Subscription ID**, then waits up to six hours for ARM completion, refreshing its Console authentication while polling. It does not publish LocalBox administrator credentials. A Client VM appearing after roughly 15-20 minutes confirms only that deployment has started. Full nested Azure Local provisioning can take 4-6 hours and must still be checked separately.

The subsequent preparation script took **4 hours 24 minutes 26 seconds** in the
TEST4 run reported on 25 October 2026, including reference-VM creation. This is
additional post-provisioning time, not the total event deployment duration or a
guaranteed runtime. MDE was still Pending when preparation finished. See the
[timing evidence and planning guidance](../localbox/readme.md#preparation-time);
allow time for both preparation and later assessments.

1. Inspect the Azure deployment, Client bootstrap logs and Azure Local/Arc status. Resolve failures before proceeding.
2. If the Client password is unknown, an authorized event lead/coach uses the Azure VM's **Help > Reset password** to set a known password for the `arcdemo` host account, then connects to `LocalBox-Client` through Bastion. Do not expose this password through participant credentials or job logs. A host password reset does not change the nested-node Windows credentials. See [LocalBox credentials](#localbox-credentials).
3. Copy **Lab Group ObjectId** from the Console's **Credentials** tab for the preparation prompt or `-AksAdminGroupObjectId`. Confirm that intended Azure lab identities/coaches are members; see the group dependency below.
4. Follow [LocalBox preparation](../localbox/readme.md), **once per event on the global LocalBox Client**, in elevated PowerShell 7. It creates AKS and then installs/verifies the shared MetalLB extension and reserved ARP pool. Azure authentication uses the Client VM's managed identity; preparation constructs the nested Windows credential locally from the installed configuration without printing it. An explicit `-NodeCredential` overrides that value after a nested-account rotation.
   Preparation includes `sov-ref-vm` by default; run it **the day before the event** for inspection while participant VMs onboard, or opt out with `-IncludeReferenceVm:$false`. Follow the [reference readiness checks](../localbox/readme.md#reference-readiness-and-participant-use); Console plan configuration and successful provisioning do not establish completed VM assessments. Participants must not modify this shared VM; no RBAC restrictions are added.
5. Run [Pester health checks](../tests/readme.md) for LocalBox and every selected participant lab. A control-plane-only pass does not establish full readiness.
6. Console shared setup enables and verifies **Defender for Servers Plan 2** and **Endpoint protection** on every event subscription. Complete the [Defender readiness checklist](../localbox/manual-preparation.md#defender-for-servers-readiness-organizer) and [participant VM readiness exercise](../localbox/manual-preparation.md#step-6-test-the-environment), including guest management, actual Defender onboarding and Update Manager. Verified subscription settings do not prove that a VM has completed onboarding.
7. Verify an intended participant can use Entra-authenticated `az connectedk8s proxy` and a private application port-forward from their Codespace. Participants inspect MetalLB, not install it, and never need LocalBox-Client access. This validates the lab access path, not routing to the MetalLB service VIP.

Global setup registers `Microsoft.KubernetesRuntime`, waits for registration,
resolves its tenant service-principal object ID using the Console's existing
Graph-capable identity, and records it in the shared RG tag
`microhack-k8s-runtime-object-id`. Missing registration or identity resolution
fails setup explicitly. Organizer preparation reads that nonsecret tag; it does
not require Graph permissions on the Client managed identity. This does not move
AKS or MetalLB installation into the Console hook: they remain part of the
organizer's post-provisioning preparation.

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