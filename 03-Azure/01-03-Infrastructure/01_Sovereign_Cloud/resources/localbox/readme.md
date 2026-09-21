# LocalBox post-provisioning preparation

Run [prepare-localbox.ps1](../prepare-localbox.ps1) **inside LocalBox-Client**, after Jumpstart has finished deploying the nested Azure Local cluster. This is common to hosted and manual delivery. It does not deploy a new LocalBox or replace the existing Azure AKS/K3s labs.

## Prerequisites

- Elevated PowerShell 7 on `LocalBox-Client` and an installed Azure CLI. Preparation automatically installs missing `stack-hci-vm`, `customlocation` and `aksarc` extensions, including during `-WhatIf`, verifies their versions and leaves existing versions unchanged. Internet access to the extension downloads is required; installation failure stops preparation before infrastructure changes. Record the versions printed by the script for your event.
- Extensions are installed in your persistent CLI extension directory (`AZURE_EXTENSION_DIR`, if set), not the temporary authentication profile. The script does not install or upgrade the Azure CLI itself. Health checks additionally require Pester 5.7.1 or later within major version 5; an installed Pester 6 is not a substitute for the runner's supported version.
- Healthy Azure Local nodes, storage, Arc Resource Bridge, `jumpstart` custom location and `hybridaksextension`.
- The Client VM's system-assigned managed identity and its existing LocalBox resource-group permissions. It needs `Microsoft.Authorization/roleAssignments/read` at the AKS connected-cluster scope and, if the group lacks the proxy role, `Microsoft.Authorization/roleAssignments/write` there. Contributor alone cannot create role assignments. An authorized access administrator must arrange this permission or preassign the group role before preparation; the script never elevates its own identity. It uses a temporary isolated CLI login and restores the caller's profile. No subscription-wide or Graph permissions are added.
- An existing Entra AKS admin-group object ID. Hosted events use **Lab Group ObjectId** from the Console's **Credentials** tab, published by [shared automation](../hosted-events/readme.md#console-group-dependency). Group membership is not validated through Graph by this script.
- The installed Jumpstart configuration referenced by `$env:LocalBoxConfigFile` (or `-ConfigPath`), containing `SDNDomainFQDN` and `SDNAdminPassword`. Preparation constructs the nested administrator credential locally without printing it. Supply `-NodeCredential` to override it if the nested password/account has changed. Azure managed identity cannot authenticate Windows PowerShell Direct inside nested nodes.
- `Microsoft.EdgeMarketplace` registered by the subscription owner. The Marketplace image workflow also requires the Azure Connected Machine Resource Manager role for the `Microsoft.AzureStackHCI` resource-provider identity on the image resource group; ask the deployment owner to verify this prerequisite. No automatic privilege escalation is attempted.
- Verified DHCP exclusions/static reservations for both pools, sufficient backing `V:` capacity and event budget. Dynamic disks do not add physical backing capacity.

For the standard Jumpstart configuration, the nested-node administrator is `jumpstart\Administrator`. The Client VM's `arcdemo` account is not the nested-node administrator. Use the nested domain's credentials (adjust the domain if customized), not a password reset solely on the Client VM.

LocalBox administrator credentials are not published to participants. If the Client password is unknown, an authorized event lead/coach can reset the Client's `arcdemo` account through the Azure portal, connect via Bastion and open elevated PowerShell 7. A Client-only reset leaves the nested password unchanged; the installed Jumpstart configuration retains the value that preparation uses. Do not open, print, screenshot or share the configuration to obtain the password. Restricted Console retrieval remains optional future work, not a prerequisite for this local workflow; see [LocalBox credentials](../hosted-events/readme.md#localbox-credentials).

## Download and run

Download files, inspect them, then execute. Do not pipe downloaded content into `Invoke-Expression`. The main URL works after publication; use your published branch/ref while validating a change. An immutable commit is preferable for repeatable events.

```powershell
$base = 'https://raw.githubusercontent.com/microsoft/MicroHack/refs/heads/main/03-Azure/01-03-Infrastructure/01_Sovereign_Cloud/resources'
Invoke-WebRequest "$base/prepare-localbox.ps1" -OutFile './prepare-localbox.ps1'
./prepare-localbox.ps1 -AddressReservationsConfirmed -WhatIf
./prepare-localbox.ps1 -AddressReservationsConfirmed
```

If the nested account was rotated, pass a current `PSCredential` through `-NodeCredential`; do not substitute the reset Client password. Missing configuration credentials produce an actionable error instead of exposing their contents or prompting unexpectedly.

