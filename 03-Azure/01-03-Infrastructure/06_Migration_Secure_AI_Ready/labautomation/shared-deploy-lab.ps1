param(
    [Parameter(Mandatory = $true)]
    [string]$SubscriptionId,

    [Parameter(Mandatory = $true)]
    [string[]]$PreferredLocation = @(),

    [string[]]$AllowedEntraUserIds = @()
)

$ErrorActionPreference = 'Stop'
if ((Get-AzContext).Subscription.Id -ne $SubscriptionId) {
    throw 'The authenticated subscription does not match SubscriptionId.'
}

$providers = @(
    'Microsoft.Compute', 'Microsoft.Network', 'Microsoft.KeyVault',
    'Microsoft.Storage', 'Microsoft.DevTestLab', 'Microsoft.ManagedIdentity',
    'Microsoft.Migrate', 'Microsoft.OffAzure', 'Microsoft.RecoveryServices',
    'Microsoft.Insights', 'Microsoft.OperationalInsights', 'Microsoft.Monitor',
    'Microsoft.AlertsManagement', 'Microsoft.Web', 'Microsoft.Security'
)

foreach ($provider in $providers) {
    Update-MhhToken | Out-Null
    $registration = Get-AzResourceProvider -ProviderNamespace $provider
    if ($registration.RegistrationState -notcontains 'Registered') {
        Register-AzResourceProvider -ProviderNamespace $provider | Out-Null
    }
}

$deadline = [DateTime]::UtcNow.AddMinutes(10)
do {
    Update-MhhToken | Out-Null
    $pending = @(
        foreach ($provider in $providers) {
            $registration = Get-AzResourceProvider -ProviderNamespace $provider
            if ($registration.RegistrationState -notcontains 'Registered') {
                $provider
            }
        }
    )
    if ($pending.Count -eq 0) {
        Write-Host 'Migration lab resource providers are registered. No subscription-wide Defender plans were changed.'
        return
    }
    Write-Host "Waiting for provider registration: $($pending -join ', ')"
    Start-Sleep -Seconds 10
} while ([DateTime]::UtcNow -lt $deadline)

throw "Provider registration timed out: $($pending -join ', ')."
