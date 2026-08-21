<#
  shared-deploy-lab.ps1 — EMEA MicroHack once-per-subscription hook for the Foundry CLM microhack.

  The microsoft/MicroHack platform runs THIS script exactly once per Azure subscription, in parallel
  across subscriptions, BEFORE the per-participant deploy-lab.ps1 fan-out starts. It is the sanctioned
  home for one-off subscription preparation that the many parallel deploy-lab.ps1 runs would otherwise
  race on — the platform README names "registering resource providers" as the canonical example.

  Why the CLM hack needs it:
    Challenge 5 publishes the Foundry agent to Teams / M365 Copilot, which auto-creates an Azure Bot.
    That requires the 'Microsoft.BotService' resource provider registered at SUBSCRIPTION scope. The
    platform pre-registers Microsoft.App / Microsoft.OperationalInsights but NOT Microsoft.BotService,
    and in a 'resourcegroup' lab the participant holds only subscription-Reader (+ RG-Owner), so they
    cannot self-register it (registration is a subscription-scope write — az provider register fails
    with AuthorizationFailed for a Reader). Registering it here — once per subscription, ahead of the
    labs — makes Challenge 5 "just work" for every participant WITHOUT granting anyone subscription
    Owner. (Switching lab-defaults.json to 'resourcegroup-with-subscriptionowner' would instead make
    every one of the up-to-8 participants sharing a subscription an Owner of it — they could then see
    and delete each other's resource groups. This hook keeps that isolation intact.)

  Platform contract / guarantees (see labautomation/README.md):
    - Picked up automatically by file name; parameters below are the shared-hook contract.
    - Az context is already set to $SubscriptionId  -> do NOT Connect-AzAccount.
    - Az.Accounts / Az.Resources are already imported; the hook runs with subscription-level rights
      sufficient to register providers / deploy shared resources.
    - Runs to completion before the FIRST deploy-lab.ps1 in the subscription starts.
    - If this hook THROWS, the platform runs NO deploy-lab.ps1 for the subscription and marks the
      deployment failed. Registering Microsoft.BotService is therefore best-effort: a failure here
      only affects Challenge 5, so it must WARN and continue — it must never abort provisioning of
      Challenges 1-4 for the whole subscription.
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

# Resource providers the CLM labs need that the platform does NOT pre-register.
#   Microsoft.BotService — Challenge 5 "Publish to Teams / M365 Copilot" auto-creates an Azure Bot.
# Add more here if a future challenge needs another subscription-scoped provider.
$requiredProviders = @(
    'Microsoft.BotService'
)

foreach ($provider in $requiredProviders) {
    try {
        $state = (Get-AzResourceProvider -ProviderNamespace $provider -ErrorAction SilentlyContinue |
            Select-Object -First 1).RegistrationState

        if ($state -eq 'Registered') {
            Write-Host "[OK]    [$SubscriptionId] Resource provider '$provider' already registered."
            continue
        }

        Write-Host "[INFO]  [$SubscriptionId] Registering resource provider '$provider' (state: '$state')..."
        Register-AzResourceProvider -ProviderNamespace $provider -ErrorAction Stop | Out-Null
        Write-Host "[OK]    [$SubscriptionId] Registration submitted for '$provider' (async, idempotent, subscription-wide)."
    }
    catch {
        # Best-effort: NEVER abort the whole subscription's provisioning over one provider registration.
        # A missing Microsoft.BotService only blocks Challenge 5's Teams publish, not Challenges 1-4.
        Write-Host "[WARN]  [$SubscriptionId] Could not register '$provider': $_"
        Write-Host "[WARN]  [$SubscriptionId] Challenge 5 'Publish to Teams' may fail with MissingSubscriptionRegistration"
        Write-Host "[WARN]  [$SubscriptionId] until a subscription Owner runs once:"
        Write-Host "[WARN]  [$SubscriptionId]   az provider register --namespace $provider --subscription $SubscriptionId"
    }
}

Write-Host "[OK]    [$SubscriptionId] Shared subscription preparation complete (CLM microhack)."
