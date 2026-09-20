# LocalBox post-provisioning preparation

Run [prepare-localbox.ps1](../prepare-localbox.ps1) **inside LocalBox-Client**, after Jumpstart has finished deploying the nested Azure Local cluster. This is common to hosted and manual delivery. It does not deploy a new LocalBox or replace the existing Azure AKS/K3s labs.

## Prerequisites

- Elevated PowerShell 7 on `LocalBox-Client` and an installed Azure CLI. Preparation automatically installs missing `stack-hci-vm`, `customlocation` and `aksarc` extensions, including during `-WhatIf`, verifies their versions and leaves existing versions unchanged. Internet access to the extension downloads is required; installation failure stops preparation before infrastructure changes. Record the versions printed by the script for your event.
- Extensions are installed in your persistent CLI extension directory (`AZURE_EXTENSION_DIR`, if set), not the temporary authentication profile. The script does not install or upgrade the Azure CLI itself. Health checks additionally require Pester 5.7.1 or later within major version 5; an installed Pester 6 is not a substitute for the runner's supported version.
- Healthy Azure Local nodes, storage, Arc Resource Bridge, `jumpstart` custom location and `hybridaksextension`.
- The Client VM's system-assigned managed identity and its existing LocalBox resource-group permissions. The script uses a temporary isolated CLI login and restores the caller's profile. No subscription-wide or Graph permissions are added.
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

`-WhatIf` installs missing CLI extensions as a deliberate local-tooling exception, then performs authenticated reads and validation. It does not provision Azure resources or change Hyper-V or storage. It can create and remove a temporary local CLI profile. It does not establish that later resource creation will succeed.

## Prepared resources

| Resource | Default |
| --- | --- |
| Storage | One stable-named 1 TiB dynamic VHDX per node; grow `UserStorage_1` to 1 TiB, never shrink or grow it again on every rerun |
| VM image | `2025-datacenter-azure-edition-smalldisk-01`, matching the walkthrough screenshot; Marketplace Windows Server 2025 Azure Edition smalldisk, explicitly on `UserStorage1` |
| VM network | `localbox-vm-lnet-vlan200`, VLAN 200, `192.168.200.0/24`, pool `.10-.199` after reservation review |
| AKS network | `localbox-aks-lnet-vlan110`, VLAN 110, `10.10.0.0/24`, nodes `.101-.199` |
| AKS control plane / service reservation | `10.10.0.5`; `.10-.100` reserved for future service VIPs; this script does not install a load balancer |
| AKS cluster | `localbox-aks`, one control-plane node and three Linux workers; `Standard_A4_v2` defaults, subject to installed-version capacity/CLI validation |
| Output | `C:\LocalBox\sovereign-localbox.json`, nonsecret IDs and expected configuration for health tests |

Topology defaults come from the installed Jumpstart config, except the VM pool bounds and configurable resource names/sizes. The network/broadcast addresses, gateways and Jumpstart infrastructure reservations must not be allocated. `-AddressReservationsConfirmed` is your explicit confirmation that DHCP/static reservations were reviewed; the script cannot safely infer all DHCP leases from Azure. It does not change routers or DHCP configuration.

Azure Local may append generated suffixes to its `UserStorage1` and `UserStorage2` resource names. The script resolves the actual storage-container ID and verifies its custom location; ambiguous names fail rather than selecting the first match.

On Windows, the script invokes Azure CLI through its bundled Python executable rather than `az.cmd`. This preserves arguments such as `ConvergedSwitch(compute_management)` that the batch wrapper otherwise interprets as command syntax. Keep the standard Azure CLI installation layout intact.

Use `-ImageVersion` to pin a Marketplace version, `-KubernetesVersion` for a supported AKS version, and size/count overrides when required. Images can take several hours; `-TimeoutMinutes` defaults to 360 per long operation. A timed-out local command does not cancel an already submitted Azure operation. Inspect status before rerunning. Matching resources are reused; incompatible resources produce an error, never automatic replacement.

If an image was imported manually before preparation under the documented name but on another storage path, preparation stops before disk expansion. The facilitator must review its dependencies; only if the image is confirmed unused should it be removed manually so preparation can import it on `UserStorage1` under the same documented name. Otherwise, resolve placement with the Azure Local administrator before proceeding. Do not change image names or use `-RemoveUserStorage2` to work around this conflict. Automation never deletes or moves an existing image.

## Optional storage consolidation

On a new, empty environment, pass `-RemoveUserStorage2` to request removal of the unused second Azure storage path, CSV and virtual disk. Each destructive operation requires confirmation. The script refuses consolidation when storage is unhealthy/busy, the volume is not empty, its identity is ambiguous, or existing LocalBox workload resources are found. Do this **before** image/AKS creation. Never use confirmation suppression to override a failed safety check.

If existing workloads use the secondary volume, do not remove it. Use the [manual reference](manual-preparation.md) with an Azure Local administrator to assess storage and placement. Image placement is explicitly `UserStorage1`; retaining `UserStorage2` can still affect other workload placement and requires the participant VM smoke test.

## Verify readiness

Follow [Pester health checks](../tests/readme.md). Provisioning success is not a health verdict. The nonsecret manifest intentionally records `FullHealthVerified = false`.

For AKS runtime access, follow [Jumpstart's AKS guide](https://jumpstart.azure.com/azure_jumpstart_localbox/AKS): use a separate CLI profile/session authenticated as a group member, and keep `az connectedk8s proxy` running with a dedicated kubeconfig. Do not log out the provisioning identity or give its managed identity broader permissions to run tests. Group membership grants Kubernetes administration; Azure proxy/connect permissions must also be in place.

Finally, use the [participant VM exercise](manual-preparation.md#step-6-test-the-environment) to validate actual VM guest networking, guest management, Defender coverage and update assessment. These participant-created VMs are not created by the preparation script.

## References

- [Jumpstart AKS on Azure Local](https://jumpstart.azure.com/azure_jumpstart_localbox/AKS)
- [Azure Local Marketplace images](https://learn.microsoft.com/azure/azure-local/manage/virtual-machine-image-azure-marketplace)
- [Logical networks for AKS on Azure Local](https://learn.microsoft.com/azure/aks-hybrid-edge/local/hyperconverged/aks-networks)
- [Azure CLI image commands](https://learn.microsoft.com/cli/azure/stack-hci-vm/image)
- [Jumpstart configuration](https://github.com/microsoft/azure_arc/blob/main/azure_jumpstart_localbox/artifacts/PowerShell/LocalBox-Config.psd1)