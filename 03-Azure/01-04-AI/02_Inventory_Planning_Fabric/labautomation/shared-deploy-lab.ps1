<#
.SYNOPSIS
    Prepare resource providers once per subscription before participant deployments.
.DESCRIPTION
    Requires subscription-level provider registration permission. The platform has
    already selected the subscription; this hook never signs in or changes context.
#>
param(
    [Parameter(Mandatory=$true)]
    [string]$SubscriptionId,

    [Parameter(Mandatory=$true)]
    [string[]]$PreferredLocation = @(),

    [string[]]$AllowedEntraUserIds = @()
)

$ErrorActionPreference = 'Stop'
$context = Get-AzContext
if ($context.Subscription.Id -ne $SubscriptionId) {
    throw "Az context does not match SubscriptionId '$SubscriptionId'. Select the intended subscription before running this hook."
}

$providers = @(
    'Microsoft.CognitiveServices',
    'Microsoft.Fabric',
    'Microsoft.Insights',
    'Microsoft.OperationalInsights',
    'Microsoft.BotService'
)

foreach ($provider in $providers) {
    $state = (Get-AzResourceProvider -ProviderNamespace $provider -ErrorAction Stop |
        Select-Object -First 1).RegistrationState
    if ($state -eq 'Registered') {
        Write-Host "[OK]    $provider is registered."
        continue
    }
    Register-AzResourceProvider -ProviderNamespace $provider -ErrorAction Stop | Out-Null
    for ($elapsed = 0; $elapsed -le 300; $elapsed += 5) {
        $state = (Get-AzResourceProvider -ProviderNamespace $provider -ErrorAction Stop |
            Select-Object -First 1).RegistrationState
        if ($state -eq 'Registered') { break }
        if ($elapsed -lt 300) { Start-Sleep -Seconds 5 }
    }
    if ($state -ne 'Registered') {
        throw "$provider did not register within 300 seconds (last state: '$state'). Check subscription-level registration permissions."
    }
    Write-Host "[OK]    $provider is registered."
}
