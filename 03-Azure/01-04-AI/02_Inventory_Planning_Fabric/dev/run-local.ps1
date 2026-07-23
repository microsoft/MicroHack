# Local-only wrapper to run deploy-lab.ps1 outside the MicroHack platform.
# Supplies the platform-provided helper (Get-MhhStableHash), pre-creates the
# resource group, and passes the current signed-in user's Entra object ID.
# NOT part of the hack deliverable — for local end-to-end verification only.
#
# Prereqs: Connect-AzAccount (Az) AND az login (CLI) to the SAME subscription.
# deploy-lab.ps1 provisions the signed-in user's Foundry project + their own Fabric
# F2 capacity; you then build your workspace + Data Agent by running
# setup/Setup-InventoryDataAgent.ipynb (see Challenge 0).

param(
    # Defaults to the current Az context subscription; pass to override.
    [string]$SubscriptionId = ((Get-AzContext -ErrorAction SilentlyContinue).Subscription.Id),
    [string]$ResourceGroupName = "rg-inventory-hack-local",
    [string]$Location = "swedencentral",
    # Defaults to the current signed-in user's Entra object ID (resolved below).
    [string[]]$AllowedEntraUserIds = @()
)

$ErrorActionPreference = "Stop"

if (-not $SubscriptionId) {
    throw "No subscription in context. Run Connect-AzAccount first, or pass -SubscriptionId."
}

# The platform passes the lab's attendee object IDs here. Run locally, this defaults
# to the signed-in user so the RBAC grants target you.
if ($AllowedEntraUserIds.Count -eq 0) {
    $signedInId = (Get-AzADUser -SignedIn -ErrorAction SilentlyContinue).Id
    if (-not $signedInId) {
        throw "Could not resolve your Entra object ID. Pass -AllowedEntraUserIds <object-id> explicitly."
    }
    $AllowedEntraUserIds = @($signedInId)
}

# Platform-provided helper shim: deterministic, DNS-safe, lowercase hash.
function Get-MhhStableHash {
    param([Parameter(ValueFromRemainingArguments = $true)][object[]]$InputValues, [int]$Length = 12)
    $strings = @()
    foreach ($v in $InputValues) { if ($v -is [array]) { $strings += $v } else { $strings += $v } }
    $joined = ($strings -join '|')
    if ([string]::IsNullOrEmpty($joined)) { $joined = "default" }
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $bytes = $sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($joined))
    $hex = -join ($bytes | ForEach-Object { $_.ToString('x2') })
    return $hex.Substring(0, $Length)
}

# Platform-provided helper shim: resolve an Entra object ID to a lab-user record
# (Id / UserPrincipalName / ShortName). The real platform serves this from a cache;
# locally we resolve via Get-AzADUser.
function Get-MhhLabUser {
    param([Parameter(Mandatory = $true, ValueFromPipeline = $true)][Alias('ObjectId', 'Id')][string[]]$UserId)
    process {
        foreach ($id in $UserId) {
            $u = Get-AzADUser -ObjectId $id -ErrorAction SilentlyContinue
            $upn = $u.UserPrincipalName
            [PSCustomObject]@{
                Id                = $id
                UserPrincipalName = $upn
                ShortName         = if ($upn) { ($upn -split '@')[0].ToLower() } else { $null }
            }
        }
    }
}

# Pre-create the resource group (the platform does this for 'resourcegroup' type).
if (-not (Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue)) {
    Write-Host "[INFO]  Creating resource group '$ResourceGroupName' in '$Location'..."
    New-AzResourceGroup -Name $ResourceGroupName -Location $Location | Out-Null
    Write-Host "[OK]    Resource group created."
} else {
    Write-Host "[OK]    Resource group already exists."
}

& "$PSScriptRoot\..\labautomation\deploy-lab.ps1" `
    -DeploymentType 'resourcegroup' `
    -SubscriptionId $SubscriptionId `
    -ResourceGroupName $ResourceGroupName `
    -PreferredLocation @($Location, "westeurope", "norwayeast") `
    -AllowedEntraUserIds $AllowedEntraUserIds
