<#
.SYNOPSIS
    Register required Azure resource providers for the Sovereign Cloud MicroHack.

.DESCRIPTION
    This script registers all required Azure resource providers needed for the
    Sovereign Cloud MicroHack across all available subscriptions.

    Required providers include:
    - Azure Arc and hybrid connectivity
    - Azure Local (Stack HCI)
    - Confidential computing
    - Key Vault and encryption
    - Monitoring and policy

.EXAMPLE
    .\1-resource-providers.ps1
    Registers all required resource providers across all subscriptions

.NOTES
    Author: MicroHack Team
    Date: January 2026

.LINK
    https://learn.microsoft.com/azure/azure-resource-manager/management/resource-providers-and-types
#>

[CmdletBinding()]
param()

# Ensure required modules are available
$requiredModules = @('Az.Accounts', 'Az.Resources')
foreach ($module in $requiredModules) {
    if (-not (Get-Module -ListAvailable -Name $module)) {
        Write-Error "$module module is not installed. Please run: Install-Module -Name $module"
        exit 1
    }
}

# Import required modules
Import-Module Az.Accounts, Az.Resources -ErrorAction Stop

Write-Host "`n=== Resource Provider Registration Utility ===" -ForegroundColor Cyan
Write-Host "This script will register all required resource providers for the Sovereign Cloud MicroHack."
Write-Host ""

# Check if user is logged in
try {
    $context = Get-AzContext
    if (-not $context) {
        Write-Host "No Azure context found. Please login..." -ForegroundColor Yellow
        Connect-AzAccount
        $context = Get-AzContext
    } else {
        Write-Host "Using Azure account: $($context.Account.Id)" -ForegroundColor Green
    }
} catch {
    Write-Error "Failed to get Azure context. Please run Connect-AzAccount first."
    exit 1
}

# Get all subscriptions
$subscriptions = Get-AzSubscription

if ($subscriptions.Count -eq 0) {
    Write-Error "No subscriptions found. Please ensure you have access to at least one subscription."
    exit 1
}

Write-Host "Found $($subscriptions.Count) subscription(s)" -ForegroundColor Green

# List of resource providers to register for Sovereign Cloud MicroHack
$providers = @(
    # Azure Arc and Hybrid
    "Microsoft.HybridCompute",
    "Microsoft.GuestConfiguration",
    "Microsoft.HybridConnectivity",
    "Microsoft.AzureArcData",

    # Azure Local (Stack HCI)
    "Microsoft.AzureStackHCI",
    "Microsoft.ResourceConnector",
    "Microsoft.HybridContainerService",

    # Compute and Confidential Computing
    "Microsoft.Compute",
    "Microsoft.ConfidentialLedger",

    # Security and Compliance
    "Microsoft.Security",
    "Microsoft.PolicyInsights",
    "Microsoft.Advisor",

    # Monitoring and Operations
    "Microsoft.OperationsManagement",
    "Microsoft.OperationalInsights",
    "Microsoft.Insights",
    "Microsoft.Monitor",

    # Key Vault and Encryption
    "Microsoft.KeyVault",
    "Microsoft.ManagedIdentity",

    # Networking
    "Microsoft.Network",

    # Storage
    "Microsoft.Storage",

    # Attestation (for Confidential Computing)
    "Microsoft.Attestation",

    # Kubernetes (for AKS Arc)
    "Microsoft.Kubernetes",
    "Microsoft.KubernetesConfiguration",
    "Microsoft.ContainerService",

    # Extended Location (for Azure Local)
    "Microsoft.ExtendedLocation"
)

Write-Host "`nResource providers to register:" -ForegroundColor Yellow
foreach ($provider in $providers) {
    Write-Host "  - $provider" -ForegroundColor Gray
}