The script prompts for the Entra group object ID, or accepts `-AksAdminGroupObjectId`. Subscription, resource group and configuration path default from Jumpstart's machine environment. Explicit scope values must match this Client's deployment. Run only one preparation session at a time.

If the Console-owned group is not available yet, `-SkipAks` explicitly prepares only storage, the VM image and both networks. It does not fabricate a group or grant anyone cluster access. The manifest records this as a partial run, and full health checks fail until preparation is rerun without `-SkipAks` using a valid admin-group ID.

`-WhatIf` installs missing CLI extensions as a deliberate local-tooling exception, then performs authenticated reads and validation. It does not provision Azure resources, assign roles or change Hyper-V or storage. The RBAC step only reports the planned group/cluster assignment, without querying a cluster that may not exist yet; it does not validate role-assignment permissions. It can create and remove a temporary local CLI profile. It does not establish that later resource creation will succeed.

## Prepared resources

| Resource | Default |
| --- | --- |
| Storage | One stable-named 1 TiB dynamic VHDX per node; grow `UserStorage_1` to 1 TiB, never shrink or grow it again on every rerun |
| VM image | `2025-datacenter-azure-edition-smalldisk-01`, matching the walkthrough screenshot; Marketplace Windows Server 2025 Azure Edition smalldisk, explicitly on `UserStorage1` |
| VM network | `localbox-vm-lnet-vlan200`, VLAN 200, `192.168.200.0/24`, pool `.10-.199` after reservation review |
| AKS network | `localbox-aks-lnet-vlan110`, VLAN 110, `10.10.0.0/24`, nodes `.101-.199` |
| AKS control plane / service reservation | `10.10.0.5`; `.10-.100` reserved for future service VIPs; this script does not install a load balancer |
| AKS cluster | `localbox-aks`, one control-plane node and three Linux workers; `Standard_A4_v2` defaults, subject to installed-version capacity/CLI validation |
| AKS proxy access | Azure Arc Enabled Kubernetes Cluster User Role for `AksAdminGroupObjectId`, scoped to the connected-cluster resource; matching direct or inherited grants are reused |
| Output | `C:\LocalBox\sovereign-localbox.json`, nonsecret IDs and expected configuration for health tests |

Topology defaults come from the installed Jumpstart config, except the VM pool bounds and configurable resource names/sizes. The network/broadcast addresses, gateways and Jumpstart infrastructure reservations must not be allocated. `-AddressReservationsConfirmed` is your explicit confirmation that DHCP/static reservations were reviewed; the script cannot safely infer all DHCP leases from Azure. It does not change routers or DHCP configuration.

Azure Local may append generated suffixes to its `UserStorage1` and `UserStorage2` resource names. The script resolves the actual storage-container ID and verifies its custom location; ambiguous names fail rather than selecting the first match.

On Windows, the script invokes Azure CLI through its bundled Python executable rather than `az.cmd`. This preserves arguments such as `ConvergedSwitch(compute_management)` that the batch wrapper otherwise interprets as command syntax. Keep the standard Azure CLI installation layout intact.

The `aksarc` extension can print a first-use privacy notice even when JSON output is requested. Preparation separates stderr from JSON stdout and checks AKS validation/creation by exit code, then verifies the cluster through ARM reads. If an older script fails with `Conversion from JSON failed` after network preparation, use the corrected script and rerun with the same parameters after inspecting resource status. Matching resources are reused; do not delete them to fix an output-parsing error.

Use `-ImageVersion` to pin a Marketplace version, `-KubernetesVersion` for a supported AKS version, and size/count overrides when required. Images can take several hours; `-TimeoutMinutes` defaults to 360 per long operation. A timed-out local command does not cancel an already submitted Azure operation. Inspect status before rerunning. Matching resources are reused; incompatible resources produce an error, never automatic replacement.

If an image was imported manually before preparation under the documented name but on another storage path, preparation stops before disk expansion. The facilitator must review its dependencies; only if the image is confirmed unused should it be removed manually so preparation can import it on `UserStorage1` under the same documented name. Otherwise, resolve placement with the Azure Local administrator before proceeding. Do not change image names or use `-RemoveUserStorage2` to work around this conflict. Automation never deletes or moves an existing image.

## Optional storage consolidation

On a new, empty environment, pass `-RemoveUserStorage2` to request removal of the unused second Azure storage path, CSV and virtual disk. Each destructive operation requires confirmation. The script refuses consolidation when storage is unhealthy/busy, the volume is not empty, its identity is ambiguous, or existing LocalBox workload resources are found. Do this **before** image/AKS creation. Never use confirmation suppression to override a failed safety check.

