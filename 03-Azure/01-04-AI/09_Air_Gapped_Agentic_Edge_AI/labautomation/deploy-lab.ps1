<#
.SYNOPSIS
Deploys the Air-Gapped Agentic Edge AI lab resources into a participant's resource group.
.DESCRIPTION
Provisions the Edge Host VM (Standard_D16s_v5 Ubuntu 24.04 with K3s),
Azure Bastion, Schema Registry Storage Account, and Key Vault, then emits
HackboxCredential entries to the participant dashboard.
.PARAMETER DeploymentType
Defines the deployment scope; allowed values are subscription, resourcegroup, or resourcegroup-with-subscriptionowner.
.PARAMETER SubscriptionId
Specifies the Azure subscription that contains the lab resources.
.PARAMETER ResourceGroupName
In case of resourcegroup deployment, specifies the target resource group name.
.PARAMETER PreferredLocation
Specifies the preferred Azure regions (ordered by preference) for resource deployment.
.PARAMETER AllowedEntraUserIds
Optional list of Entra user object IDs permitted to access the lab resources.
#>
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('subscription', 'resourcegroup', 'resourcegroup-with-subscriptionowner')]
    [string]$DeploymentType,

    [Parameter(Mandatory = $true)]
    [string]$SubscriptionId,

    [string]$ResourceGroupName = '',

    [string[]]$PreferredLocation = @(),

    [string[]]$AllowedEntraUserIds = @()
)

$ErrorActionPreference = 'Stop'
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
$templatePath = Join-Path (Split-Path -Parent $scriptPath) 'resources\infra\main.bicep'

if ($DeploymentType -ne 'subscription' -and [string]::IsNullOrEmpty($ResourceGroupName)) {
    throw "ResourceGroupName must be provided when DeploymentType is '$DeploymentType'."
}

$effectiveLocation = if ($PreferredLocation.Count -gt 0 -and -not [string]::IsNullOrWhiteSpace($PreferredLocation[0])) {
    $PreferredLocation[0]
}
else {
    'swedencentral'
}

if ($DeploymentType -eq 'subscription') {
    $stableHash = Get-MhhStableHash $AllowedEntraUserIds -Length 12
    $effectiveResourceGroup = "rg-edgeai-$stableHash"
    if (-not (Get-AzResourceGroup -Name $effectiveResourceGroup -ErrorAction SilentlyContinue)) {
        New-AzResourceGroup -Name $effectiveResourceGroup -Location $effectiveLocation | Out-Null
    }
}
else {
    $effectiveResourceGroup = $ResourceGroupName
}

$adminUsername = 'edgeadmin'
$adminPassword = New-MhhStablePassword -Seed "edgeai-$effectiveResourceGroup"
$participantObjectId = if ($AllowedEntraUserIds.Count -gt 0) { $AllowedEntraUserIds[0] } else { '' }

$deploymentResult = Invoke-MhhDeploymentWithRegionFallback `
    -PreferredLocations    $PreferredLocation `
    -ResourceGroupName     $effectiveResourceGroup `
    -RgOwnerEntraObjectIds $AllowedEntraUserIds `
    -TemplateFile          $templatePath `
    -TemplateParameterObject @{
        edgeProfile         = 'fast-k3s'
        adminUsername       = $adminUsername
        adminPasswordOrKey  = $adminPassword
        authType            = 'password'
        deployBastion       = $true
        participantObjectId = $participantObjectId
    }

$outputs = $deploymentResult.Outputs
$tenantId = (Get-AzContext).Tenant.Id
$rgPortalUrl = "https://portal.azure.com/#@$tenantId/resource/subscriptions/$SubscriptionId/resourceGroups/$effectiveResourceGroup/overview"
$vmPortalUrl = "https://portal.azure.com/#@$tenantId/resource/subscriptions/$SubscriptionId/resourceGroups/$effectiveResourceGroup/providers/Microsoft.Compute/virtualMachines/$($outputs.edgeVmName.Value)/connect"

@{ 'HackboxCredential' = @{ name = 'ResourceGroupName'; value = $effectiveResourceGroup; note = 'Lab Resource Group containing the Edge Host VM and supporting resources' } }
@{ 'HackboxCredential' = @{ name = 'AzurePortalResourceGroupUrl'; value = $rgPortalUrl; note = 'Direct link to your lab Resource Group in the Azure Portal' } }
@{ 'HackboxCredential' = @{ name = 'EdgeHostVmName'; value = $outputs.edgeVmName.Value; note = 'Ubuntu 24.04 K3s Edge Host VM (connect via Azure Bastion)' } }
@{ 'HackboxCredential' = @{ name = 'AzurePortalEdgeVmUrl'; value = $vmPortalUrl; note = 'Direct link to connect to your Edge Host VM via Azure Bastion' } }
@{ 'HackboxCredential' = @{ name = 'EdgeHostAdminUsername'; value = $adminUsername; note = 'SSH / Bastion username for the Edge Host VM' } }
@{ 'HackboxCredential' = @{ name = 'EdgeHostAdminPassword'; value = $adminPassword; note = 'SSH / Bastion password for the Edge Host VM' } }
@{ 'HackboxCredential' = @{ name = 'ArcClusterName'; value = $outputs.arcClusterSuggestedName.Value; note = 'Suggested name when onboarding K3s to Azure Arc in Challenge 1' } }
@{ 'HackboxCredential' = @{ name = 'ArcControlPlaneLocation'; value = 'westeurope'; note = 'Supported region for Azure Arc, Device Registry, and Azure IoT Operations control-plane resources' } }
@{ 'HackboxCredential' = @{ name = 'SchemaStorageAccount'; value = $outputs.schemaStorageAccountName.Value; note = 'HNS-enabled Storage Account for Azure IoT Operations Schema Registry' } }
@{ 'HackboxCredential' = @{ name = 'EdgeManagedIdentityClientId'; value = $outputs.userAssignedIdentityClientId.Value; note = 'Client ID of the User-Assigned Managed Identity attached to the Edge Host VM' } }
