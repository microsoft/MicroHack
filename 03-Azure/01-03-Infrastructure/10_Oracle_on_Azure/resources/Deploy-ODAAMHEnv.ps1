#Requires -Version 5.1
<#
.SYNOPSIS
    Deploys ODAA MH environment with Azure Kubernetes Service (AKS) and NGINX Ingress Controller

.DESCRIPTION
    This script automates the deployment of Azure resources for ODAA MH workshop environment.
    It creates a resource group, deploys AKS cluster using Bicep template, and installs NGINX ingress controller.
    The script allows multiple deployments with different names using configurable parameters.

.PARAMETER ResourceGroupName
    Name of the Azure resource group to create

.PARAMETER Prefix
    Prefix for naming Azure resources

.PARAMETER Postfix
    Postfix for naming Azure resources (useful for creating multiple environments)

.PARAMETER Location
    Azure region where resources will be deployed

.PARAMETER SubscriptionName
    Azure subscription name to use for deployment

.PARAMETER SkipPrerequisites
    Skip prerequisite checks (Azure CLI, kubectl, helm, jq)

.PARAMETER SkipLogin
    Skip Azure login process

.EXAMPLE
    .\Deploy-ODAAMHEnv.ps1 -ResourceGroupName "odaa-team1" -Prefix "ODAA" -Postfix "team1" -Location "germanywestcentral"

.EXAMPLE
    .\Deploy-ODAAMHEnv.ps1 -ResourceGroupName "odaa-team2" -Prefix "ODAA" -Postfix "team2" -Location "germanywestcentral" -SkipLogin

.NOTES
    Author: Generated for ODAA MH Workshop
    Prerequisites: Azure CLI, kubectl, helm, jq
    Note: Scripts originally designed for bash but adapted for PowerShell
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory = $true)]
    [string]$Prefix,
    
    [Parameter(Mandatory = $false)]
    [string]$Postfix = "",
    
    [Parameter(Mandatory = $false)]
    [string]$Location = "germanywestcentral",
    
    [Parameter(Mandatory = $false)]
    [string]$SubscriptionName = "sub-cptdx-01",
    
    [Parameter(Mandatory = $false)]
    [switch]$SkipPrerequisites,
    
    [Parameter(Mandatory = $false)]
    [switch]$SkipLogin
)

# Global variables
$ErrorActionPreference = "Stop"
$ProgressPreference = "Continue"

# Function to write colored output
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

# Function to check if a command exists
function Test-Command {
    param([string]$Command)
    
    try {
        Get-Command $Command -ErrorAction Stop | Out-Null
        return $true
    }
    catch {
        return $false
    }
}

# Function to check prerequisites
function Test-Prerequisites {
    Write-ColorOutput "Checking prerequisites..." "Yellow"
    
    $prerequisites = @(
        @{ Name = "Azure CLI"; Command = "az" },
        @{ Name = "kubectl"; Command = "kubectl" },
        @{ Name = "helm"; Command = "helm" },
        @{ Name = "jq"; Command = "jq" }
    )
    
    $missing = @()
    
    foreach ($prereq in $prerequisites) {
        if (Test-Command $prereq.Command) {
            Write-ColorOutput "✓ $($prereq.Name) is installed" "Green"
        }
        else {
            Write-ColorOutput "✗ $($prereq.Name) is NOT installed" "Red"
            $missing += $prereq.Name
        }
    }
    
    if ($missing.Count -gt 0) {
        Write-ColorOutput "Missing prerequisites: $($missing -join ', ')" "Red"
        Write-ColorOutput "Please install the missing tools before running this script." "Red"
        
        Write-ColorOutput "`nInstallation instructions:" "Yellow"
        Write-ColorOutput "- Azure CLI: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli" "Cyan"
        Write-ColorOutput "- kubectl: https://kubernetes.io/docs/tasks/tools/install-kubectl/" "Cyan"
        Write-ColorOutput "- helm: https://helm.sh/docs/intro/install/" "Cyan"
        Write-ColorOutput "- jq: https://stedolan.github.io/jq/download/" "Cyan"
        
        exit 1
    }
    
    Write-ColorOutput "All prerequisites are installed!" "Green"
}

# Function to login to Azure
function Connect-AzureAccount {
    Write-ColorOutput "Logging into Azure..." "Yellow"
    
    try {
        # Login with device code
        az login --use-device-code
        
        # Show current account
        Write-ColorOutput "Current account information:" "Cyan"
        az account show
        
        # Set subscription
        Write-ColorOutput "Setting subscription to: $SubscriptionName" "Yellow"
        az account set -s $SubscriptionName
        
        Write-ColorOutput "Successfully logged into Azure!" "Green"
    }
    catch {
        Write-ColorOutput "Failed to login to Azure: $_" "Red"
        exit 1
    }
}