If existing workloads use the secondary volume, do not remove it. Use the [manual reference](manual-preparation.md) with an Azure Local administrator to assess storage and placement. Image placement is explicitly `UserStorage1`; retaining `UserStorage2` can still affect other workload placement and requires the participant VM smoke test.

## Verify readiness

Follow [Pester health checks](../tests/readme.md). Provisioning success is not a health verdict. The nonsecret manifest intentionally records `FullHealthVerified = false`.

For AKS runtime access, follow [Jumpstart's AKS guide](https://jumpstart.azure.com/azure_jumpstart_localbox/AKS): use a separate CLI profile/session authenticated as a group member, and keep `az connectedk8s proxy` running with the kubeconfig used for health checks (default `$HOME/.kube/config`). Do not log out the provisioning identity or give its managed identity broader permissions to run tests.

Preparation now reconciles two separate access requirements: the cluster's Entra admin-group configuration for Kubernetes administration, and **Azure Arc Enabled Kubernetes Cluster User Role** (`00493d72-78f6-4148-b6c5-d3ce8e4799dd`) for ARM's `Microsoft.Kubernetes/connectedClusters/listClusterUserCredential/action`. New role assignments target only the `Microsoft.Kubernetes/connectedClusters/localbox-aks` resource (or the configured cluster name), never the resource group or subscription. Existing unconditional assignments for the same group/role at the cluster, resource group or subscription are reused, including a manually assigned resource-group grant. Existing assignments are never deleted or broadened; conditional grants require administrator review.

Rerunning preparation repairs a missing proxy assignment on an existing cluster, using a stable assignment ID. `-SkipAks` skips this RBAC step as well as AKS preparation. Authorization failures stop preparation with the required permission and scope; they are not treated as success. After a new grant, allow Azure RBAC propagation and refresh the group member's sign-in/proxy session if access is initially denied. Role assignment does not prove group membership or successful proxy access; rerun the Full health checks using a group-member kubeconfig.

Finally, use the [participant VM exercise](manual-preparation.md#step-6-test-the-environment) to validate actual VM guest networking, guest management, Defender coverage and update assessment. These participant-created VMs are not created by the preparation script.

## Measure participant VM capacity

Use [test-localbox-capacity.ps1](../test-localbox-capacity.ps1) beside [prepare-localbox.ps1](../prepare-localbox.ps1) to test the Challenge 6 VM footprint: 2 vCPUs, fixed 4096 MiB RAM, the prepared Windows image, VLAN 200 and `UserStorage_1`, with guest management enabled. It does not install updates, alter Defender plans, change RBAC or resize shared infrastructure. Existing subscription policies and paid plans still apply to the test VMs.

The script creates a uniquely named, tagged `rg-lbcap-<run-id>` resource group. By default it provisions one VM at a time. Set `-BatchSize 5` to submit up to five deployments without waiting for each VM to finish; Azure provisioning overlaps, although ARM previews and request submission are serialized. The whole batch must reach ARM success, Running power state and Connected guest management before another batch starts. It stops at the requested total, the first failure/timeout, or a safety reserve. Failed provisioning is not automatically classified as capacity exhaustion, and submitted Azure operations can continue after a local timeout. No automatic rollback or deletion occurs.

Run in PowerShell 7 with your existing Azure CLI login. The operator needs resource-group creation/deployment permissions in the selected subscription, access to the shared image/network/storage/custom location, and VM Run Command permission on `LocalBox-Client` for remote mode. No login, logout or account selection is performed by the script. Keep other preparation/capacity sessions idle.

From your workstation, Linux/WSL or another machine, use `-RemoteClusterId`. Deployments run locally; read-only probes execute on the Client through Azure VM Run Command. You do not need to copy the scripts or retrieve the nested administrator password. The probe uses the installed configuration locally on the Client and returns only an allowlisted nonsecret manifest and capacity measurements. Run Command creates normal operational execution artifacts. Even `-WhatIf` performs these probes, but creates no VMs, resource group or journal.

```powershell
$clusterId = '/subscriptions/<subscription-id>/resourceGroups/rg-localbox-shared/providers/Microsoft.AzureStackHCI/clusters/localboxcluster'
$statePath = Join-Path $HOME '.microhack/capacity-test/run.json'
$run = @{ RemoteClusterId = $clusterId; StatePath = $statePath }

./test-localbox-capacity.ps1 @run -VmCount 5 -WhatIf
./test-localbox-capacity.ps1 @run -VmCount 5 -GenerateVmCredential
./test-localbox-capacity.ps1 @run -Mode Status

# Increase the total for the same run; existing Ready VMs are retained.
./test-localbox-capacity.ps1 @run -VmCount 10 -GenerateVmCredential

# Exercise participant-like deployment overlap in a bounded batch.
./test-localbox-capacity.ps1 @run -VmCount 15 -BatchSize 5 -GenerateVmCredential -SubmitBatch
./test-localbox-capacity.ps1 @run -Mode Status

# Review first; the second command prompts before deletion.
./test-localbox-capacity.ps1 @run -Mode Cleanup -WhatIf
./test-localbox-capacity.ps1 @run -Mode Cleanup
```

Alternatively, run elevated on `LocalBox-Client` without `-RemoteClusterId`. The local defaults use `C:\LocalBox\sovereign-localbox.json` and write the journal to `C:\LocalBox\capacity-test\run.json`. Supply `-NodeCredential` only for a rotated nested account; remote probes require the installed configuration to contain the current nested credential.

`-GenerateVmCredential` creates a random local administrator password in memory and discards it after the invocation. It is not recoverable from the report. Use `-VmCredential (Get-Credential -UserName localadmin)` instead when you need interactive guest sign-in. The password is passed via a secure ARM parameter in a temporary directory restricted to the invoking user, never as a command-line password. Temporary files are removed on normal success/failure; a forcibly killed process can leave the protected temporary directory behind. Never print or publish these files.

Default reserves are 300 GiB on the backing `V:` volume, 150 GiB on the primary CSV and 12 GiB of free memory on **each** nested node. Before submitting a batch, the script additionally budgets 40 GiB of guest disk growth per new VM multiplied by the storage copy count on `V:`, and the entire batch's memory on each node without assuming balanced placement. For five 4-GiB VMs and two storage copies, that requires at least 700 GiB free on `V:`, 350 GiB on the primary CSV and 32 GiB free on each node before submission. These conservative stop thresholds are configurable upward or within the parameter limits, not guarantees that later workloads cannot grow. The two CSV capacities are not additional physical capacity, and the script does not place test VMs on `UserStorage_2`.

Keep the JSON journal: it identifies the run, VMs, target, baseline/latest measurements and stop reason. The adjacent CSV records VM readiness, elapsed seconds and per-VM post-deployment headroom. Re-running with a larger `-VmCount` extends the same run only when its existing VMs are Ready; it never changes their size or recreates them. Use `-Mode Status` after an interrupted or timed-out invocation before retrying. A trailing `Submitting` entry can be retried only after Azure confirms no deployment, VM or NIC exists; partial resources require manual inspection. A new journal creates a separate run, so clean up old runs to avoid consuming capacity twice.

For terminals that cannot maintain a long-running monitor, add `-SubmitNext` for one VM, or `-SubmitBatch -BatchSize 5` for one batch. The command returns while Azure provisions the submitted VMs. Check `-Mode Status`, then repeat once all existing VMs are Ready. `-VmCount` remains the total limit, not the number to add; a partly filled final batch will be smaller. Submitted VMs are not counted as healthy. ARM what-if must confirm exactly the three intended new resources for each VM; harmless `Ignore`/`NoChange` entries for existing resources are allowed, but modifications and deletions are rejected.

Cleanup validates the exact journal-derived group name, subscription, cluster, group ownership tags and resource inventory. It refuses a group containing unrelated resources and never deletes the shared LocalBox group. Do not add other resources to the test group. Review the Azure Local VM list after cleanup to confirm nested workload storage was released, then rerun the Full LocalBox health checks.

A successful test establishes a **running, guest-connected VM count**, not a maximum or a workshop performance guarantee. The journal records each VM's batch ID and readiness time; post-deployment headroom measurements apply to the completed batch. CPU is sampled, not stress-tested. Batch mode exercises overlapping deployment and guest onboarding, but Defender coverage and simultaneous Update Manager assessments still need a representative rehearsal. Node-failure reserve is not certified by this script. Leave event headroom below the demonstrated count.

## References

- [Jumpstart AKS on Azure Local](https://jumpstart.azure.com/azure_jumpstart_localbox/AKS)
- [Azure Local Marketplace images](https://learn.microsoft.com/azure/azure-local/manage/virtual-machine-image-azure-marketplace)
- [Logical networks for AKS on Azure Local](https://learn.microsoft.com/azure/aks-hybrid-edge/local/hyperconverged/aks-networks)
- [Azure CLI image commands](https://learn.microsoft.com/cli/azure/stack-hci-vm/image)
- [Jumpstart configuration](https://github.com/microsoft/azure_arc/blob/main/azure_jumpstart_localbox/artifacts/PowerShell/LocalBox-Config.psd1)
- [Create Azure Local VMs with ARM templates](https://learn.microsoft.com/azure/azure-local/manage/create-arc-virtual-machines)