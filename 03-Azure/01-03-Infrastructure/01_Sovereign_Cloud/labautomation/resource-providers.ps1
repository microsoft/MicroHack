<#
.SYNOPSIS
    Register required Azure resource providers for the Sovereign Cloud MicroHack.

.DESCRIPTION
    This script idempotently registers all Azure resource providers needed for
    the Sovereign Cloud MicroHack in the current subscription.

    Required providers include:
    - Azure Arc and hybrid connectivity
    - Azure Local (Stack HCI)
    - Confidential computing
    - Key Vault and encryption
    - Monitoring and policy

.EXAMPLE
    .\resource-providers.ps1
    Registers all required resource providers

.NOTES
    Author: MicroHack Team
    Date: January 2026

.LINK
    https://learn.microsoft.com/azure/azure-resource-manager/management/resource-providers-and-types
#>

[CmdletBinding()]
param()

Write-Host "`n=== Resource Provider Registration Utility ===" -ForegroundColor Cyan
Write-Host "This script will register all required resource providers for the Sovereign Cloud MicroHack."
Write-Host ""

$context = Get-AzContext -ErrorAction Stop
if (-not $context.Subscription.Id) {
    throw "The current Azure context does not contain a subscription."
}
$subscriptionId = $context.Subscription.Id
Write-Host "Registering providers in subscription: $subscriptionId" -ForegroundColor Green

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

# Register resource providers for the current subscription
foreach ($provider in $providers) {
    $existingProvider = Get-AzResourceProvider -ProviderNamespace $provider -ErrorAction Stop

    if ($existingProvider.RegistrationState -eq 'Registered') {
        Write-Host "  [REGISTERED] $provider" -ForegroundColor Green
        continue
    }

    Write-Host "  [REGISTERING] $provider..." -ForegroundColor Yellow
    Register-AzResourceProvider -ProviderNamespace $provider -ErrorAction Stop | Out-Null
    Write-Host "    Registration initiated" -ForegroundColor Gray
}

Write-Host "`n" + ("=" * 80) -ForegroundColor Cyan
Write-Host "SUMMARY" -ForegroundColor Cyan
Write-Host ("=" * 80) -ForegroundColor Cyan
Write-Host "Resource provider registration initiated for subscription: $subscriptionId" -ForegroundColor Green
Write-Host "`nNote: Some providers may take a few minutes to fully register." -ForegroundColor Yellow
Write-Host "You can check registration status with: Get-AzResourceProvider -ProviderNamespace <namespace>" -ForegroundColor Gray
