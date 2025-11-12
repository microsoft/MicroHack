# ===============================================================================
# Deploy Ingress Controllers to All AKS Clusters
# ===============================================================================
# This script deploys ingress-nginx helm charts to all AKS clusters provisioned
# by Terraform. It reads cluster kubeconfig directly from terraform output,
# eliminating the need for separate Azure CLI authentication.
#
# Usage:
#   .\deploy-ingress-controllers.ps1
#
# Prerequisites:
#   - Terraform has been successfully applied
#   - helm CLI is installed and available in PATH
#   - kubectl CLI is installed and available in PATH
#
# ===============================================================================

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$HelmVersion = "4.14.0",
    
    [Parameter(Mandatory=$false)]
    [string]$Namespace = "ingress-nginx",
    
    [Parameter(Mandatory=$false)]
    [switch]$Uninstall
)

$ErrorActionPreference = "Stop"

# ===============================================================================
# Helper Functions
# ===============================================================================

function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

function Test-Prerequisites {
    Write-ColorOutput "`n==> Checking prerequisites..." "Cyan"
    
    # Check helm
    try {
        $helmVersion = helm version --short 2>&1
        Write-ColorOutput "  ✓ Helm CLI found: $helmVersion" "Green"
    }
    catch {
        Write-ColorOutput "  ✗ Helm CLI not found. Please install helm from https://helm.sh/docs/intro/install/" "Red"
        exit 1
    }
    
    # Check kubectl
    try {
        $kubectlVersion = kubectl version --client --short 2>&1
        Write-ColorOutput "  ✓ kubectl found" "Green"
    }
    catch {
        Write-ColorOutput "  ✗ kubectl not found. Please install kubectl" "Red"
        exit 1
    }
    
    # Check terraform
    try {
        terraform version | Out-Null
        Write-ColorOutput "  ✓ Terraform found" "Green"
    }
    catch {
        Write-ColorOutput "  ✗ Terraform not found in PATH" "Red"
        exit 1
    }
}

function Get-TerraformOutput {
    Write-ColorOutput "`n==> Reading Terraform outputs..." "Cyan"
    
    try {
        # Get kubeconfig output as JSON
        $kubeconfigJson = terraform output -json aks_kubeconfigs 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            Write-ColorOutput "  ✗ Failed to read terraform output. Make sure 'terraform apply' has been run successfully." "Red"
            Write-ColorOutput "  Error: $kubeconfigJson" "Red"
            exit 1
        }
        
        $kubeconfigs = $kubeconfigJson | ConvertFrom-Json
        
        if ($null -eq $kubeconfigs -or $kubeconfigs.PSObject.Properties.Count -eq 0) {
            Write-ColorOutput "  ✗ No AKS clusters found in terraform output" "Red"
            exit 1
        }
        
        Write-ColorOutput "  ✓ Found $($kubeconfigs.PSObject.Properties.Count) AKS cluster(s)" "Green"
        
        return $kubeconfigs
    }
    catch {
        Write-ColorOutput "  ✗ Error reading terraform output: $_" "Red"
        exit 1
    }
}

function Deploy-IngressController {
    param(
        [string]$ClusterName,
        [string]$KubeconfigContent,
        [string]$HelmVersion,
        [string]$Namespace
    )
    
    Write-ColorOutput "`n  Processing cluster: $ClusterName" "Yellow"
    
    # Create temporary kubeconfig file
    $tempKubeconfig = Join-Path $env:TEMP "kubeconfig-$ClusterName-$(Get-Random).yaml"
    
    try {
        # Write kubeconfig to temp file
        $KubeconfigContent | Out-File -FilePath $tempKubeconfig -Encoding utf8 -Force
        
        # Set KUBECONFIG environment variable for this scope
        $env:KUBECONFIG = $tempKubeconfig
        
        # Test cluster connectivity
        Write-ColorOutput "    → Testing cluster connectivity..." "Gray"
        $clusterInfo = kubectl cluster-info 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            Write-ColorOutput "    ✗ Cannot connect to cluster $ClusterName" "Red"
            Write-ColorOutput "    Error: $clusterInfo" "Red"
            return $false
        }
        
        Write-ColorOutput "    ✓ Connected to cluster" "Green"
        
        # Add ingress-nginx helm repo
        Write-ColorOutput "    → Adding/updating ingress-nginx helm repository..." "Gray"
        helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx 2>&1 | Out-Null
        helm repo update 2>&1 | Out-Null
        
        # Install/Upgrade ingress-nginx
        Write-ColorOutput "    → Deploying ingress-nginx v$HelmVersion..." "Gray"
        
        $helmArgs = @(
            "upgrade", "--install", "nginx-quick",
            "ingress-nginx/ingress-nginx",
            "--version", $HelmVersion,
            "--namespace", $Namespace,
            "--create-namespace",
            "--set", "controller.service.annotations.service\.beta\.kubernetes\.io/azure-load-balancer-health-probe-request-path=/healthz",
            "--wait",
            "--timeout", "5m"
        )
        
        $helmOutput = & helm $helmArgs 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            Write-ColorOutput "    ✗ Helm deployment failed for $ClusterName" "Red"
            Write-ColorOutput "    Error: $helmOutput" "Red"
            return $false
        }
        
        Write-ColorOutput "    ✓ Ingress controller deployed successfully" "Green"
        
        # Verify deployment
        Write-ColorOutput "    → Verifying deployment..." "Gray"
        $pods = kubectl get pods -n $Namespace -l app.kubernetes.io/name=ingress-nginx -o json 2>&1 | ConvertFrom-Json
        
        if ($pods.items.Count -gt 0) {
            $runningPods = ($pods.items | Where-Object { $_.status.phase -eq "Running" }).Count
            Write-ColorOutput "    ✓ Found $runningPods running pod(s) in namespace '$Namespace'" "Green"
        }
        
        return $true
    }
    catch {
        Write-ColorOutput "    ✗ Exception during deployment: $_" "Red"
        return $false
    }
    finally {
        # Clean up temporary kubeconfig file
        if (Test-Path $tempKubeconfig) {
            Remove-Item $tempKubeconfig -Force -ErrorAction SilentlyContinue
        }
        
        # Clear KUBECONFIG environment variable
        $env:KUBECONFIG = ""
    }
}

