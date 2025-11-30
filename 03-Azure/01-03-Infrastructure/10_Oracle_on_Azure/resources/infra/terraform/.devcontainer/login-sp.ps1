#!/usr/bin/env pwsh
# Login script for Azure Service Principal

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Logging in Azure CLI as Service Principal" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

# Source .env file if environment variables not already set
if (-not $env:ARM_CLIENT_ID) {
    $envFile = Join-Path $PSScriptRoot ".env"
    if (Test-Path $envFile) {
        Write-Host "Loading credentials from .devcontainer/.env..."
        Get-Content $envFile | ForEach-Object {
            if ($_ -match '^export\s+(\w+)="?([^"]*)"?$') {
                [Environment]::SetEnvironmentVariable($Matches[1], $Matches[2], "Process")
            }
            elseif ($_ -match '^(\w+)="?([^"]*)"?$') {
                [Environment]::SetEnvironmentVariable($Matches[1], $Matches[2], "Process")
            }
        }
    }
}

if (-not $env:ARM_CLIENT_ID -or -not $env:ARM_CLIENT_SECRET -or -not $env:ARM_TENANT_ID) {
    Write-Host "ERROR: Missing required environment variables!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Create .devcontainer/.env from .devcontainer/.env.example:"
    Write-Host "  cp .devcontainer/.env.example .devcontainer/.env"
    Write-Host "  # Edit .env with your SP credentials"
    Write-Host "  # Then rebuild the container"
    exit 1
}

# Login as service principal
az login --service-principal `
    --username $env:ARM_CLIENT_ID `
    --password $env:ARM_CLIENT_SECRET `
    --tenant $env:ARM_TENANT_ID `
    --output none

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Azure login failed!" -ForegroundColor Red
    exit 1
}

# Set subscription if provided
if ($env:ARM_SUBSCRIPTION_ID) {
    az account set --subscription $env:ARM_SUBSCRIPTION_ID
}

Write-Host ""
Write-Host "Logged in as Service Principal:" -ForegroundColor Green
az account show --query "{name:name, user:user.name, type:user.type}" -o table

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Dev Container Ready!" -ForegroundColor Cyan
Write-Host "Use 'tf' as shortcut for 'terraform'" -ForegroundColor Yellow
Write-Host "============================================" -ForegroundColor Cyan
