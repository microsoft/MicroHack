param(
    [Parameter(Mandatory=$true)]
    [string]$SubscriptionId,

    [string[]]$PreferredLocation = @(),
    [string[]]$AllowedEntraUserIds = @()
)

$ErrorActionPreference = 'Stop'

# This preview feature is required for public IP allocation in the workshop subscription.
$feature = 'AllowBringYourOwnPublicIpAddress'
$state = az feature show --namespace Microsoft.Network --name $feature --query properties.state -o tsv
if ($LASTEXITCODE -ne 0) { throw "Could not inspect Microsoft.Network/$feature." }
if ($state -ne 'Registered') {
    if ($state -ne 'Registering') {
        az feature register --namespace Microsoft.Network --name $feature --output none
        if ($LASTEXITCODE -ne 0) { throw "Could not register Microsoft.Network/$feature." }
    }
    $deadline = [DateTime]::UtcNow.AddMinutes(30)
    do {
        if ([DateTime]::UtcNow -ge $deadline) { throw "Timed out registering Microsoft.Network/$feature." }
        Start-Sleep -Seconds 30
        Update-MhhToken | Out-Null
        $state = az feature show --namespace Microsoft.Network --name $feature --query properties.state -o tsv
        if ($LASTEXITCODE -ne 0) { throw "Could not inspect Microsoft.Network/$feature registration progress." }
    } while ($state -eq 'Registering')
    if ($state -ne 'Registered') { throw "Microsoft.Network/$feature registration ended in state '$state'." }
}

foreach ($provider in @(
    'Microsoft.Network',
    'Microsoft.Compute',
    'Microsoft.Storage',
    'Microsoft.ContainerRegistry',
    'Microsoft.App',
    'Microsoft.Sql',
    'Microsoft.DBforPostgreSQL',
    'Microsoft.KeyVault',
    'Microsoft.Insights',
    'Microsoft.OperationalInsights',
    'Microsoft.LoadTestService',
    'Microsoft.Security',
    'Microsoft.CognitiveServices'
)) {
    Update-MhhToken | Out-Null
    az provider register --namespace $provider --wait --output none
    if ($LASTEXITCODE -ne 0) { throw "Could not register $provider." }
}
