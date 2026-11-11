# MicroHack Lab — EMEA Platform Conventions

This workspace is a microhack lab for the **EMEA MicroHack platform** ([microsoft/MicroHack](https://github.com/microsoft/MicroHack)).
The platform renders a front-end UI, but **all resource provisioning comes from `labautomation/deploy-lab.ps1`**.
Without a working deployment script, no resources appear in the Azure portal — the platform is just a shiny front end.

## Mandatory Structure

```
labautomation/          ← exactly this name, no dashes
  deploy-lab.ps1        ← platform entry point (optional but recommended)
  lab-defaults.json     ← platform configuration (required if folder exists)
  README.md             ← usage notes
challenges/             ← challenge instructions (Markdown)
walkthrough/            ← solutions
README.md               ← hack intro, objectives, prerequisites
```

## deploy-lab.ps1 — Parameter Contract

The platform **skips the script** if the parameter block does not exactly match:

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

## Platform Guarantees (before your script runs)

- Az context is already set to `$SubscriptionId` — **do NOT call `Connect-AzAccount`**
- For `resourcegroup`/`resourcegroup-with-subscriptionowner`: the RG exists and your script has `Owner` — **do NOT call `New-AzResourceGroup`**
- For `subscription`: your script has `Owner` on the subscription; **you must create the RG yourself** using `Get-MhhStableHash` for deterministic naming
- `Az.Accounts` and `Az.Resources` modules are already imported

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

- `deploymentType`: `"resourcegroup"` | `"resourcegroup-with-subscriptionowner"` | `"subscription"`
- `groups`: `[]` (Azure only), `["GHCPUsers"]` (GitHub Copilot seat), `["M365-E5-Users"]` (M365 E5)
- `preferredLocation`: comma-separated regions, priority order
- `estimatedDailyCostsUsd`: per-user per-day cost for the lifecycle wizard

## Returning Credentials to Users

Write a hashtable to the output stream — the platform captures it and shows it on the user's dashboard:

```powershell
@{ HackboxCredential = @{ name = "AdminPassword"; value = "TopSecret!"; note = "VM admin password" } }
```

## Delivery Deadline

Labs must have at least a skeleton committed by **end of July** — September events are already scheduled.

## Platform Compatibility

The platform supports **on-site**, **online**, and **hybrid** delivery.
Do not hard-code corporate network or specific DNS assumptions.
