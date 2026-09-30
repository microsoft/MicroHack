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
# Console pre-creates RGs in the first preferred location. Recipes inherit that location.
# Do not report shared success merely because a different candidate passed.
if ($locations[0] -notin $ready) {
    throw "The supplied participant RG region '$($locations[0])' is not ready. Eligible alternatives: $($ready -join ', '). Reconfigure the event location and recreate EMPTY lab scopes explicitly; no automatic relocation/deletion is performed. $($failures -join '; ')"
}
Initialize-MhhHostedTagPolicy -SubscriptionId $SubscriptionId -Location $locations[0]
Update-AzTag -ResourceId "/subscriptions/$SubscriptionId" -Operation Merge -Tag @{
    'microhack-adaptive-location' = $locations[0]
    'microhack-adaptive-regions' = $ready -join ','
    'microhack-adaptive-lab-count' = "$labCount"
} -ErrorAction Stop | Out-Null
Write-Host "Validated $labCount labs in $($ready -join ', '): 16 free vCPUs per lab, including AKS surge. SKU exposure is not a capacity reservation."
