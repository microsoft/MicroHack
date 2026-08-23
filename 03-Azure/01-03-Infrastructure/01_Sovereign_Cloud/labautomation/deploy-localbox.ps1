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

    [ValidateSet('australiaeast', 'southcentralus', 'eastus', 'westeurope', 'southeastasia', 'canadacentral', 'japaneast', 'centralindia')]
    [string]$AzureLocalInstanceLocation = 'westeurope',

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
    $state = & az provider show --subscription $SubscriptionId --namespace $providerNamespace --query registrationState --output tsv --only-show-errors
    if ($LASTEXITCODE -ne 0 -or $state -ne 'Registered') {
        throw "Resource provider $providerNamespace must be registered before deploying LocalBox (current state: $state)."
    }
}

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

$servicePrincipals = Invoke-AzJson -Arguments @(
    'ad', 'sp', 'list', '--display-name', 'Microsoft.AzureStackHCI',
    '--query', "[?appId=='1412d89f-b8a8-4111-b4fd-e82905cbd85d']"
)
if ($servicePrincipals.Count -ne 1) {
    throw "Expected one Microsoft.AzureStackHCI resource-provider service principal, found $($servicePrincipals.Count)."
}

$generatedPassword = $false
if ([string]::IsNullOrEmpty($WindowsAdminPassword) -and -not [string]::IsNullOrEmpty($env:LOCALBOX_ADMIN_PASSWORD)) {
    $WindowsAdminPassword = $env:LOCALBOX_ADMIN_PASSWORD
}
elseif ([string]::IsNullOrEmpty($WindowsAdminPassword)) {
    $WindowsAdminPassword = New-LocalBoxPassword
    $generatedPassword = $true
}

$resourceGroup = Invoke-AzJson -Arguments @(
    'group', 'create', '--subscription', $SubscriptionId, '--name', $ResourceGroupName,
    '--location', $Location, '--tags', 'workload=sovereign-localbox', 'challenge=6'
)
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
            spnProviderId = @{ value = $servicePrincipals[0].id }
            tenantId = @{ value = $account.tenantId }
            location = @{ value = $Location }
            githubAccount = @{ value = $GithubAccount }
            githubBranch = @{ value = $GithubRef }
            azureLocalInstanceLocation = @{ value = $AzureLocalInstanceLocation }
            deployBastion = @{ value = $DeployBastion }
            vmSize = @{ value = $VmSize }
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