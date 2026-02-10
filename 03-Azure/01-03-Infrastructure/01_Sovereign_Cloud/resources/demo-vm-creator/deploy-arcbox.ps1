#Requires -Version 7.0

<#
.SYNOPSIS
    Deploy Azure Arc Jumpstart ArcBox for IT Pros environment.

.DESCRIPTION
    This script deploys the ArcBox for IT Pros environment from Azure Arc Jumpstart.
    ArcBox provides a pre-packaged Azure Arc sandbox with nested VMs that are
    automatically onboarded to Azure Arc.

    The deployment uses the official Arc Jumpstart Bicep templates from:
    https://github.com/microsoft/azure_arc

    ArcBox includes:
    - ArcBox-Client VM (Windows Server jump host)
    - Nested VMs: Windows Server and Ubuntu Linux (Arc-enabled)
    - Log Analytics workspace
    - Azure Policy assignments for Arc-enabled servers

.PARAMETER ResourceGroupName
    The name of the resource group to deploy ArcBox to (will be created if it doesn't exist)

.PARAMETER Location
    Azure region for deployment (default: swedencentral)

.PARAMETER WindowsAdminUsername
    Admin username for Windows VMs (default: arcdemo)

.PARAMETER DeployBastion
    Deploy Azure Bastion for secure VM access (default: true)

.PARAMETER Flavor
    ArcBox flavor to deploy: ITPro, DevOps, DataOps (default: ITPro)

.EXAMPLE
    .\deploy-arcbox.ps1 -ResourceGroupName "rg-arcbox-shared" -Location "swedencentral"

.EXAMPLE
    .\deploy-arcbox.ps1 -ResourceGroupName "rg-arcbox-shared" -Location "westeurope" -DeployBastion $false

.NOTES
    Author: MicroHack Team
    Date: January 2026

    Prerequisites:
    - Azure CLI installed
    - Sufficient vCPU quota (8 vCPUs)
    - Required resource providers registered

    Deployment time: ~30 minutes

.LINK
    https://jumpstart.azure.com/azure_jumpstart_arcbox
.LINK
    https://github.com/microsoft/azure_arc/tree/main/azure_jumpstart_arcbox
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $false)]
    [string]$Location = "swedencentral",

    [Parameter(Mandatory = $false)]
    [string]$WindowsAdminUsername = "arcdemo",

    [Parameter(Mandatory = $false)]
    [bool]$DeployBastion = $true,

    [Parameter(Mandatory = $false)]
    [ValidateSet("ITPro", "DevOps", "DataOps")]
    [string]$Flavor = "ITPro"
)

Write-Host "`n=== Azure Arc Jumpstart ArcBox Deployment ===" -ForegroundColor Cyan
Write-Host "Flavor: $Flavor" -ForegroundColor Gray
Write-Host "Location: $Location" -ForegroundColor Gray
Write-Host "Resource Group: $ResourceGroupName" -ForegroundColor Gray
Write-Host ""

# Check if Azure CLI is installed
if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    Write-Error "Azure CLI is not installed. Please install it from: https://docs.microsoft.com/cli/azure/install-azure-cli"
    exit 1
}

# Check if logged in
$account = az account show 2>$null | ConvertFrom-Json
if (-not $account) {
    Write-Host "Not logged in to Azure CLI. Please login..." -ForegroundColor Yellow
    az login
    $account = az account show | ConvertFrom-Json
}

Write-Host "Using subscription: $($account.name)" -ForegroundColor Green

# Prompt for password
$WindowsAdminPassword = Read-Host -Prompt "Enter admin password for VMs" -MaskInput

# Create resource group if it doesn't exist
Write-Host "`nCreating resource group '$ResourceGroupName' in '$Location'..." -ForegroundColor Cyan
az group create --name $ResourceGroupName --location $Location | Out-Null

# Arc Jumpstart ArcBox template URL
$templateUri = "https://raw.githubusercontent.com/microsoft/azure_arc/main/azure_jumpstart_arcbox/ARM/azuredeploy.json"

Write-Host "`n=== Starting ArcBox Deployment ===" -ForegroundColor Cyan
Write-Host "This deployment will take approximately 30 minutes to complete." -ForegroundColor Yellow
Write-Host "You can monitor progress in the Azure Portal under:" -ForegroundColor Gray
Write-Host "  Resource Groups > $ResourceGroupName > Deployments" -ForegroundColor Gray
Write-Host ""

# Build deployment parameters

$paramsFile = Join-Path (Split-Path (New-TemporaryFile).FullName) "arcbox-params.json"
@{
    "`$schema" = "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#"
    contentVersion = "1.0.0.0"
    parameters = @{
        sshRSAPublicKey = @{ value = $sshRSAPublicKey }
        windowsAdminUsername = @{ value = $WindowsAdminUsername }
        windowsAdminPassword = @{ value = $PlainPassword }
        deployBastion = @{ value = $DeployBastion }
        flavor = @{ value = $Flavor }
    }
} | ConvertTo-Json -Depth 10 | Set-Content $paramsFile

Write-Host "Starting deployment..." -ForegroundColor Cyan
Write-Host "Template: $templateUri" -ForegroundColor Gray
Write-Host ""

# Deploy using Azure CLI
try {

$deploymentName = "arcbox-deployment-$(Get-Random -Maximum 9999)"

    az deployment group create `
        --name $deploymentName `
        --resource-group $ResourceGroupName `
        --template-uri $templateUri `
        --parameters $paramsFile `
        --no-wait

    Write-Host "`n=== Deployment Initiated ===" -ForegroundColor Green
    Write-Host "The ArcBox deployment has been started in the background." -ForegroundColor Gray
    Write-Host ""
    Write-Host "To monitor deployment progress:" -ForegroundColor Cyan
    Write-Host "  1. Azure Portal: Resource Groups > $ResourceGroupName > Deployments" -ForegroundColor Gray
    Write-Host "  2. Azure CLI: az deployment group show -g $ResourceGroupName -n $deploymentName" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Once deployment completes:" -ForegroundColor Cyan
    Write-Host "  1. Connect to ArcBox-Client VM via Azure Bastion" -ForegroundColor Gray
    Write-Host "  2. All nested VMs will be automatically onboarded to Azure Arc" -ForegroundColor Gray
    Write-Host "  3. Arc-enabled servers will appear in the Azure Portal" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Documentation: https://jumpstart.azure.com/azure_jumpstart_arcbox" -ForegroundColor Yellow
} catch {
    Write-Error "Deployment failed: $($_.Exception.Message)"
    exit 1
}
