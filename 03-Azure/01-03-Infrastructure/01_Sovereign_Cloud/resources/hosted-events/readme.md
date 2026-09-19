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

The shared hook submits `localbox-*` asynchronously in `rg-localbox-shared`. A Client VM appearing after roughly 15-20 minutes confirms only that deployment has started. Full nested Azure Local provisioning can take 4-6 hours.

1. Inspect the Azure deployment, Client bootstrap logs and Azure Local/Arc status. Resolve failures before proceeding.
2. Connect to `LocalBox-Client` through its Bastion. If needed, an authorized facilitator uses **Help > Reset password** to set a known password for the `arcdemo` host account. Resetting the host password does not change the nested-node Windows credentials.
3. Obtain the AKS admin-group object ID and confirm that intended Azure lab identities/coaches are members. See the group dependency below.
4. Follow [LocalBox preparation](../localbox/readme.md), once per shared subscription. Azure authentication uses the Client VM's managed identity; nested Windows storage operations require their own credentials.
5. Run [Pester health checks](../tests/readme.md) for LocalBox and every selected participant lab. A control-plane-only pass does not establish full readiness.
6. Complete the [participant VM readiness exercise](../localbox/manual-preparation.md#step-6-test-the-environment), including guest management, Defender and Update Manager. Subscription-wide paid-plan changes require the authorized owner and approved budget.

### Policy failures

The hosted wrapper applies a temporary, resource-group-scoped `SecurityControl=Ignore` exemption for Azure Local validation. It expires under hosted governance automation after 14 days. Its tag alone does not prove that policy processing is complete, and it does not undo earlier policy changes. Ask the content/platform owner to verify the exemption and repair the validation storage/Key Vault settings if provisioning was already affected. The preparation script does not disable policy, change those security settings or renew exemptions.

### Automatic shutdown

Deployment automation also applies `CostControl=Ignore` to the LocalBox resource group and its deployed resources, and to the participant lab resource groups, resources and Azure AKS node pools. This requests exemption from hosted cost-control shutdown automation so LocalBox and the other lab VMs remain running during preparation and delivery. Resource-group tags are not inherited, so the resources are tagged explicitly. Re-running shared preparation also merges the tag onto an existing `LocalBox-Client` VM when reusing its deployment; participant resources receive it on their next deployment.

Verify that the hosted governance system honors the tag. It does not disable independent VM shutdown schedules, restart already stopped VMs or prevent the Console's scheduled teardown. Keep monitoring costs and retain the event end time and cleanup process.

### Console group dependency

The [platform contract](../../../../../99-MicroHack-Template/labautomation/README.md#groups-supported-values) currently documents `groups` as licensing activation (`GHCPUsers`, `M365-E5-Users`), not arbitrary group creation. Do not add an invented group name or schema field.

The Console owner must provide the supported mechanism to create/reuse a security group per shared LocalBox scope, maintain intended temporary Azure users/coaches and late registrations, expose its object ID, and remove the group at teardown. If the supported hook returns the ID, it can publish a non-reserved `LocalBox AKS Admin Group ID` credential. Until that contract is available, obtain the ID through the Console owner. The preparation script prompts for it but does not create groups, query Graph or grant directory privileges.

## Run and close the event

- Export Console user credentials and distribute them securely to the correct attendees/coaches. Console login credentials and Azure Temporary Access Passes (TAPs) are distinct.
- Ensure the event is **LIVE**, then select **Start Hack**. Timers are optional; coaches validate work and approve challenge advancement.
- For schedule changes, save the new times and select **Update TAPs** to refresh existing Azure access.
- Access is revoked at the scheduled end; the guide describes environment teardown approximately 15-30 minutes later. Verify completion, including the shared LocalBox resource group and the Console-owned group. Escalate retained resources instead of launching the broad manual cleanup utility.
- For forced cleanup, use both **Delete & Purge Users** and **Remove Lab Environment** in the Console lifecycle. **Retain the event record** for cost reporting.

For support, use the current program contacts/playbook supplied with Console access. Console issues go to its owner; content deployment failures go to the Sovereign Cloud content owners.