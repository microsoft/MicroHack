# LocalBox post-provisioning preparation

Run [prepare-localbox.ps1](../prepare-localbox.ps1) **inside LocalBox-Client**, after Jumpstart has finished deploying the nested Azure Local cluster. This is common to hosted and manual delivery. It does not deploy a new LocalBox or replace the existing Azure AKS/K3s labs.

## Prerequisites

- Elevated PowerShell 7 on `LocalBox-Client`; installed Azure CLI with `stack-hci-vm`, `customlocation` and `aksarc` extensions. Install missing extensions explicitly before running; the script neither installs nor upgrades tooling. Record the versions used for your event.
- Healthy Azure Local nodes, storage, Arc Resource Bridge, `jumpstart` custom location and `hybridaksextension`.
- The Client VM's system-assigned managed identity and its existing LocalBox resource-group permissions. The script uses a temporary isolated CLI login and restores the caller's profile. No subscription-wide or Graph permissions are added.
- An existing Entra AKS admin-group object ID. Hosted events obtain this from the Console owner; [group provisioning is a documented dependency](../hosted-events/readme.md#console-group-dependency). Group membership is not validated through Graph by this script.
- Windows administrator credentials for `AzLHOST1`/`AzLHOST2`. Enter these in the local `Get-Credential` prompt. Azure managed identity cannot authenticate Windows PowerShell Direct inside nested nodes.
- `Microsoft.EdgeMarketplace` registered by the subscription owner. The Marketplace image workflow also requires the Azure Connected Machine Resource Manager role for the `Microsoft.AzureStackHCI` resource-provider identity on the image resource group; ask the deployment owner to verify this prerequisite. No automatic privilege escalation is attempted.
- Verified DHCP exclusions/static reservations for both pools, sufficient backing `V:` capacity and event budget. Dynamic disks do not add physical backing capacity.

## Download and run

Download files, inspect them, then execute. Do not pipe downloaded content into `Invoke-Expression`. The main URL works after publication; use your published branch/ref while validating a change. An immutable commit is preferable for repeatable events.

```powershell
$base = 'https://raw.githubusercontent.com/microsoft/MicroHack/refs/heads/main/03-Azure/01-03-Infrastructure/01_Sovereign_Cloud/resources'
Invoke-WebRequest "$base/prepare-localbox.ps1" -OutFile './prepare-localbox.ps1'
$nodeCredential = Get-Credential -Message 'Nested Azure Local Windows administrator'
./prepare-localbox.ps1 -NodeCredential $nodeCredential -AddressReservationsConfirmed -WhatIf
./prepare-localbox.ps1 -NodeCredential $nodeCredential -AddressReservationsConfirmed
```

The script prompts for the Entra group object ID, or accepts `-AksAdminGroupObjectId`. Subscription, resource group and configuration path default from Jumpstart's machine environment. Explicit scope values must match this Client's deployment. Run only one preparation session at a time.

`-WhatIf` performs authenticated reads and local validation, but no Azure/Hyper-V/storage provisioning. It can create and remove a temporary local CLI profile. It does not establish that later resource creation will succeed.

## Prepared resources

| Resource | Default |
| --- | --- |
| Storage | One stable-named 1 TiB dynamic VHDX per node; grow `UserStorage_1` to 1 TiB, never shrink or grow it again on every rerun |
| VM image | `localbox-windows-server-2025`, Marketplace Windows Server 2025 Azure Edition smalldisk, explicitly on `UserStorage1` |
| VM network | `localbox-vm-lnet-vlan200`, VLAN 200, `192.168.200.0/24`, pool `.10-.199` after reservation review |
| AKS network | `localbox-aks-lnet-vlan110`, VLAN 110, `10.10.0.0/24`, nodes `.101-.199` |
| AKS control plane / service reservation | `10.10.0.5`; `.10-.100` reserved for future service VIPs; this script does not install a load balancer |
| AKS cluster | `localbox-aks`, one control-plane and one Linux worker; `Standard_A4_v2` defaults, subject to installed-version capacity/CLI validation |
| Output | `C:\LocalBox\sovereign-localbox.json`, nonsecret IDs and expected configuration for health tests |

Topology defaults come from the installed Jumpstart config, except the VM pool bounds and configurable resource names/sizes. The network/broadcast addresses, gateways and Jumpstart infrastructure reservations must not be allocated. `-AddressReservationsConfirmed` is your explicit confirmation that DHCP/static reservations were reviewed; the script cannot safely infer all DHCP leases from Azure. It does not change routers or DHCP configuration.

Use `-ImageVersion` to pin a Marketplace version, `-KubernetesVersion` for a supported AKS version, and size/count overrides when required. Images can take several hours; `-TimeoutMinutes` defaults to 360 per long operation. A timed-out local command does not cancel an already submitted Azure operation. Inspect status before rerunning. Matching resources are reused; incompatible resources produce an error, never automatic replacement.

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