#Requires -Version 7.0
<#
.SYNOPSIS
Deploys the Azure Arc Jumpstart LocalBox environment used by the Sovereign Cloud lab.
.DESCRIPTION
Downloads a coherent set of upstream LocalBox Bicep templates, validates them, and
deploys the LocalBox host, networking, storage, and optional Azure Bastion resources.
.PARAMETER SubscriptionId
The Azure subscription that receives the LocalBox resources.
.PARAMETER ResourceGroupName
The resource group to create or update.
.PARAMETER Location
The Azure region for the LocalBox Azure resources.
.PARAMETER WindowsAdminPassword
Optional host administrator password. For unattended deployment, prefer the
LOCALBOX_ADMIN_PASSWORD environment variable so the secret is not in the process list.
A random password is generated when neither value is supplied.
.PARAMETER GithubRef
The azure_arc branch, tag, or commit used for both Bicep and runtime artifacts.
.PARAMETER AzureLocalResourceProviderObjectId
Optional tenant-specific object ID of the Microsoft.AzureStackHCI enterprise
application. The script resolves it through Microsoft Graph when omitted.
.PARAMETER NoWait
Submit the deployment without waiting for ARM completion.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$SubscriptionId,

    [string]$ResourceGroupName = 'rg-localbox-shared',

    [string]$Location = 'swedencentral',

    [string]$WindowsAdminUsername = 'arcdemo',

    [string]$WindowsAdminPassword,

    [bool]$DeployBastion = $true,

    [ValidateSet('Standard_E32s_v5', 'Standard_E32s_v6')]
    [string]$VmSize = 'Standard_E32s_v6',

    [string]$GithubAccount = 'microsoft',

    [string]$GithubRef = 'main',

    [string]$AzureLocalResourceProviderObjectId,

    [ValidateSet('australiaeast', 'southcentralus', 'eastus', 'westeurope', 'southeastasia', 'canadacentral', 'japaneast', 'centralindia')]
    [string]$AzureLocalInstanceLocation = 'australiaeast',

    [switch]$NoWait
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

function Invoke-AzJson {
    param([Parameter(Mandatory = $true)][string[]]$Arguments)

    $output = & az @Arguments --only-show-errors --output json
    if ($LASTEXITCODE -ne 0) {
        throw "Azure CLI command failed: az $($Arguments -join ' ')"
    }
    if ([string]::IsNullOrWhiteSpace(($output -join "`n"))) {
        return $null
    }
    return ($output -join "`n") | ConvertFrom-Json
}

function New-LocalBoxPassword {
    $upper = 'ABCDEFGHJKLMNPQRSTUVWXYZ'
    $lower = 'abcdefghijkmnopqrstuvwxyz'
    $digits = '23456789'
    $special = '!@#%+='
    $all = $upper + $lower + $digits + $special
    $characters = @(
        $upper[(Get-Random -Maximum $upper.Length)]
        $lower[(Get-Random -Maximum $lower.Length)]
        $digits[(Get-Random -Maximum $digits.Length)]
        $special[(Get-Random -Maximum $special.Length)]
    )
    $characters += 1..20 | ForEach-Object { $all[(Get-Random -Maximum $all.Length)] }
    return -join ($characters | Sort-Object { Get-Random })
}

if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    throw 'Azure CLI is required to deploy LocalBox.'
}

$account = Invoke-AzJson -Arguments @('account', 'show', '--subscription', $SubscriptionId)
Write-Host "Using subscription: $($account.name) ($SubscriptionId)" -ForegroundColor Green

$requiredProviders = @(
    'Microsoft.Authorization',
    'Microsoft.AzureStackHCI',
    'Microsoft.Compute',
    'Microsoft.ExtendedLocation',
    'Microsoft.GuestConfiguration',
    'Microsoft.HybridCompute',
    'Microsoft.HybridContainerService',
    'Microsoft.KeyVault',
    'Microsoft.Kubernetes',
    'Microsoft.KubernetesConfiguration',
    'Microsoft.ManagedIdentity',
    'Microsoft.Network',
    'Microsoft.OperationalInsights',
    'Microsoft.OperationsManagement',
    'Microsoft.ResourceConnector',
    'Microsoft.Storage'
)
foreach ($providerNamespace in $requiredProviders) {
    for ($attempt = 1; $attempt -le 60; $attempt++) {
        $state = & az provider show --subscription $SubscriptionId --namespace $providerNamespace --query registrationState --output tsv --only-show-errors
        if ($LASTEXITCODE -ne 0) {
            throw "Unable to query resource provider $providerNamespace."
        }
        if ($state -eq 'Registered') {
            break
        }
        Write-Host "Waiting for resource provider $providerNamespace ($attempt/60): $state" -ForegroundColor Gray
        Start-Sleep -Seconds 10
    }
    if ($state -ne 'Registered') {
        throw "Resource provider $providerNamespace did not reach Registered state within 10 minutes (current state: $state)."
    }
}

