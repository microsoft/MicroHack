<#
.SYNOPSIS
Deploys the lab resources scoped to a subscription or resource group.
.DESCRIPTION
Provides a controlled deployment flow for lab environments, optionally limited to a resource group and specific Entra user IDs.
.PARAMETER DeploymentType
Defines the deployment scope; allowed values are subscription or resourcegroup.
.PARAMETER SubscriptionId
Specifies the Azure subscription that contains the lab resources.
.PARAMETER ResourceGroupName
In case of resourcegroup deployment, specifies the target resource group name.
.PARAMETER PreferredLocation
Specifies the preferred Azure regions (ordered by preference) for resource deployment. An empty array indicates no preference.
.PARAMETER AllowedEntraUserIds
Optional list of Entra user object IDs permitted to access the lab resources.
#>
param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('subscription','resourcegroup', 'resourcegroup-with-subscriptionowner')]
    [string]$DeploymentType,
    
    [Parameter(Mandatory=$true)]
    [string]$SubscriptionId,

    [string]$ResourceGroupName = "",

    [string[]]$PreferredLocation = @(),

    [string[]]$AllowedEntraUserIds = @()
)

$ErrorActionPreference = 'Stop'

$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
Write-Host "[$SubscriptionId] Running deploy-lab.ps1 in $scriptPath"

# Lab environment configuration
$environmentName = "sqlhack"
$sharedResourceGroupName = "rg-sqlhack-shared"
$adminUsername = "DemoUser"
$adminPassword = New-MhhStablePassword -Purpose 'vm-admin' -SubscriptionId $SubscriptionId -ResourceGroupName "Default"

# Template file path
$templatePath = Join-Path $scriptPath "infra"
$template = Join-Path $templatePath "main.bicep"
Write-Host "[$SubscriptionId] Deploying lab resources from template $template"

#if ($AllowedEntraUserIds.Count -eq 0) {
#    throw "No Entra user object ID was provided. The MicroHack platform must pass at least one value in AllowedEntraUserIds."
#}

# set the effective location (example)
if($PreferredLocation.Count -gt 0) {
    $effectiveLocation = $PreferredLocation[0]
} else {
    $effectiveLocation = "swedencentral" # Default location if no preference is provided
}
$deploymentLocations = if ($PreferredLocation.Count -gt 0) { $PreferredLocation } else { @($effectiveLocation) }

# set the effective resource group based on deployment type (example)
if($DeploymentType -eq 'subscription') {
    $stableHash = Get-MhhStableHash -Value $AllowedEntraUserIds -Length 24
    $effectiveResourceGroup = "lab-$stableHash"
    Write-Host "Deploying lab resources at the subscription level in subscription $SubscriptionId..."
    if(-not (Get-AzResourceGroup -Name $effectiveResourceGroup -ErrorAction SilentlyContinue)) {
        Write-Host "Creating resource group '$effectiveResourceGroup' in location '$effectiveLocation'..."
        New-AzResourceGroup -Name $effectiveResourceGroup -Location $effectiveLocation -Verbose
    } else {
        Write-Host "Resource group '$effectiveResourceGroup' already exists."
    }
}
else {
    if ([string]::IsNullOrWhiteSpace($ResourceGroupName)) {
        throw "ResourceGroupName is empty for deployment type '$DeploymentType'. The MicroHack platform must provide the participant resource group."
    }
    $effectiveResourceGroup = $ResourceGroupName
}

Write-Host "[$SubscriptionId] Deploying to user: $($AllowedEntraUserIds[0])"

$me = Get-MhhLabUser -UserId @($AllowedEntraUserIds)[0]
Write-Host "Deploying for $($me.UserPrincipalName) ($($me.ShortName))"
$vmPostfix = "$(($me.ShortName -split "\.")[0])"
if ($vmPostfix.Length -gt 12) {
    $vmPostfix = $vmPostfix.Substring(0,12)
}
$vmPostfix = $vmPostfix -replace "_", "-"
$vmName = "VM-$vmPostfix"
$TeamName = $me.ShortName
$TeamName = $TeamName.ToUpper()
$legacySQLName = "legacySQL2016"


$storageAccountName = Get-AzStorageAccount -ResourceGroupName $sharedResourceGroupName -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty StorageAccountName
$managedInstanceFQDN = Get-AzSqlInstance -ResourceGroupName $sharedResourceGroupName -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullyQualifiedDomainName

Write-Host "[$SubscriptionId] Using storage account: $storageAccountName"
Write-Host "[$SubscriptionId] Using managed instance FQDN: $managedInstanceFQDN"
Write-Host "[$SubscriptionId] Using Computer Name: $vmName"

# Deploy lab resources using Invoke-MhhDeploymentWithRegionFallback
$result = Invoke-MhhDeploymentWithRegionFallback `
    -PreferredLocations      $deploymentLocations `
    -ResourceGroupName       $effectiveResourceGroup `
    -RgOwnerEntraObjectIds   $AllowedEntraUserIds `
    -TemplateFile            $template `
    -TemplateParameterObject @{
        environmentName           = $environmentName
        location                  = $effectiveLocation
        sharedResourceGroupName   = $sharedResourceGroupName
        adminUsername             = $adminUsername
        adminPassword             = $adminPassword
        storageAccountName        = $storageAccountName
        managedInstanceFQDN       = $managedInstanceFQDN
        vmName                    = $vmName
        TeamName                  = $TeamName
        legacySQLName             = $legacySQLName
    }

Write-Host "[$SubscriptionId] Lab deployment completed successfully"
Write-Host "[$SubscriptionId] Lab Resource Group: $effectiveResourceGroup"
Write-Host "[$SubscriptionId] Shared Resource Group: $sharedResourceGroupName"
Write-Host "[$SubscriptionId] Result: $($result)"

# feed the effective resource group back to the console
@{"HackboxCredential" = @{ name = "ResourceGroupName" ; value = $effectiveResourceGroup; note = "The name of the resource group where lab resources are deployed" }}
@{"HackboxCredential" = @{ name = "Team VM Name" ; value = $vmName; note = "The name of the Team VM" }}
@{"HackboxCredential" = @{ name = "Team / Link Name" ; value = $TeamName; note = "Name of the Team (Prefix for DBs and to use as Link Name for SQLMI)" }}
