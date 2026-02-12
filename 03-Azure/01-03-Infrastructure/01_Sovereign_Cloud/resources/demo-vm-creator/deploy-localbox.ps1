#Requires -Version 7.0
<#
.SYNOPSIS
    Deploy Azure Arc Jumpstart LocalBox environment for Azure Local.

.DESCRIPTION
    This script deploys the LocalBox environment from Azure Arc Jumpstart.
    LocalBox provides a virtualized Azure Local environment for testing
    Azure Local features without physical hardware.

    The deployment uses the official Arc Jumpstart Bicep templates from:
    https://github.com/microsoft/azure_arc

    LocalBox includes:
    - Virtualized Azure Local cluster (single-node)
    - Arc Resource Bridge integration
    - Custom Location for VM deployment
    - VM Gallery Images
    - AKS on Azure Local support (optional)

.PARAMETER ResourceGroupName
    The name of the resource group to deploy LocalBox to (will be created if it doesn't exist)

.PARAMETER Location
    Azure region for deployment (default: swedencentral)

.PARAMETER WindowsAdminUsername
    Admin username for Windows VMs (default: arcdemo)

.PARAMETER DeployBastion
    Deploy Azure Bastion for secure VM access (default: true)

.PARAMETER DeployAKSHCI
    Deploy AKS on Azure Local (default: false, adds significant deployment time)


.EXAMPLE
    .\deploy-localbox.ps1 -ResourceGroupName "rg-localbox-shared" -Location "swedencentral"


.NOTES
    Author: MicroHack Team
    Date: January 2026

    Prerequisites:
    - Azure CLI installed
    - Sufficient vCPU quota (32 vCPUs, Standard_E32s_v6 or larger recommended)
    - Required resource providers registered

    Deployment time: ~4-6 hours

    IMPORTANT: LocalBox requires significant compute resources. Ensure you have
    adequate vCPU quota before deployment.

.LINK
    https://jumpstart.azure.com/azure_jumpstart_localbox
.LINK
    https://github.com/microsoft/azure_arc/tree/main/azure_jumpstart_localbox
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
    [string]$GithubAccount = "microsoft",

    [Parameter(Mandatory = $false)]
    [string]$GithubBranch = "main",

    [Parameter(Mandatory = $false)]
    [ValidateSet('australiaeast', 'southcentralus', 'eastus', 'westeurope', 'southeastasia', 'canadacentral', 'japaneast', 'centralindia')]
    [string]$AzureLocalInstanceLocation = "westeurope"
)

Write-Host "`n=== Azure Arc Jumpstart LocalBox Deployment ===" -ForegroundColor Cyan
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

# Warning about resource requirements
Write-Host "`n" + ("=" * 80) -ForegroundColor Yellow
Write-Host "WARNING: LocalBox requires significant compute resources!" -ForegroundColor Yellow
Write-Host ("=" * 80) -ForegroundColor Yellow
Write-Host "Minimum requirements:" -ForegroundColor Yellow
Write-Host "  - vCPU quota: 32 vCPUs (Standard_E32s_v6 or larger)" -ForegroundColor Gray
Write-Host "  - Deployment time: 4-6 hours" -ForegroundColor Gray
Write-Host ""

$confirm = Read-Host "Do you want to proceed? (y/N)"
if ($confirm -ne 'y' -and $confirm -ne 'Y') {
    Write-Host "Deployment cancelled." -ForegroundColor Yellow
    exit 0
}

# Prompt for password
$WindowsAdminPassword = Read-Host -Prompt "Enter admin password for the host VM" -MaskInput

# Retrieve the object id of your directory's Azure Local resource provider.
$spnProviderId = az ad sp list --display-name "Microsoft.AzureStackHCI Resource Provider" --output json | ConvertFrom-Json

if (-not $spnProviderId -or -not $spnProviderId.id) {
    Write-Host "`n" + ("=" * 80) -ForegroundColor Red
    Write-Host "ERROR: Could not retrieve Azure Local Resource Provider service principal." -ForegroundColor Red
    Write-Host ("=" * 80) -ForegroundColor Red
    Write-Host ""
    Write-Host "This typically happens due to:" -ForegroundColor Yellow
    Write-Host "  - Stale authentication token (Continuous Access Evaluation)" -ForegroundColor Gray
    Write-Host "  - Insufficient permissions to query Entra ID" -ForegroundColor Gray
    Write-Host ""
    Write-Host "To resolve, run the following commands:" -ForegroundColor Cyan
    Write-Host "  1. az logout" -ForegroundColor White
    Write-Host "  2. Elevate to a privileged account in PIM (e.g., Global Reader or Directory Reader)" -ForegroundColor White
    Write-Host "  3. az login" -ForegroundColor White
    Write-Host "  4. Re-run this script" -ForegroundColor White
    Write-Host ""
    exit 1
}

$spnTenantId = az account show --output json | ConvertFrom-Json

