# Local-only wrapper to run labautomation/deploy-lab.ps1 outside the MicroHack platform.
# Supplies the platform helper Get-MhhStableHash, creates the resource group (the platform does
# this for 'resourcegroup' labs) and passes your signed-in user's Entra object ID.
# For facilitators verifying the lab end to end; attendees never run this.

param(
    [string]$SubscriptionId = ((Get-AzContext -ErrorAction SilentlyContinue).Subscription.Id),
    [string]$ResourceGroupName = "rg-decision-hack-local",
    [string]$Location = "swedencentral",
    [string[]]$AllowedEntraUserIds = @()
)

$ErrorActionPreference = "Stop"

if (-not $SubscriptionId) {
    throw "No subscription in context. Run Connect-AzAccount first, or pass -SubscriptionId."
}
Set-AzContext -Subscription $SubscriptionId | Out-Null

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
    $joined = (@($InputValues | ForEach-Object { $_ }) -join '|')
    if ([string]::IsNullOrEmpty($joined)) { $joined = "default" }
    $bytes = [System.Security.Cryptography.SHA256]::Create().ComputeHash([System.Text.Encoding]::UTF8.GetBytes($joined))
    return (-join ($bytes | ForEach-Object { $_.ToString('x2') })).Substring(0, $Length)
}

if (-not (Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue)) {
    Write-Host "[INFO]  Creating resource group '$ResourceGroupName' in '$Location'..."
    New-AzResourceGroup -Name $ResourceGroupName -Location $Location | Out-Null
}

& "$PSScriptRoot\..\labautomation\deploy-lab.ps1" `
    -DeploymentType 'resourcegroup' `
    -SubscriptionId $SubscriptionId `
    -ResourceGroupName $ResourceGroupName `
    -PreferredLocation @($Location, "westeurope", "germanywestcentral") `
    -AllowedEntraUserIds $AllowedEntraUserIds
