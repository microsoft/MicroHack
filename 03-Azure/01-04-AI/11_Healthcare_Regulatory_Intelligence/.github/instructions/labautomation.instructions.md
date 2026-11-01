---
description: "Use when creating, editing, or reviewing labautomation/deploy-lab.ps1, lab-defaults.json, or any PowerShell helper inside labautomation/. Enforces microsoft/MicroHack platform deployment conventions."
applyTo: "labautomation/**,**/11_Healthcare_Regulatory_Intelligence/labautomation/**"
---

# Lab Automation Conventions (microsoft/MicroHack)

## deploy-lab.ps1: Required Parameter Contract

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

**NEVER do these. They break platform integration:**

```powershell
# WRONG: platform already sets Az context
Connect-AzAccount

# WRONG: platform pre-creates the RG for resourcegroup deployments
New-AzResourceGroup -Name $ResourceGroupName ...
```

**For `subscription` deployments only**, you must create your own RG using a deterministic name:

```powershell
$stableHash = Get-MhhStableHash $AllowedEntraUserIds -Length 24
$effectiveResourceGroup = "lab-$stableHash"
New-AzResourceGroup -Name $effectiveResourceGroup -Location $effectiveLocation
```

## Resolving Effective Location

```powershell
$effectiveLocation = if ($PreferredLocation.Count -eq 1) { $PreferredLocation[0] } else { "swedencentral" }
```

Reject more than one preferred region in this lab. Do not silently move resources
or processing across borders. Surface capacity/availability failures for facilitator approval.

## Deploying Resources

Reference templates relative to `$scriptPath`:

```powershell
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
$template = Join-Path $scriptPath "..\infra\main.bicep"
New-AzResourceGroupDeployment -ResourceGroupName $effectiveResourceGroup -TemplateFile $template -Verbose
```

## Returning Credentials to the User Dashboard

Write a hashtable to the output stream. The platform captures every one:

```powershell
@{ HackboxCredential = @{ name = "ResourceGroupName"; value = $ResourceGroupName; note = "Dedicated training resources" } }
```

Always return at minimum the resource group name so users can find their resources.

## lab-defaults.json: Required Shape

```json
{
  "$schema": "https://raw.githubusercontent.com/microsoft/MicroHack/refs/heads/main/lab-defaults-schema.json",
  "groups": [],
  "deploymentType": "resourcegroup",
  "labsPerSubscription": 4,
  "preferredLocation": "uksouth",
  "estimatedDailyCostsUsd": 15.0
}
```

- `$schema` is **required**; the platform validates against it
- `deploymentType`: `"resourcegroup"` | `"resourcegroup-with-subscriptionowner"` | `"subscription"`
- `groups`: `[]` for Azure-only; add `"GHCPUsers"` or `"M365-E5-Users"` as needed
- `preferredLocation`: one approved region for this lab; no automatic regional fallback
- `estimatedDailyCostsUsd`: planning allowance, not a verified price quote; document assumptions

## Available Platform Helper Cmdlets

| Cmdlet | Use |
|--------|-----|
| `Get-MhhStableHash` | Deterministic per-user hash for resource naming in `subscription` mode |
| `Get-MhhLabUser` | Get Entra user details for `$AllowedEntraUserIds` |
| `Invoke-MhhDeploymentWithRegionFallback` | Deploy with automatic region fallback |
| `Test-MhhDeploymentFailureRetryable` | Check if a deployment error is transient |

The fallback helpers above are part of the shared platform reference, **not
approved for this lab**: they can recycle a resource group or change regions.
Use the reviewed incremental deployment hook and obtain separate approval for
any destructive cleanup or cross-region move.
