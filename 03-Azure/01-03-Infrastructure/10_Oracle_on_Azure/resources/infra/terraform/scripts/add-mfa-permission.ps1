<#
.SYNOPSIS
    Add UserAuthenticationMethod.ReadWrite.All permission to the service principal.

.DESCRIPTION
    This script adds the Microsoft Graph permission required to reset MFA for users.
    Must be run by a Global Administrator to grant admin consent.

.PARAMETER ClientId
    The Application (Client) ID of the service principal

.EXAMPLE
    .\add-mfa-permission.ps1 -ClientId "8a9f736e-4eb2-4484-ae90-2493f57102b3"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ClientId
)

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Adding MFA Management Permission" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# Microsoft Graph App ID (constant)
$graphAppId = "00000003-0000-0000-c000-000000000000"

# Permission IDs for Microsoft Graph
# UserAuthenticationMethod.ReadWrite.All (Application)
$permissionId = "50483e42-d915-4231-9639-7fdb7fd190e5"

Write-Host "Service Principal: $ClientId" -ForegroundColor Yellow
Write-Host "Permission: UserAuthenticationMethod.ReadWrite.All (Application)" -ForegroundColor Yellow
Write-Host ""

# Add the permission
Write-Host "Step 1: Adding API permission..." -ForegroundColor Cyan
try {
    az ad app permission add `
        --id $ClientId `
        --api $graphAppId `
        --api-permissions "$permissionId=Role"
    
    Write-Host "  Permission added successfully" -ForegroundColor Green
} catch {
    Write-Host "  Permission may already exist or error: $_" -ForegroundColor Yellow
}

# Grant admin consent
Write-Host "`nStep 2: Granting admin consent..." -ForegroundColor Cyan
Write-Host "  (This requires Global Administrator privileges)" -ForegroundColor Yellow
try {
    az ad app permission admin-consent --id $ClientId
    Write-Host "  Admin consent granted successfully" -ForegroundColor Green
} catch {
    Write-Host "  ERROR: Could not grant admin consent." -ForegroundColor Red
    Write-Host "  Please grant consent manually in Azure Portal:" -ForegroundColor Yellow
    Write-Host "  1. Go to: https://portal.azure.com" -ForegroundColor White
    Write-Host "  2. Navigate to: Entra ID > App registrations > $ClientId" -ForegroundColor White
    Write-Host "  3. Click: API permissions" -ForegroundColor White
    Write-Host "  4. Click: Grant admin consent for <tenant>" -ForegroundColor White
    exit 1
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Permission Added Successfully!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "The service principal can now reset MFA for users." -ForegroundColor White
Write-Host "To trigger MFA reset via Terraform:" -ForegroundColor White
Write-Host "  1. Edit identity/terraform.tfvars" -ForegroundColor Gray
Write-Host "  2. Set: mfa_reset_trigger = `"<new-value>`"" -ForegroundColor Gray
Write-Host "  3. Run: terraform apply" -ForegroundColor Gray
