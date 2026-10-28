# Local-only wrapper to run labautomation/deploy-lab.ps1 outside the MicroHack platform.
# Supplies the platform-provided helper (Get-MhhStableHash), pre-creates the resource
# group, and passes the signed-in user's Entra object ID, exactly as the platform would.
# Not part of the participant flow: for facilitators testing the lab automation.
#
# Prereqs: Connect-AzAccount (Az PowerShell) AND az login (Azure CLI) to the SAME subscription.
# The CLI is used afterwards by the lab tools (python3 -m regintel).
#
# Examples:
#   ./dev/run-local.ps1                                   # current subscription, uksouth
#   ./dev/run-local.ps1 -Location swedencentral           # try another region
#   ./dev/run-local.ps1 -DeploymentType subscription      # let the script name the resource group

param(
    [string]$SubscriptionId = ((Get-AzContext -ErrorAction SilentlyContinue).Subscription.Id),
    [ValidateSet('resourcegroup', 'subscription')]
    [string]$DeploymentType = 'resourcegroup',
    [string]$ResourceGroupName = 'rg-regintel-local',
    [string]$Location = 'uksouth',
    [string[]]$AllowedEntraUserIds = @()
)

$ErrorActionPreference = 'Stop'

if (-not $SubscriptionId) {
    throw 'No subscription in context. Run Connect-AzAccount first, or pass -SubscriptionId.'
}
if ((Get-AzContext).Subscription.Id -ne $SubscriptionId) {
    throw 'Az context does not match SubscriptionId. Select the intended subscription before running.'
}
$cliSubscription = (az account show --query id -o tsv 2>$null)
if ($cliSubscription -ne $SubscriptionId) {
    Write-Warning "Azure CLI is on subscription '$cliSubscription', not '$SubscriptionId'. The lab tools use the CLI: run 'az account set --subscription $SubscriptionId'."
}

# The platform passes the lab's attendee object IDs. Locally, default to the signed-in user.
if ($AllowedEntraUserIds.Count -eq 0) {
    $signedInId = (Get-AzADUser -SignedIn -ErrorAction SilentlyContinue).Id
    if (-not $signedInId) {
        throw 'Could not resolve your Entra object ID. Pass -AllowedEntraUserIds <object-id> explicitly.'
    }
    $AllowedEntraUserIds = @($signedInId)
}

# Platform-provided helper shim: deterministic, DNS-safe, lowercase hash.
function Get-MhhStableHash {
    param([Parameter(ValueFromRemainingArguments = $true)][object[]]$InputValues, [int]$Length = 12)
    $strings = @()
    foreach ($v in $InputValues) { $strings += $v }
    $joined = ($strings -join '|')
    if ([string]::IsNullOrEmpty($joined)) { $joined = 'default' }
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $bytes = $sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($joined))
    $hex = -join ($bytes | ForEach-Object { $_.ToString('x2') })
    return $hex.Substring(0, $Length)
}

$arguments = @{
    DeploymentType      = $DeploymentType
    SubscriptionId      = $SubscriptionId
    PreferredLocation   = @($Location)
    AllowedEntraUserIds = $AllowedEntraUserIds
}
if ($DeploymentType -eq 'resourcegroup') {
    # The platform creates the resource group for 'resourcegroup' deployments.
    if (-not (Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue)) {
        Write-Host "[INFO]  Creating resource group '$ResourceGroupName' in '$Location'..."
        New-AzResourceGroup -Name $ResourceGroupName -Location $Location | Out-Null
    }
    $arguments.ResourceGroupName = $ResourceGroupName
}

# Az PowerShell compiles .bicep with the Bicep CLI on PATH; reuse the Azure CLI's copy if that is the only one.
if (-not (Get-Command bicep -ErrorAction SilentlyContinue)) {
    $cliBicep = Join-Path $HOME '.azure/bin'
    if (Test-Path (Join-Path $cliBicep 'bicep*')) {
        $env:PATH = "$cliBicep$([IO.Path]::PathSeparator)$env:PATH"
    } else {
        throw 'Bicep CLI not found. Run "az bicep install" or see https://aka.ms/bicep-install.'
    }
}

$started = Get-Date
$outputs = & "$PSScriptRoot\..\labautomation\deploy-lab.ps1" @arguments
Write-Host ("[OK]    Deployed in {0:N0} minutes. Lab dashboard values:" -f ((Get-Date) - $started).TotalMinutes)
$outputs | ForEach-Object { $_.HackboxCredential } | ForEach-Object { Write-Host ("        {0,-24} {1}" -f $_.name, $_.value) }
