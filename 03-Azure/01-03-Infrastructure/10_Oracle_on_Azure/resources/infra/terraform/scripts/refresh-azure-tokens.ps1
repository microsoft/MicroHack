#!/usr/bin/env pwsh
<#!
.SYNOPSIS
Refreshes Azure CLI tokens for all Microhack subscriptions.

.DESCRIPTION
Cycles through every subscription used by the Oracle on Azure Microhack and
forces fresh Azure Resource Manager and Microsoft Graph tokens. This prevents
ExpiredAuthenticationToken errors during long Terraform runs by renewing the
auxiliary tokens Azure requires for cross-subscription operations.

.EXAMPLE
./refresh-azure-tokens.ps1
#>

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "[ OK ] $Message" -ForegroundColor Green
}

function Write-WarningMessage {
    param([string]$Message)
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Invoke-AzCommand {
    param([string[]]$Arguments)
    $output = az @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Command 'az $($Arguments -join ' ')' failed: $output"
    }
    return $output
}

function Get-AzTokenExpiry {
    param(
        [string]$SubscriptionId,
        [string]$ResourceType
    )

    $args = @(
        "account", "get-access-token",
        "--subscription", $SubscriptionId,
        "--resource-type", $ResourceType,
        "-o", "json"
    )

    $json = Invoke-AzCommand -Arguments $args | ConvertFrom-Json
    return [datetime]::Parse($json.expiresOn)
}

if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    Write-WarningMessage "Azure CLI not found. Install with 'winget install --id Microsoft.AzureCLI' and rerun."
    exit 1
}

try {
    $currentAccount = Invoke-AzCommand -Arguments @("account", "show", "-o", "json") | ConvertFrom-Json
    Write-Info "Using existing Azure CLI session for $($currentAccount.user.name)."
}
catch {
    Write-WarningMessage "No active Azure CLI session detected. Run 'az login' and re-run this script."
    exit 1
}

$subscriptions = @(
    [pscustomobject]@{ Name = "sub-t0";   SubscriptionId = "556f9b63-ebc9-4c7e-8437-9a05aa8cdb25"; TenantId = "f71980b2-590a-4de9-90d5-6fbc867da951" },
    [pscustomobject]@{ Name = "sub-t1";   SubscriptionId = "a0844269-41ae-442c-8277-415f1283d422"; TenantId = "f71980b2-590a-4de9-90d5-6fbc867da951" },
    [pscustomobject]@{ Name = "sub-t2";   SubscriptionId = "b1658f1f-33e5-4e48-9401-f66ba5e64cce"; TenantId = "f71980b2-590a-4de9-90d5-6fbc867da951" },
    [pscustomobject]@{ Name = "sub-t3";   SubscriptionId = "9aa72379-2067-4948-b51c-de59f4005d04"; TenantId = "f71980b2-590a-4de9-90d5-6fbc867da951" },
    [pscustomobject]@{ Name = "sub-t4";   SubscriptionId = "98525264-1eb4-493f-983d-16a330caa7f6"; TenantId = "f71980b2-590a-4de9-90d5-6fbc867da951" },
    [pscustomobject]@{ Name = "sub-odaa"; SubscriptionId = "4aecf0e8-2fe2-4187-bc93-0356bd2676f5"; TenantId = "f71980b2-590a-4de9-90d5-6fbc867da951" }
)

Write-Info "Refreshing Azure tokens for $($subscriptions.Count) subscriptions without prompting for login."

foreach ($entry in $subscriptions) {
    Write-Info "Processing $($entry.Name) ($($entry.SubscriptionId))."

    try {
        Invoke-AzCommand -Arguments @("account", "set", "--subscription", $entry.SubscriptionId) | Out-Null

        $armExpiry = Get-AzTokenExpiry -SubscriptionId $entry.SubscriptionId -ResourceType "arm"
        $graphExpiry = Get-AzTokenExpiry -SubscriptionId $entry.SubscriptionId -ResourceType "ms-graph"

        Write-Success "ARM token valid until $($armExpiry.ToUniversalTime().ToString("u")) UTC."
        Write-Success "MS Graph token valid until $($graphExpiry.ToUniversalTime().ToString("u")) UTC."
    }
    catch {
        Write-WarningMessage "Failed to refresh tokens for $($entry.SubscriptionId): $($_.Exception.Message)"
    }
}

$defaultSubscriptionId = $currentAccount.id
if ($defaultSubscriptionId) {
    Invoke-AzCommand -Arguments @("account", "set", "--subscription", $defaultSubscriptionId) | Out-Null
    Write-Info "Default Azure context restored to $($currentAccount.name) ($defaultSubscriptionId)."
}

Write-Success "Token refresh complete. Terraform can now run without auxiliary token expiry."