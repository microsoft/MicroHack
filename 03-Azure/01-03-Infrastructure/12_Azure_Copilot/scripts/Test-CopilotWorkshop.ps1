#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Tests all deployed Azure resources for the Copilot Workshop.
.DESCRIPTION
    Validates that all resources exist and are correctly configured
    for each challenge scenario.
.PARAMETER Suffix
    The deployment suffix used during provisioning (e.g., 'abcd').
.EXAMPLE
    .\Test-CopilotWorkshop.ps1 -Suffix abcd
#>
param(
    [Parameter(Mandatory=$true)]
    [string]$Suffix
)

$ErrorActionPreference = "Continue"
Set-StrictMode -Version Latest

$passed = 0
$failed = 0
$warnings = 0

function Test-Resource {
    param([string]$Name, [scriptblock]$Test, [string]$Challenge)
    try {
        $result = & $Test
        if ($result) {
            Write-Host "  ✓ PASS: $Name" -ForegroundColor Green
            $script:passed++
        }
        else {
            Write-Host "  ✗ FAIL: $Name" -ForegroundColor Red
            $script:failed++
        }
    }
    catch {
        Write-Host "  ✗ FAIL: $Name - $_" -ForegroundColor Red
        $script:failed++
    }
}

function Test-Warning {
    param([string]$Name, [string]$Message)
    Write-Host "  ⚠ WARN: $Name - $Message" -ForegroundColor Yellow
    $script:warnings++
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host " Azure Copilot Workshop - Test Suite" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$account = az account show -o json 2>&1 | ConvertFrom-Json
Write-Host "Subscription: $($account.name)`n" -ForegroundColor Green

# ──────────────────────────────────────────────
# Challenge 00: Basics
# ──────────────────────────────────────────────
Write-Host "Challenge 00: Azure Copilot Basics" -ForegroundColor Yellow
Write-Host "  Resource Group: rg-copilot-$Suffix-ch00" -ForegroundColor DarkGray

Test-Resource "Resource group exists" {
    (az group exists --name rg-copilot-$Suffix-ch00 2>&1) -eq "true"
}

Test-Resource "Storage account (stcopilotworkshop*)" {
    $name = az storage account list -g rg-copilot-$Suffix-ch00 --query "[?starts_with(name, 'stcopilotworkshop')].name" -o tsv 2>&1
    if ([string]::IsNullOrWhiteSpace($name)) { return $false }
    $r = az storage account show -n $name.Trim() -g rg-copilot-$Suffix-ch00 --query provisioningState -o tsv 2>&1
    $r -eq "Succeeded"
}

Test-Resource "VNet vnet-copilot-workshop" {
    $r = az network vnet show -n vnet-copilot-workshop -g rg-copilot-$Suffix-ch00 --query provisioningState -o tsv 2>&1
    $r -eq "Succeeded"
}

Test-Resource "VNet has 2 subnets" {
    $raw = az network vnet subnet list --vnet-name vnet-copilot-workshop -g rg-copilot-$Suffix-ch00 -o json 2>&1
    $subnets = $raw | ConvertFrom-Json
    $subnets.Count -ge 2
}

Test-Resource "NSG nsg-copilot-workshop" {
    $r = az network nsg show -n nsg-copilot-workshop -g rg-copilot-$Suffix-ch00 --query provisioningState -o tsv 2>&1
    $r -eq "Succeeded"
}

# ──────────────────────────────────────────────
# Challenge 02: Observability Agent
# ──────────────────────────────────────────────
Write-Host "`nChallenge 02: Observability Agent" -ForegroundColor Yellow
Write-Host "  Resource Group: rg-copilot-$Suffix-ch02" -ForegroundColor DarkGray

Test-Resource "Resource group exists" {
    (az group exists --name rg-copilot-$Suffix-ch02 2>&1) -eq "true"
}

Test-Resource "Log Analytics workspace law-copilot-ch02" {
    $r = az monitor log-analytics workspace show -g rg-copilot-$Suffix-ch02 -n law-copilot-ch02 --query provisioningState -o tsv 2>&1
    $r -eq "Succeeded"
}

Test-Resource "App Insights ai-copilot-ch02" {
    $r = az monitor app-insights component show --app ai-copilot-ch02 -g rg-copilot-$Suffix-ch02 --query provisioningState -o tsv 2>&1
    $r -eq "Succeeded"
}

Test-Resource "App Service (app-copilot-buggy-*)" {
    $name = az webapp list -g rg-copilot-$Suffix-ch02 --query "[?starts_with(name, 'app-copilot-buggy')].name" -o tsv 2>&1
    if ([string]::IsNullOrWhiteSpace($name)) { return $false }
    $r = az webapp show -g rg-copilot-$Suffix-ch02 -n $name.Trim() --query state -o tsv 2>&1
    $r -eq "Running"
}

Test-Resource "App responds on /health" {
    try {
        $name = az webapp list -g rg-copilot-$Suffix-ch02 --query "[?starts_with(name, 'app-copilot-buggy')].defaultHostName" -o tsv 2>&1
        if ([string]::IsNullOrWhiteSpace($name)) { return $false }
        $r = Invoke-RestMethod -Uri "https://$($name.Trim())/health" -TimeoutSec 30
        $r.status -eq "healthy"
    }
    catch { $false }
}

Test-Resource "App /crash returns 500" {
    try {
        $name = az webapp list -g rg-copilot-$Suffix-ch02 --query "[?starts_with(name, 'app-copilot-buggy')].defaultHostName" -o tsv 2>&1
        if ([string]::IsNullOrWhiteSpace($name)) { return $false }
        Invoke-WebRequest -Uri "https://$($name.Trim())/crash" -TimeoutSec 10
        $false  # Should have thrown
    }
    catch {
        $_.Exception.Response.StatusCode.value__ -eq 500
    }
}

Test-Resource "App /slow responds > 3s" {
    try {
        $name = az webapp list -g rg-copilot-$Suffix-ch02 --query "[?starts_with(name, 'app-copilot-buggy')].defaultHostName" -o tsv 2>&1
        if ([string]::IsNullOrWhiteSpace($name)) { return $false }
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        Invoke-WebRequest -Uri "https://$($name.Trim())/slow" -TimeoutSec 30
        $sw.Stop()
        $sw.ElapsedMilliseconds -gt 3000
    }
    catch { $false }
}

Test-Resource "Alert rule: alert-http-5xx" {
    $r = az monitor metrics alert show -g rg-copilot-$Suffix-ch02 -n "alert-http-5xx" --query enabled -o tsv 2>&1
    $r -eq "True"
}

Test-Resource "Alert rule: alert-slow-response" {
    $r = az monitor metrics alert show -g rg-copilot-$Suffix-ch02 -n "alert-slow-response" --query enabled -o tsv 2>&1
    $r -eq "True"
}

Test-Resource "Alert rule: alert-http-4xx" {
    $r = az monitor metrics alert show -g rg-copilot-$Suffix-ch02 -n "alert-http-4xx" --query enabled -o tsv 2>&1
    $r -eq "True"
}

# ──────────────────────────────────────────────
# Challenge 03: Optimization Agent
# ──────────────────────────────────────────────
Write-Host "`nChallenge 03: Optimization Agent" -ForegroundColor Yellow
Write-Host "  Resource Group: rg-copilot-$Suffix-ch03" -ForegroundColor DarkGray

Test-Resource "Resource group exists" {
    (az group exists --name rg-copilot-$Suffix-ch03 2>&1) -eq "true"
}

Test-Resource "VM vm-copilot-oversized exists" {
    $r = az vm show -g rg-copilot-$Suffix-ch03 -n vm-copilot-oversized --query provisioningState -o tsv 2>&1
    $r -eq "Succeeded"
}

Test-Resource "VM is oversized (D4s_v3)" {
    $r = az vm show -g rg-copilot-$Suffix-ch03 -n vm-copilot-oversized --query hardwareProfile.vmSize -o tsv 2>&1
    $r -eq "Standard_D4s_v3"
}

Test-Warning "Azure Advisor recommendations" "May take 24-48 hours to appear for the oversized VM"

# ──────────────────────────────────────────────
# Challenge 04: Resiliency Agent
# ──────────────────────────────────────────────
Write-Host "`nChallenge 04: Resiliency Agent" -ForegroundColor Yellow
Write-Host "  Resource Group: rg-copilot-$Suffix-ch04" -ForegroundColor DarkGray

Test-Resource "Resource group exists" {
    (az group exists --name rg-copilot-$Suffix-ch04 2>&1) -eq "true"
}

Test-Resource "VM vm-copilot-noresilience exists" {
    $r = az vm show -g rg-copilot-$Suffix-ch04 -n vm-copilot-noresilience --query provisioningState -o tsv 2>&1
    $r -eq "Succeeded"
}

Test-Resource "VM has NO availability zone (not zone-resilient)" {
    $zones = az vm show -g rg-copilot-$Suffix-ch04 -n vm-copilot-noresilience --query zones -o tsv 2>&1
    [string]::IsNullOrWhiteSpace($zones)
}

# Check backup is NOT configured
Test-Resource "VM has NO backup configured" {
    # List all recovery services vaults in the resource group
    $vaults = az backup vault list --resource-group rg-copilot-$Suffix-ch04 --query "[].name" -o tsv 2>&1
    if ([string]::IsNullOrWhiteSpace($vaults) -or $vaults -match "error") {
        # No vaults exist, so no backup is configured
        return $true
    }
    # Check if VM is protected in any vault
    foreach ($vault in $vaults -split "`n") {
        $backupItems = az backup item list --resource-group rg-copilot-$Suffix-ch04 --vault-name $vault.Trim() --query "[?properties.friendlyName=='vm-copilot-noresilience'].id" -o tsv 2>&1
        if (-not [string]::IsNullOrWhiteSpace($backupItems) -and $backupItems -notmatch "error") {
            return $false  # Backup IS configured
        }
    }
    return $true  # No backup found
}

# ──────────────────────────────────────────────
# Challenge 05: Troubleshooting Agent
# ──────────────────────────────────────────────
Write-Host "`nChallenge 05: Troubleshooting Agent" -ForegroundColor Yellow
Write-Host "  Resource Group: rg-copilot-$Suffix-ch05" -ForegroundColor DarkGray

Test-Resource "Resource group exists" {
    (az group exists --name rg-copilot-$Suffix-ch05 2>&1) -eq "true"
}

Test-Resource "VM vm-copilot-broken exists" {
    $r = az vm show -g rg-copilot-$Suffix-ch05 -n vm-copilot-broken --query provisioningState -o tsv 2>&1
    $r -eq "Succeeded"
}

Test-Resource "NSG DenySSH rule blocks port 22" {
    $r = az network nsg rule show -g rg-copilot-$Suffix-ch05 --nsg-name nsg-copilot-broken -n DenySSH --query access -o tsv 2>&1
    $r -eq "Deny"
}

Test-Resource "NSG DenyAllInbound rule exists" {
    $r = az network nsg rule show -g rg-copilot-$Suffix-ch05 --nsg-name nsg-copilot-broken -n DenyAllInbound --query access -o tsv 2>&1
    $r -eq "Deny"
}

Test-Resource "Cosmos DB (cosmos-copilot-broken-*)" {
    $name = az cosmosdb list -g rg-copilot-$Suffix-ch05 --query "[?starts_with(name, 'cosmos-copilot-broken')].name" -o tsv 2>&1
    if ([string]::IsNullOrWhiteSpace($name)) { return $false }
    $r = az cosmosdb show -n $name.Trim() -g rg-copilot-$Suffix-ch05 --query provisioningState -o tsv 2>&1
    $r -eq "Succeeded"
}

Test-Resource "Cosmos DB has restrictive firewall" {
    $name = az cosmosdb list -g rg-copilot-$Suffix-ch05 --query "[?starts_with(name, 'cosmos-copilot-broken')].name" -o tsv 2>&1
    if ([string]::IsNullOrWhiteSpace($name)) { return $false }
    $name = $name.Trim()
    $ip = az cosmosdb show -n $name -g rg-copilot-$Suffix-ch05 --query "ipRules[].ipAddressOrRange" -o tsv 2>&1
    $pub = az cosmosdb show -n $name -g rg-copilot-$Suffix-ch05 --query "publicNetworkAccess" -o tsv 2>&1
    # Restrictive if: public access disabled, or IP rules limited to localhost/0.0.0.0
    ($pub -eq "Disabled") -or (-not [string]::IsNullOrWhiteSpace($ip) -and ($ip -match "127\.0\.0\.1|0\.0\.0\.0"))
}

# ──────────────────────────────────────────────
# Summary
# ──────────────────────────────────────────────
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host " Test Results" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Passed:   $passed" -ForegroundColor Green
Write-Host "  Failed:   $failed" -ForegroundColor $(if ($failed -gt 0) { "Red" } else { "Green" })
Write-Host "  Warnings: $warnings" -ForegroundColor Yellow
Write-Host "  Total:    $($passed + $failed)`n"

if ($failed -eq 0) {
    Write-Host "All tests passed! Workshop is ready. ✓`n" -ForegroundColor Green
    exit 0
}
else {
    Write-Host "Some tests failed. Check the output above.`n" -ForegroundColor Red
    exit 1
}
