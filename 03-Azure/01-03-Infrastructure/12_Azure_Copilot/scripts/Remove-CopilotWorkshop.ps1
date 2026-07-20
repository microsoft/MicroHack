#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Tears down all Azure resources created for the Azure Copilot Workshop.
.DESCRIPTION
    Deletes all resource groups created by Deploy-Lab.ps1.
    This is irreversible — all resources will be permanently deleted.
.PARAMETER Suffix
    The deployment suffix used during provisioning (e.g., 'abcd').
.PARAMETER Force
    Skip confirmation prompt.
.EXAMPLE
    .\Remove-CopilotWorkshop.ps1 -Suffix abcd
    .\Remove-CopilotWorkshop.ps1 -Suffix abcd -Force
#>
param(
    [Parameter(Mandatory=$true)]
    [string]$Suffix,
    [switch]$Force
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$groups= @("rg-copilot-$Suffix-ch00","rg-copilot-$Suffix-ch02","rg-copilot-$Suffix-ch03","rg-copilot-$Suffix-ch04","rg-copilot-$Suffix-ch05")

Write-Host "`n========================================" -ForegroundColor Red
Write-Host " Azure Copilot Workshop - Teardown All" -ForegroundColor Red
Write-Host "========================================`n" -ForegroundColor Red

$account = az account show -o json 2>&1 | ConvertFrom-Json
Write-Host "Subscription: $($account.name)" -ForegroundColor Yellow
Write-Host "The following resource groups will be DELETED:`n" -ForegroundColor Yellow

foreach ($g in $groups) {
    $exists = az group exists --name $g 2>&1
    $status = if ($exists -eq "true") { "exists" } else { "not found" }
    Write-Host "  - $g ($status)"
}

if (-not $Force) {
    Write-Host ""
    $confirm = Read-Host "Type 'yes' to confirm deletion"
    if ($confirm -ne "yes") {
        Write-Host "Aborted." -ForegroundColor Yellow
        exit 0
    }
}

Write-Host "`nDeleting resource groups (async)..." -ForegroundColor Yellow
foreach ($g in $groups) {
    $exists = az group exists --name $g 2>&1
    if ($exists -eq "true") {
        az group delete --name $g --yes --no-wait -o none 2>&1 | Out-Null
        Write-Host "  ✓ Deletion started: $g" -ForegroundColor Green
    } else {
        Write-Host "  - Skipped (not found): $g" -ForegroundColor DarkGray
    }
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host " Teardown initiated!" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "`nResource groups are being deleted asynchronously."
Write-Host "This may take 5-10 minutes to complete."
Write-Host "Check status: az group list -o table`n"
