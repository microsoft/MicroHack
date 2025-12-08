<#
.SYNOPSIS
    Deploy ingress-nginx and K8s manifests to all AKS clusters.

.DESCRIPTION
    This script deploys ingress-nginx Helm chart and Kubernetes manifests 
    to all AKS clusters from Terraform output. You can exclude specific 
    clusters from deployment. The script automatically starts stopped clusters
    and stops them again after deployment to save costs.

.PARAMETER ExcludeAksClusters
    Array of AKS cluster names or resource IDs to exclude from deployment.
    Example: @("aks-user00", "aks-user01")
    Example: @("/subscriptions/.../managedClusters/aks-user00")

.PARAMETER CleanupNamespace
    Name of the namespace to delete before deploying manifests.
    If the namespace exists, it will be deleted along with all its resources.
    Default: "microhack"

.PARAMETER SkipNamespaceCleanup
    Skip the namespace cleanup step.

.PARAMETER KeepRunning
    Do not stop clusters after deployment (keep them running even if they were originally stopped).

.PARAMETER ShowDebug
    Enable debug output for troubleshooting.

.EXAMPLE
    # Deploy to all clusters
    .\deploy-base-pods.ps1

.EXAMPLE
    # Exclude specific clusters by name
    .\deploy-base-pods.ps1 -ExcludeAksClusters @("aks-user00", "aks-user01")

.EXAMPLE
    # Exclude by resource ID
    .\deploy-base-pods.ps1 -ExcludeAksClusters @("/subscriptions/xxx/resourceGroups/aks-user00/providers/Microsoft.ContainerService/managedClusters/aks-user00")

.EXAMPLE
    # Skip namespace cleanup
    .\deploy-base-pods.ps1 -SkipNamespaceCleanup

.EXAMPLE
    # Keep clusters running after deployment
    .\deploy-base-pods.ps1 -KeepRunning

.EXAMPLE
    # Exclude clusters with debug output
    .\deploy-base-pods.ps1 -ExcludeAksClusters @("aks-user00") -ShowDebug
#>

param(
    [Parameter()]
    [string[]]$ExcludeAksClusters = @(),

    [Parameter()]
    [string]$CleanupNamespace = "microhacks",

    [switch]$SkipNamespaceCleanup,

    [switch]$KeepRunning,

    [switch]$ShowDebug
)

$ErrorActionPreference = "Continue"
$K8sPath = "$PSScriptRoot\k8s"

# Helper function to check if cluster should be excluded
function Test-ClusterExcluded {
    param([string]$ClusterName, [string]$ResourceGroup, [string]$SubscriptionId)
    
    foreach ($exclusion in $ExcludeAksClusters) {
        # Check if exclusion matches cluster name
        if ($exclusion -eq $ClusterName) {
            return $true
        }
        # Check if exclusion matches resource ID pattern
        if ($exclusion -match "/managedClusters/$ClusterName$") {
            return $true
        }
    }
    return $false
}

# Show exclusions if any
if ($ExcludeAksClusters.Count -gt 0) {
    Write-Host "Excluding clusters: $($ExcludeAksClusters -join ', ')" -ForegroundColor Yellow
    Write-Host ""
}

# Update Helm repositories
Write-Host "Updating Helm repositories..." -ForegroundColor Cyan
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx 2>&1 | Out-Null
helm repo update 2>&1 | Out-Null
Write-Host "Helm repositories updated.`n" -ForegroundColor Green

# Get kubeconfigs from Terraform output
$tfOutput = terraform output -json aks_kubeconfigs | ConvertFrom-Json

