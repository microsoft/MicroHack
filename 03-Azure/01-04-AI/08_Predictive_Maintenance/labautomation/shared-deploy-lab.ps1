#!/usr/bin/env pwsh
<#
.SYNOPSIS
Runs once per subscription before any deploy-lab.ps1 run starts.
.DESCRIPTION
Registers the resource providers used by this hack's main.bicep so that
per-participant deployments do not fail on an unregistered provider.
.PARAMETER SubscriptionId
Specifies the Azure subscription that contains the lab resources.
.PARAMETER PreferredLocation
Specifies the preferred Azure regions, ordered by preference.
.PARAMETER AllowedEntraUserIds
Entra user object IDs of every participant holding a lab in this subscription.
#>
param(
    [Parameter(Mandatory=$true)]
    [string]$SubscriptionId,

    [Parameter(Mandatory=$true)]
    [string[]]$PreferredLocation = @(),

    [Parameter(Mandatory=$false)]
    [string[]]$AllowedEntraUserIds = @()
)

$requiredProviders = @(
    "Microsoft.Storage",
    "Microsoft.OperationalInsights",
    "Microsoft.Insights",
    "Microsoft.DocumentDB",
    "Microsoft.Search",
    "Microsoft.ContainerRegistry",
    "Microsoft.App",
    "Microsoft.CognitiveServices",
    "Microsoft.ApiManagement"
)

foreach($provider in $requiredProviders) {
    $registrationState = (Get-AzResourceProvider `
        -ProviderNamespace $provider `
        -ErrorAction Stop | Select-Object -First 1).RegistrationState

    if($registrationState -eq "Registered") {
        Write-Host "[$SubscriptionId] Resource provider $provider is already registered."
        continue
    }

    Write-Host "[$SubscriptionId] Registering resource provider: $provider"
    Register-AzResourceProvider `
        -ProviderNamespace $provider `
        -ErrorAction Stop | Out-Null
}

# No shared (subscription-level) resources are required by this hack; every
# resource in main.bicep is deployed per-participant resource group.