function Uninstall-IngressController {
    param(
        [string]$ClusterName,
        [string]$KubeconfigContent,
        [string]$Namespace
    )
    
    Write-ColorOutput "`n  Uninstalling from cluster: $ClusterName" "Yellow"
    
    # Create temporary kubeconfig file
    $tempKubeconfig = Join-Path $env:TEMP "kubeconfig-$ClusterName-$(Get-Random).yaml"
    
    try {
        # Write kubeconfig to temp file
        $KubeconfigContent | Out-File -FilePath $tempKubeconfig -Encoding utf8 -Force
        
        # Set KUBECONFIG environment variable for this scope
        $env:KUBECONFIG = $tempKubeconfig
        
        # Uninstall helm release
        Write-ColorOutput "    → Uninstalling nginx-quick release..." "Gray"
        
        $helmOutput = helm uninstall nginx-quick --namespace $Namespace 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            Write-ColorOutput "    ⚠ Helm uninstall failed (release may not exist)" "Yellow"
        }
        else {
            Write-ColorOutput "    ✓ Helm release uninstalled" "Green"
        }
        
        # Delete namespace
        Write-ColorOutput "    → Deleting namespace '$Namespace'..." "Gray"
        kubectl delete namespace $Namespace --ignore-not-found=true 2>&1 | Out-Null
        Write-ColorOutput "    ✓ Namespace deleted" "Green"
        
        return $true
    }
    catch {
        Write-ColorOutput "    ✗ Exception during uninstall: $_" "Red"
        return $false
    }
    finally {
        # Clean up temporary kubeconfig file
        if (Test-Path $tempKubeconfig) {
            Remove-Item $tempKubeconfig -Force -ErrorAction SilentlyContinue
        }
        
        # Clear KUBECONFIG environment variable
        $env:KUBECONFIG = ""
    }
}

# ===============================================================================
# Main Script
# ===============================================================================

Write-ColorOutput "`n===============================================================================" "Cyan"
Write-ColorOutput "          AKS Ingress Controller Deployment Automation" "Cyan"
Write-ColorOutput "===============================================================================`n" "Cyan"

# Check prerequisites
Test-Prerequisites

# Get terraform outputs
$kubeconfigs = Get-TerraformOutput

# Process each cluster
$successCount = 0
$failCount = 0
$clusterCount = $kubeconfigs.PSObject.Properties.Count

Write-ColorOutput "`n==> Processing $clusterCount cluster(s)..." "Cyan"

foreach ($property in $kubeconfigs.PSObject.Properties) {
    $clusterName = $property.Name
    $clusterData = $property.Value
    
    $kubeconfigRaw = $clusterData.kubeconfig_raw
    
    if ($Uninstall) {
        $result = Uninstall-IngressController `
            -ClusterName $clusterName `
            -KubeconfigContent $kubeconfigRaw `
            -Namespace $Namespace
    }
    else {
        $result = Deploy-IngressController `
            -ClusterName $clusterName `
            -KubeconfigContent $kubeconfigRaw `
            -HelmVersion $HelmVersion `
            -Namespace $Namespace
    }
    
    if ($result) {
        $successCount++
    }
    else {
        $failCount++
    }
}

# Summary
Write-ColorOutput "`n═══════════════════════════════════════════════════════════════════════════════" "Cyan"
Write-ColorOutput "Deployment Summary:" "Cyan"
Write-ColorOutput "═══════════════════════════════════════════════════════════════════════════════`n" "Cyan"

Write-ColorOutput "  Total clusters processed: $clusterCount" "White"

if ($successCount -gt 0) {
    Write-ColorOutput "  Successful: $successCount" "Green"
}

if ($failCount -gt 0) {
    Write-ColorOutput "  Failed: $failCount" "Red"
}

Write-ColorOutput "" "White"

if ($failCount -eq 0) {
    Write-ColorOutput "✓ All ingress controllers deployed successfully!" "Green"
    exit 0
}
else {
    Write-ColorOutput "⚠ Some deployments failed. Please review the output above for details." "Yellow"
    exit 1
}
