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

$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition

# Validate parameters
if($DeploymentType -eq 'resourcegroup' -and [string]::IsNullOrEmpty($ResourceGroupName)) {
    throw "ResourceGroupName must be provided when DeploymentType is 'resourcegroup'."
}

# set the effective location (example)
if($PreferredLocation.Count -gt 0) {
    $effectiveLocation = $PreferredLocation[0]
} else {
    $effectiveLocation = "swedencentral" # Default location if no preference is provided
}

# set the effective resource group based on deployment type (example)
if($DeploymentType -eq 'subscription') {
    $stableHash = Get-MhhStablehash $AllowedEntraUserIds -Length 24
    $effectiveResourceGroup = "lab-$stableHash"
    Write-Host "Deploying lab resources at the subscription level in subscription $SubscriptionId..."
    New-AzResourceGroup -Name $effectiveResourceGroup -Location $effectiveLocation -Verbose
}
else {
    $effectiveResourceGroup = $ResourceGroupName
}
# feed the effective resource group back to the console
@{"HackboxCredential" = @{ name = "ResourceGroupName" ; value = $effectiveResourceGroup; note = "The name of the resource group where lab resources are deployed" }}

# $template = Join-Path $scriptPath "template.bicep"
# $template = Join-Path $scriptPath "template.json"
# New-AzResourceGroupDeployment -ResourceGroupName $effectiveResourceGroup -TemplateFile $template -Verbose

# You can send back information to the hackbox console (credentials) - Simply return a hashtable like this:
# @{"HackboxCredential" = @{ name = "AdminPassword" ; value = "TopSecret"; note = "Useful info here" }}

