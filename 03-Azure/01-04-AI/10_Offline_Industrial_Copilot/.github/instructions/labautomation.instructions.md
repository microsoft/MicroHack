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
$effectiveLocation = if ($PreferredLocation.Count -gt 0) { $PreferredLocation[0] } else { "westeurope" }
```

## Deploying Resources

Reference templates relative to `$scriptPath`:

```powershell
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
$template = Join-Path $scriptPath "template.bicep"
New-AzResourceGroupDeployment -ResourceGroupName $effectiveResourceGroup -TemplateFile $template -Verbose
```

## Returning Credentials to the User Dashboard

Write a hashtable to the output stream — the platform captures every one:

```powershell
@{ HackboxCredential = @{ name = "AdminPassword"; value = "TopSecret!"; note = "VM admin password" } }
```

Always return at minimum the resource group name so users can find their resources.

## lab-defaults.json — Required Shape

```json
{
  "$schema": "https://raw.githubusercontent.com/microsoft/MicroHack/refs/heads/main/lab-defaults-schema.json",
  "groups": [],
  "deploymentType": "resourcegroup",
  "labsPerSubscription": 4,
  "preferredLocation": "westeurope, swedencentral, norwayeast",
  "estimatedDailyCostsUsd": 5.0
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
