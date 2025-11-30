#!/usr/bin/env pwsh
# Setup script for dev container - configures PowerShell profile and OCI

$profilePath = $PROFILE
$profileDir = Split-Path $profilePath -Parent

# Create profile directory if it doesn't exist
if (!(Test-Path $profileDir)) {
    New-Item -Path $profileDir -ItemType Directory -Force | Out-Null
}

# Create or update PowerShell profile
$profileContent = @'
# Terraform alias
Set-Alias tf terraform

# Short prompt - shows only current folder name
function prompt {
    $folder = Split-Path -Leaf (Get-Location)
    "$folder > "
}
'@

Set-Content -Path $profilePath -Value $profileContent -Force

Write-Host "PowerShell profile configured:" -ForegroundColor Green
Write-Host "  - 'tf' alias for terraform" -ForegroundColor Cyan
Write-Host "  - Short prompt (folder name only)" -ForegroundColor Cyan

# ============================================================================
# OCI CLI Configuration - Fix Windows path to Linux path
# ============================================================================
$ociConfigPath = "/home/vscode/.oci/config"
$ociConfigLinux = "/home/vscode/.oci/config_linux"

if (Test-Path $ociConfigPath) {
    Write-Host "`nConfiguring OCI CLI..." -ForegroundColor Cyan
    
    # Read the Windows config and fix the key_file path
    $configContent = Get-Content $ociConfigPath -Raw
    
    # Replace Windows-style paths with Linux paths
    # Matches patterns like: key_file=C:\Users\...\filename.pem
    $fixedContent = $configContent -replace 'key_file=.*\\([^\\]+\.pem)', 'key_file=/home/vscode/.oci/$1'
    
    # Write the fixed config
    Set-Content -Path $ociConfigLinux -Value $fixedContent -NoNewline
    
    # Set OCI_CLI_CONFIG_FILE environment variable in profile
    Add-Content -Path $profilePath -Value "`n# OCI CLI config with Linux paths`n`$env:OCI_CLI_CONFIG_FILE = '$ociConfigLinux'"
    
    Write-Host "  - OCI config fixed for Linux paths" -ForegroundColor Green
    Write-Host "  - Using: $ociConfigLinux" -ForegroundColor Gray
} else {
    Write-Host "`nOCI config not found at $ociConfigPath" -ForegroundColor Yellow
    Write-Host "  Mount your ~/.oci folder or run 'oci setup config'" -ForegroundColor Gray
}
