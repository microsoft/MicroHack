#Requires -Version 7.0
<#
.SYNOPSIS
Deploys the Azure Arc Jumpstart LocalBox environment used by the Sovereign Cloud lab.
.DESCRIPTION
Downloads upstream LocalBox Bicep templates and substitutes the lab's Developer
Bastion network module, then validates and deploys the environment.
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
.PARAMETER UseConsoleCredentials
Use the Console's stable LocalBox password instead of a supplied or random password.
It is not published as a participant credential. Coach/event-lead-only retrieval
requires a supported mechanism from the Console owner.
.PARAMETER GithubRef
The azure_arc branch, tag, or commit used for both Bicep and runtime artifacts.
.PARAMETER DeployBastion
Deploy Bastion Developer for one browser-based coach connection at a time.
The host remains private and retains NAT Gateway outbound access when enabled.
.PARAMETER AzureLocalResourceProviderObjectId
Optional tenant-specific object ID of the Microsoft.AzureStackHCI enterprise
application. The script resolves it through Microsoft Graph when omitted.
.PARAMETER AzureLocalInstanceLocation
Azure Local registration region, separate from the Azure host region.
Defaults to Australia East for the lab. The upstream staging storage account
also uses this region, independently of the Azure host region.
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

    [switch]$UseConsoleCredentials,

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

    # Preserve Azure's error details for the caller's regional fallback classifier.
    $PSNativeCommandUseErrorActionPreference = $false
    $output = @(& az @Arguments --only-show-errors --output json 2>&1)
    $exitCode = $LASTEXITCODE
    $stderr = @($output | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] })
    $stdout = ($output | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] }) -join "`n"
    $operation = ($Arguments | Select-Object -First 3) -join ' '
    if ($exitCode -ne 0) {
        throw "Azure CLI 'az $operation' failed (exit code ${exitCode}): $($stderr -join "`n")"
    }
    foreach ($message in $stderr) { Write-Warning "$message" }
    if ([string]::IsNullOrWhiteSpace($stdout)) {
        return $null
    }
    try { return $stdout | ConvertFrom-Json -ErrorAction Stop }
    catch {
        throw "Azure CLI 'az $operation' returned invalid JSON. Raw stdout and command arguments are omitted because they may contain sensitive data. Inspect deployment state before retrying."
    }
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

function Assert-LocalBoxNetworkCompatibility {
    param([string]$SubscriptionId, [string]$ResourceGroupName)

    $bastions = @(Invoke-AzJson -Arguments @(
        'network', 'bastion', 'list', '--subscription', $SubscriptionId, '--resource-group', $ResourceGroupName
    ))
    foreach ($bastion in @($bastions | Where-Object name -eq 'LocalBox-Bastion')) {
        if ($bastion.sku.name -ne 'Developer') {
            throw "Existing LocalBox-Bastion SKU '$($bastion.sku.name)' cannot be changed to Developer in place. Use a fresh resource group or arrange an explicitly approved delete/recreate migration. No existing Bastion was changed."
        }
    }
    $networks = @(Invoke-AzJson -Arguments @(
        'network', 'vnet', 'list', '--subscription', $SubscriptionId, '--resource-group', $ResourceGroupName
    ))
    $legacySubnets = @($networks | Where-Object name -eq 'LocalBox-VNet' |
        ForEach-Object { $_.subnets } | Where-Object name -eq 'AzureBastionSubnet')
    if ($legacySubnets.Count) {
        throw 'LocalBox-VNet contains a legacy AzureBastionSubnet. Use a fresh resource group or arrange an explicitly approved migration; this deployment will not automatically remove an existing Bastion subnet.'
    }
}

$networkTemplateFile = Join-Path $PSScriptRoot 'localbox-network.bicep'
if (-not (Test-Path -LiteralPath $networkTemplateFile -PathType Leaf)) {
    throw 'Missing localbox-network.bicep. Import the complete labautomation directory before deploying LocalBox.'
}
$startupSource = Join-Path $PSScriptRoot 'localbox-startup.ps1'
. $startupSource

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

$availableVmSizes = @(Invoke-AzJson -Arguments @(
    'vm', 'list-skus', '--subscription', $SubscriptionId, '--location', $Location,
    '--resource-type', 'virtualMachines', '--size', $VmSize, '--all'
) | Where-Object { $_.name -eq $VmSize })
if ($availableVmSizes.Count -ne 1 -or
    @($availableVmSizes[0].restrictions | Where-Object { $_.type -ne 'Zone' }).Count -gt 0) {
    throw "VM size $VmSize is unavailable in $Location for this subscription (missing SKU or regional restriction). No deployment was submitted."
}

$familyName = if ($VmSize -eq 'Standard_E32s_v6') { 'standardEsv6Family' } else { 'standardESv5Family' }
$usageEntries = Invoke-AzJson -Arguments @(
    'vm', 'list-usage', '--subscription', $SubscriptionId, '--location', $Location
)
$usage = @($usageEntries | Where-Object { $_.name.value -eq $familyName }) | Select-Object -First 1
if (-not $usage -or ($usage.limit - $usage.currentValue) -lt 32) {
    throw "At least 32 unused $familyName vCPUs are required in $Location."
}
$regionalUsage = @($usageEntries | Where-Object { $_.name.value -eq 'cores' }) | Select-Object -First 1
if (-not $regionalUsage -or ($regionalUsage.limit - $regionalUsage.currentValue) -lt 32) {
    throw "At least 32 unused regional vCPUs are required in $Location."
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
if ($UseConsoleCredentials) {
    if (-not [string]::IsNullOrEmpty($WindowsAdminPassword) -or -not [string]::IsNullOrEmpty($env:LOCALBOX_ADMIN_PASSWORD)) {
        throw 'UseConsoleCredentials cannot be combined with WindowsAdminPassword or LOCALBOX_ADMIN_PASSWORD.'
    }
    $WindowsAdminPassword = New-MhhStablePassword -Purpose 'localbox-admin-v1' -Length 24 -ErrorAction Stop
    if ([string]::IsNullOrWhiteSpace($WindowsAdminPassword)) {
        throw 'Console did not provide a LocalBox password.'
    }
}
elseif ([string]::IsNullOrEmpty($WindowsAdminPassword) -and -not [string]::IsNullOrEmpty($env:LOCALBOX_ADMIN_PASSWORD)) {
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
    Assert-LocalBoxNetworkCompatibility -SubscriptionId $SubscriptionId -ResourceGroupName $ResourceGroupName
    $resourceGroup = Invoke-AzJson -Arguments @(
        'group', 'show', '--subscription', $SubscriptionId, '--name', $ResourceGroupName
    )
    Invoke-AzJson -Arguments @(
        'group', 'update', '--subscription', $SubscriptionId, '--name', $ResourceGroupName,
        '--set', 'tags.workload=sovereign-localbox', 'tags.challenge=6', 'tags.SecurityControl=Ignore', 'tags.CostControl=Ignore'
    ) | Out-Null
}
else {
    $resourceGroup = Invoke-AzJson -Arguments @(
        'group', 'create', '--subscription', $SubscriptionId, '--name', $ResourceGroupName,
        '--location', $Location, '--tags', 'workload=sovereign-localbox', 'challenge=6', 'SecurityControl=Ignore', 'CostControl=Ignore'
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
    Copy-Item -LiteralPath $networkTemplateFile -Destination (Join-Path $tempDirectory 'network/network.bicep') -ErrorAction Stop
    if ($DeployBastion) {
        Write-Host 'Using Bastion Developer: one browser connection at a time; no native-client tunnels. Regional support is checked by ARM validation.' -ForegroundColor Cyan
    }

    $resourceTags = @{
        Project = 'jumpstart_LocalBox'
        SecurityControl = 'Ignore'
        CostControl = 'Ignore'
    }
    $clients = @(Invoke-AzJson -Arguments @('resource', 'list', '--subscription', $SubscriptionId,
        '--resource-group', $ResourceGroupName, '--resource-type', 'Microsoft.Compute/virtualMachines') |
        Where-Object name -eq 'LocalBox-Client')
    if ($clients.Count -gt 1) { throw 'Cannot uniquely identify the existing LocalBox Client.' }
    $newClient = $clients.Count -eq 0
    $startupId = [guid]::Empty
    if ($newClient) { $startupId = [guid]::NewGuid() }
    elseif ($clients[0].tags.'microhack-startup-version' -or $clients[0].tags.'microhack-startup-id') {
        if ($clients[0].tags.'microhack-startup-version' -ne '1' -or
            -not [guid]::TryParse([string]$clients[0].tags.'microhack-startup-id', [ref]$startupId) -or $startupId -eq [guid]::Empty) {
            throw 'Existing LocalBox startup-protection metadata is unrecognized. No bootstrap migration was attempted.'
        }
    }
    if ($startupId -ne [guid]::Empty) {
        $resourceTags['microhack-startup-version'] = '1'
        $resourceTags['microhack-startup-id'] = $startupId.ToString()
        Set-LocalBoxStartupTemplate -HostTemplate (Join-Path $tempDirectory 'host/host.bicep') `
            -StartupSource $startupSource -Id $startupId -NewVm:$newClient
        Write-Host 'Using correlated startup protection with bounded base-image downloads. Existing VM custom data is never replaced.'
    }
    else {
        $existingMonitors = @(Invoke-AzJson -Arguments @(
            'vm', 'run-command', 'list', '--subscription', $SubscriptionId,
            '--resource-group', $ResourceGroupName, '--vm-name', 'LocalBox-Client'
        ) | Where-Object name -eq 'sovereign-localbox-startup-watch')
        if ($existingMonitors.Count) {
            throw 'The existing Client has a startup monitor but no startup identity tags. Organizer review is required; no bootstrap migration was attempted.'
        }
        Write-Warning 'This existing Client predates startup protection. Its bootstrap is left unchanged; use a new VM to enable guarded startup.'
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
            tags = @{ value = $resourceTags }
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

    if ($startupId -ne [guid]::Empty) {
        # Upstream progress updates replace VM tags with the resource group's tags.
        Invoke-AzJson -Arguments @(
            'group', 'update', '--subscription', $SubscriptionId, '--name', $ResourceGroupName,
            '--set', 'tags.microhack-startup-version=1', "tags.microhack-startup-id=$startupId"
        ) | Out-Null
    }

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