$networkFeatureName = 'AllowBringYourOwnPublicIpAddress'
$networkFeatureState = & az feature show `
    --subscription $SubscriptionId `
    --namespace Microsoft.Network `
    --name $networkFeatureName `
    --query properties.state `
    --output tsv `
    --only-show-errors
if ($LASTEXITCODE -ne 0) {
    throw "Unable to query provider feature Microsoft.Network/$networkFeatureName."
}

if ($networkFeatureState -ne 'Registered') {
    Write-Host "Registering provider feature Microsoft.Network/$networkFeatureName..." -ForegroundColor Yellow
    Invoke-AzJson -Arguments @(
        'feature', 'register', '--subscription', $SubscriptionId,
        '--namespace', 'Microsoft.Network', '--name', $networkFeatureName
    ) | Out-Null

    for ($attempt = 1; $attempt -le 90; $attempt++) {
        Start-Sleep -Seconds 10
        $networkFeatureState = & az feature show `
            --subscription $SubscriptionId `
            --namespace Microsoft.Network `
            --name $networkFeatureName `
            --query properties.state `
            --output tsv `
            --only-show-errors
        if ($LASTEXITCODE -ne 0) {
            throw "Unable to query provider feature Microsoft.Network/$networkFeatureName."
        }
        if ($networkFeatureState -eq 'Registered') {
            break
        }
        Write-Host "Waiting for feature registration ($attempt/90): $networkFeatureState" -ForegroundColor Gray
    }
}

if ($networkFeatureState -ne 'Registered') {
    throw "Provider feature Microsoft.Network/$networkFeatureName did not reach Registered state within 15 minutes (current state: $networkFeatureState)."
}

Invoke-AzJson -Arguments @(
    'provider', 'register', '--subscription', $SubscriptionId,
    '--namespace', 'Microsoft.Network', '--wait'
) | Out-Null

