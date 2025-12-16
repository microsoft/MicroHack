#!/usr/bin/env pwsh
# ===============================================================================
# Enable Terraform Logging Script
# ===============================================================================
# This script enables detailed Terraform logging and redirects output to a logs
# folder for troubleshooting and debugging purposes.
# ===============================================================================

# Create logs directory if it doesn't exist
$logsDir = Join-Path -Path $PSScriptRoot -ChildPath "logs"
if (-not (Test-Path -Path $logsDir)) {
    New-Item -ItemType Directory -Path $logsDir -Force | Out-Null
    Write-Host "Created logs directory: $logsDir" -ForegroundColor Green
} else {
    Write-Host "Logs directory already exists: $logsDir" -ForegroundColor Yellow
}

# Set Terraform logging environment variables
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$logFile = Join-Path -Path $logsDir -ChildPath "terraform_$timestamp.log"

$env:TF_LOG = "TRACE"
$env:TF_LOG_PATH = $logFile

Write-Host "`nTerraform logging enabled:" -ForegroundColor Cyan
Write-Host "  TF_LOG      = $env:TF_LOG" -ForegroundColor White
Write-Host "  TF_LOG_PATH = $env:TF_LOG_PATH" -ForegroundColor White
Write-Host "`nRun your Terraform commands now. Logs will be written to:" -ForegroundColor Green
Write-Host "  $logFile" -ForegroundColor White
Write-Host "`nTo disable logging, close this PowerShell session or run:" -ForegroundColor Yellow
Write-Host "  Remove-Item Env:\TF_LOG; Remove-Item Env:\TF_LOG_PATH" -ForegroundColor Gray