# Create resource group if it doesn't exist
Write-Host "`nCreating resource group '$ResourceGroupName' in '$Location'..." -ForegroundColor Cyan
az group create --name $ResourceGroupName --location $Location | Out-Null

# Arc Jumpstart LocalBox Bicep template URL
$templateUri = "https://raw.githubusercontent.com/microsoft/azure_arc/main/azure_jumpstart_localbox/bicep/main.bicep"

Write-Host "`n=== Starting LocalBox Deployment ===" -ForegroundColor Cyan
Write-Host "This deployment will take approximately 4-6 hours to complete." -ForegroundColor Yellow
Write-Host "You can monitor progress in the Azure Portal under:" -ForegroundColor Gray
Write-Host "  Resource Groups > $ResourceGroupName > Deployments" -ForegroundColor Gray
Write-Host ""

# Download Bicep template locally (--template-uri does not support remote .bicep files)
Write-Host "Downloading Bicep templates..." -ForegroundColor Cyan
$tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "localbox-bicep"

# Create directory structure
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $tempDir "mgmt") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $tempDir "network") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $tempDir "host") -Force | Out-Null

$templateFile = Join-Path $tempDir "main.bicep"
$baseUri = "https://raw.githubusercontent.com/microsoft/azure_arc/main/azure_jumpstart_localbox/bicep"

# List of all required Bicep files
$bicepFiles = @(
    "main.bicep",
    "mgmt/mgmtArtifacts.bicep",
    "mgmt/storageAccount.bicep",
    "mgmt/customerUsageAttribution.bicep",
    "network/network.bicep",
    "host/host.bicep"
)

try {
    foreach ($file in $bicepFiles) {
        $sourceUrl = "$baseUri/$file"
        $destPath = Join-Path $tempDir $file
        Write-Host "  Downloading: $file" -ForegroundColor Gray
        Invoke-WebRequest -Uri $sourceUrl -OutFile $destPath -UseBasicParsing
    }
    Write-Host "Templates downloaded to: $tempDir" -ForegroundColor Gray
} catch {
    Write-Error "Failed to download Bicep template: $($_.Exception.Message)"
    exit 1
}

# Build deployment parameters
$paramsFile = Join-Path (Split-Path (New-TemporaryFile).FullName) "localbox-params.json"
@{
    "`$schema" = "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#"
    contentVersion = "1.0.0.0"
    parameters = @{
        windowsAdminUsername = @{ value = $WindowsAdminUsername }
        windowsAdminPassword = @{ value = $WindowsAdminPassword }
        spnProviderId = @{ value = $spnProviderId.id }
        tenantId = @{ value = $spnTenantId.tenantId }
        location = @{ value = $Location }
        githubAccount = @{ value = $GithubAccount }
        githubBranch = @{ value = $GithubBranch }
        azureLocalInstanceLocation = @{ value = $AzureLocalInstanceLocation }
    }
} | ConvertTo-Json -Depth 10 | Set-Content $paramsFile

Write-Host "Starting deployment..." -ForegroundColor Cyan
Write-Host "Template: $templateFile" -ForegroundColor Gray
Write-Host "Parameters: $paramsFile" -ForegroundColor Gray
Write-Host ""

# Deploy using Azure CLI

$deploymentName = "localbox-deployment-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

try {
    az deployment group create `
        --name $deploymentName `
        --resource-group $ResourceGroupName `
        --template-file $templateFile `
        --parameters $paramsFile `
        --no-wait

    Write-Host "`n=== Deployment Initiated ===" -ForegroundColor Green
    Write-Host "The LocalBox deployment has been started in the background." -ForegroundColor Gray
    Write-Host ""
    Write-Host "To monitor deployment progress:" -ForegroundColor Cyan
    Write-Host "  1. Azure Portal: Resource Groups > $ResourceGroupName > Deployments" -ForegroundColor Gray
    Write-Host "  2. Azure CLI: az deployment group show -g $ResourceGroupName -n $deploymentName" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Once deployment completes:" -ForegroundColor Cyan
    Write-Host "  1. Connect to LocalBox-Client VM via Azure Bastion or RDP" -ForegroundColor Gray
    Write-Host "  2. Azure Local instance will appear in the Azure Portal" -ForegroundColor Gray
    Write-Host "  3. Follow https://jumpstart.azure.com/azure_jumpstart_localbox/RB to create a Logical Network for VMs and download a Marketplace Image" -ForegroundColor Gray
    Write-Host "  4. You can deploy VMs on Azure Local via the Portal" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Azure Local Features Available:" -ForegroundColor Yellow
    Write-Host "  - Arc Resource Bridge for hybrid management" -ForegroundColor Gray
    Write-Host "  - Custom Location for VM deployment" -ForegroundColor Gray
    Write-Host "  - VM Gallery Images from Azure Marketplace" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Documentation: https://jumpstart.azure.com/azure_jumpstart_localbox" -ForegroundColor Yellow
} catch {
    Write-Error "Deployment failed: $($_.Exception.Message)"
    exit 1
}