$availableVmSize = & az vm list-sizes `
    --subscription $SubscriptionId `
    --location $Location `
    --query "[?name=='$VmSize'].name | [0]" `
    --output tsv `
    --only-show-errors
if ($LASTEXITCODE -ne 0) {
    throw "Unable to query VM size availability in $Location."
}
if ($availableVmSize -ne $VmSize) {
    throw "VM size $VmSize is unavailable in $Location."
}

$familyName = if ($VmSize -eq 'Standard_E32s_v6') { 'Standard Esv6 Family vCPUs' } else { 'Standard Esv5 Family vCPUs' }
$usageEntries = Invoke-AzJson -Arguments @(
    'vm', 'list-usage', '--subscription', $SubscriptionId, '--location', $Location
)
$usage = @($usageEntries | Where-Object { $_.name.localizedValue -eq $familyName }) | Select-Object -First 1
if (-not $usage -or ($usage.limit - $usage.currentValue) -lt 32) {
    throw "At least 32 unused $familyName vCPUs are required in $Location."
}

if ([string]::IsNullOrWhiteSpace($AzureLocalResourceProviderObjectId)) {
    $servicePrincipals = Invoke-AzJson -Arguments @(
        'ad', 'sp', 'list', '--filter', "appId eq '1412d89f-b8a8-4111-b4fd-e82905cbd85d'"
    )
    if ($servicePrincipals.Count -ne 1) {
        throw "Expected one Microsoft.AzureStackHCI resource-provider service principal, found $($servicePrincipals.Count)."
    }
    $AzureLocalResourceProviderObjectId = $servicePrincipals[0].id
}

$generatedPassword = $false
if ([string]::IsNullOrEmpty($WindowsAdminPassword) -and -not [string]::IsNullOrEmpty($env:LOCALBOX_ADMIN_PASSWORD)) {
    $WindowsAdminPassword = $env:LOCALBOX_ADMIN_PASSWORD
}
elseif ([string]::IsNullOrEmpty($WindowsAdminPassword)) {
    $WindowsAdminPassword = New-LocalBoxPassword
    $generatedPassword = $true
}

$resourceGroupExists = & az group exists `
    --subscription $SubscriptionId `
    --name $ResourceGroupName `
    --output tsv `
    --only-show-errors
if ($LASTEXITCODE -ne 0) {
    throw "Unable to determine whether resource group $ResourceGroupName exists."
}

if ($resourceGroupExists -eq 'true') {
    $resourceGroup = Invoke-AzJson -Arguments @(
        'group', 'show', '--subscription', $SubscriptionId, '--name', $ResourceGroupName
    )
    Invoke-AzJson -Arguments @(
        'group', 'update', '--subscription', $SubscriptionId, '--name', $ResourceGroupName,
        '--set', 'tags.workload=sovereign-localbox', 'tags.challenge=6', 'tags.SecurityControl=Ignore'
    ) | Out-Null
}
else {
    $resourceGroup = Invoke-AzJson -Arguments @(
        'group', 'create', '--subscription', $SubscriptionId, '--name', $ResourceGroupName,
        '--location', $Location, '--tags', 'workload=sovereign-localbox', 'challenge=6', 'SecurityControl=Ignore'
    )
}
Write-Host "Resource group ready: $($resourceGroup.name) ($($resourceGroup.location))" -ForegroundColor Green

$tempDirectory = Join-Path ([System.IO.Path]::GetTempPath()) "localbox-bicep-$([guid]::NewGuid())"
$parametersFile = Join-Path $tempDirectory 'localbox.parameters.json'
$templateFile = Join-Path $tempDirectory 'main.bicep'
$baseUri = "https://raw.githubusercontent.com/$GithubAccount/azure_arc/$GithubRef/azure_jumpstart_localbox/bicep"
$bicepFiles = @(
    'main.bicep',
    'mgmt/mgmtArtifacts.bicep',
    'mgmt/storageAccount.bicep',
    'mgmt/customerUsageAttribution.bicep',
    'network/network.bicep',
    'host/host.bicep'
)
$deploymentName = "localbox-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

try {
    foreach ($directory in @('', 'mgmt', 'network', 'host')) {
        New-Item -ItemType Directory -Path (Join-Path $tempDirectory $directory) -Force | Out-Null
    }
    foreach ($file in $bicepFiles) {
        Write-Host "Downloading LocalBox template: $file"
        Invoke-WebRequest -Uri "$baseUri/$file" -OutFile (Join-Path $tempDirectory $file) -UseBasicParsing
    }

    @{
        '$schema' = 'https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#'
        contentVersion = '1.0.0.0'
        parameters = @{
            windowsAdminUsername = @{ value = $WindowsAdminUsername }
            windowsAdminPassword = @{ value = $WindowsAdminPassword }
            spnProviderId = @{ value = $AzureLocalResourceProviderObjectId }
            tenantId = @{ value = $account.tenantId }
            location = @{ value = $Location }
            githubAccount = @{ value = $GithubAccount }
            githubBranch = @{ value = $GithubRef }
            azureLocalInstanceLocation = @{ value = $AzureLocalInstanceLocation }
            deployBastion = @{ value = $DeployBastion }
            vmSize = @{ value = $VmSize }
            tags = @{ value = @{
                Project = 'jumpstart_LocalBox'
                SecurityControl = 'Ignore'
            } }
            governResourceTags = @{ value = $false }
        }
    } | ConvertTo-Json -Depth 10 | Set-Content -Path $parametersFile -Encoding utf8NoBOM
    if (-not $IsWindows) {
        chmod 600 $parametersFile
    }

    Write-Host 'Compiling and validating LocalBox deployment...' -ForegroundColor Cyan
    & az bicep build --file $templateFile --stdout --only-show-errors | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw 'LocalBox Bicep compilation failed.'
    }
    Invoke-AzJson -Arguments @(
        'deployment', 'group', 'validate', '--subscription', $SubscriptionId,
        '--resource-group', $ResourceGroupName, '--name', $deploymentName,
        '--template-file', $templateFile, '--parameters', "@$parametersFile"
    ) | Out-Null

    Write-Host "Starting LocalBox deployment '$deploymentName'..." -ForegroundColor Cyan
    $deploymentArguments = @(
        'deployment', 'group', 'create', '--subscription', $SubscriptionId,
        '--resource-group', $ResourceGroupName, '--name', $deploymentName,
        '--template-file', $templateFile, '--parameters', "@$parametersFile"
    )
    if ($NoWait) {
        $deploymentArguments += '--no-wait'
    }
    Invoke-AzJson -Arguments $deploymentArguments | Out-Null

    $state = if ($NoWait) { 'Submitted' } else {
        & az deployment group show --subscription $SubscriptionId --resource-group $ResourceGroupName --name $deploymentName --query properties.provisioningState --output tsv --only-show-errors
    }
    Write-Host "LocalBox deployment state: $state" -ForegroundColor Green
    Write-Output ([pscustomobject]@{
        SubscriptionId = $SubscriptionId
        ResourceGroupName = $ResourceGroupName
        DeploymentName = $deploymentName
        Location = $Location
        VmName = 'LocalBox-Client'
        BastionName = if ($DeployBastion) { 'LocalBox-Bastion' } else { $null }
        ProvisioningState = $state
        GeneratedPassword = $generatedPassword
        WindowsAdminUsername = $WindowsAdminUsername
    })
}
finally {
    if (Test-Path $tempDirectory) {
        Remove-Item -Path $tempDirectory -Recurse -Force
    }
}