# adjust parameters with your own values as needed
resourceGroupName="rg-on-prem"
resourceGroupLocation="germanywestcentral"
adminUsername="MHAdmin"
adminPassword="REPLACEME"
    
# in a sponsored subscription there is a core limit of 10 cores per VM-series per region. Therefore, the script will distribute the VMs to different regions
# assuming you stick to the Standard_D2ads_v5, max 5 VMs per region can be deployed. As each participant should have one windows and one linux machine,
# we are deploying always 2 VMs (1 linux and 1 windows) per user. This means we can fit 2 participants into one region. So make your that you add enough regions
# to the regions array to fit all participants.

number_of_participants=10
regions=("germanywestcentral" "northeurope" "swedencentral" "francecentral" "westeurope")


# create a resource group
az group create --name $resourceGroupName --location $resourceGroupLocation
number_of_regions=${#regions[@]}
echo "Number of regions: $number_of_regions"
number_of_loops=$((number_of_participants * 2 - 1 ))
echo "Number of loops: $number_of_loops"
    
for j in $(eval echo {0..$number_of_loops})
do
    # i++ for every second iteration, so we have win-0 and lnx-0 in the same region
    i=$(($j / 2))
    region_index=$((i % number_of_regions))
    location=${regions[($i % $number_of_regions)]}
    
    # every loop we switch between creating a linux and a windows VM
    if (( $j % 2 == 0 )); then
        type="lnx"   
    else
        type="win"
    fi

    vmName="vm-$type-mh$i"
    echo "Creating VM $vmName in $location"

    networkInterfaceName="$vmName-nic"
    publicIpAddressName="$vmName-pip"
    networkSecurityGroupName="$vmName-nsg"
    virtualNetworkName="$vmName-vnet"
    virtualMachineComputerName=$vmName
    virtualMachineSize="Standard_D2ads_v5"
    deploymentName="$vmName-Deploy"
    
    # Create a VM
    az deployment group create \
    --resource-group $resourceGroupName \
    --name $deploymentName \
    --template-file ./template-$type.json \
    --parameters @parameters-$type.json \
    --parameters virtualMachineName=$vmName \
        adminUsername=$adminUsername \
        adminPassword=$adminPassword \
        networkInterfaceName=$networkInterfaceName \
        publicIpAddressName=$publicIpAddressName \
        networkSecurityGroupName=$networkSecurityGroupName \
        virtualNetworkName=$virtualNetworkName \
        virtualMachineComputerName=$virtualMachineComputerName \
        virtualMachineRG=$resourceGroupName \
        virtualMachineSize=$virtualMachineSize \
        location=$location

    # Run the reconfig script to disable the Azure Guest Agent
    if [ $type == "win" ]; then
        az vm run-command create --name reconfigWin$i --vm-name $vmName -g $resourceGroupName --location $location --script @reconfig-win.ps1 --async-execution
    else
        az vm run-command invoke -g $resourceGroupName -n $vmName --command-id RunShellScript --scripts @reconfig-ubuntu.sh --no-wait
    fi

done