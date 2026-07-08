# MicroHack — Authoring Conventions

This workspace is the **microsoft/MicroHack** repository.
It hosts community-contributed microhack labs for EMEA events and beyond.
The platform renders a front-end UI, but **all resource provisioning comes from `labautomation/deploy-lab.ps1`** inside each hack.
Without a working deployment script, no resources appear in the Azure portal — the platform is just a shiny front end.

## Repository Structure

```
<hack-name>/
  challenges/           ← challenge instructions (Markdown)
  walkthrough/          ← solutions
  images/               ← screenshots (store locally, not in CDN)
  Readme.md             ← hack intro, objectives, prerequisites
  labautomation/        ← optional: only if the hack needs Azure resource provisioning
    deploy-lab.ps1      ← platform entry point
    lab-defaults.json   ← platform configuration (required if folder exists)
    README.md           ← usage notes
```

Use `99-MicroHack-Template/` as the starting point for every new hack.

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

## Content Conventions

- File/folder names: lowercase with dashes (e.g. `01-zero-trust/`)
- Images: store in `images/` subfolder within the hack, keep files small
- Challenges: numbered Markdown files in `challenges/` (`challenge-01.md`, `challenge-02.md`, …)
- Walkthroughs: matching numbered folders in `walkthrough/`
- Platform compatibility: works for on-site, online, and hybrid events — no corporate network or DNS assumptions

## Tooling Available

Use `/scaffold-lab-automation` (Copilot Chat slash command) to generate a compliant `deploy-lab.ps1` from a description of your hack's Azure resources.
Use the **Hack Compliance Validator** agent to audit your hack before requesting platform access.
