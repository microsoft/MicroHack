# Enable Container Network Observability Logs on AKS clusters
param(
    [switch]$Debug
)

$ErrorActionPreference = "Continue"

Write-Host "Enabling Container Network Observability Logs on AKS clusters..." -ForegroundColor Cyan
Write-Host ""

# Get AKS cluster information from Terraform output
$tfOutput = terraform output -json aks_clusters | ConvertFrom-Json

if (-not $tfOutput) {
    Write-Host "Error: No AKS clusters found in Terraform output" -ForegroundColor Red
    exit 1
}

# Process each AKS cluster
foreach ($property in $tfOutput.PSObject.Properties) {
    $clusterName = $property.Name
    $clusterInfo = $property.Value
    
    Write-Host "Processing cluster: $clusterName" -ForegroundColor Yellow
    Write-Host "  Resource Group: $($clusterInfo.resource_group_name)" -ForegroundColor Gray
    Write-Host "  Subscription: $($clusterInfo.subscription_id)" -ForegroundColor Gray
    
    # Set the subscription context
    Write-Host "  Setting subscription context..." -ForegroundColor Gray
    az account set -s $clusterInfo.subscription_id 2>&1 | Out-Null
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  [FAILED] Could not set subscription context" -ForegroundColor Red
        continue
    }
    
    # Check if monitoring addon is enabled
    Write-Host "  Checking monitoring addon status..." -ForegroundColor Gray
    $monitoringStatus = az aks show -n $clusterInfo.name -g $clusterInfo.resource_group_name --query "addonProfiles.omsagent.enabled" -o tsv 2>&1
    
    if ($monitoringStatus -ne "true") {
        Write-Host "  [SKIPPED] Monitoring addon not enabled (required for Container Network Logs)" -ForegroundColor Yellow
        continue
    }
    
    # Enable Advanced Container Networking Services with Container Network Logs
    Write-Host "  Enabling ACNS and Container Network Logs..." -ForegroundColor Cyan
    
    $enableCmd = @(
        "aks", "update",
        "--enable-acns",
        "--enable-container-network-logs",
        "-g", $clusterInfo.resource_group_name,
        "-n", $clusterInfo.name
    )
    
    if ($Debug) {
        Write-Host "  [DEBUG] Command: az $($enableCmd -join ' ')" -ForegroundColor Gray
        $output = & az $enableCmd 2>&1
        Write-Host $output -ForegroundColor Gray
        $success = $LASTEXITCODE -eq 0
    } else {
        $null = & az $enableCmd 2>&1
        $success = $LASTEXITCODE -eq 0
    }
    
    if ($success) {
        Write-Host "  [SUCCESS] Container Network Logs enabled" -ForegroundColor Green
    } else {
        Write-Host "  [FAILED] Could not enable Container Network Logs" -ForegroundColor Red
    }
    
    Write-Host ""
}

Write-Host "Container Network Observability Logs configuration complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Create ContainerNetworkLog CRDs to define what traffic to capture" -ForegroundColor Gray
Write-Host "  2. View logs in Log Analytics workspace" -ForegroundColor Gray
Write-Host "  3. Set up Grafana dashboards for visualization" -ForegroundColor Gray
Write-Host ""
Write-Host "Documentation: https://learn.microsoft.com/en-us/azure/aks/container-network-observability-logs" -ForegroundColor Gray