# Register resource providers for each subscription
foreach ($subscription in $subscriptions) {
    Write-Host "`n" + ("=" * 80) -ForegroundColor Cyan
    Write-Host "Processing Subscription: $($subscription.Name)" -ForegroundColor Cyan
    Write-Host ("=" * 80) -ForegroundColor Cyan

    Set-AzContext -SubscriptionId $subscription.Id | Out-Null

    foreach ($provider in $providers) {
        $existingProvider = Get-AzResourceProvider -ProviderNamespace $provider -ErrorAction SilentlyContinue

        if ($existingProvider.RegistrationState -eq 'Registered') {
            Write-Host "  [REGISTERED] $provider" -ForegroundColor Green
        } else {
            Write-Host "  [REGISTERING] $provider..." -ForegroundColor Yellow
            try {
                Register-AzResourceProvider -ProviderNamespace $provider | Out-Null
                Write-Host "    Registration initiated" -ForegroundColor Gray
            } catch {
                Write-Host "    Failed to register: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
    }

    $networkFeatureName = "AllowBringYourOwnPublicIpAddress"
    $networkFeature = Get-AzProviderFeature `
        -ProviderNamespace "Microsoft.Network" `
        -FeatureName $networkFeatureName `
        -ErrorAction Stop

    if ($networkFeature.RegistrationState -ne 'Registered') {
        Write-Host "  [REGISTERING] Microsoft.Network/$networkFeatureName..." -ForegroundColor Yellow
        Register-AzProviderFeature `
            -ProviderNamespace "Microsoft.Network" `
            -FeatureName $networkFeatureName `
            -ErrorAction Stop | Out-Null

        for ($attempt = 1; $attempt -le 90; $attempt++) {
            Start-Sleep -Seconds 10
            $networkFeature = Get-AzProviderFeature `
                -ProviderNamespace "Microsoft.Network" `
                -FeatureName $networkFeatureName `
                -ErrorAction Stop
            if ($networkFeature.RegistrationState -eq 'Registered') {
                break
            }
            Write-Host "    Waiting for feature registration ($attempt/90): $($networkFeature.RegistrationState)" -ForegroundColor Gray
        }
    }

    if ($networkFeature.RegistrationState -ne 'Registered') {
        throw "Provider feature Microsoft.Network/$networkFeatureName did not reach Registered state within 15 minutes (current state: $($networkFeature.RegistrationState))."
    }

    Write-Host "  [REGISTERED] Microsoft.Network/$networkFeatureName" -ForegroundColor Green
    Register-AzResourceProvider -ProviderNamespace "Microsoft.Network" -ErrorAction Stop | Out-Null

    for ($attempt = 1; $attempt -le 30; $attempt++) {
        $networkProvider = Get-AzResourceProvider -ProviderNamespace "Microsoft.Network" -ErrorAction Stop
        if ($networkProvider.RegistrationState -eq 'Registered') {
            break
        }
        Write-Host "    Waiting for Microsoft.Network propagation ($attempt/30)..." -ForegroundColor Gray
        Start-Sleep -Seconds 10
    }

    if ($networkProvider.RegistrationState -ne 'Registered') {
        throw "Resource provider Microsoft.Network did not return to Registered state within 5 minutes."
    }

    $aksFeatureName = "AzureLinuxCVMPreview"
    $aksFeature = Get-AzProviderFeature `
        -ProviderNamespace "Microsoft.ContainerService" `
        -FeatureName $aksFeatureName `
        -ErrorAction Stop

    if ($aksFeature.RegistrationState -ne 'Registered') {
        Write-Host "  [REGISTERING] Microsoft.ContainerService/$aksFeatureName..." -ForegroundColor Yellow
        Register-AzProviderFeature `
            -ProviderNamespace "Microsoft.ContainerService" `
            -FeatureName $aksFeatureName `
            -ErrorAction Stop | Out-Null

        for ($attempt = 1; $attempt -le 90; $attempt++) {
            Start-Sleep -Seconds 10
            $aksFeature = Get-AzProviderFeature `
                -ProviderNamespace "Microsoft.ContainerService" `
                -FeatureName $aksFeatureName `
                -ErrorAction Stop
            if ($aksFeature.RegistrationState -eq 'Registered') {
                break
            }
            Write-Host "    Waiting for feature registration ($attempt/90): $($aksFeature.RegistrationState)" -ForegroundColor Gray
        }
    }

    if ($aksFeature.RegistrationState -ne 'Registered') {
        throw "Provider feature Microsoft.ContainerService/$aksFeatureName did not reach Registered state within 15 minutes (current state: $($aksFeature.RegistrationState))."
    }

    Write-Host "  [REGISTERED] Microsoft.ContainerService/$aksFeatureName" -ForegroundColor Green
    Register-AzResourceProvider -ProviderNamespace "Microsoft.ContainerService" -ErrorAction Stop | Out-Null

    for ($attempt = 1; $attempt -le 30; $attempt++) {
        $containerServiceProvider = Get-AzResourceProvider -ProviderNamespace "Microsoft.ContainerService" -ErrorAction Stop
        if ($containerServiceProvider.RegistrationState -eq 'Registered') {
            break
        }
        Write-Host "    Waiting for Microsoft.ContainerService propagation ($attempt/30)..." -ForegroundColor Gray
        Start-Sleep -Seconds 10
    }

    if ($containerServiceProvider.RegistrationState -ne 'Registered') {
        throw "Resource provider Microsoft.ContainerService did not return to Registered state within 5 minutes."
    }
}

Write-Host "`n" + ("=" * 80) -ForegroundColor Cyan
Write-Host "SUMMARY" -ForegroundColor Cyan
Write-Host ("=" * 80) -ForegroundColor Cyan
Write-Host "Resource provider registration initiated across $($subscriptions.Count) subscription(s)." -ForegroundColor Green
Write-Host "`nNote: Some providers may take a few minutes to fully register." -ForegroundColor Yellow
Write-Host "You can check registration status with: Get-AzResourceProvider -ProviderNamespace <namespace>" -ForegroundColor Gray
