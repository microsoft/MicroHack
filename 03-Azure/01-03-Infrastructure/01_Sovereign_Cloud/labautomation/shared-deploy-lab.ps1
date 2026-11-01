<#
.SYNOPSIS
Prepares a subscription for Sovereign Cloud MicroHack labs.
.DESCRIPTION
Runs once per subscription before participant lab deployments and registers the
required Azure resource providers. It ensures one preferred region has the VM
SKUs and compute quota required by the subscription's participant count.
LocalBox is deployed separately by global-event-deploy.ps1 once per event.
For Microsoft-hosted environments only: assigns and verifies the MCAPS control-tag
initiative and enables paid Defender for Servers P2 with Endpoint protection before
deploying resources. Do not use this hook for BYOS setup.
#>
param(
    [Parameter(Mandatory=$true)]
    [string]$SubscriptionId,

    [Parameter(Mandatory=$true)]
    [string[]]$PreferredLocation,

    [Parameter(Mandatory=$false)]
    [string[]]$AllowedEntraUserIds = @()
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'quota-helpers.ps1')
. (Join-Path $PSScriptRoot 'hosted-tag-policy.ps1')
. (Join-Path $PSScriptRoot 'hosted-defender.ps1')

Update-MhhToken | Out-Null
if ((Get-AzContext -ErrorAction Stop).Subscription.Id -ne $SubscriptionId) {
    throw "The Azure context must target participant subscription $SubscriptionId."
}

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
    $quotaRequirements = @(Get-MhhSovereignComputeRequirements -ConfidentialQuotaName $candidate.QuotaName)
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

Initialize-MhhHostedTagPolicy -SubscriptionId $SubscriptionId -Location $selectedCandidate.Location
Initialize-MhhHostedDefender -SubscriptionId $SubscriptionId