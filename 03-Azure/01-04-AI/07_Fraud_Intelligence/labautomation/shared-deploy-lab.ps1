<#
.SYNOPSIS
Runs once per subscription before any deploy-lab.ps1 run starts.
.DESCRIPTION
Deploy shared resources or perform one-time subscription preparation here. If this hook fails, participant deployments do not start.
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

$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition

$requiredProviders = @(
    "Microsoft.Monitor",
    "Microsoft.DocumentDB",
    "Microsoft.CognitiveServices",
    "Microsoft.Search",
    "Microsoft.App",
    "Microsoft.ApiManagement",
    "Microsoft.OperationalInsights",
    "Microsoft.Insights",
    "Microsoft.Storage"
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

# Deploy shared resources here when needed.
# Any HackboxCredential emitted by this hook is visible to every participant
# sharing the subscription, so do not emit participant-specific secrets.