# Function to create Azure Resource Group
function New-AzureResourceGroup {
    param(
        [string]$Name,
        [string]$Location
    )
    
    Write-ColorOutput "Creating Azure Resource Group: $Name in $Location..." "Yellow"
    
    try {
        az group create -n $Name -l $Location
        Write-ColorOutput "✓ Resource Group '$Name' created successfully!" "Green"
    }
    catch {
        Write-ColorOutput "Failed to create resource group: $_" "Red"
        exit 1
    }
}

# Function to deploy Azure resources using Bicep
function Deploy-AzureResources {
    param(
        [string]$ResourceGroupName,
        [string]$Prefix,
        [string]$Postfix,
        [string]$Location
    )
    
    Write-ColorOutput "Deploying Azure resources using Bicep template..." "Yellow"
    
    $bicepFile = "./infra/bicep/main.bicep"
    
    if (-not (Test-Path $bicepFile)) {
        Write-ColorOutput "Bicep file not found: $bicepFile" "Red"
        Write-ColorOutput "Please make sure you're running this script from the resources directory." "Red"
        exit 1
    }
    
    try {
        az deployment group create -n $Prefix -g $ResourceGroupName -f $bicepFile -p location=$Location aksName=$Prefix postfix=$Postfix
        Write-ColorOutput "✓ Azure resources deployed successfully!" "Green"
        
        # List created resources
        Write-ColorOutput "`nListing created resources:" "Cyan"
        az resource list -g $ResourceGroupName -o table --query "[].{Name:name, Type:type}"
        
    }
    catch {
        Write-ColorOutput "Failed to deploy Azure resources: $_" "Red"
        exit 1
    }
}

# Function to connect to AKS cluster
function Connect-AKSCluster {
    param(
        [string]$ResourceGroupName,
        [string]$AksName
    )
    
    Write-ColorOutput "Connecting to AKS cluster: $AksName..." "Yellow"
    
    try {
        # Get AKS credentials
        az aks get-credentials -g $ResourceGroupName -n $AksName --overwrite-existing
        
        # Verify connection by listing namespaces
        Write-ColorOutput "Verifying AKS connection - listing namespaces:" "Cyan"
        kubectl get namespaces
        
        Write-ColorOutput "✓ Successfully connected to AKS cluster!" "Green"
    }
    catch {
        Write-ColorOutput "Failed to connect to AKS cluster: $_" "Red"
        exit 1
    }
}

# Function to install NGINX Ingress Controller
function Install-NginxIngressController {
    Write-ColorOutput "Installing NGINX Ingress Controller..." "Yellow"
    
    try {
        # Add helm repository
        Write-ColorOutput "Adding ingress-nginx helm repository..." "Cyan"
        helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
        helm repo update
        
        # Create namespace
        Write-ColorOutput "Creating ingress-nginx namespace..." "Cyan"
        kubectl create namespace ingress-nginx --dry-run=client -o yaml | kubectl apply -f -
        
        # Install NGINX ingress controller
        Write-ColorOutput "Installing NGINX ingress controller..." "Cyan"
        helm install nginx-quick ingress-nginx/ingress-nginx -n ingress-nginx
        
        # Wait for deployment to be ready
        Write-ColorOutput "Waiting for NGINX controller to be ready..." "Yellow"
        kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=300s
        
        # Patch health probe
        Write-ColorOutput "Patching health probe..." "Cyan"
        kubectl patch service nginx-quick-ingress-nginx-controller -n ingress-nginx -p '{\"metadata\":{\"annotations\":{\"service.beta.kubernetes.io/azure-load-balancer-health-probe-request-path\":\"/healthz\"}}}'
        
        # Verify annotation
        Write-ColorOutput "Verifying health probe annotation:" "Cyan"
        kubectl get service nginx-quick-ingress-nginx-controller -n ingress-nginx -o jsonpath='{.metadata.annotations}' | jq
        
        # Show service details
        Write-ColorOutput "NGINX Ingress Controller service details:" "Cyan"
        kubectl get service --namespace ingress-nginx nginx-quick-ingress-nginx-controller --output wide
        
        # Get external IP
        Write-ColorOutput "Getting external IP of NGINX controller..." "Yellow"
        $maxAttempts = 10
        $attempt = 1
        
        do {
            Write-ColorOutput "Attempt $attempt/$maxAttempts - Waiting for external IP..." "Yellow"
            $externalIP = kubectl get service -n ingress-nginx -o jsonpath='{range .items[*]} {.status.loadBalancer.ingress[*].ip} {"\n"} {end}'
            
            if ($externalIP -and $externalIP.Trim()) {
                Write-ColorOutput "✓ External IP obtained: $($externalIP.Trim())" "Green"
                break
            }
            
            Start-Sleep 30
            $attempt++
        } while ($attempt -le $maxAttempts)
        
        if (-not $externalIP -or -not $externalIP.Trim()) {
            Write-ColorOutput "Warning: External IP not yet assigned. Check later with: kubectl get service -n ingress-nginx" "Yellow"
        }
        
        Write-ColorOutput "✓ NGINX Ingress Controller installed successfully!" "Green"
    }
    catch {
        Write-ColorOutput "Failed to install NGINX Ingress Controller: $_" "Red"
        exit 1
    }
}

