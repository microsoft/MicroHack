<#
.SYNOPSIS
Deploys the lab resources scoped to a subscription or resource group.
.DESCRIPTION
Provides a controlled deployment flow for lab environments, optionally limited to a resource group and specific Entra user IDs.
.PARAMETER DeploymentType
Defines the deployment scope; allowed values are subscription, resourcegroup, or resourcegroup-with-subscriptionowner.
.PARAMETER SubscriptionId
Specifies the Azure subscription that contains the lab resources.
.PARAMETER ResourceGroupName
For resource group deployment, specifies the target resource group name.
.PARAMETER PreferredLocation
Specifies the preferred Azure regions, ordered by preference.
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

$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition

if($DeploymentType -eq 'resourcegroup' -and [string]::IsNullOrEmpty($ResourceGroupName)) {
    throw "ResourceGroupName must be provided when DeploymentType is 'resourcegroup'."
}

if($PreferredLocation.Count -gt 0) {
    $effectiveLocation = $PreferredLocation[0]
} else {
    $effectiveLocation = "swedencentral"
}

if($DeploymentType -eq 'subscription') {
    $stableHash = Get-MhhStablehash $AllowedEntraUserIds -Length 24
    $effectiveResourceGroup = "lab-$stableHash"
    Write-Host "Deploying lab resources at the subscription level in subscription $SubscriptionId..."
    if(-not (Get-AzResourceGroup -Name $effectiveResourceGroup -ErrorAction SilentlyContinue)) {
        Write-Host "Creating resource group '$effectiveResourceGroup' in location '$effectiveLocation'..."
        New-AzResourceGroup -Name $effectiveResourceGroup -Location $effectiveLocation -Verbose
    } else {
        Write-Host "Resource group '$effectiveResourceGroup' already exists."
    }
} else {
    $effectiveResourceGroup = $ResourceGroupName
}

if($AllowedEntraUserIds.Count -eq 0) {
    throw "At least one AllowedEntraUserIds value is required to assign lab access."
}

$resourceSuffix = Get-MhhStablehash $AllowedEntraUserIds -Length 12
$applicationInsightsName = "appi-fraud-$resourceSuffix"
$cosmosAccountName = "cosmosfraud$resourceSuffix"
$foundryAccountName = "aifraud$resourceSuffix"
$foundryProjectName = "fraud-intelligence"

@{"HackboxCredential" = @{ name = "ResourceGroupName"; value = $effectiveResourceGroup; note = "The name of the resource group where lab resources are deployed" }}
@{"HackboxCredential" = @{ name = "ApplicationInsightsName"; value = $applicationInsightsName; note = "The name of the Application Insights resource" }}
@{"HackboxCredential" = @{ name = "CosmosAccountName"; value = $cosmosAccountName; note = "The name of the Azure Cosmos DB account" }}
@{"HackboxCredential" = @{ name = "FoundryAccountName"; value = $foundryAccountName; note = "The name of the Microsoft Foundry account" }}
@{"HackboxCredential" = @{ name = "FoundryProjectName"; value = $foundryProjectName; note = "The name of the Microsoft Foundry project" }}
@{"HackboxCredential" = @{ name = "EffectiveLocation"; value = $effectiveLocation; note = "The effective Azure region for the lab deployment" }}

$template = Join-Path $scriptPath "main.bicep"
$templateParameters = @{
    location = $effectiveLocation
    resourceSuffix = $resourceSuffix
    userObjectId = $AllowedEntraUserIds[0]
}

Invoke-MhhDeploymentWithRegionFallback `
    -PreferredLocations $PreferredLocation `
    -ResourceGroupName $effectiveResourceGroup `
    -RgOwnerEntraObjectIds $AllowedEntraUserIds `
    -Tag @{ CostControl = "Ignore"; SecurityControl = "Ignore" } `
    -TemplateFile $template `
    -TemplateParameterObject $templateParameters
