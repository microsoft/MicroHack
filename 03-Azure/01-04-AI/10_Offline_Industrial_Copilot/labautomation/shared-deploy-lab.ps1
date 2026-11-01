<#
.SYNOPSIS
Runs once per subscription before any deploy-lab.ps1 run starts.
.DESCRIPTION
Registers the resource providers used by the Offline Industrial Copilot lab so the per-participant deployments do not race each other.
Also registers the Microsoft.Network/AllowBringYourOwnPublicIpAddress feature. Without it the subscription refuses every
public IP (SubscriptionNotRegisteredForFeature), and the lab VM needs one for Remote Desktop.
.PARAMETER SubscriptionId
Specifies the Azure subscription that contains the lab resources.
.PARAMETER PreferredLocation
Specifies the preferred Azure regions (ordered by preference) for resource deployment.
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
    "Microsoft.Compute",
    "Microsoft.Network",
    "Microsoft.Storage",
    "Microsoft.KeyVault",
    "Microsoft.OperationalInsights",
    "Microsoft.Insights",
    "Microsoft.MachineLearningServices"
)
foreach($provider in $requiredProviders) {
    $state = (Get-AzResourceProvider -ProviderNamespace $provider -ErrorAction SilentlyContinue | Select-Object -First 1).RegistrationState
    if($state -ne "Registered") {
        Write-Host "[$SubscriptionId] Registering resource provider: $provider"
        Register-AzResourceProvider -ProviderNamespace $provider -ErrorAction Stop | Out-Null
    }
}

# The lab VM needs a public IP for Remote Desktop. Some subscriptions refuse every public IP until this feature is registered.
$feature = "AllowBringYourOwnPublicIpAddress"
$featureState = (Get-AzProviderFeature -ProviderNamespace "Microsoft.Network" -FeatureName $feature -ErrorAction Stop).RegistrationState
if($featureState -ne "Registered") {
    Write-Host "[$SubscriptionId] Registering feature Microsoft.Network/$feature (state: $featureState)"
    if($featureState -notin @("Registering", "Pending")) {
        Register-AzProviderFeature -ProviderNamespace "Microsoft.Network" -FeatureName $feature -ErrorAction Stop | Out-Null
    }
    for($attempt = 1; $attempt -le 90 -and $featureState -ne "Registered"; $attempt++) {
        Start-Sleep -Seconds 10
        $featureState = (Get-AzProviderFeature -ProviderNamespace "Microsoft.Network" -FeatureName $feature -ErrorAction Stop).RegistrationState
    }
    if($featureState -ne "Registered") {
        throw "Microsoft.Network/$feature did not reach Registered within 15 minutes (state: $featureState). A subscription owner can run: az feature register --namespace Microsoft.Network --name $feature; az provider register --namespace Microsoft.Network"
    }
    # The feature only takes effect after Microsoft.Network is registered again.
    Register-AzResourceProvider -ProviderNamespace "Microsoft.Network" -ErrorAction Stop | Out-Null
    for($attempt = 1; $attempt -le 30; $attempt++) {
        if((Get-AzResourceProvider -ProviderNamespace "Microsoft.Network" | Select-Object -First 1).RegistrationState -eq "Registered") { break }
        Start-Sleep -Seconds 10
    }
    Write-Host "[$SubscriptionId] Feature Microsoft.Network/$feature is registered"
}
