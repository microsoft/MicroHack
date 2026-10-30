# Manual setup

Use this path outside eligible Console-hosted events. You own the Azure subscription, costs, permissions and cleanup. A personal subscription does not need Console accounts, exported users or a `LabUsers` group.

## Before you begin

Use an isolated lab subscription and an identity authorized as subscription Owner for preparation. LocalBox also queries Microsoft Entra ID for a resource-provider service principal; subscription Owner alone does not grant directory-read permissions.

The shared Challenge 5/7 platform needs **12 DSv5-family vCPUs, 4 confidential-family vCPUs and 16 total regional vCPUs per participant**, plus upgrade surge headroom. LocalBox for Challenge 6 is a separate deployment and needs **32 additional available Esv5/Esv6 vCPUs** in its host region. Check VM-size availability, AKS support and quota before deploying; quota does not guarantee capacity. See the [regional and quota guidance](../../Readme.md#general-prerequisites).

> [!WARNING]
> AKS nodes, VMs, Bastion, NAT Gateway and other deployed resources incur Azure charges. Stopping a Codespace does not stop or delete Azure resources. Budget for LocalBox deployment and post-provisioning time as well as the challenges.

## Install and verify the tools

The recommended [Sovereign Cloud Codespace](../../Readme.md#recommended-environment-github-codespaces) includes PowerShell 7, Azure CLI, Bicep and the challenge tools. Check the Azure PowerShell modules separately using the commands below.

For a local workstation, install the following before continuing:

| Tool | Purpose | Installation |
|---|---|---|
| Git | Clone this repository | [Install Git](https://git-scm.com/downloads) |
| PowerShell 7 (`pwsh`) | Run the `.ps1` preparation scripts | [Install PowerShell](https://learn.microsoft.com/powershell/scripting/install/installing-powershell) |
| Azure CLI (`az`) | Deploy Bicep and run LocalBox's CLI commands | [Install Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) |
| Azure CLI-managed Bicep | Compile templates for `az deployment` | Run `az bicep install` if missing |
| `Az.Accounts`, `Az.Resources`, `Az.Compute` | Azure PowerShell authentication, provider registration and quota checks | Install in PowerShell 7 as shown below |

**Bash or PowerShell 7** - verify the executables:

```bash
git --version
pwsh --version
az version
az bicep version
```

If `az bicep version` reports that Bicep is missing, run the following in **Bash or PowerShell 7**:

```bash
az bicep install
az bicep version
```

**PowerShell 7 (`pwsh`)** - check installed modules:

```powershell
Get-Module -ListAvailable -Name Az.Accounts, Az.Resources, Az.Compute
```

If any are missing, install them in the same PowerShell 7 environment you will use for the scripts:

```powershell
Install-Module -Name Az.Accounts, Az.Resources, Az.Compute `
    -Scope CurrentUser -Repository PSGallery
```

If prompted to trust PSGallery, review the repository and select `Y` or `A` to proceed. Installing modules in Windows PowerShell 5.1 or a different machine/container does not ensure they are available in this PowerShell 7 session.

The optional multi-user RBAC script additionally needs `Microsoft.Graph.Groups`. Install it only if using that script:

```powershell
Install-Module -Name Microsoft.Graph.Groups -Scope CurrentUser -Repository PSGallery
```

Full health checks additionally require `kubectl` and Pester 5.7.1 or later within major version 5. Follow the [health-check tooling requirements](../tests/readme.md#tooling-and-authentication); the individual challenge walkthroughs list their remaining tools.

## Choose the working directory

**All remaining examples start in `03-Azure/01-03-Infrastructure/01_Sovereign_Cloud`**, not in the repository root, `labautomation`, or `resources/manual-setup`. The Sovereign Cloud Codespace opens in this directory already.

If you are at the **repository root**, change directory using one of these alternatives.

**Bash:**

```bash
cd 03-Azure/01-03-Infrastructure/01_Sovereign_Cloud
pwd
```

**PowerShell 7:**

```powershell
Set-Location './03-Azure/01-03-Infrastructure/01_Sovereign_Cloud'
Get-Location
```

Do not repeat this directory change if you are already in `01_Sovereign_Cloud`. If you have not cloned the repository, run `git clone https://github.com/microsoft/MicroHack.git` and enter the new `MicroHack` directory first.

> [!NOTE]
> Code blocks are labeled by shell. Bash uses `\` for line continuation; PowerShell uses a backtick. Do not mix them or put spaces after a continuation character. A `.ps1` file runs in PowerShell; a `.bicep` file is a deployment template, not an executable.

## Authenticate and select the subscription

Azure CLI and Azure PowerShell maintain **separate sign-ins and subscription contexts**. `az login` does not authenticate `Get-AzSubscription`, and `Connect-AzAccount` does not authenticate Azure CLI. Use the same intended lab account and subscription in both.

**Bash or PowerShell 7** - sign in to Azure CLI for Bicep and LocalBox deployments:

```bash
az login --use-device-code
az account set --subscription '<subscription-id>'
az account show --query '{Account:user.name,Subscription:name,SubscriptionId:id,Tenant:tenantId}' --output table
```

Replace `<subscription-id>` with your lab subscription ID. Open the URL printed by the login command and enter its device code. Do not save codes, passwords or tokens in files or commands.

**PowerShell 7** - sign in for the subscription-preparation scripts:

```powershell
Connect-AzAccount -UseDeviceAuthentication
Set-AzContext -SubscriptionId '<subscription-id>'
Get-AzContext
```

If starting from Bash, enter `pwsh` first, then run these PowerShell commands and the preparation scripts in that **same session**. Use `exit` to return to Bash. In a multi-tenant account, specify the intended tenant with `az login --tenant '<tenant-id>' --use-device-code` and `Connect-AzAccount -Tenant '<tenant-id>' -UseDeviceAuthentication`.

## Prepare the subscription

### Register resource providers

Review the [provider-registration script](subscription-preparations/1-resource-providers.ps1) before running it.

> [!WARNING]
> This script enumerates **all subscriptions accessible to the Azure PowerShell account** and changes context for each one. `Set-AzContext` does **not** limit its scope, and the script has no subscription parameter. Do not run it unchanged if accessible subscriptions include environments you are not authorized or intending to prepare. Use an appropriately restricted lab identity, or review and explicitly narrow the script's subscription enumeration before execution.

**PowerShell 7** - inspect the affected subscriptions, then run only after confirming the scope:

```powershell
Get-AzSubscription | Select-Object Name, Id, TenantId
& './resources/manual-setup/subscription-preparations/1-resource-providers.ps1'
```

Registration can take several minutes. The summary reports registration **initiated**, not that every provider is ready. Check required providers in the target subscription before deployment; select that subscription again because the script changes context:

```powershell
Set-AzContext -SubscriptionId '<subscription-id>'
'Microsoft.Compute', 'Microsoft.Network', 'Microsoft.ContainerService' |
    ForEach-Object { Get-AzResourceProvider -ProviderNamespace $_ } |
    Select-Object ProviderNamespace, RegistrationState
```

### Check quota and availability

**PowerShell 7** - example for one participant using confidential v6 nodes in Sweden Central:

```powershell
& './resources/manual-setup/subscription-preparations/2-vcpu-quotas.ps1' `
    -Region 'swedencentral' `
    -NumberOfLabUsers 1 `
    -ConfidentialVmGeneration v6
```

The script prompts for subscription selection; press Enter to use the current Azure PowerShell subscription. Match the region and confidential generation to your intended deployment (`v5` for `Standard_DC2as_v5`, `v6` for `Standard_DC2as_v6`). Review [the script](subscription-preparations/2-vcpu-quotas.ps1) before using its optional `-SubmitQuotaRequests` switch; the example above does not submit increase requests.

The participant calculation does not cover LocalBox's additional Esv5/Esv6 quota, upgrade surge headroom, or Challenge 4's ACI capacity. Check those separately. Confirm regional SKU availability and AKS support using the [regional guidance](../../Readme.md#general-prerequisites); the example region and size below are not a capacity guarantee.

### Optional multi-user preparation

For an individual lab, skip [multi-user RBAC](subscription-preparations/3-rbac.ps1) and [participant resource-group creation](subscription-preparations/4-resource-groups.ps1). For a workshop, review their Graph permissions, subscription selection, group and resource-group settings before running them. Do not give students subscription Owner just to operate LocalBox.

**PowerShell 7** - inspect parameters before using the scripts:

```powershell
Get-Help './resources/manual-setup/subscription-preparations/3-rbac.ps1' -Detailed
Get-Help './resources/manual-setup/subscription-preparations/4-resource-groups.ps1' -Detailed
```

## Deploy participant infrastructure

The [Sovereign lab Bicep template](../../labautomation/sovereign-lab.bicep) provisions the shared Challenge 5/7 AKS cluster with two system and two Ubuntu confidential nodes, K3s VM, Bastion and networking. It does **not** deploy LocalBox. No standalone CVM password or attestation provider is required.

Choose **one** of the following shell alternatives. Both use Azure CLI and its managed Bicep installation. Replace the example region and confidential size with your validated selection, and choose a stable, unique `nameSuffix` of 6-12 characters for each participant. Reuse those values when updating an existing lab.

If you have already completed Challenge 1, restore its exercise assignments to **DoNotEnforce** before deployment. Do not change unrelated or organizer-managed policies.

### Bash

Starting directory: `01_Sovereign_Cloud`. Return from PowerShell with `exit` first if needed.

```bash
az group create \
  --name rg-sovereign-lab \
  --location swedencentral

az deployment group create \
  --name sovereign-lab \
  --resource-group rg-sovereign-lab \
  --template-file ./labautomation/sovereign-lab.bicep \
  --parameters \
    location=swedencentral \
    nameSuffix=coach01 \
    confidentialVmSize=Standard_DC2as_v6
```

### PowerShell 7

Starting directory: `01_Sovereign_Cloud`. Azure CLI must be signed in even if `Get-AzContext` shows an authenticated PowerShell session.

```powershell
az group create `
    --name rg-sovereign-lab `
    --location swedencentral

az deployment group create `
    --name sovereign-lab `
    --resource-group rg-sovereign-lab `
    --template-file './labautomation/sovereign-lab.bicep' `
    --parameters `
        location=swedencentral `
        nameSuffix=coach01 `
        confidentialVmSize=Standard_DC2as_v6
```

In either shell, Azure CLI prompts for the required secure `adminPassword` parameter. Enter a strong K3s VM administrator password at that prompt rather than putting it in the command, source control or shell history. Keep it in an approved password manager for later access.

Wait for the deployment result. The resource group's `Succeeded` state confirms only group creation, not completion of the lab deployment.

**Bash or PowerShell 7** - inspect the deployment state and retrieve its outputs:

```bash
az deployment group show --resource-group rg-sovereign-lab --name sovereign-lab --query properties.provisioningState --output tsv
az deployment group show --resource-group rg-sovereign-lab --name sovereign-lab --query properties.outputs --output json
```

Retain the successful deployment name and outputs for health testing; provide `aksClusterName` and `confidentialNodePoolName` to participants. Deployment success does not replace the live health checks.

Challenge 4 provisions its own ACI/ACR comparison in North Europe. Challenge 5 consumes the shared cluster in its actual region; its cleanup deletes only applications. See [regional findings, quotas and migration guidance](../../Readme.md#general-prerequisites) before using an existing lab.

For organizers reproducing the full Console workflow locally, follow the [template's local testing instructions](../../../../../99-MicroHack-Template/labautomation/README.md#local-testing), including its helper container and shared preparation before per-lab deployment. The Console hooks are not general standalone deployment scripts.

## Deploy and prepare LocalBox

LocalBox is the separate environment for Challenge 6. Confirm its additional **32 Esv5/Esv6 vCPU** quota and cost before running the [manual entry point](localbox/deploy-localbox.ps1). The script estimates **4-6 hours** for initial deployment; nested provisioning and the [post-provisioning preparation](../localbox/readme.md#preparation-time) must also finish. Start at least 24 hours before an event and verify readiness rather than relying on elapsed time.

Starting directory for both alternatives: `01_Sovereign_Cloud`. The script uses the current **Azure CLI** subscription, prompts for confirmation and a host administrator password, then submits a deployment with `--no-wait`. Signing in only with `Connect-AzAccount` is not sufficient.

**Bash** - launch the PowerShell script:

```bash
pwsh -File ./resources/manual-setup/localbox/deploy-localbox.ps1 \
  -ResourceGroupName rg-localbox-shared \
  -Location swedencentral
```

**PowerShell 7:**

```powershell
& './resources/manual-setup/localbox/deploy-localbox.ps1' `
    -ResourceGroupName 'rg-localbox-shared' `
    -Location 'swedencentral'
```

Use the deployment name printed by the script to monitor **Azure portal > Resource groups > rg-localbox-shared > Deployments**. A submitted deployment is not a ready LocalBox.

The Azure Local registration and staging storage region defaults to **Australia East** for this lab, independently of the Azure host region. Choose another supported and subscription-eligible region with `-AzureLocalInstanceLocation` when needed; this lab default is not a European data-residency recommendation.

Wait for the nested Azure Local deployment, then connect to `LocalBox-Client` and follow the shared [post-provisioning guide](../localbox/readme.md). This preparation runs in elevated PowerShell 7 **inside LocalBox-Client**, not in the Codespace. Supply an existing Entra security-group object ID for AKS; its intended administrators must be members. Follow that guide's remaining identity and MetalLB prerequisites as well.

## Validate readiness

Run the [health checks](../tests/readme.md) before participants begin. Use that guide's commands for your selected scope and mode; Full LocalBox checks run inside LocalBox-Client, while Kubernetes checks require working authentication and the appropriate proxy/tunnel. Offline mocked tests do not establish that deployed infrastructure is ready.

Verify scoped participant access and approved Defender for Servers settings using the [manual preparation and readiness reference](../localbox/manual-preparation.md).

## Troubleshooting

| Symptom | Action |
|---|---|
| Script path is not recognized or file is not found | Check `pwd` in Bash or `Get-Location` in PowerShell. These examples start in `01_Sovereign_Cloud`; do not prepend `MicroHack/03-Azure/...` when already inside that directory. |
| `Get-AzSubscription` is not recognized | Enter `pwsh`, then install the required Az modules in that environment. Azure CLI installation alone does not provide PowerShell cmdlets. |
| Interactive authentication is unsupported | Run `Connect-AzAccount -UseDeviceAuthentication` before the preparation scripts. For Azure CLI, use `az login --use-device-code`. |
| No Azure context or subscriptions | Sign in to the correct tool, account and tenant. Verify the selected subscription and permissions; CLI and PowerShell contexts are independent. |
| Running `sovereign-lab.bicep` directly fails | Use `az deployment group create --template-file ...` as shown above; Bicep is not an executable script. |
| Bicep is not installed for Azure CLI | Run `az bicep install`, then verify with `az bicep version`. |
| Deployment reports quota, SKU or regional availability errors | Review quota and supported sizes for the exact region and confidential generation. Do not blindly retry or assume a different region is permitted. |
| Deployment is denied by policy | Read the denied resource and assignment details. Restore only your Challenge 1 exercise assignments to `DoNotEnforce` if needed; do not disable organization policies. |
| LocalBox cannot find the Azure Local resource-provider service principal | Verify the correct tenant and appropriate directory-read access. Subscription Owner does not automatically grant Entra directory permissions. |

## Cleanup

There is no automatic Console teardown in this path. Remove only resource groups and groups you own after use, including shared LocalBox, and verify removal. The [existing bulk cleanup utility](cleanup/1-resource-groups.ps1) scans all accessible subscriptions and deletes every resource group matching its pattern after confirmation. It is intended for controlled multi-user lab subscriptions, not ordinary personal subscriptions or hosted-event lifecycle cleanup. Preview its complete list and never use a broad pattern against unrelated workloads.