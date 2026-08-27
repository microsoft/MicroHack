<#
  shared-deploy-lab.ps1 — EMEA MicroHack once-per-subscription hook for the Citadel
  Agentic Governance microhack.

  The microsoft/MicroHack platform picks this script up automatically by file name and runs
  it exactly ONCE PER AZURE SUBSCRIPTION, before the per-participant deploy-lab.ps1 fan-out.
  It is the sanctioned home for one-off subscription preparation that the many parallel lab
  deployments would otherwise race on — registering resource providers being the canonical
  example.

  Why this lab needs it:
    The hub-and-spoke deployment touches ten resource providers (API Management, Cognitive
    Services, Cosmos DB, Event Hub, Key Vault, Container Registry, ...). The platform
    pre-registers only a small common set, and in a 'resourcegroup' lab the participant holds
    RG-Owner plus subscription-READER — provider registration is a subscription-scope write,
    so a participant cannot self-register and deploy-lab.ps1 fails with
    MissingSubscriptionRegistration in every region it tries. Registering here, once and ahead
    of the labs, makes the deployment work without granting anyone subscription Owner.

  Platform contract:
    - Az context is already set to $SubscriptionId  -> do NOT Connect-AzAccount.
    - Az.Accounts / Az.Resources are already imported.
    - Runs to completion before the FIRST deploy-lab.ps1 in the subscription starts.
    - If this hook THROWS, the platform runs NO deploy-lab.ps1 for the subscription. Provider
      registration is therefore best-effort: a provider that is already registered, or that a
      subscription policy manages centrally, must not take down the whole subscription's
      provisioning. Failures are reported loudly with the exact remediation command instead.
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

# Required = infra/resources.bicep deploys a resource of this type, so the lab cannot
#            provision at all without it.
# Optional = only a follow-on challenge (7-9, incl. the instructor-led HR MCP) needs it.
$providers = @(
    @{ Namespace = 'Microsoft.ApiManagement';          Required = $true;  Reason = 'APIM AI gateway (all challenges)' }
    @{ Namespace = 'Microsoft.CognitiveServices';      Required = $true;  Reason = 'Azure AI Foundry hub + spoke accounts, model deployments' }
    @{ Namespace = 'Microsoft.DocumentDB';             Required = $true;  Reason = 'Cosmos DB usage tracking (challenge 2)' }
    @{ Namespace = 'Microsoft.KeyVault';               Required = $true;  Reason = 'Hub and spoke Key Vaults' }
    @{ Namespace = 'Microsoft.OperationalInsights';    Required = $true;  Reason = 'Log Analytics workspaces (challenge 3)' }
    @{ Namespace = 'Microsoft.Insights';               Required = $true;  Reason = 'Application Insights / agent tracing (challenge 3)' }
    @{ Namespace = 'Microsoft.EventHub';               Required = $true;  Reason = 'Usage event streaming pipeline' }
    @{ Namespace = 'Microsoft.Storage';                Required = $true;  Reason = 'Usage ingestion storage account' }
    @{ Namespace = 'Microsoft.ManagedIdentity';        Required = $true;  Reason = 'User-assigned identities for APIM backend auth' }
    @{ Namespace = 'Microsoft.ContainerRegistry';      Required = $true;  Reason = 'Spoke ACR (challenge 7 container publishing)' }
    @{ Namespace = 'Microsoft.App';                    Required = $false; Reason = 'HR MCP Container App (challenge 9, instructor-led)' }
    @{ Namespace = 'Microsoft.AlertsManagement';       Required = $false; Reason = 'Governance alert rules (optional extension)' }
)

$pending = New-Object System.Collections.Generic.List[string]
$failed = New-Object System.Collections.Generic.List[hashtable]

foreach ($provider in $providers) {
    $ns = $provider.Namespace
    try {
        $state = (Get-AzResourceProvider -ProviderNamespace $ns -ErrorAction SilentlyContinue |
            Select-Object -First 1).RegistrationState

        if ($state -eq 'Registered') {
            Write-Host "[OK]    [$SubscriptionId] Resource provider '$ns' already registered."
            continue
        }

        Write-Host "[INFO]  [$SubscriptionId] Registering '$ns' (state: '$state') — $($provider.Reason)..."
        Register-AzResourceProvider -ProviderNamespace $ns -ErrorAction Stop | Out-Null
        if ($provider.Required) { $pending.Add($ns) }
        Write-Host "[OK]    [$SubscriptionId] Registration submitted for '$ns' (async, idempotent, subscription-wide)."
    }
    catch {
        # Best-effort: never abort the whole subscription's provisioning over one registration.
        Write-Host "[WARN]  [$SubscriptionId] Could not register '$ns': $_"
        $failed.Add($provider)
    }
}

# Registration is asynchronous. The per-participant deployments start as soon as this hook
# returns, so wait for the REQUIRED providers to actually reach 'Registered' rather than
# letting every parallel lab race a half-registered subscription.
if ($pending.Count -gt 0) {
    $timeoutSeconds = 300
    $intervalSeconds = 15
    $elapsed = 0

    Write-Host "[INFO]  [$SubscriptionId] Waiting for $($pending.Count) required provider(s) to finish registering (up to ${timeoutSeconds}s)..."
    while ($elapsed -lt $timeoutSeconds -and $pending.Count -gt 0) {
        Start-Sleep -Seconds $intervalSeconds
        $elapsed += $intervalSeconds

        foreach ($ns in @($pending)) {
            $state = (Get-AzResourceProvider -ProviderNamespace $ns -ErrorAction SilentlyContinue |
                Select-Object -First 1).RegistrationState
            if ($state -eq 'Registered') {
                Write-Host "[OK]    [$SubscriptionId] '$ns' is registered."
                $pending.Remove($ns) | Out-Null
            }
        }
    }

    foreach ($ns in $pending) {
        Write-Host "[WARN]  [$SubscriptionId] '$ns' was still registering after ${timeoutSeconds}s — deployments may hit MissingSubscriptionRegistration on their first attempt."
    }
}

foreach ($provider in $failed) {
    $severity = if ($provider.Required) { 'ERROR' } else { 'WARN' }
    Write-Host "[$severity] [$SubscriptionId] '$($provider.Namespace)' is NOT registered — $($provider.Reason)."
    Write-Host "[$severity] [$SubscriptionId] A subscription Owner must run once (subscription-wide, unblocks every lab):"
    Write-Host "[$severity] [$SubscriptionId]   az provider register --namespace $($provider.Namespace) --subscription $SubscriptionId"
}

Write-Host "[OK]    [$SubscriptionId] Shared subscription preparation complete (Citadel Agentic Governance microhack)."