# Deploy to each cluster
foreach ($property in $tfOutput.PSObject.Properties) {
    $userKey = $property.Name
    $aksClusterName = $property.Value.cluster_name
    $resourceGroup = $property.Value.resource_group_name
    $subscriptionId = $property.Value.subscription_id
    
    # Check if cluster should be excluded
    if (Test-ClusterExcluded -ClusterName $aksClusterName -ResourceGroup $resourceGroup -SubscriptionId $subscriptionId) {
        Write-Host "$aksClusterName SKIPPED (excluded)" -ForegroundColor Yellow
        continue
    }
    
    # Check AKS power state
    Write-Host "$aksClusterName checking power state... " -NoNewline
    $powerState = az aks show --name $aksClusterName --resource-group $resourceGroup --subscription $subscriptionId --query "powerState.code" -o tsv 2>$null
    $wasOriginallyStopped = $false
    
    if ($powerState -eq "Stopped") {
        $wasOriginallyStopped = $true
        Write-Host "STOPPED - starting cluster..." -ForegroundColor Yellow
        $null = az aks start --name $aksClusterName --resource-group $resourceGroup --subscription $subscriptionId 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Host "$aksClusterName FAILED to start cluster" -ForegroundColor Red
            continue
        }
        Write-Host "$aksClusterName cluster started successfully" -ForegroundColor Green
        
        # Wait for nodes to become Ready after starting
        Write-Host "$aksClusterName waiting for nodes to be Ready... " -NoNewline
        $maxWaitSeconds = 300
        $waitInterval = 10
        $elapsed = 0
        $nodesReady = $false
        
        # Get fresh kubeconfig after start
        $kubeconfig = az aks get-credentials --name $aksClusterName --resource-group $resourceGroup --subscription $subscriptionId --file - 2>$null
        $tempKubeconfig = [System.IO.Path]::GetTempFileName()
        $kubeconfig | Out-File -FilePath $tempKubeconfig -Encoding utf8
        
        while ($elapsed -lt $maxWaitSeconds -and -not $nodesReady) {
            Start-Sleep -Seconds $waitInterval
            $elapsed += $waitInterval
            
            # Check if all nodes are Ready
            $notReadyNodes = kubectl get nodes --kubeconfig $tempKubeconfig --no-headers 2>$null | Where-Object { $_ -notmatch '\sReady\s' }
            if ($null -eq $notReadyNodes -or $notReadyNodes.Count -eq 0) {
                $nodesReady = $true
            } else {
                Write-Host "." -NoNewline
            }
        }
        
        if ($nodesReady) {
            Write-Host " Ready" -ForegroundColor Green
        } else {
            Write-Host " TIMEOUT (continuing anyway)" -ForegroundColor Yellow
        }
    } else {
        Write-Host "Running" -ForegroundColor Green
        # Use kubeconfig from Terraform output
        $kubeconfig = $property.Value.kubeconfig_raw
        $tempKubeconfig = [System.IO.Path]::GetTempFileName()
        $kubeconfig | Out-File -FilePath $tempKubeconfig -Encoding utf8
    }
    
    # Deploy ingress-nginx
    Write-Host "$aksClusterName ingress-nginx " -NoNewline
    
    $helmArgs = @(
        "upgrade", "--install", "ingress-nginx", "ingress-nginx",
        "--repo", "https://kubernetes.github.io/ingress-nginx",
        "--namespace", "ingress-nginx", "--create-namespace",
        "--set", "controller.livenessProbe.httpGet.path=/healthz",
        "--set", "controller.readinessProbe.httpGet.path=/healthz",
        "--set", "controller.service.annotations.service\.beta\.kubernetes\.io/azure-load-balancer-health-probe-request-path=/healthz",
        "--set", "defaultBackend.enabled=false",
        "--kubeconfig", $tempKubeconfig,
        "--wait", "--timeout", "5m"
    )
    
    if ($ShowDebug) {
        Write-Host "`n[DEBUG] Helm command: helm $($helmArgs -join ' ')" -ForegroundColor Gray
        $output = & helm $helmArgs 2>&1
        Write-Host $output -ForegroundColor Gray
        $success = $LASTEXITCODE -eq 0
    } else {
        $null = & helm $helmArgs 2>&1
        $success = $LASTEXITCODE -eq 0
    }
    
    Write-Host $(if ($success) { "OK" } else { "FAILED" }) -ForegroundColor $(if ($success) { "Green" } else { "Red" })
    
    # Cleanup namespace if it exists
    if (-not $SkipNamespaceCleanup) {
        Write-Host "$aksClusterName namespace/$CleanupNamespace " -NoNewline
        
        # Check if namespace exists
        $nsExists = kubectl get namespace $CleanupNamespace --kubeconfig $tempKubeconfig 2>&1
        if ($LASTEXITCODE -eq 0) {
            # Namespace exists, delete it
            if ($ShowDebug) {
                Write-Host "`n[DEBUG] Namespace exists, deleting..." -ForegroundColor Gray
                $output = kubectl delete namespace $CleanupNamespace --kubeconfig $tempKubeconfig --wait=true 2>&1
                Write-Host $output -ForegroundColor Gray
                $success = $LASTEXITCODE -eq 0
            } else {
                $null = kubectl delete namespace $CleanupNamespace --kubeconfig $tempKubeconfig --wait=true 2>&1
                $success = $LASTEXITCODE -eq 0
            }
            Write-Host $(if ($success) { "DELETED" } else { "DELETE FAILED" }) -ForegroundColor $(if ($success) { "Yellow" } else { "Red" })
        } else {
            Write-Host "NOT EXISTS (skip cleanup)" -ForegroundColor Gray
        }
    }

    # Deploy K8s manifests
    $yamlFiles = Get-ChildItem -Path $K8sPath -Filter "*.yaml" | 
                 Where-Object { $_.Name -notlike "*-job.yaml" } | 
                 Sort-Object Name
    
    foreach ($yamlFile in $yamlFiles) {
        Write-Host "$aksClusterName $($yamlFile.Name) " -NoNewline
        
        if ($ShowDebug) {
            Write-Host "`n[DEBUG] kubectl apply -f $($yamlFile.FullName)" -ForegroundColor Gray
            $output = kubectl apply -f $yamlFile.FullName --kubeconfig $tempKubeconfig 2>&1
            Write-Host $output -ForegroundColor Gray
            $success = $LASTEXITCODE -eq 0
        } else {
            $null = kubectl apply -f $yamlFile.FullName --kubeconfig $tempKubeconfig 2>&1
            $success = $LASTEXITCODE -eq 0
        }
        
        Write-Host $(if ($success) { "OK" } else { "FAILED" }) -ForegroundColor $(if ($success) { "Green" } else { "Red" })
    }
    
    Remove-Item $tempKubeconfig -Force
    
    # Stop cluster if it was originally stopped (to save costs)
    if ($wasOriginallyStopped -and -not $KeepRunning) {
        Write-Host "$aksClusterName stopping cluster (was originally stopped)... " -NoNewline
        $null = az aks stop --name $aksClusterName --resource-group $resourceGroup --subscription $subscriptionId 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "STOPPED" -ForegroundColor Yellow
        } else {
            Write-Host "FAILED to stop" -ForegroundColor Red
        }
    }
}

Write-Host "`nDeployment complete!" -ForegroundColor Green
