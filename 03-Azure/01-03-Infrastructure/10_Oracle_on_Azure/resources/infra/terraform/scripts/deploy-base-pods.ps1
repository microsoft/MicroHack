# Deploy ingress-nginx and K8s manifests to all AKS clusters
param(
    [switch]$Debug
)

$ErrorActionPreference = "Continue"
$K8sPath = "$PSScriptRoot\k8s"

# Update Helm repositories
Write-Host "Updating Helm repositories..." -ForegroundColor Cyan
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx 2>&1 | Out-Null
helm repo update 2>&1 | Out-Null
Write-Host "Helm repositories updated.`n" -ForegroundColor Green

# Get kubeconfigs from Terraform output
$tfOutput = terraform output -json aks_kubeconfigs | ConvertFrom-Json

# Deploy to each cluster
foreach ($property in $tfOutput.PSObject.Properties) {
    $clusterName = $property.Name
    $kubeconfig = $property.Value.kubeconfig_raw
    $tempKubeconfig = [System.IO.Path]::GetTempFileName()
    $kubeconfig | Out-File -FilePath $tempKubeconfig -Encoding utf8
    
    # Deploy ingress-nginx
    Write-Host "$clusterName ingress-nginx " -NoNewline
    
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
    
    if ($Debug) {
        Write-Host "`n[DEBUG] Helm command: helm $($helmArgs -join ' ')" -ForegroundColor Gray
        $output = & helm $helmArgs 2>&1
        Write-Host $output -ForegroundColor Gray
        $success = $LASTEXITCODE -eq 0
    } else {
        $null = & helm $helmArgs 2>&1
        $success = $LASTEXITCODE -eq 0
    }
    
    Write-Host $(if ($success) { "OK" } else { "FAILED" }) -ForegroundColor $(if ($success) { "Green" } else { "Red" })
    
    # Deploy K8s manifests
    $yamlFiles = Get-ChildItem -Path $K8sPath -Filter "*.yaml" | 
                 Where-Object { $_.Name -notlike "*-job.yaml" } | 
                 Sort-Object Name
    
    foreach ($yamlFile in $yamlFiles) {
        Write-Host "$clusterName $($yamlFile.Name) " -NoNewline
        
        if ($Debug) {
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
}

Write-Host "`nDeployment complete!" -ForegroundColor Green
