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

# Validate parameters
if($DeploymentType -eq 'resourcegroup' -and [string]::IsNullOrEmpty($ResourceGroupName)) {
    throw "ResourceGroupName must be provided when DeploymentType is 'resourcegroup'."
}

# set the effective location (used as the metadata location for the subscription-scoped deployment)
if($PreferredLocation.Count -gt 0) {
    $effectiveLocation = $PreferredLocation[0]
} else {
    $effectiveLocation = "swedencentral" # Default location if no preference is provided
}

# With deploymentType = resourcegroup the platform has already created one resource
# group per participant in the shared subscription and granted the participant Owner
# on it. Surface that resource group name on the participant's dashboard.
if(-not [string]::IsNullOrEmpty($ResourceGroupName)) {
    @{"HackboxCredential" = @{ name = "Resource Group Name"; value = $ResourceGroupName; note = "Your dedicated resource group (you have Owner)" }}
}

# Register the resource providers required by the Sovereign Cloud lab on the shared
# subscription (the platform has already set the Azure context to $SubscriptionId).
Write-Host "Registering required resource providers..."
& (Join-Path $PSScriptRoot 'resource-providers.ps1')

# Assign the lab-specific subscription-scoped RBAC (Security Reader + Resource Policy
# Contributor) to the participant.
# main.bicep targets the subscription scope, so it is deployed with New-AzSubscriptionDeployment.
$deploymentName = "lab-" + (Get-MhhStableHash -Value $AllowedEntraUserIds -Length 24)

Write-Host "Assigning subscription-scoped lab RBAC to participant $($AllowedEntraUserIds[0])..."
New-AzSubscriptionDeployment `
    -Name                    $deploymentName `
    -Location                $effectiveLocation `
    -TemplateFile            (Join-Path $PSScriptRoot 'main.bicep') `
    -TemplateParameterObject @{
        userObjectId = $AllowedEntraUserIds[0]
        resourceGroupName = $ResourceGroupName
    } | Out-Null