# Function to display deployment summary
function Show-DeploymentSummary {
    param(
        [string]$ResourceGroupName,
        [string]$AksName,
        [string]$Location
    )
    
    Write-ColorOutput "`n" + "="*80 "Green"
    Write-ColorOutput "DEPLOYMENT SUMMARY" "Green"
    Write-ColorOutput "="*80 "Green"
    
    Write-ColorOutput "Resource Group: $ResourceGroupName" "White"
    Write-ColorOutput "AKS Cluster: $AksName" "White"
    Write-ColorOutput "Location: $Location" "White"
    Write-ColorOutput "Timestamp: $(Get-Date)" "White"
    
    Write-ColorOutput "`nDeployed Resources:" "Cyan"
    try {
        az resource list -g $ResourceGroupName -o table --query "[].{Name:name, Type:type}"
    }
    catch {
        Write-ColorOutput "Could not retrieve resource list" "Yellow"
    }
    
    Write-ColorOutput "`nNGINX Ingress Controller External IP:" "Cyan"
    try {
        $externalIP = kubectl get service -n ingress-nginx -o jsonpath='{range .items[*]} {.status.loadBalancer.ingress[*].ip} {"\n"} {end}'
        if ($externalIP -and $externalIP.Trim()) {
            Write-ColorOutput $externalIP.Trim() "White"
        }
        else {
            Write-ColorOutput "Not yet assigned - check later" "Yellow"
        }
    }
    catch {
        Write-ColorOutput "Could not retrieve external IP" "Yellow"
    }
    
    Write-ColorOutput "`nIMPORTANT:" "Red"
    Write-ColorOutput "Make sure the CIDR of the created VNet is added to the Oracle NSG." "Yellow"
    Write-ColorOutput "="*80 "Green"
}

# Main execution
function Main {
    $startTime = Get-Date
    
    Write-ColorOutput "Starting ODAA MH Environment Deployment" "Green"
    Write-ColorOutput "Resource Group: $ResourceGroupName" "White"
    Write-ColorOutput "Prefix: $Prefix" "White"
    Write-ColorOutput "Postfix: $Postfix" "White"
    Write-ColorOutput "Location: $Location" "White"
    Write-ColorOutput ""
    
    # Check prerequisites
    if (-not $SkipPrerequisites) {
        Test-Prerequisites
    }
    else {
        Write-ColorOutput "Skipping prerequisite checks..." "Yellow"
    }
    
    # Login to Azure
    if (-not $SkipLogin) {
        Connect-AzureAccount
    }
    else {
        Write-ColorOutput "Skipping Azure login..." "Yellow"
    }
    
    # Create resource group
    New-AzureResourceGroup -Name $ResourceGroupName -Location $Location
    
    # Deploy Azure resources
    Deploy-AzureResources -ResourceGroupName $ResourceGroupName -Prefix $Prefix -Postfix $Postfix -Location $Location
    
    # Connect to AKS
    $aksName = $Prefix + $Postfix
    Connect-AKSCluster -ResourceGroupName $ResourceGroupName -AksName $aksName
    
    # Install NGINX Ingress Controller
    Install-NginxIngressController
    
    # Show deployment summary
    Show-DeploymentSummary -ResourceGroupName $ResourceGroupName -AksName $aksName -Location $Location
    
    $endTime = Get-Date
    $duration = $endTime - $startTime
    Write-ColorOutput "`nDeployment completed in $($duration.ToString('hh\:mm\:ss'))" "Green"
}

# Execute main function
try {
    Main
}
catch {
    Write-ColorOutput "Deployment failed: $_" "Red"
    Write-ColorOutput "Stack trace: $($_.ScriptStackTrace)" "Red"
    exit 1
}
