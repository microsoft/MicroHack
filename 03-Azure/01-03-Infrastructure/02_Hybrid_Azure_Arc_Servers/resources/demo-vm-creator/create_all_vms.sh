resourceGroupLocation="francecentral"
myResourceGroup="rg-onpremvms"
az group create --name $resourceGroupName --location $resourceGroupLocation
az group create --name "rg-onpremvms" --location "francecentral"
# Loop to create 10 Windows VMs
for i in {1..10}
do
    # Define unique names for resource group and VM
    resourceGroupLocation="francecentral"
    adminUsername="MHAdmin"
    adminPassword=""
    myResourceGroup="rg-onpremvms"
    
    resourceGroupName="rg-onpremvms"
    vmName="vm-win-mh$i"
    networkInterfaceName="vm-win-mh$i"
    publicIpAddressName="pip-win-mh$i"
    networkSecurityGroupName="nsg-win-mh$i"
    virtualNetworkName="vnet-win-mh$i"
    virtualMachineComputerName=vmName
    virtualMachineRG=resourceGroupName
    virtualMachineSize="Standard_D2ads_v5"
    deploymentName="MHWinDeploy$1"
    # Define parameters


    # Create a resource group
    # az group create --name $resourceGroupName --location $resourceGroupLocation

    # Create a VM
    az deployment group create \
    --resource-group $resourceGroupName \
    --name $deploymentName \
    --template-file ./template-win.json \
    --parameters @parameters-win.json \
    --parameters virtualMachineName=$vmName adminUsername=$adminUsername adminPassword=$adminPassword networkInterfaceName=$networkInterfaceName publicIpAddressName=$publicIpAddressName networkSecurityGroupName=$networkSecurityGroupName virtualNetworkName=$virtualNetworkName virtualMachineComputerName=$virtualMachineComputerName virtualMachineRG=$virtualMachineRG virtualMachineSize=$virtualMachineSize location=$resourceGroupLocation
done


# Loop to create 10 Linux VMs
for i in {1..10}
do
    # Define unique names for resource group and VM
    resourceGroupLocation="francecentral"
    adminUsername="MHAdmin"
    adminPassword=""
    myResourceGroup="rg-onpremmachines"
    
    resourceGroupName="rg-onpremvms"
    vmName="vm-lnx-mh$i"
    networkInterfaceName="vm-lnx-mh$i"
    publicIpAddressName="pip-lnx-mh$i"
    networkSecurityGroupName="nsg-lnx-mh$i"
    virtualNetworkName="vnet-lnx-mh$i"
    virtualMachineComputerName=vmName
    virtualMachineRG=resourceGroupName
    virtualMachineSize="Standard_D2ads_v5"
    deploymentName="MHLnxDeploy$1"
    # Define parameters


    # Create a resource group
    # az group create --name $resourceGroupName --location $resourceGroupLocation

    # Create a VM
    az deployment group create \
    --resource-group $resourceGroupName \
    --name $deploymentName \
    --template-file ./template-lnx.json \
    --parameters @parameters-lnx.json \
    --parameters virtualMachineName=$vmName adminUsername=$adminUsername adminPassword=$adminPassword networkInterfaceName=$networkInterfaceName publicIpAddressName=$publicIpAddressName networkSecurityGroupName=$networkSecurityGroupName virtualNetworkName=$virtualNetworkName virtualMachineComputerName=$virtualMachineComputerName virtualMachineRG=$virtualMachineRG virtualMachineSize=$virtualMachineSize location=$resourceGroupLocation
done

