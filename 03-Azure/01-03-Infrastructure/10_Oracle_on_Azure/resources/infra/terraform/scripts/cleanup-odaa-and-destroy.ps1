az account set -s sub-mhodaa
$adbInstances = az oracle-database autonomous-database list --query "[].{name:name, resourceGroup:resourceGroup, id:id, provisioningState:properties.provisioningState, lifecycleState:properties.lifecycleState}" -o json | ConvertFrom-Json
Write-Log "Deleting ADB instance: $($Instance.name) (this may take several minutes)..."
Write-Log "Running: az oracle-database autonomous-database delete --name $($Instance.name) --resource-group $($Instance.resourceGroup) --yes"
$deleteResult = az oracle-database autonomous-database delete --name $Instance.name --resource-group $Instance.resourceGroup --yes --verbose 2>&1

$compartmentId = "ocid1.compartment.oc1..aaaaaaaayehuog6myqxudqejx3ddy6bzkr2f3dnjuuygs424taimn4av4wbq"
# delete all nsg in a compartment
$nsgs = oci network nsg list --compartment-id $compartmentId --all --query "data[].id" | ConvertFrom-Json
foreach ($nsgId in $nsgs) {
    Write-Host "Deleting NSG: $nsgId"
    oci network nsg delete --nsg-id $nsgId --force
}

# delete all VCNs in a compartment
$vcns = oci network vcn list --compartment-id $compartmentId --all --query "data[].id" | ConvertFrom-Json
foreach ($vcnId in $vcns) {
    Write-Host "Deleting VCN: $vcnId"
    oci network vcn delete --vcn-id $vcnId --force
}    
