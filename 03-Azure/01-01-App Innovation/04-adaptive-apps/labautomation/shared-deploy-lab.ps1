<#
.SYNOPSIS
Prepare a dedicated Microsoft-hosted subscription, not a BYOS subscription.
#>
param(
    [Parameter(Mandatory)][string]$SubscriptionId,
    [Parameter(Mandatory)][string[]]$PreferredLocation,
    [string[]]$AllowedEntraUserIds = @()
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'console-helpers.ps1')
. (Join-Path $PSScriptRoot 'hosted-tag-policy.ps1')
Update-MhhToken | Out-Null
Assert-AdaptiveContext -SubscriptionId $SubscriptionId

$defaults = Get-Content (Join-Path $PSScriptRoot 'lab-defaults.json') -Raw | ConvertFrom-Json
$locations = @($PreferredLocation | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim().ToLowerInvariant() } | Where-Object { $_ } | Select-Object -Unique)
if ($locations.Count -eq 0) { throw 'At least one preferred location is required.' }
$labCount = @($AllowedEntraUserIds | Where-Object { $_ } | Select-Object -Unique).Count
if ($labCount -eq 0) { $labCount = $defaults.labsPerSubscription }
$feature = 'AllowBringYourOwnPublicIpAddress'
$featureState = (Invoke-AdaptiveAz -Arguments @('feature', 'show', '--namespace', 'Microsoft.Network', '--name', $feature)).properties.state
if ($featureState -ne 'Registered') {
    if ($featureState -notin @('Registering', 'Pending')) {
        Invoke-AdaptiveAz -Arguments @('feature', 'register', '--namespace', 'Microsoft.Network', '--name', $feature) | Out-Null
    }
    for ($attempt = 0; $attempt -lt 90; $attempt++) {
        Start-Sleep -Seconds 10
        Update-MhhToken | Out-Null
        $featureState = (Invoke-AdaptiveAz -Arguments @('feature', 'show', '--namespace', 'Microsoft.Network', '--name', $feature)).properties.state
        if ($featureState -eq 'Registered') { break }
        if ($featureState -notin @('Registering', 'Pending')) {
            throw "Microsoft.Network/$feature registration ended in state '$featureState'."
        }
        Write-Host "Waiting for Microsoft.Network/$feature registration ($($attempt + 1)/90): $featureState"
    }
}
if ($featureState -ne 'Registered') {
    throw "Microsoft.Network/$feature did not reach Registered within 15 minutes (state: '$featureState'). Resolve feature registration before retrying."
}
# Re-register Network after the feature is registered so public IP allocation sees it.
$providers = @('Microsoft.Compute', 'Microsoft.Network', 'Microsoft.ContainerService',
    'Microsoft.ContainerRegistry', 'Microsoft.ManagedIdentity', 'Microsoft.DBforPostgreSQL',
    'Microsoft.OperationalInsights', 'Microsoft.PolicyInsights', 'Microsoft.Sql',
    'Microsoft.KeyVault', 'Microsoft.Storage')
foreach ($provider in $providers) {
    Update-MhhToken | Out-Null
    Invoke-AdaptiveAz -Arguments @('provider', 'register', '--namespace', $provider) | Out-Null
}
foreach ($provider in $providers) {
    $registered = $false
    for ($attempt = 0; $attempt -lt 60; $attempt++) {
        Update-MhhToken | Out-Null
        $state = Invoke-AdaptiveAz -Arguments @('provider', 'show', '--namespace', $provider)
        if ($state.registrationState -eq 'Registered') { $registered = $true; break }
        Start-Sleep -Seconds 10
    }
    if (-not $registered) { throw "Resource provider $provider did not register within ten minutes." }
}

$ready = @()
$failures = @()
foreach ($location in $locations) {
    Update-MhhToken | Out-Null
    try {
        $ready += Test-AdaptiveRegion -Location $location -LabCount $labCount
    } catch {
        $failures += "$location`: $($_.Exception.Message)"
        Write-Warning $failures[-1]
    }
}
if ($ready.Count -eq 0) {
    throw "No preferred region passed Adaptive Apps preflight. $($failures -join '; ')"
}
Initialize-MhhHostedTagPolicy -SubscriptionId $SubscriptionId -Location $ready[0]
Update-AzTag -ResourceId "/subscriptions/$SubscriptionId" -Operation Merge -Tag @{
    'microhack-adaptive-location' = $ready[0]
    'microhack-adaptive-regions' = $ready -join ','
    'microhack-adaptive-lab-count' = "$labCount"
} -ErrorAction Stop | Out-Null
Write-Host "Validated $labCount labs in $($ready -join ', '): 16 free vCPUs per lab, including AKS surge. SKU exposure is not a capacity reservation."
