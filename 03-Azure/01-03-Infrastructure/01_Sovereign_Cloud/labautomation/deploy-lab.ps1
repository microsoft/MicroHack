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

$confidentialVmSize = 'Standard_DC2as_v6'
$confidentialQuotaRequired = 4
$eligibleDeploymentLocations = @()
$regionReadinessSummary = @()
foreach($candidateLocation in $deploymentLocations) {
    $skuAvailable = Get-AzComputeResourceSku -Location $candidateLocation -ErrorAction Stop |
        Where-Object {
            $_.ResourceType -ieq 'virtualMachines' -and
            $_.Name -ieq $confidentialVmSize -and
            -not ($_.Restrictions | Where-Object { $_.Type -ieq 'Location' })
        } |
        Select-Object -First 1

    if($null -eq $skuAvailable) {
        $regionReadinessSummary += "${candidateLocation}: $confidentialVmSize unavailable"
        Write-Warning "Skipping $candidateLocation because $confidentialVmSize is unavailable for this subscription."
        continue
    }

    $quota = Get-AzVMUsage -Location $candidateLocation -ErrorAction Stop |
        Where-Object { $_.Name.Value -ieq 'standardDCasv6Family' } |
        Select-Object -First 1

    $current = if($null -eq $quota) { 0 } else { $quota.CurrentValue }
    $limit = if($null -eq $quota) { 0 } else { $quota.Limit }
    $available = $limit - $current
    $regionReadinessSummary += "${candidateLocation}: $confidentialVmSize available, ${current}/${limit} DCasv6 vCPUs used"

    if($available -ge $confidentialQuotaRequired) {
        $eligibleDeploymentLocations += $candidateLocation
    } else {
        Write-Warning "Skipping $candidateLocation because only $available of $confidentialQuotaRequired required Standard DCasv6 Family vCPUs are available."
    }
}

if($eligibleDeploymentLocations.Count -eq 0) {
    throw "No preferred region satisfies the confidential compute requirements ($($regionReadinessSummary -join '; ')). Ensure $confidentialVmSize is available and request at least $confidentialQuotaRequired available Standard DCasv6 Family vCPUs per participant in one configured region before rerunning Step 2."
}

$deploymentLocations = $eligibleDeploymentLocations
$effectiveLocation = $deploymentLocations[0]

# With deploymentType = resourcegroup the platform has already created one resource
# group per participant in the shared subscription and granted the participant Owner
# on it. In subscription mode this script creates a stable resource group instead.
@{"HackboxCredential" = @{ name = "Resource Group Name"; value = $ResourceGroupName; note = "Your dedicated resource group (you have Owner)" }}

# Provider registration is initiated once per subscription by shared-deploy-lab.ps1.
# Registration is asynchronous, so verify the providers required by the shared lab.
$sovereignLabProviders = @(
    'Microsoft.Attestation',
    'Microsoft.Compute',
    'Microsoft.ContainerService',
    'Microsoft.ManagedIdentity',
    'Microsoft.Network'
)
foreach($providerNamespace in $sovereignLabProviders) {
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

# Deploy the shared Sovereign Cloud topology first. The helper recreates the resource group
# on retries, so subscription and resource-group role assignments are applied after it.
$nameSuffix = $stableHash.Substring(0, 8)
$k3sAdminPassword = New-MhhStablePassword -Purpose 'adaptive-apps-k3s-admin' -Length 24
$cvmAdminPassword = New-MhhStablePassword -Purpose 'sovereign-cvm-admin' -Length 24

Write-Host "Deploying the shared Sovereign Cloud platform for Challenges 4, 5, and 7..."
$sovereignLabResult = Invoke-MhhDeploymentWithRegionFallback `
    -PreferredLocations      $deploymentLocations `
    -ResourceGroupName       $ResourceGroupName `
    -RgOwnerEntraObjectIds   $AllowedEntraUserIds `
    -TemplateFile            (Join-Path $PSScriptRoot 'sovereign-lab.bicep') `
    -TemplateParameterObject @{
        nameSuffix = $nameSuffix
        adminPassword = $k3sAdminPassword
        cvmAdminPassword = $cvmAdminPassword
        confidentialVmSize = $confidentialVmSize
    } `
    -DeploymentNamePrefix    'sovereign-lab' `
    -Tag                     @{
        workload = 'sovereign-lab'
        challenges = '4,5,7'
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

@{"HackboxCredential" = @{ name = "Sovereign Lab Region"; value = $sovereignLabResult.LocationUsed; note = "Region selected after capacity checks" }}
@{"HackboxCredential" = @{ name = "Sovereign Lab AKS Cluster"; value = $sovereignLabResult.Outputs.aksClusterName; note = "Shared by Challenges 5 and 7" }}
@{"HackboxCredential" = @{ name = "AKS Confidential Node Pool"; value = $sovereignLabResult.Outputs.confidentialNodePoolName; note = "Challenge 5" }}
@{"HackboxCredential" = @{ name = "Confidential VM"; value = $sovereignLabResult.Outputs.confidentialVmName; note = "Challenge 4" }}
@{"HackboxCredential" = @{ name = "Confidential VM Admin Username"; value = "azureuser"; note = $sovereignLabResult.Outputs.confidentialVmName }}
@{"HackboxCredential" = @{ name = "Confidential VM Admin Password"; value = $cvmAdminPassword; note = $sovereignLabResult.Outputs.confidentialVmName }}
@{"HackboxCredential" = @{ name = "Attestation Provider"; value = $sovereignLabResult.Outputs.attestationProviderName; note = $sovereignLabResult.Outputs.attestationProviderUri }}
@{"HackboxCredential" = @{ name = "Sovereign Lab K3s VM"; value = $sovereignLabResult.Outputs.k3sVmName; note = "Private local/edge execution environment" }}
@{"HackboxCredential" = @{ name = "Sovereign Lab Bastion"; value = $sovereignLabResult.Outputs.bastionName; note = "Shared private access path" }}
@{"HackboxCredential" = @{ name = "K3s VM Admin Username"; value = "azureuser"; note = $sovereignLabResult.Outputs.k3sVmName }}
@{"HackboxCredential" = @{ name = "K3s VM Admin Password"; value = $k3sAdminPassword; note = $sovereignLabResult.Outputs.k3sVmName }}
@{"HackboxCredential" = @{ name = "K3s NAT Egress IP"; value = $sovereignLabResult.Outputs.natEgressIp; note = "Deterministic outbound address" }}