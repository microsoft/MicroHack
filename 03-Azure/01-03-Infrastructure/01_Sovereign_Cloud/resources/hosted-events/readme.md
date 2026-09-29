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

## Complete LocalBox preparation

The shared hook submits `localbox-*` in `rg-localbox-shared`, then waits up to six hours for ARM completion, refreshing its Console authentication while polling. It does not publish LocalBox administrator credentials. A Client VM appearing after roughly 15-20 minutes confirms only that deployment has started. Full nested Azure Local provisioning can take 4-6 hours and must still be checked separately.

1. Inspect the Azure deployment, Client bootstrap logs and Azure Local/Arc status. Resolve failures before proceeding.
2. If the Client password is unknown, an authorized event lead/coach uses the Azure VM's **Help > Reset password** to set a known password for the `arcdemo` host account, then connects to `LocalBox-Client` through Bastion. Do not expose this password through participant credentials or job logs. A host password reset does not change the nested-node Windows credentials. See [LocalBox credentials](#localbox-credentials).
3. Copy **Lab Group ObjectId** from the Console's **Credentials** tab for the preparation prompt or `-AksAdminGroupObjectId`. Confirm that intended Azure lab identities/coaches are members; see the group dependency below.
4. Follow [LocalBox preparation](../localbox/readme.md), once per shared subscription, in elevated PowerShell 7. Azure authentication uses the Client VM's managed identity; preparation constructs the nested Windows credential locally from the installed configuration without printing it. An explicit `-NodeCredential` overrides that value after a nested-account rotation.
5. Run [Pester health checks](../tests/readme.md) for LocalBox and every selected participant lab. A control-plane-only pass does not establish full readiness.
6. Complete the [participant VM readiness exercise](../localbox/manual-preparation.md#step-6-test-the-environment), including guest management, Defender and Update Manager. Subscription-wide paid-plan changes require the authorized owner and approved budget.

### Hosted MCAPS control-tag initiative

The organizer-owned [shared hook](../../labautomation/shared-deploy-lab.ps1) deploys the [hosted tag initiative](../../labautomation/infra/hosted-tag-policy.bicep) once per subscription, before LocalBox deployment and participant lab fan-out. This is specific to MCAPS governance in Microsoft-internal hosted environments. **Do not deploy it for bring-your-own-subscription or manual setup.** The Console deployment identity must be authorized to create subscription-scoped policy initiatives and assignments, as well as the lab resources.

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

Shared-hook credentials are visible to **every lab in that subscription**. Only the resource-group name and nonsecret lab-group metadata are published by this hook. LocalBox administrator credentials must be restricted to coaches/event leads. A supported Console mechanism for restricted retrieval or secret input is pending confirmation from the Console owner and is not implemented here. It is not required for the Client-reset/local-configuration workflow above. The manual deployment path keeps its existing password handling and does not require Console helpers.

**Existing deployments:** environments are reused without password rotation. Original random passwords cannot be recovered from ARM or reconstructed by rerunning this hook, but Jumpstart's installed configuration on the Client retains `SDNAdminPassword`. After gaining host access, preparation reads that value through `$env:LocalBoxConfigFile` and uses the configured domain's Administrator account for PowerShell Direct. A Client-only reset does not alter it. If the nested account has since been rotated, supply its current credential explicitly. Do not redeploy the environment merely to recover a password.

Treat the installed configuration as a secret-bearing file: do not print it, include it in screenshots or attach it to support requests. Limit Client administrator access to authorized facilitators. If its password has been exposed, coordinate rotation with the LocalBox administrator; changing only `arcdemo` is not sufficient to rotate the nested credential.

If an earlier automation version already published an administrator password, removing its output does not erase the stored Console credential. Ask the Console owner to remove the entry and coordinate credential rotation with the LocalBox administrator.

### Console group dependency

The shared hook calls the Console-supported `Get-MhhDefaultLabGroup` helper and publishes **Lab Group ObjectId**, **Lab Group GroupName** and **Lab Group DisplayName** as separate credentials. Complete the Console's Entra user/group creation lifecycle first; missing or invalid metadata stops shared deployment. The object ID is the value to supply to LocalBox preparation for AKS Entra administration.

The [platform contract](../../../../../99-MicroHack-Template/labautomation/README.md#groups-supported-values) still uses `groups` for licensing activation (`GHCPUsers`, `M365-E5-Users`), not arbitrary group creation. No new schema fields or Graph permissions are needed. The Console owns the event group, its membership and teardown; the facilitator must verify intended users/coaches and late registrations. The preparation script still prompts for the ID on the Client, where Console helpers are unavailable, and does not create groups or validate membership through Graph.

## Run and close the event

- Export Console user credentials and distribute them securely to the correct attendees/coaches. Console login credentials and Azure Temporary Access Passes (TAPs) are distinct.
- Ensure the event is **LIVE**, then select **Start Hack**. Timers are optional; coaches validate work and approve challenge advancement.
- For schedule changes, save the new times and select **Update TAPs** to refresh existing Azure access.
- Access is revoked at the scheduled end; the guide describes environment teardown approximately 15-30 minutes later. Verify completion, including the shared LocalBox resource group and the Console-owned group. Escalate retained resources instead of launching the broad manual cleanup utility.
- For forced cleanup, use both **Delete & Purge Users** and **Remove Lab Environment** in the Console lifecycle. **Retain the event record** for cost reporting.

For support, use the current program contacts/playbook supplied with Console access. Console issues go to its owner; content deployment failures go to the Sovereign Cloud content owners.