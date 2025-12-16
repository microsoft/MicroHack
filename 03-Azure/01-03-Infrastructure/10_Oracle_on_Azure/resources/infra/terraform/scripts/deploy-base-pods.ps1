# Deploy ingress-nginx and K8s manifests to all AKS clusters

$K8sPath = "$PSScriptRoot\k8s"

# Get kubeconfigs from Terraform output
$tfOutput = terraform output -json aks_kubeconfigs | ConvertFrom-Json

# Deploy to each cluster
foreach ($property in $tfOutput.PSObject.Properties) {
    $clusterName = $property.Name
    $kubeconfig = $property.Value.kubeconfig_raw
    # Save kubeconfig to temp file
    $tempKubeconfig = [System.IO.Path]::GetTempFileName()
    $kubeconfig | Out-File -FilePath $tempKubeconfig -Encoding utf8
    
    # Deploy ingress-nginx
    Write-Host "$clusterName ingress-nginx " -NoNewline
    $result = helm upgrade --install ingress-nginx ingress-nginx `
        --repo https://kubernetes.github.io/ingress-nginx `
        --namespace ingress-nginx --create-namespace `
        --kubeconfig $tempKubeconfig 2>&1
    Write-Host $(if ($LASTEXITCODE -eq 0) { "OK" } else { "FAILED" })
    
    # Deploy K8s manifests (excluding job files)
    $yamlFiles = Get-ChildItem -Path $K8sPath -Filter "*.yaml" | 
                 Where-Object { $_.Name -notlike "*-job.yaml" } | 
                 Sort-Object Name
    
    foreach ($yamlFile in $yamlFiles) {
        Write-Host "$clusterName $($yamlFile.Name) " -NoNewline
        $result = kubectl apply -f $yamlFile.FullName --kubeconfig $tempKubeconfig 2>&1
        Write-Host $(if ($LASTEXITCODE -eq 0) { "OK" } else { "FAILED" })
    }
    
    # Cleanup temp file
    Remove-Item $tempKubeconfig -Force
}

Write-Host "`nDeployment complete!" -ForegroundColor Green
