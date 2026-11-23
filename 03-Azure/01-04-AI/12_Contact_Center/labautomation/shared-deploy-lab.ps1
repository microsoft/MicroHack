<#
.SYNOPSIS
Runs once per subscription, before any deploy-lab.ps1 run starts.
.DESCRIPTION
Registers the resource providers that infra/main.bicep deploys. The participant owns only their resource group and
cannot register a provider (a subscription-level action), so a missing registration would fail every lab.
Best-effort: if this script throws, the platform runs no deploy-lab.ps1 in the subscription, so a provider that
cannot be registered is reported with the command to fix it instead.
.PARAMETER SubscriptionId
Specifies the Azure subscription that contains the lab resources.
.PARAMETER PreferredLocation
Specifies the preferred Azure regions (ordered by preference) for resource deployment.
.PARAMETER AllowedEntraUserIds
Entra user object IDs of every participant holding a lab in this subscription.
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$SubscriptionId,

    [Parameter(Mandatory = $true)]
    [string[]]$PreferredLocation = @(),

    [Parameter(Mandatory = $false)]
    [string[]]$AllowedEntraUserIds = @()
)

$ErrorActionPreference = 'Stop'

$providers = @(
    'Microsoft.CognitiveServices',
    'Microsoft.Storage',
    'Microsoft.Search',
    'Microsoft.Web',
    'Microsoft.OperationalInsights',
    'Microsoft.Insights'
)

$pending = @()
foreach ($provider in $providers) {
    try {
        $state = (Get-AzResourceProvider -ProviderNamespace $provider -ErrorAction SilentlyContinue | Select-Object -First 1).RegistrationState
        if ($state -eq 'Registered') {
            Write-Host "[OK]    [$SubscriptionId] $provider is registered."
            continue
        }
        Write-Host "[INFO]  [$SubscriptionId] Registering $provider (state: '$state')..."
        Register-AzResourceProvider -ProviderNamespace $provider -ErrorAction Stop | Out-Null
        $pending += $provider
    } catch {
        Write-Host "[WARN]  [$SubscriptionId] Could not register $provider`: $_"
        Write-Host "[WARN]  [$SubscriptionId] A subscription owner can run: az provider register --namespace $provider --subscription $SubscriptionId"
    }
}

# Registration is asynchronous and the labs start as soon as this script returns, so wait for it.
for ($waited = 0; $pending.Count -gt 0 -and $waited -lt 300; $waited += 15) {
    Start-Sleep -Seconds 15
    $pending = @($pending | Where-Object {
        (Get-AzResourceProvider -ProviderNamespace $_ -ErrorAction SilentlyContinue | Select-Object -First 1).RegistrationState -ne 'Registered'
    })
}
foreach ($provider in $pending) {
    Write-Host "[WARN]  [$SubscriptionId] $provider was still registering after 5 minutes. The first labs may fail with MissingSubscriptionRegistration."
}