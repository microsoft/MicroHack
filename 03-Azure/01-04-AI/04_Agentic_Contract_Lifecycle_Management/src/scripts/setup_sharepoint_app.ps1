#!/usr/bin/env pwsh
# ==========================================================================
# Challenge 1 (coach/setup) — create the Microsoft Entra app registration the
# SharePoint corpus needs, grant Graph permissions, admin-consent, and mint a
# client secret. Prints the SHAREPOINT_* values to paste into your repo-root .env.
#
# Grants (application / app-only, admin-consented):
#   - Sites.ReadWrite.All  -> lets src/scripts/upload_corpus_to_sharepoint.py upload
#                             the PDFs (and covers the indexer's site read).
#   - Files.Read.All       -> lets the AI Search SharePoint indexer read content.
#
# Requirements:
#   - Azure CLI (az) installed and logged in (az login).
#   - Rights to create app registrations AND grant admin consent (Global Admin /
#     Privileged Role Admin / Application Administrator). Without consent rights
#     the script still creates everything and prints the command an admin runs.
#
# Usage:  pwsh src/scripts/setup_sharepoint_app.ps1 [-DisplayName "Display Name"]
# ==========================================================================
param([string]$DisplayName = "CLM Microhack Corpus")

$ErrorActionPreference = "Stop"
$GraphAppId = "00000003-0000-0000-c000-000000000000"   # Microsoft Graph

if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    throw "Azure CLI (az) not found. Install it, then run 'az login'."
}
az account show *> $null
if ($LASTEXITCODE -ne 0) { throw "Not logged in. Run 'az login' (or 'az login --use-device-code') first." }

Write-Host "Resolving Microsoft Graph application-role ids..."
$SitesRw   = az ad sp show --id $GraphAppId --query "appRoles[?value=='Sites.ReadWrite.All'].id | [0]" -o tsv
$FilesRead = az ad sp show --id $GraphAppId --query "appRoles[?value=='Files.Read.All'].id | [0]" -o tsv
if ([string]::IsNullOrWhiteSpace($SitesRw) -or [string]::IsNullOrWhiteSpace($FilesRead)) {
    throw "Could not resolve Microsoft Graph app-role ids."
}

# Reuse an existing app of the same name so re-runs don't create duplicates.
$AppId = az ad app list --display-name $DisplayName --query "[0].appId" -o tsv
if ([string]::IsNullOrWhiteSpace($AppId) -or $AppId -eq "None") {
    Write-Host "Creating app registration '$DisplayName'..."
    $AppId = az ad app create --display-name $DisplayName --sign-in-audience AzureADMyOrg --query appId -o tsv
} else {
    Write-Host "Reusing existing app registration '$DisplayName' ($AppId)."
}

# Ensure a service principal exists for the app.
az ad sp show --id $AppId *> $null
if ($LASTEXITCODE -ne 0) { az ad sp create --id $AppId | Out-Null }

Write-Host "Adding Graph application permissions (Sites.ReadWrite.All, Files.Read.All)..."
az ad app permission add --id $AppId --api $GraphAppId --api-permissions "$SitesRw=Role" "$FilesRead=Role" | Out-Null

Write-Host "Granting admin consent (requires admin rights; retrying briefly for propagation)..."
Start-Sleep -Seconds 15
az ad app permission admin-consent --id $AppId
if ($LASTEXITCODE -ne 0) {
    Write-Warning "Admin consent did not complete (you may lack the required rights)."
    Write-Host   "         Ask a tenant admin to run:"
    Write-Host   "           az ad app permission admin-consent --id $AppId"
    Write-Host   "         ...or in the portal: Entra admin center -> App registrations -> '$DisplayName'"
    Write-Host   "         -> API permissions -> 'Grant admin consent'."
}

Write-Host "Creating a client secret (valid 1 year)..."
$Secret   = az ad app credential reset --id $AppId --display-name "clm-microhack" --years 1 --query password -o tsv
$TenantId = az account show --query tenantId -o tsv

Write-Host ""
Write-Host "======================================================================"
Write-Host " App registration ready. Add these to your repo-root .env:"
Write-Host "======================================================================"
Write-Host "SHAREPOINT_TENANT_ID=$TenantId"
Write-Host "SHAREPOINT_APP_ID=$AppId"
Write-Host "SHAREPOINT_APP_SECRET=$Secret"
Write-Host "----------------------------------------------------------------------"
Write-Host " Then set these from your SharePoint site (create the site+library first):"
Write-Host "   SHAREPOINT_SITE_URL=https://<tenant>.sharepoint.com/sites/<YourSite>"
Write-Host "   SHAREPOINT_DOC_LIBRARY=Documents"
Write-Host "======================================================================"
Write-Host " NOTE: the client secret above is shown ONCE - copy it now."
Write-Host " Next: python src/scripts/upload_corpus_to_sharepoint.py  (then seed_corpus.py)"
