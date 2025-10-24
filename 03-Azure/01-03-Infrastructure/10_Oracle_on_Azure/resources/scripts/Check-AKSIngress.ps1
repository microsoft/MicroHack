# Check AKS Ingress Configuration Script
# This script helps diagnose your current AKS ingress setup

param(
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroup = "odaa",
    
    [Parameter(Mandatory=$false)]
    [string]$AksName = "odaa",
    
    [Parameter(Mandatory=$false)]
    [string]$Namespace = "microhacks"
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "AKS Ingress Configuration Analysis" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# Step 1: Check AKS addons
Write-Host "`n1. Checking AKS addons..." -ForegroundColor Green
$aksAddons = az aks show --name $AksName --resource-group $ResourceGroup --query "addonProfiles" -o json | ConvertFrom-Json

if ($aksAddons.ingressApplicationGateway.enabled -eq $true) {
    Write-Host "✅ Application Gateway Ingress Controller (AGIC) is enabled" -ForegroundColor Green
    $agicConfig = $aksAddons.ingressApplicationGateway.config
    Write-Host "   Application Gateway: $($agicConfig.applicationGatewayName)" -ForegroundColor Yellow
    Write-Host "   Resource Group: $($agicConfig.applicationGatewayResourceGroup)" -ForegroundColor Yellow
} else {
    Write-Host "❌ Application Gateway Ingress Controller (AGIC) is NOT enabled" -ForegroundColor Red
}

# Step 2: Check for ingress controllers
Write-Host "`n2. Checking for ingress controllers in cluster..." -ForegroundColor Green
kubectl get pods --all-namespaces -l app.kubernetes.io/name=ingress-nginx -o wide
kubectl get pods --all-namespaces -l app=ingress-appgw -o wide

# Step 3: Check ingress classes
Write-Host "`n3. Available ingress classes..." -ForegroundColor Green
kubectl get ingressclass

# Step 4: Check services of type LoadBalancer
Write-Host "`n4. LoadBalancer services (public IPs)..." -ForegroundColor Green
kubectl get services --all-namespaces -o wide | Where-Object { $_ -match "LoadBalancer" }

# Step 5: Check existing ingress resources
Write-Host "`n5. Existing ingress resources..." -ForegroundColor Green
kubectl get ingress --all-namespaces -o wide

# Step 6: Check NSG rules for AKS subnet
Write-Host "`n6. Checking NSG rules for AKS subnet..." -ForegroundColor Green
$aksDetails = az aks show --name $AksName --resource-group $ResourceGroup -o json | ConvertFrom-Json
$aksSubnetId = $aksDetails.agentPoolProfiles[0].vnetSubnetId

if ($aksSubnetId) {
    $subnetDetails = az network vnet subnet show --ids $aksSubnetId -o json | ConvertFrom-Json
    $nsgId = $subnetDetails.networkSecurityGroup.id
    
    if ($nsgId) {
        $nsgName = $nsgId.Split('/')[-1]
        $nsgResourceGroup = $nsgId.Split('/')[4]
        
        Write-Host "   NSG Name: $nsgName" -ForegroundColor Yellow
        Write-Host "   NSG Resource Group: $nsgResourceGroup" -ForegroundColor Yellow
        
        Write-Host "`n   Inbound rules allowing HTTP/HTTPS:" -ForegroundColor Cyan
        az network nsg rule list --nsg-name $nsgName --resource-group $nsgResourceGroup --query "[?direction=='Inbound' && (destinationPortRange=='80' || destinationPortRange=='443' || destinationPortRange=='*')].{Name:name, Priority:priority, Source:sourceAddressPrefix, DestPort:destinationPortRange, Access:access}" -o table
    } else {
        Write-Host "   ❌ No NSG associated with AKS subnet" -ForegroundColor Red
    }
} else {
    Write-Host "   ❌ Could not determine AKS subnet" -ForegroundColor Red
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Analysis Complete" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

Write-Host "`nRecommendations:" -ForegroundColor Yellow
Write-Host "• If no ingress controller is found, install one:" -ForegroundColor White
Write-Host "  - AGIC (recommended): az aks enable-addons --addons ingress-appgw" -ForegroundColor White
Write-Host "  - NGINX: helm install ingress-nginx ingress-nginx/ingress-nginx" -ForegroundColor White
Write-Host "• Ensure NSG allows inbound traffic on ports 80/443" -ForegroundColor White
Write-Host "• Create ingress resources to route traffic to your services" -ForegroundColor White