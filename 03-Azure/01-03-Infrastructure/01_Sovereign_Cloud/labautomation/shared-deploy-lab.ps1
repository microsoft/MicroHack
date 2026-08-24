<#
.SYNOPSIS
Prepares a subscription for Sovereign Cloud MicroHack labs.
.DESCRIPTION
Runs once per subscription before participant lab deployments and registers the
required Azure resource providers. It ensures one preferred region has exactly
the DCasv6 quota required by the subscription's participant count. LocalBox
deployment is temporarily disabled.
#>
param(
    [Parameter(Mandatory=$true)]
    [string]$SubscriptionId,

    [Parameter(Mandatory=$true)]
    [string[]]$PreferredLocation,

    [Parameter(Mandatory=$false)]
    [string[]]$AllowedEntraUserIds = @()
)

. (Join-Path $PSScriptRoot 'quota-helpers.ps1')

Write-Host "Preparing subscription $SubscriptionId for Sovereign Cloud labs..."
& (Join-Path $PSScriptRoot 'resource-providers.ps1')

if (-not $?) {
    throw "Resource provider registration failed for subscription $SubscriptionId."
}

$defaults = Get-Content (Join-Path $PSScriptRoot 'lab-defaults.json') -Raw | ConvertFrom-Json
if($PreferredLocation.Count -eq 0) {
    $PreferredLocation = @($defaults.preferredLocation)
}
$PreferredLocation = @($PreferredLocation | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })

$participantCount = @($AllowedEntraUserIds | Where-Object { $_ } | Select-Object -Unique).Count
if($participantCount -eq 0) {
    $participantCount = $defaults.labsPerSubscription
}
if($participantCount -lt 1) {
    throw 'Unable to determine the number of participants for confidential compute quota preparation.'
}

$confidentialVmSize = 'Standard_DC2as_v6'
$confidentialQuotaName = 'standardDCasv6Family'
$confidentialVcpusPerParticipant = 4
$confidentialQuotaRequired = $confidentialVcpusPerParticipant * $participantCount
$quotaReadyLocation = $null
$quotaReadinessSummary = @()

for($attempt = 1; $attempt -le 30; $attempt++) {
    Update-MhhToken | Out-Null
    $quotaProvider = Get-AzResourceProvider -ProviderNamespace Microsoft.Quota -ErrorAction Stop
    if($quotaProvider.RegistrationState -eq 'Registered') {
        break
    }
    Write-Host "Waiting for Microsoft.Quota registration ($attempt/30)..."
    Start-Sleep -Seconds 10
}
if($quotaProvider.RegistrationState -ne 'Registered') {
    throw 'Microsoft.Quota did not reach Registered state within 5 minutes.'
}

foreach($candidateLocation in $PreferredLocation) {
    Update-MhhToken | Out-Null
    $skuAvailable = Get-AzComputeResourceSku -Location $candidateLocation -ErrorAction Stop |
        Where-Object {
            $_.ResourceType -ieq 'virtualMachines' -and
            $_.Name -ieq $confidentialVmSize -and
            -not ($_.Restrictions | Where-Object { $_.Type -ieq 'Location' })
        } |
        Select-Object -First 1

    if($null -eq $skuAvailable) {
        $quotaReadinessSummary += "${candidateLocation}: $confidentialVmSize unavailable"
        continue
    }

    $quota = Get-AzVMUsage -Location $candidateLocation -ErrorAction Stop |
        Where-Object { $_.Name.Value -ieq $confidentialQuotaName } |
        Select-Object -First 1
    $current = if($null -eq $quota) { 0 } else { $quota.CurrentValue }
    $limit = if($null -eq $quota) { 0 } else { $quota.Limit }
    $available = $limit - $current

    if($available -ge $confidentialQuotaRequired) {
        $quotaReadyLocation = $candidateLocation
        $quotaReadinessSummary += "${candidateLocation}: ${available} DCasv6 vCPUs available"
        break
    }

    $newLimit = $current + $confidentialQuotaRequired
    Write-Host "Requesting exactly $newLimit $confidentialQuotaName vCPUs in $candidateLocation for $participantCount participants..."
    $quotaResult = Request-MhhComputeQuota `
        -SubscriptionId $SubscriptionId `
        -Location $candidateLocation `
        -QuotaName $confidentialQuotaName `
        -NewLimit $newLimit

    if($quotaResult.Succeeded) {
        $quotaReadyLocation = $candidateLocation
        $quotaReadinessSummary += "${candidateLocation}: quota request succeeded with limit $newLimit"
        break
    }

    $quotaReadinessSummary += "${candidateLocation}: $($quotaResult.State) $($quotaResult.ErrorCode) $($quotaResult.Message)"
    Write-Warning "DCasv6 quota request failed in ${candidateLocation}: $($quotaResult.ErrorCode) - $($quotaResult.Message)"
}

