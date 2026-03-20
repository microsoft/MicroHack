<#
.SYNOPSIS
    Deploys the Azure Copilot Workshop lab resources (HackboxConsole entry-point).
.DESCRIPTION
    Provides the standard HackboxConsole deployment interface for the Azure Copilot
    MicroHack.  Accepts the platform-mandated parameters and delegates to the Bicep-based
    deployment in ../iac/ and the app deployment from ../app/.
.PARAMETER DeploymentType
    Defines the deployment scope; allowed values are subscription or resourcegroup.
.PARAMETER SubscriptionId
    Specifies the Azure subscription that contains the lab resources.
.PARAMETER ResourceGroupName
    In case of resourcegroup deployment, specifies the target resource group name.
.PARAMETER PreferredLocation
    Specifies the preferred Azure region for resource deployment. "" indicates no preference.
.PARAMETER AllowedEntraUserIds
    Optional list of Entra user object IDs permitted to access the lab resources.
#>
param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('subscription','resourcegroup', 'resourcegroup-with-subscriptionowner')]
    [string]$DeploymentType,

    [Parameter(Mandatory=$true)]
    [string]$SubscriptionId,

    [string]$ResourceGroupName = "",

    [string]$PreferredLocation = "",

    [string[]]$AllowedEntraUserIds = @()
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition

# ──────────────────────────────────────────────
# Validate parameters
# ──────────────────────────────────────────────
if ($DeploymentType -eq 'resourcegroup' -and [string]::IsNullOrEmpty($ResourceGroupName)) {
    throw "ResourceGroupName must be provided when DeploymentType is 'resourcegroup'."
}

# Resolve preferred location — default to francecentral if none specified
$Location = if ([string]::IsNullOrEmpty($PreferredLocation)) { "francecentral" } else { $PreferredLocation }

# ──────────────────────────────────────────────
# Helper
# ──────────────────────────────────────────────
function Invoke-Az {
    & az $args
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Azure CLI command failed with exit code $LASTEXITCODE"
        exit $LASTEXITCODE
    }
}

# ──────────────────────────────────────────────
# Set subscription context
# ──────────────────────────────────────────────
Write-Host "Setting subscription context to $SubscriptionId ..."
Invoke-Az account set --subscription $SubscriptionId

# Generate a deployment suffix
$suffix = -join ((97..122) | Get-Random -Count 4 | ForEach-Object { [char]$_ })

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host " Azure Copilot Workshop - Lab Deploy"    -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan
Write-Host "Subscription: $SubscriptionId"            -ForegroundColor Green
Write-Host "Location:     $Location"                  -ForegroundColor Green
Write-Host "Suffix:       $suffix"                    -ForegroundColor Green

# ──────────────────────────────────────────────
# Ensure SSH key pair exists (VM challenges)
# ──────────────────────────────────────────────
$sshPubKeyPath = Join-Path $HOME ".ssh" "id_rsa.pub"
if (-not (Test-Path $sshPubKeyPath)) {
    Write-Host "`nSSH key not found. Generating key pair..." -ForegroundColor Yellow
    $sshKeyDir = Join-Path $HOME ".ssh"
    if (-not (Test-Path $sshKeyDir)) { New-Item -ItemType Directory -Path $sshKeyDir -Force | Out-Null }
    $sshKeyPath = Join-Path $HOME ".ssh" "id_rsa"
    ssh-keygen -t rsa -b 4096 -f $sshKeyPath -q -N ""
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to generate SSH key pair."
        exit 1
    }
}
$sshPublicKey = (Get-Content $sshPubKeyPath -Raw).Trim()

# ──────────────────────────────────────────────
# Deploy infrastructure via Bicep
# ──────────────────────────────────────────────
Write-Host "`n[1/3] Deploying infrastructure (Bicep)..." -ForegroundColor Yellow
$mainBicep  = Join-Path $scriptPath "..\iac\main.bicep"
$timestamp  = Get-Date -Format "yyyyMMddHHmmss"
$paramsFile = Join-Path $env:TEMP "copilot-workshop-params-$timestamp.json"

