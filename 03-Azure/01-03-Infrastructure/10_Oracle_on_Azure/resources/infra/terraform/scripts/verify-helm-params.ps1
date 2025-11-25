# Verify ingress-nginx Helm chart parameters for health probes
# Run this before implementing the deployment script

Write-Host "Fetching ingress-nginx Helm chart..." -ForegroundColor Cyan

# Update helm repos
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx 2>&1 | Out-Null
helm repo update 2>&1 | Out-Null

Write-Host "`nSearching for health probe configuration parameters...`n" -ForegroundColor Cyan

# Show all values (inspect for livenessProbe and readinessProbe paths)
$allValues = helm show values ingress-nginx/ingress-nginx

# Extract relevant sections
Write-Host "=== Controller Liveness Probe Configuration ===" -ForegroundColor Green
$allValues | Select-String -Pattern "livenessProbe:" -Context 0,10

Write-Host "`n=== Controller Readiness Probe Configuration ===" -ForegroundColor Green
$allValues | Select-String -Pattern "readinessProbe:" -Context 0,10

Write-Host "`n=== Current Default Health Check Paths ===" -ForegroundColor Yellow
$allValues | Select-String -Pattern "path.*health" -Context 1

Write-Host "`n--- To verify the exact parameter paths, use: ---" -ForegroundColor Cyan
Write-Host "helm show values ingress-nginx/ingress-nginx | Out-File ingress-nginx-values.txt" -ForegroundColor White
Write-Host "`nThen search for 'livenessProbe' and 'readinessProbe' in the file." -ForegroundColor White
