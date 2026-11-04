# Deploy the migration lab

Instructors prepare Challenge 1 before the session. Both deployment options use the same [Bicep template](../labautomation/bicep/main.bicep) and Bootstrap scripts: one learner resource group contains source and destination networks, Bastion, NAT Gateways, Key Vault, and a Hyper-V host with four nested VMs. Discovery, migration, monitoring, and App Service remain learner exercises.

| Option | Use when |
| --- | --- |
| [Hackbox Console](#option-1-hackbox-console) | The Console provisions learner scopes, runs automation, verifies readiness, and delivers connection details. |
| [Manual deployment](#option-2-manual-deployment) | An instructor deploys directly into Azure without the Console or its helper commands. |

## Before either deployment

- Require **Owner on the Hack subscription** for the deployment account and learner accounts. This allows learners to register additional resource providers during the exercises; RG Owner with subscription Reader is not sufficient when those providers are not preregistered. Manual organizers assign subscription Owner themselves.
- Arrange any separate Microsoft Entra permissions needed for Azure Migrate appliance registration; subscription Owner does not grant directory roles.
- Check regional capacity and quota. The host needs **Standard_D16s_v5**, zone **1**, a **PremiumV2_LRS** data disk, and Bastion Developer support; the default region is **swedencentral**. Budget per learner for 30 regional vCPUs, including 16 DSv5 and 10 BS-family vCPUs, and five Standard public IPs across the Hack. See [quota requests](https://learn.microsoft.com/azure/quotas/quickstart-increase-quota-portal).
- Resolve subscription policy restrictions and any required feature registrations with the organizer. Optional Defender plans must be separately approved and enabled; deployment does not change subscription-wide Defender plans.
- Allow **35-90+ minutes** for initial setup. The USD 80 daily baseline estimate in [lab-defaults.json](../labautomation/lab-defaults.json) is a conservative planning value, not a quote; later exercises add costs.

> [!WARNING]
> Subscription Owner grants control of all resource groups, resources, role assignments, and subscription settings, including other learners' labs in a shared subscription. Learner RGs are not security-isolated. Use trusted training accounts, work only in the assigned lab RG, and obtain instructor approval before changing shared settings. Remove temporary subscription Owner assignments after the Hack.

The Console deployer applies the approved training RG tags `SecurityControl=Ignore` and `CostControl=Ignore`. Direct Bicep deployment does **not** apply these exemptions. If required for a manual lab, obtain governance approval and apply the approved tags explicitly. Tags affect only controls that honor them; they are not universal policy exemptions and do not stop billing.

## Option 1: Hackbox Console

1. Import this Hack's complete `labautomation` folder, including its `bicep` subtree and both JSON files. Review [deployment-settings.json](../labautomation/deployment-settings.json) before importing; the configured source must contain the matching Bootstrap and guest artifacts.
2. Select **resourcegroup-with-subscriptionowner** deployment, overriding the supplied `resourcegroup` default. This keeps one lab RG per learner while granting both RG Owner and subscription Owner; plain `resourcegroup` grants only subscription Reader and does not meet this Hack's access requirement. Defaults are two labs per subscription in `swedencentral`; adjust the event settings and quota as needed.
3. Run predeployment. [shared-deploy-lab.ps1](../labautomation/shared-deploy-lab.ps1) registers baseline providers once per subscription; [deploy-lab.ps1](../labautomation/deploy-lab.ps1) deploys and verifies each lab. Learners can register additional providers as required by later exercises.
4. Confirm each learner has subscription Owner, then hand out the Console's connection and credential fields only after verification succeeds. Learners then follow [Solution 1](../walkthrough/challenge-01/solution-01.md).

The dashboard includes **Migration Windows Guest** username and initial-password fields for `MHBox-AzMigSrv`, `MHBox-SQL`, and `MHBox-Win2K22`, plus **Migration Ubuntu Guest** fields for `MHBox-Ubuntu-01`. These are the supplied guest images' lab-only defaults, separate from the generated host login; they are not changed by deployment reruns. If a learner changes a guest password, the dashboard's initial password no longer applies. To add these fields to an already verified Console lab, re-import the updated automation package and rerun its deployment; the completed baseline is reused without restarting guests or resetting learner progress.

Fresh `rg-labuser-0013` labs use `mh-0013-hv` and matching network prefixes. Leading zeros are preserved; learner numbers can contain one to nine digits. Existing labs and nonstandard RG names retain hash-based names. Keep the RG's `LabId`, `LabNameSuffix`, and `LabRegion` records intact: completed reruns preserve learner progress, and incomplete retries retain the original names and region.

## Option 2: Manual deployment

Use **PowerShell 7**, Azure CLI with Bicep support, and an interactive user login. Azure Cloud Shell's **PowerShell** environment also works after checking out the repository. Run the blocks below in order, starting at the repository root. Do not run the Console's `deploy-lab.ps1` in an ordinary shell: it requires platform helpers.

### Sign in and prepare the subscription

Sign in with a subscription Owner account. The provider list matches the shared preparation script and covers baseline deployment, not every provider used by later exercises. An organizer runs registration once; it is skipped for providers already registered. Learners register additional providers when needed using their subscription Owner access. In Cloud Shell, omit `Invoke-Az login` because the session is already authenticated.

```powershell
Set-Location '.\03-Azure\01-03-Infrastructure\06_Migration_Secure_AI_Ready'
$ErrorActionPreference = 'Stop'
function Invoke-Az {
    $result = & az @args
    if ($LASTEXITCODE -ne 0) { throw 'Azure CLI failed; inspect the error above before continuing.' }
    $result
}
Invoke-Az login --output none
$subscriptionId = Read-Host 'Subscription ID'
Invoke-Az account set --subscription $subscriptionId
$participantIds = @((Invoke-Az ad signed-in-user show --query id --output tsv))

$providers = @(
    'Microsoft.Compute', 'Microsoft.Network', 'Microsoft.KeyVault', 'Microsoft.Storage',
    'Microsoft.DevTestLab', 'Microsoft.ManagedIdentity', 'Microsoft.Migrate', 'Microsoft.OffAzure',
    'Microsoft.RecoveryServices', 'Microsoft.Insights', 'Microsoft.OperationalInsights',
    'Microsoft.Monitor', 'Microsoft.AlertsManagement', 'Microsoft.Web', 'Microsoft.Security'
)
foreach ($provider in $providers) {
    $state = Invoke-Az provider show --namespace $provider --query registrationState --output tsv
    if ($state -ne 'Registered') {
        Invoke-Az provider register --namespace $provider --wait --output none
    }
}
```

By default, the signed-in user receives Key Vault secret access. To deploy for other learners, replace `$participantIds` with their Entra **object IDs** and separately assign them **Owner on the Hack subscription**; the template does not assign this role.

### Create a fresh lab and deploy

Choose a new RG, not an existing or Console-managed lab. Keep the number as a quoted string to preserve leading zeros. The example reads the same source JSON as Console deployment; there is no hardcoded test account or branch.

Azure CLI will prompt securely for the omitted `windowsAdminPassword`. Use a unique 12-123 character password meeting Windows complexity requirements and retain it securely for recovery. It is not placed in the temporary parameters file or command history.

```powershell
$resourceGroup = 'rg-migration-0013'
$number = '0013'
$location = 'swedencentral'
if ((Invoke-Az group exists --name $resourceGroup --output tsv) -ne 'false') {
    throw 'The RG already exists. Inspect it or choose a fresh name; do not delete it to retry.'
}
$source = Get-Content '.\labautomation\deployment-settings.json' -Raw | ConvertFrom-Json
$templateFile = (Resolve-Path '.\labautomation\bicep\main.bicep').ProviderPath
$scope = "$subscriptionId/$resourceGroup".ToLowerInvariant()
$labId = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData(
    [Text.Encoding]::UTF8.GetBytes($scope))).Substring(0, 8).ToLowerInvariant()
$parameters = @{
    labSuffix = @{ value = $labId }
    resourceNameSuffix = @{ value = $number }
    participantObjectIds = @{ value = $participantIds }
    location = @{ value = $location }
    githubAccount = @{ value = $source.githubAccount }
    githubBranch = @{ value = $source.githubBranch }
}
Invoke-Az group create --name $resourceGroup --location $location --output none
$parameterFile = [IO.Path]::GetTempFileName()
try {
    $parameters | ConvertTo-Json -Depth 5 | Set-Content $parameterFile -Encoding utf8NoBOM
    $outputs = Invoke-Az deployment group create --name migration-manual `
        --resource-group $resourceGroup --mode Incremental `
        --template-file $templateFile `
        --parameters "@$parameterFile" --query properties.outputs --output json |
        ConvertFrom-Json
} finally {
    Remove-Item -LiteralPath $parameterFile
}
$outputs | Format-List
```

Record the output host name, username, Key Vault, and network names. Connect to the host through Azure Bastion using the password entered above. Key Vault also stores `windowsAdminUserName` and `windowsAdminPassword`; do not copy secret values into shared notes or transcripts.

Manual deployment does not run the Console's capacity preflight, automatic resume, or completed-baseline safeguards. If the command is interrupted, inspect the existing ARM deployment rather than rerunning the creation block:

```powershell
Invoke-Az deployment group show --resource-group $resourceGroup --name migration-manual `
    --query properties.provisioningState --output tsv
```

An incomplete deployment retry must retain its RG, names, region, source version, and original password. Do not resubmit a healthy baseline, switch deployment methods in the same RG, or delete resources as a retry shortcut.

## Verify readiness and hand off

**ARM success alone is not lab readiness.** The host reboots after Bootstrap, then logon provisioning prepares the nested guests. Inspect `C:\MHBox\Logs` if setup fails.

For either option, complete [Solution 1's initial-handoff checks](../walkthrough/challenge-01/solution-01.md): host tags `DeploymentProgress=Deployment Completed` and `LabReady=single-rg-v1`, a valid schema-version-1 `C:\MHBox\lab-ready.json`, all four nested VMs running, and both live dashboards returning HTTP success with correct metadata. Console labs additionally have RG tag `LabVerified=single-rg-v1`; manual instructors perform the verification themselves, without that Console tag.

For manual labs, securely provide the subscription, RG, region, host, Key Vault, network names, and login instructions to learners. References to the "dashboard" in later challenges mean these instructor-provided details when no Console is used.

Keep the RG through Challenges 2-8: it contains both source and migrated resources. Azure Monitor may create an Azure-managed `MA_*_managed` group for workspace internals; do not delete it separately. At the end, obtain approval, complete supported migration/replication and backup cleanup, then remove the lab RG. Deletion removes the entire lab, not just the source environment.

## Testing changes

Use a fresh test RG and a real learner account with **subscription Owner** to exercise deployment, both dashboard variants, provider registration during Challenges 2-8, and preservation of learner progress on a completed Console rerun. The [local harness](../../../../99-MicroHack-Template/labautomation/README.md#local-testing) is also available for testing Console automation; its helpers are local-development stand-ins, not the manual deployment requirement.

To test unpublished changes, set `githubAccount` and `githubBranch` in [deployment-settings.json](../labautomation/deployment-settings.json) to a repository account and branch or commit containing the matching artifacts. The source must be publicly downloadable by the VMs. Re-import the Console package after edits; the manual example reads the JSON directly. Keep these fields out of `lab-defaults.json`. For official upstream deployment, use `microsoft` and `main` once the matching version is published there. Complete the Azure deployment and learner-flow tests before upstream integration; syntax checks alone are not sufficient.
