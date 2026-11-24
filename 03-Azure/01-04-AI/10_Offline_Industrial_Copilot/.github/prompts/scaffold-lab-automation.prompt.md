---
description: "Scaffold a complete labautomation/ directory for a new EMEA MicroHack. Generates deploy-lab.ps1, lab-defaults.json, and README.md that are 100% compliant with the microsoft/MicroHack platform contract."
name: "Scaffold Lab Automation"
agent: "agent"
argument-hint: "Describe the Azure resources this hack needs to deploy (e.g. 'a Storage Account and a Function App for an inventory management scenario')"
tools: [edit, read, search]
---

You are scaffolding the `labautomation/` directory for an EMEA MicroHack.
The user has described what Azure resources the hack needs.

**Do not ask clarifying questions** — infer reasonable defaults and note assumptions in the README.

## Step 1 — Read existing context

Check whether `labautomation/` already exists. If it does, read existing files before overwriting.

## Step 2 — Create lab-defaults.json

Create `labautomation/lab-defaults.json`. Always include the `$schema` field:

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

Adjust `deploymentType`, `preferredLocation`, and `estimatedDailyCostsUsd` to match the hack's needs.
Add `"GHCPUsers"` or `"M365-E5-Users"` to `groups` only if the hack requires those licenses.

## Step 3 — Create deploy-lab.ps1

Create `labautomation/deploy-lab.ps1` following the **exact** platform parameter contract:

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

**Critical rules — the platform silently skips the script if these are violated:**
- Do NOT call `Connect-AzAccount` — Az context is pre-set by the platform
- Do NOT call `New-AzResourceGroup` for `resourcegroup` deployments — the RG is pre-created
- For `subscription` deployments: use `Get-MhhStableHash $AllowedEntraUserIds -Length 24` for deterministic RG naming, then call `New-AzResourceGroup`
- Always emit at least one `@{ HackboxCredential = @{ name = ...; value = ...; note = ... } }` to the output stream

Add the actual resource deployments (Bicep, ARM, or Az cmdlets) in the body.
Reference the Bicep/ARM template file relative to `$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition`.

## Step 4 — Create README.md

Create `labautomation/README.md` covering:
- What the script deploys (bullet list of resources)
- `deploymentType` choice and reason
- `preferredLocation` choice and reason
- `estimatedDailyCostsUsd` basis
- Any assumptions made during scaffolding

## Step 5 — Self-validate

After creating all files, verify against the compliance checklist:
- Directory named exactly `labautomation` (no dashes) ✅
- `lab-defaults.json` has `$schema` field ✅
- `deploy-lab.ps1` parameter block matches contract exactly ✅
- No `Connect-AzAccount` in the script ✅
- No `New-AzResourceGroup` for resourcegroup deployment type ✅
- At least one `HackboxCredential` returned ✅
- No hard-coded environment assumptions ✅

Report any item you could not satisfy and why.
