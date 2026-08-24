<#
.SYNOPSIS
Prepares a subscription for Sovereign Cloud MicroHack labs.
.DESCRIPTION
Runs once per subscription before participant lab deployments and registers the
required Azure resource providers. It ensures one preferred region has the VM
SKUs and compute quota required by the subscription's participant count.
LocalBox deployment is temporarily disabled.
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

$confidentialCandidates = @(Get-MhhConfidentialComputeCandidates -PreferredLocation $PreferredLocation)
$selectedCandidate = $null
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

foreach($candidate in $confidentialCandidates) {
    Update-MhhToken | Out-Null
    $candidateLocation = $candidate.Location
    $requiredVmSizes = @($candidate.VmSize, 'Standard_D4s_v5')
    $availableVmSizes = Get-AzComputeResourceSku -Location $candidateLocation -ErrorAction Stop |
        Where-Object {
            $_.ResourceType -ieq 'virtualMachines' -and
            $_.Name -iin $requiredVmSizes -and
            -not ($_.Restrictions | Where-Object { $_.Type -ieq 'Location' })
        } |
        Select-Object -ExpandProperty Name -Unique
    $unavailableVmSizes = @($requiredVmSizes | Where-Object { $_ -inotin $availableVmSizes })

    if($unavailableVmSizes.Count -gt 0) {
        $quotaReadinessSummary += "$candidateLocation/$($candidate.VmSize): unavailable VM sizes $($unavailableVmSizes -join ', ')"
        continue
    }

    $regionalUsage = Get-AzVMUsage -Location $candidateLocation -ErrorAction Stop
    $locationReady = $true
    $quotaRequirements = @(
        @{ Name = $candidate.QuotaName; PerParticipant = 4 }
        @{ Name = 'StandardDSv5Family'; PerParticipant = 12 }
        @{ Name = 'cores'; PerParticipant = 16 }
    )
    foreach($requirement in $quotaRequirements) {
        $quotaName = $requirement.Name
        $quotaRequired = $requirement.PerParticipant * $participantCount
        $quota = $regionalUsage |
            Where-Object { $_.Name.Value -ieq $quotaName } |
            Select-Object -First 1
        $current = if($null -eq $quota) { 0 } else { $quota.CurrentValue }
        $limit = if($null -eq $quota) { 0 } else { $quota.Limit }
        $available = $limit - $current

        if($available -ge $quotaRequired) {
            continue
        }

        $newLimit = $current + $quotaRequired
        Write-Host "Requesting exactly $newLimit $quotaName vCPUs in $candidateLocation for $participantCount participants..."
        $quotaResult = Request-MhhComputeQuota `
            -SubscriptionId $SubscriptionId `
            -Location $candidateLocation `
            -QuotaName $quotaName `
            -NewLimit $newLimit

        if($quotaResult.Succeeded) {
            continue
        }

        $quotaFailureDetails = @(
            $quotaResult.State
            $quotaResult.ErrorCode
            $quotaResult.Message
        ) | Where-Object { $_ }
        $quotaFailureDetails = $quotaFailureDetails -join ' - '
        $quotaReadinessSummary += "$candidateLocation/$($candidate.VmSize)/${quotaName}: $quotaFailureDetails"
        Write-Warning "Quota request failed for $quotaName in ${candidateLocation}: $quotaFailureDetails"
        $locationReady = $false
        break
    }

    if($locationReady) {
        $selectedCandidate = $candidate
        break
    }
}

if(-not $selectedCandidate) {
    throw "No preferred region satisfies the aggregate compute requirements for $participantCount participants ($($quotaReadinessSummary -join '; '))."
}

Set-MhhConfidentialComputeSelection -SubscriptionId $SubscriptionId -Candidate $selectedCandidate
Write-Host "Selected $($selectedCandidate.VmSize) in $($selectedCandidate.Location); compute SKUs and quotas are ready for $participantCount participants." -ForegroundColor Green
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