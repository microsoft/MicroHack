az account set -s sub-mhodaa
$adbInstances = az oracle-database autonomous-database list --query "[].{name:name, resourceGroup:resourceGroup, id:id, provisioningState:properties.provisioningState, lifecycleState:properties.lifecycleState}" -o json | ConvertFrom-Json

# Delete ADB instances
foreach ($Instance in $adbInstances) {
    Write-Host "Deleting ADB instance: $($Instance.name) (this may take several minutes)..." -ForegroundColor Cyan
    Write-Host "Running: az oracle-database autonomous-database delete --name $($Instance.name) --resource-group $($Instance.resourceGroup) --yes" -ForegroundColor Gray
    $deleteResult = az oracle-database autonomous-database delete --name $Instance.name --resource-group $Instance.resourceGroup --yes --verbose 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Successfully deleted $($Instance.name)" -ForegroundColor Green
    } else {
        Write-Host "Failed to delete $($Instance.name): $deleteResult" -ForegroundColor Red
    }
}

$compartmentId = "ocid1.compartment.oc1..aaaaaaaayehuog6myqxudqejx3ddy6bzkr2f3dnjuuygs424taimn4av4wbq"

# Delete all subnets in the VCNs first
Write-Host "`nDeleting subnets..." -ForegroundColor Cyan
$subnets = oci network subnet list --compartment-id $compartmentId --all --query "data[].id" 2>$null | ConvertFrom-Json
foreach ($subnetId in $subnets) {
    Write-Host "Deleting Subnet: $subnetId"
    oci network subnet delete --subnet-id $subnetId --force --wait-for-state TERMINATED 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Successfully deleted subnet" -ForegroundColor Green
    } else {
        Write-Host "Failed to delete subnet (may be in use)" -ForegroundColor Yellow
    }
}

# Delete all NSGs in a compartment
Write-Host "`nDeleting Network Security Groups..." -ForegroundColor Cyan
$nsgs = oci network nsg list --compartment-id $compartmentId --all --query "data[].id" 2>$null | ConvertFrom-Json
foreach ($nsgId in $nsgs) {
    Write-Host "Deleting NSG: $nsgId"
    oci network nsg delete --nsg-id $nsgId --force --wait-for-state TERMINATED 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Successfully deleted NSG" -ForegroundColor Green
    } else {
        Write-Host "Failed to delete NSG (may still have VNICs attached)" -ForegroundColor Yellow
    }
}

# Delete all VCNs in a compartment
Write-Host "`nDeleting VCNs..." -ForegroundColor Cyan
$vcns = oci network vcn list --compartment-id $compartmentId --all --query "data[].id" 2>$null | ConvertFrom-Json
foreach ($vcnId in $vcns) {
    Write-Host "Deleting VCN: $vcnId"
    oci network vcn delete --vcn-id $vcnId --force --wait-for-state TERMINATED 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Successfully deleted VCN" -ForegroundColor Green
    } else {
        Write-Host "Failed to delete VCN (may still have dependencies)" -ForegroundColor Yellow
    }
}

Write-Host "`nCleanup complete!" -ForegroundColor Green    
