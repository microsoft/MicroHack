<#
.SYNOPSIS
Hook that runs once per subscription before any deploy-lab.ps1 run starts.
.DESCRIPTION
Registers all Azure Resource Providers required for Azure Arc-enabled Kubernetes,
Azure IoT Operations, and Foundry Local so per-participant deployments do not race.
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

$requiredProviders = @(
    'Microsoft.Compute',
    'Microsoft.Network',
    'Microsoft.Storage',
    'Microsoft.KeyVault',
    'Microsoft.ExtendedLocation',
    'Microsoft.Kubernetes',
    'Microsoft.KubernetesConfiguration',
    'Microsoft.IoTOperations',
    'Microsoft.DeviceRegistry',
    'Microsoft.SecretSyncController'
)

foreach ($provider in $requiredProviders) {
    $state = (Get-AzResourceProvider -ProviderNamespace $provider -ErrorAction SilentlyContinue | Select-Object -First 1).RegistrationState
    if ($state -ne 'Registered') {
        Write-Host "[$SubscriptionId] Registering resource provider: $provider"
        Register-AzResourceProvider -ProviderNamespace $provider -ErrorAction Stop | Out-Null
    }
    else {
        Write-Host "[$SubscriptionId] Resource provider $provider is already registered."
    }
}

# Resolve the tenant-specific Object ID of the Microsoft.ExtendedLocation resource provider
# (AppId: bc313c14-388c-4e7d-a58e-70017303ee3b) so participants who lack Microsoft Graph
# directory-read permissions can still pass --custom-locations-oid in Challenge 01.
$customLocationsSp = Get-AzADServicePrincipal -ApplicationId 'bc313c14-388c-4e7d-a58e-70017303ee3b' -ErrorAction SilentlyContinue
if ($customLocationsSp -and $customLocationsSp.Id) {
    @{ 'HackboxCredential' = @{
        name  = 'CustomLocationsRpObjectId'
        value = $customLocationsSp.Id
        note  = 'Microsoft.ExtendedLocation Service Principal Object ID for az connectedk8s enable-features'
    } }
}