if(-not $quotaReadyLocation) {
    throw "No preferred region has the required $confidentialQuotaRequired DCasv6 vCPUs for $participantCount participants ($($quotaReadinessSummary -join '; '))."
}

Write-Host "DCasv6 quota is ready in $quotaReadyLocation for $participantCount participants." -ForegroundColor Green
<#

The Sovereign Cloud shared deployment needs to resolve the tenant-specific object ID of the Microsoft.AzureStackHCI enterprise application (appId: 1412d89f-b8a8-4111-b4fd-e82905cbd85d).
Disabled Localbox until this is resolved, as the deployment will fail with an InsufficientPermissions error when the service principal cannot be resolved.

$localBoxResourceGroupName = 'rg-localbox-shared'
$localBoxLocation = if ($PreferredLocation.Count -gt 0) { $PreferredLocation[0] } else { 'swedencentral' }
$activeDeploymentStates = @('Accepted', 'Running', 'Ready', 'Creating', 'Created', 'Succeeded')
$resourceGroup = Get-AzResourceGroup -Name $localBoxResourceGroupName -ErrorAction SilentlyContinue
$localBoxDeployment = if ($resourceGroup) {
    Get-AzResourceGroupDeployment `
        -ResourceGroupName $localBoxResourceGroupName `
        -ErrorAction Stop |
        Where-Object {
            $_.DeploymentName -like 'localbox-*' -and
            $_.ProvisioningState -in $activeDeploymentStates
        } |
        Sort-Object Timestamp -Descending |
        Select-Object -First 1
}

if ($localBoxDeployment) {
    Write-Host "Reusing LocalBox deployment '$($localBoxDeployment.DeploymentName)' ($($localBoxDeployment.ProvisioningState))." -ForegroundColor Green
}
else {
    Write-Host "Submitting shared LocalBox deployment in $localBoxLocation..." -ForegroundColor Cyan
    $localBoxDeployment = & (Join-Path $PSScriptRoot 'deploy-localbox.ps1') `
        -SubscriptionId $SubscriptionId `
        -ResourceGroupName $localBoxResourceGroupName `
        -Location $localBoxLocation `
        -NoWait

    if (-not $? -or -not $localBoxDeployment -or $localBoxDeployment.ProvisioningState -ne 'Submitted') {
        throw "LocalBox deployment submission failed for subscription $SubscriptionId."
    }
}


$localBoxScope = "/subscriptions/$SubscriptionId/resourceGroups/$localBoxResourceGroupName"
foreach ($participantObjectId in $AllowedEntraUserIds) {
    foreach ($roleName in @('Reader', 'Azure Stack HCI VM Contributor')) {
        $roleAssignment = Get-AzRoleAssignment `
            -ObjectId $participantObjectId `
            -RoleDefinitionName $roleName `
            -Scope $localBoxScope `
            -ErrorAction SilentlyContinue

        if (-not $roleAssignment) {
            Write-Host "Assigning '$roleName' on shared LocalBox to $participantObjectId..."
            New-AzRoleAssignment `
                -ObjectId $participantObjectId `
                -RoleDefinitionName $roleName `
                -Scope $localBoxScope `
                -ErrorAction Stop | Out-Null
        }
    }
}

@{
    'HackboxCredential' = @{
        name = 'Shared LocalBox Resource Group'
        value = $localBoxResourceGroupName
        note = 'Shared Challenge 6 environment; readiness is verified by the facilitator'
    }
}
#>