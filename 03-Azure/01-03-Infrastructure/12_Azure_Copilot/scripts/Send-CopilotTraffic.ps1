#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Generates error traffic against the Ch02 buggy app to trigger alerts.
.DESCRIPTION
    Hits the crash, slow, and DB-error endpoints to generate
    Application Insights telemetry and fire alert rules.
.PARAMETER BaseUrl
    The base URL of the deployed app.
.PARAMETER Suffix
    The deployment suffix used during provisioning (used for auto-discovery).
.PARAMETER Rounds
    Number of rounds to run (default: 1).
.EXAMPLE
    .\Send-CopilotTraffic.ps1 -Suffix abcd
    .\Send-CopilotTraffic.ps1 -Rounds 5 -BaseUrl https://app-copilot-buggy-abcd.azurewebsites.net
#>
param(
    [string]$BaseUrl,
    [string]$Suffix,
    [int]$Rounds = 1
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# Auto-discover app URL if not provided
if ([string]::IsNullOrWhiteSpace($BaseUrl)) {
    if ([string]::IsNullOrWhiteSpace($Suffix)) {
        Write-Error "Provide either -BaseUrl or -Suffix to discover the app URL."
        exit 1
    }
    $rgName = "rg-copilot-$Suffix-ch02"
    Write-Host "No -BaseUrl specified. Discovering from $rgName..." -ForegroundColor Yellow
    $hostName = az webapp list -g $rgName --query "[?starts_with(name, 'app-copilot-buggy')].defaultHostName" -o tsv 2>&1
    if ([string]::IsNullOrWhiteSpace($hostName) -or $LASTEXITCODE -ne 0) {
        Write-Error "Could not discover app URL. Pass -BaseUrl explicitly or ensure $rgName is deployed."
        exit 1
    }
    $BaseUrl = "https://$($hostName.Trim())"
    Write-Host "  Discovered: $BaseUrl`n" -ForegroundColor Green
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host " Generating Error Traffic (Ch02)" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan
Write-Host "Target: $BaseUrl"
Write-Host "Rounds: $Rounds`n"

# Test connectivity first
Write-Host "Testing connectivity..." -ForegroundColor Yellow
try {
    $health = Invoke-RestMethod -Uri "$BaseUrl/health" -TimeoutSec 30
    Write-Host "  ✓ App is responsive: $($health.status)`n" -ForegroundColor Green
} catch {
    Write-Host "  ✗ App is not responding. Is it deployed?" -ForegroundColor Red
    Write-Host "  Error: $_`n" -ForegroundColor Red
    exit 1
}

for ($round = 1; $round -le $Rounds; $round++) {
    Write-Host "--- Round $round of $Rounds ---" -ForegroundColor Yellow

    # 500 errors
    Write-Host "  Generating 500 errors (10 requests)..."
    $errorCount = 0
    1..10 | ForEach-Object {
        try { Invoke-WebRequest -Uri "$BaseUrl/crash" -TimeoutSec 10 -ErrorAction SilentlyContinue } catch { $errorCount++ }
    }
    Write-Host "    ✓ $errorCount/10 errors generated" -ForegroundColor Green

    # Slow responses
    Write-Host "  Generating slow responses (3 requests, ~5s each)..."
    $slowCount = 0
    1..3 | ForEach-Object {
        try {
            $sw = [System.Diagnostics.Stopwatch]::StartNew()
            Invoke-WebRequest -Uri "$BaseUrl/slow" -TimeoutSec 30 -ErrorAction SilentlyContinue | Out-Null
            $sw.Stop()
            $slowCount++
            Write-Host "    Response ${_}: $($sw.ElapsedMilliseconds)ms" -ForegroundColor DarkGray
        } catch {}
    }
    Write-Host "    ✓ $slowCount/3 slow responses" -ForegroundColor Green

    # DB timeout errors
    Write-Host "  Generating DB timeout errors (5 requests)..."
    $dbErrorCount = 0
    1..5 | ForEach-Object {
        try { Invoke-WebRequest -Uri "$BaseUrl/api/orders" -TimeoutSec 15 -ErrorAction SilentlyContinue } catch { $dbErrorCount++ }
    }
    Write-Host "    ✓ $dbErrorCount/5 DB errors generated" -ForegroundColor Green

    # Memory leak
    Write-Host "  Triggering memory-growing endpoint (3 requests)..."
    1..3 | ForEach-Object {
        try { Invoke-RestMethod -Uri "$BaseUrl/leak" -TimeoutSec 10 | Out-Null } catch {}
    }
    Write-Host "    ✓ Memory leak requests sent" -ForegroundColor Green

    # 4xx errors (hit nonexistent endpoints)
    Write-Host "  Generating 404 errors (5 requests)..."
    $notFoundCount = 0
    1..5 | ForEach-Object {
        try { Invoke-WebRequest -Uri "$BaseUrl/nonexistent-$_" -TimeoutSec 10 -ErrorAction SilentlyContinue } catch { $notFoundCount++ }
    }
    Write-Host "    ✓ $notFoundCount/5 not-found errors generated" -ForegroundColor Green

    if ($round -lt $Rounds) { Start-Sleep -Seconds 5 }
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host " Traffic Generation Complete" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "`nTotal per round: 10 crashes + 3 slow + 5 DB errors + 3 leaks + 5 not-found = 26 requests"
Write-Host "Alerts should fire within 5-10 minutes."
Write-Host "Check alerts: Azure Portal → Monitor → Alerts`n"
