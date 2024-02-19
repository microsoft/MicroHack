az group create --name "rg-onpremvms" --location "swedencentral"


# Loop to create 5 Windows VMs in GWC
for i in {1..5}
do
    # Define unique names for resource group and VM
    resourceGroupLocation="germanywestcentral"
    adminUsername="MHAdmin"
    adminPassword="REPLACEME"
    myResourceGroup="rg-onpremvms"
    
    resourceGroupName="rg-onpremvms"
    vmName="vm-win-mh$i"
    networkInterfaceName="vm-win-mh$i"
    publicIpAddressName="pip-win-mh$i"
    networkSecurityGroupName="nsg-win-mh$i"
    virtualNetworkName="vnet-win-mh$i"
    virtualMachineComputerName=$vmName
    virtualMachineRG=$resourceGroupName
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

    az vm run-command create --name reconfigWin$i --vm-name $vmName -g $resourceGroupName --location $resourceGroupLocation --script @reconfig-win.ps1 --async-execution
done

# Loop to create 5 Windows VMs in NEU
for i in {6..10}
do
   
    # Define unique names for resource group and VM
    resourceGroupLocation="northeurope"
    adminUsername="MHAdmin"
    adminPassword="REPLACEME"
    myResourceGroup="rg-onpremvms"
    
    resourceGroupName="rg-onpremvms"
    vmName="vm-win-mh$i"
    networkInterfaceName="vm-win-mh$i"
    publicIpAddressName="pip-win-mh$i"
    networkSecurityGroupName="nsg-win-mh$i"
    virtualNetworkName="vnet-win-mh$i"
    virtualMachineComputerName=$vmName
    virtualMachineRG=$resourceGroupName
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

    az vm run-command create --name reconfigWin$i --vm-name $vmName -g $resourceGroupName --location $resourceGroupLocation --script @reconfig-win.ps1 --async-execution
done


# Loop to create 5 Linux VMs in Sweden Central
for i in {1..5}
do
    # Define unique names for resource group and VM
    resourceGroupLocation="swedencentral"
    adminUsername="MHAdmin"
    adminPassword="REPLACEME"
    myResourceGroup="rg-onpremmachines"
    
    resourceGroupName="rg-onpremvms"
    vmName="vm-lnx-mh$i"
    networkInterfaceName="vm-lnx-mh$i"
    publicIpAddressName="pip-lnx-mh$i"
    networkSecurityGroupName="nsg-lnx-mh$i"
    virtualNetworkName="vnet-lnx-mh$i"
    virtualMachineComputerName=$vmName
    virtualMachineRG=$resourceGroupName
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

    az vm run-command invoke -g $resourceGroupName -n $vmName --command-id RunShellScript --scripts @reconfig-ubuntu.sh --no-wait
done


# Loop to create 5 Linux VMs in France Central
for i in {6..10}
do
    # Define unique names for resource group and VM
    resourceGroupLocation="francecentral"
    adminUsername="MHAdmin"
    adminPassword="REPLACEME"
    myResourceGroup="rg-onpremmachines"
    
    resourceGroupName="rg-onpremvms"
    vmName="vm-lnx-mh$i"
    networkInterfaceName="vm-lnx-mh$i"
    publicIpAddressName="pip-lnx-mh$i"
    networkSecurityGroupName="nsg-lnx-mh$i"
    virtualNetworkName="vnet-lnx-mh$i"
    virtualMachineComputerName=$vmName
    virtualMachineRG=$resourceGroupName
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

    az vm run-command invoke -g $resourceGroupName -n $vmName --command-id RunShellScript --scripts @reconfig-ubuntu.sh --no-wait
done