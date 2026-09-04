---
description: "Use when creating, editing, or reviewing labautomation/deploy-lab.ps1, lab-defaults.json, or any PowerShell helper inside labautomation/. Enforces microsoft/MicroHack platform deployment conventions."
applyTo: "labautomation/**"
---

# Lab Automation Conventions (microsoft/MicroHack)

## deploy-lab.ps1 — Required Parameter Contract

The platform **silently skips** the script if the parameter block does not match exactly:

```powershell
param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('subscription','resourcegroup','resourcegroup-with-subscriptionowner')]
    [string]$DeploymentType,

    [Parameter(Mandatory=$true)]
    [string]$SubscriptionId,

    [string]$ResourceGroupName = "",

    [string[]]$PreferredLocation = @(),

    [string[]]$AllowedEntraUserIds = @()
)
```

## Critical Platform Rules

**NEVER do these — they break platform integration:**

```powershell
# WRONG — platform already sets Az context
Connect-AzAccount

# WRONG — platform pre-creates the RG for resourcegroup deployments
New-AzResourceGroup -Name $ResourceGroupName ...
```

**For `subscription` deployments only** — you must create your own RG using a deterministic name:

```powershell
$stableHash = Get-MhhStableHash $AllowedEntraUserIds -Length 24
$effectiveResourceGroup = "lab-$stableHash"
New-AzResourceGroup -Name $effectiveResourceGroup -Location $effectiveLocation
```

## Resolving Effective Location

```powershell
$effectiveLocation = if ($PreferredLocation.Count -gt 0) { $PreferredLocation[0] } else { "swedencentral" }
```

## Deploying Resources

Reference templates relative to `$scriptPath`. This hack deploys the resource-group-scoped
module `infra/resources.bicep` (the same one `azd up` uses):

```powershell
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
$template = Join-Path $scriptPath "infra/resources.bicep"
New-AzResourceGroupDeployment -ResourceGroupName $effectiveResourceGroup -TemplateFile $template -Verbose
```

## Returning Credentials to the User Dashboard

Write a hashtable to the output stream — the platform captures every one:

```powershell
@{ HackboxCredential = @{ name = "FoundryProjectEndpoint"; value = $endpoint; note = "AZURE_AI_PROJECT_ENDPOINT in .env" } }
```

Always return at minimum the resource group name so users can find their resources.

## shared-deploy-lab.ps1 — Once-Per-Subscription Hook

Optional sibling of `deploy-lab.ps1`, picked up automatically by file name. The platform runs it
**once per subscription, before** the per-participant `deploy-lab.ps1` fan-out — the correct home for
one-off subscription prep the parallel lab runs would otherwise race on (**registering resource
providers**, shared hub resources). If it **throws**, the platform runs **no** `deploy-lab.ps1` for
that subscription, so keep provider registration best-effort (try/catch + WARN, never throw).

Required parameter contract:

```powershell
param(
    [Parameter(Mandatory = $true)]
    [string]$SubscriptionId,

    [Parameter(Mandatory = $true)]
    [string[]]$PreferredLocation = @(),

    [Parameter(Mandatory = $false)]
    [string[]]$AllowedEntraUserIds = @()
)
```

This hack uses it to register **`Microsoft.BotService`** (Challenge 5 Teams / M365 publish) once per
subscription — so participants never hit `MissingSubscriptionRegistration`, **without** switching
`deploymentType` to `resourcegroup-with-subscriptionowner` (which would make every participant an
Owner of the shared subscription). Do NOT register providers in `deploy-lab.ps1`: in a `resourcegroup`
lab that script runs with only subscription-**Reader**, and every parallel job would race.

## lab-defaults.json — Required Shape

```json
{
  "$schema": "https://raw.githubusercontent.com/microsoft/MicroHack/refs/heads/main/lab-defaults-schema.json",
  "groups": [],
  "deploymentType": "resourcegroup",
  "labsPerSubscription": 4,
  "preferredLocation": "swedencentral, westeurope, norwayeast",
  "estimatedDailyCostsUsd": 12.0
}
```

- `$schema` is **required** — the platform validates against it
- `deploymentType`: `"resourcegroup"` | `"resourcegroup-with-subscriptionowner"` | `"subscription"`
- `groups`: `[]` for Azure-only; add `"GHCPUsers"` or `"M365-E5-Users"` as needed
- `preferredLocation`: comma-separated regions in priority order — list multiple for regional fallback
- `estimatedDailyCostsUsd`: cost per user per day; used in the lifecycle cost wizard

## Available Platform Helper Cmdlets

| Cmdlet | Use |
|--------|-----|
| `Get-MhhStableHash` | Deterministic per-user hash for resource naming in `subscription` mode |
| `Get-MhhLabUser` | Get Entra user details for `$AllowedEntraUserIds` |
| `Invoke-MhhDeploymentWithRegionFallback` | Deploy with automatic region fallback |
| `Test-MhhDeploymentFailureRetryable` | Check if a deployment error is transient |
