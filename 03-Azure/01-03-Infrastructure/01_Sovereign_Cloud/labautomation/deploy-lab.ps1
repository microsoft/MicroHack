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
if($DeploymentType -in @('resourcegroup', 'resourcegroup-with-subscriptionowner') -and [string]::IsNullOrEmpty($ResourceGroupName)) {
    throw "ResourceGroupName must be provided for a resource-group deployment."
}

if($AllowedEntraUserIds.Count -eq 0) {
    throw "AllowedEntraUserIds must contain at least one participant object ID."
}

$stableHash = Get-MhhStableHash -Value $AllowedEntraUserIds -Length 24
if($DeploymentType -eq 'subscription') {
    $ResourceGroupName = "rg-sovereign-$($stableHash.Substring(0, 8))"
}

# set the effective location (used as the metadata location for the subscription-scoped deployment)
if($PreferredLocation.Count -gt 0) {
    $deploymentLocations = $PreferredLocation
} else {
    $deploymentLocations = @('swedencentral')
}
$effectiveLocation = $deploymentLocations[0]

# With deploymentType = resourcegroup the platform has already created one resource
# group per participant in the shared subscription and granted the participant Owner
# on it. In subscription mode this script creates a stable resource group instead.
@{"HackboxCredential" = @{ name = "Resource Group Name"; value = $ResourceGroupName; note = "Your dedicated resource group (you have Owner)" }}

# Provider registration is initiated once per subscription by shared-deploy-lab.ps1.
# Registration is asynchronous, so verify the providers required by Challenge 7.
$adaptiveAppsProviders = @(
    'Microsoft.Compute',
    'Microsoft.ContainerService',
    'Microsoft.ManagedIdentity',
    'Microsoft.Network'
)
foreach($providerNamespace in $adaptiveAppsProviders) {
    $registered = $false
    for($attempt = 1; $attempt -le 30; $attempt++) {
        Update-MhhToken | Out-Null
        $provider = Get-AzResourceProvider -ProviderNamespace $providerNamespace -ErrorAction Stop
        if($provider.RegistrationState -eq 'Registered') {
            $registered = $true
            break
        }
        Write-Host "Waiting for $providerNamespace registration ($attempt/30)..."
        Start-Sleep -Seconds 10
    }
    if(-not $registered) {
        throw "Resource provider $providerNamespace did not reach Registered state within 5 minutes."
    }
}

# Deploy the Adaptive Apps topology first. The helper recreates the resource group
# on retries, so subscription and resource-group role assignments are applied after it.
$nameSuffix = $stableHash.Substring(0, 8)
$k3sAdminPassword = New-MhhStablePassword -Purpose 'adaptive-apps-k3s-admin' -Length 24

Write-Host "Deploying the Challenge 7 AKS and private K3s platforms..."
$adaptiveAppsResult = Invoke-MhhDeploymentWithRegionFallback `
    -PreferredLocations      $deploymentLocations `
    -ResourceGroupName       $ResourceGroupName `
    -RgOwnerEntraObjectIds   $AllowedEntraUserIds `
    -TemplateFile            (Join-Path $PSScriptRoot 'adaptive-apps.bicep') `
    -TemplateParameterObject @{
        nameSuffix = $nameSuffix
        adminPassword = $k3sAdminPassword
    } `
    -DeploymentNamePrefix    'adaptive-apps' `
    -Tag                     @{
        workload = 'sovereign-adaptive-apps'
        challenge = '7'
    }

# Assign the lab-specific subscription-scoped RBAC (Security Reader + Resource Policy
# Contributor) and resource-group roles after region fallback has recreated the RG.
$deploymentName = "lab-$stableHash"

Write-Host "Assigning subscription-scoped lab RBAC to participant $($AllowedEntraUserIds[0])..."
New-AzSubscriptionDeployment `
    -Name                    $deploymentName `
    -Location                $effectiveLocation `
    -TemplateFile            (Join-Path $PSScriptRoot 'main.bicep') `
    -TemplateParameterObject @{
        userObjectId = $AllowedEntraUserIds[0]
        resourceGroupName = $ResourceGroupName
    } | Out-Null

@{"HackboxCredential" = @{ name = "Adaptive Apps Region"; value = $adaptiveAppsResult.LocationUsed; note = "Region selected after capacity checks" }}
@{"HackboxCredential" = @{ name = "Adaptive Apps AKS Cluster"; value = $adaptiveAppsResult.Outputs.aksClusterName; note = "Azure execution environment" }}
@{"HackboxCredential" = @{ name = "Adaptive Apps K3s VM"; value = $adaptiveAppsResult.Outputs.k3sVmName; note = "Private local/edge execution environment" }}
@{"HackboxCredential" = @{ name = "Adaptive Apps Bastion"; value = $adaptiveAppsResult.Outputs.bastionName; note = "Use native-client tunneling to reach K3s" }}
@{"HackboxCredential" = @{ name = "K3s VM Admin Username"; value = "azureuser"; note = $adaptiveAppsResult.Outputs.k3sVmName }}
@{"HackboxCredential" = @{ name = "K3s VM Admin Password"; value = $k3sAdminPassword; note = $adaptiveAppsResult.Outputs.k3sVmName }}
@{"HackboxCredential" = @{ name = "K3s NAT Egress IP"; value = $adaptiveAppsResult.Outputs.natEgressIp; note = "Deterministic outbound address" }}