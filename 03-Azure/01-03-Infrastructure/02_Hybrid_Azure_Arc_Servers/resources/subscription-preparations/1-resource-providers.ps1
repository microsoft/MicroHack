# Get all subscriptions
$subscriptions = Get-AzSubscription

# List of resource providers to register
$providers = @(
    "Microsoft.HybridCompute",
    "Microsoft.GuestConfiguration",
    "Microsoft.HybridConnectivity",
    "Microsoft.AzureArcData",
    "Microsoft.Compute",
    "Microsoft.OperationsManagement",
    "Microsoft.OperationalInsights",
    "Microsoft.Insights",
    "Microsoft.KeyVault"
)

# Register resource providers for each subscription
foreach ($subscription in $subscriptions) {
    Set-AzContext -SubscriptionId $subscription.Id
    foreach ($provider in $providers) {
        if (-not (Get-AzResourceProvider -ProviderNamespace $provider)) {
            Register-AzResourceProvider -ProviderNamespace $provider
        }
    }
}