@{
    '`$schema'     = 'https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#'
    contentVersion = '1.0.0.0'
    parameters     = @{
        location     = @{ value = $Location }
        suffix       = @{ value = $suffix }
        sshPublicKey = @{ value = $sshPublicKey }
    }
} | ConvertTo-Json -Depth 5 | Set-Content $paramsFile -Encoding utf8

try {
    Invoke-Az deployment sub create `
        --location $Location `
        --template-file $mainBicep `
        --parameters "@$paramsFile" `
        --name "copilot-workshop-$timestamp" `
        -o none
}
finally {
    Remove-Item $paramsFile -Force -ErrorAction SilentlyContinue
}
Write-Host "  ✓ Infrastructure deployed" -ForegroundColor Green

# ──────────────────────────────────────────────
# Deploy Flask app (Ch02)
# ──────────────────────────────────────────────
Write-Host "`n[2/3] Deploying buggy Flask app (Ch02)..." -ForegroundColor Yellow
$webAppName = "app-copilot-buggy-$suffix"
$appDir     = Join-Path $scriptPath "..\app"
$zipPath    = Join-Path $env:TEMP "$webAppName.zip"
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
Compress-Archive -Path (Join-Path $appDir "*") -DestinationPath $zipPath -Force
Invoke-Az webapp deploy --resource-group "rg-copilot-$suffix-ch02" --name $webAppName --src-path $zipPath --type zip --track-status false -o none
Remove-Item $zipPath -Force
Write-Host "  ✓ Flask app deployed to $webAppName" -ForegroundColor Green

# ──────────────────────────────────────────────
# Generate error traffic for Ch02 alerts
# ──────────────────────────────────────────────
Write-Host "`n[3/3] Generating error traffic for alert triggers..." -ForegroundColor Yellow
$baseUrl = "https://$webAppName.azurewebsites.net"
1..10 | ForEach-Object { try { Invoke-WebRequest -Uri "$baseUrl/crash" -TimeoutSec 10 } catch {} }
1..3  | ForEach-Object { try { Invoke-WebRequest -Uri "$baseUrl/slow"  -TimeoutSec 30 } catch {} }
1..5  | ForEach-Object { try { Invoke-WebRequest -Uri "$baseUrl/api/orders" -TimeoutSec 15 } catch {} }
Write-Host "  ✓ Error traffic generated" -ForegroundColor Green

# ──────────────────────────────────────────────
# RBAC — assign Owner on resource groups if scoped
# ──────────────────────────────────────────────
$rgNames = @("rg-copilot-$suffix-ch00","rg-copilot-$suffix-ch02","rg-copilot-$suffix-ch03","rg-copilot-$suffix-ch04","rg-copilot-$suffix-ch05")

if ($DeploymentType -in @('resourcegroup','resourcegroup-with-subscriptionowner')) {
    foreach ($rg in $rgNames) {
        if ($AllowedEntraUserIds.Count -gt 0) {
            foreach ($userId in $AllowedEntraUserIds) {
                $scope = "/subscriptions/$SubscriptionId/resourceGroups/$rg"
                if (-not (Get-AzRoleAssignment -ObjectId $userId -RoleDefinitionName "Owner" -Scope $scope -ErrorAction SilentlyContinue)) {
                    Write-Host "Assigning Owner role to $userId on $rg"
                    New-AzRoleAssignment -ObjectId $userId -RoleDefinitionName "Owner" -Scope $scope -ErrorAction Stop | Out-Null
                }
            }
        }
    }
}

# ──────────────────────────────────────────────
# Emit HackboxCredentials for the platform UI
# ──────────────────────────────────────────────
@{"HackboxCredential" = @{ name = "Subscription ID";   value = $SubscriptionId; note = "Azure subscription used for the workshop" }}
@{"HackboxCredential" = @{ name = "Deployment Suffix";  value = $suffix;         note = "Random suffix appended to resource names" }}
@{"HackboxCredential" = @{ name = "App URL";            value = $baseUrl;        note = "Buggy Flask application endpoint" }}
@{"HackboxCredential" = @{ name = "Location";           value = $Location;       note = "Azure region where resources are deployed" }}

# ──────────────────────────────────────────────
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host " Deployment Complete!" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan
Write-Host "Resource Groups: $($rgNames -join ', ')"
Write-Host "App URL: $baseUrl`n"
