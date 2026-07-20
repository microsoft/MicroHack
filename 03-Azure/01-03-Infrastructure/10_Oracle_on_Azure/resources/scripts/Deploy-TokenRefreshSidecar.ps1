# Deploy Token Refresh Sidecar Container
# This script builds and deploys the token refresh sidecar to your AKS cluster

param(
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroup = "odaa",
    
    [Parameter(Mandatory=$false)]
    [string]$AcrName = "odaa",
    
    [Parameter(Mandatory=$false)]
    [string]$AksCluster = "odaa",
    
    [Parameter(Mandatory=$false)]
    [string]$Namespace = "microhacks",
    
    [Parameter(Mandatory=$false)]
    [string]$ImageTag = "latest",
    
    [Parameter(Mandatory=$false)]
    [string]$TenantId = "f71980b2-590a-4de9-90d5-6fbc867da951",
    
    [Parameter(Mandatory=$false)]
    [string]$ClientId = "7d22ece1-dd60-4279-a911-4b7b95934f2e"
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Token Refresh Sidecar Deployment" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Get ACR login server
Write-Host "Step 1: Getting ACR details..." -ForegroundColor Green
$acrLoginServer = az acr show --name $AcrName --resource-group $ResourceGroup --query loginServer -o tsv

if (!$acrLoginServer) {
    Write-Host "ERROR: Could not find ACR: $AcrName" -ForegroundColor Red
    exit 1
}

Write-Host "ACR Login Server: $acrLoginServer" -ForegroundColor Yellow

# Step 2: Build Docker image
Write-Host "`nStep 2: Building Docker image..." -ForegroundColor Green
$imageName = "${acrLoginServer}/token-refresh:${ImageTag}"

docker build -f .\resources\infra\Dockerfile.token-refresh -t $imageName .

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Docker build failed" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Image built: $imageName" -ForegroundColor Yellow

# Step 3: Push to ACR
Write-Host "`nStep 3: Pushing image to ACR..." -ForegroundColor Green

# Login to ACR
az acr login --name $AcrName

# Push image
docker push $imageName

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Docker push failed" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Image pushed to ACR" -ForegroundColor Yellow

# Step 4: Attach ACR to AKS (if not already attached)
Write-Host "`nStep 4: Ensuring AKS can pull from ACR..." -ForegroundColor Green
az aks update --name $AksCluster --resource-group $ResourceGroup --attach-acr $AcrName

# Step 5: Get AKS credentials
Write-Host "`nStep 5: Getting AKS credentials..." -ForegroundColor Green
az aks get-credentials --resource-group $ResourceGroup --name $AksCluster --overwrite-existing

# Step 6: Create deployment YAML
Write-Host "`nStep 6: Creating Kubernetes deployment..." -ForegroundColor Green

$deploymentYaml = @"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: oracle-client-with-token-refresh
  namespace: $Namespace
  labels:
    app: oracle-client
    component: database-client
spec:
  replicas: 1
  selector:
    matchLabels:
      app: oracle-client
  template:
    metadata:
      labels:
        app: oracle-client
        azure.workload.identity/use: "true"
    spec:
      serviceAccountName: oracle-client-sa
      containers:
      # Main Oracle client container
      - name: instantclient
        image: container-registry.oracle.com/database/instantclient:23
        command: ["/bin/bash"]
        args: ["-c", "sleep infinity"]
        env:
        - name: TNS_ADMIN
          value: "/tmp/wallet"
        - name: ORACLE_HOME
          value: "/opt/oracle/instantclient_23_4"
        - name: LD_LIBRARY_PATH
          value: "/opt/oracle/instantclient_23_4"
        volumeMounts:
        - name: wallet
          mountPath: /tmp/wallet
        resources:
          requests:
            memory: "256Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "500m"
      
      # Token refresh sidecar
      - name: token-refresh
        image: $imageName
        env:
        - name: AZURE_CLIENT_ID
          value: "$ClientId"
        - name: AZURE_TENANT_ID
          value: "$TenantId"
        - name: TOKEN_FILE
          value: "/tmp/wallet/token.txt"
        - name: REFRESH_INTERVAL
          value: "2700"  # 45 minutes
        - name: LOG_LEVEL
          value: "INFO"
        volumeMounts:
        - name: wallet
          mountPath: /tmp/wallet
        resources:
          requests:
            memory: "128Mi"
            cpu: "50m"
          limits:
            memory: "256Mi"
            cpu: "200m"
      
      volumes:
      - name: wallet
        emptyDir: {}
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: oracle-client-sa
  namespace: $Namespace
  annotations:
    azure.workload.identity/client-id: "$ClientId"
  labels:
    azure.workload.identity/use: "true"
"@

# Save YAML file
$yamlFile = ".\resources\infra\oracle-client-deployment.yaml"
$deploymentYaml | Out-File -FilePath $yamlFile -Encoding UTF8

Write-Host "✅ Deployment YAML created: $yamlFile" -ForegroundColor Yellow

# Step 7: Apply deployment
Write-Host "`nStep 7: Applying Kubernetes deployment..." -ForegroundColor Green

kubectl apply -f $yamlFile

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: kubectl apply failed" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Deployment applied successfully" -ForegroundColor Yellow

# Step 8: Wait for pods to be ready
Write-Host "`nStep 8: Waiting for pods to be ready..." -ForegroundColor Green
kubectl wait --for=condition=ready pod -l app=oracle-client -n $Namespace --timeout=120s

# Step 9: Display status
Write-Host "`nStep 9: Checking deployment status..." -ForegroundColor Green
Write-Host "`nPods:" -ForegroundColor Cyan
kubectl get pods -n $Namespace -l app=oracle-client

Write-Host "`nToken refresh logs (last 20 lines):" -ForegroundColor Cyan
$podName = kubectl get pods -n $Namespace -l app=oracle-client -o jsonpath='{.items[0].metadata.name}'
kubectl logs -n $Namespace $podName -c token-refresh --tail=20

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Deployment Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "`nTo test the connection:" -ForegroundColor Yellow
Write-Host "  kubectl exec -it -n $Namespace $podName -c instantclient -- bash" -ForegroundColor White
Write-Host "  # Inside the pod:" -ForegroundColor White
Write-Host "  export TNS_ADMIN=/tmp/wallet" -ForegroundColor White
Write-Host "  export LD_LIBRARY_PATH=/opt/oracle/instantclient_23_4" -ForegroundColor White
Write-Host "  sqlplus /@adbger_high" -ForegroundColor White
Write-Host "`nTo view token refresh logs:" -ForegroundColor Yellow
Write-Host "  kubectl logs -n $Namespace $podName -c token-refresh -f" -ForegroundColor White
Write-Host ""
