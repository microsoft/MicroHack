# adjust parameters with your own values as needed
resourceGroupName="rg-on-prem"
resourceGroupLocation="germanywestcentral"
adminUsername="mhadmin"
adminPassword="REPLACE-ME"
    
# in a sponsored subscription there is a core limit of 10 cores per VM-series per region. Therefore, the script will distribute the VMs to different regions
# assuming you stick to the Standard_D2ads_v5 for Windows and Standard_DS1_v2 for Linux, max 4 Win and 2 Linux VMs per region can be deployed. As each participant should have two windows and one linux machine,
# we are deploying always 3 VMs (1 linux and 2 windows) per user. This means we can fit 2 participants into one region. So make your that you add enough regions
# to the regions array to fit all participants.

number_of_participants=10
regions=("germanywestcentral" "northeurope" "swedencentral" "francecentral" "westeurope")
virtualWinMachineSize="Standard_D2ds_v4" # use a vm size with only 2 cores to avoid core limit issues in sponsored subscriptions
virtualLnxMachineSize="Standard_DS1_v2" # use a vm size with only 1 core to avoid core limit issues in sponsored subscriptions

# create a resource group
az group create --name $resourceGroupName --location $resourceGroupLocation
number_of_regions=${#regions[@]}
echo "Number of regions: $number_of_regions"
number_of_loops=$((number_of_participants * 3 - 1 ))
echo "Number of loops: $number_of_loops"
    
for j in $(eval echo {0..$number_of_loops})
do
    # i++ for every third iteration, so we have win2012-0, win2025-0 and linux-0 in the same region
    i=$(($j / 3))
    region_index=$((i % number_of_regions))
    location=${regions[($i % $number_of_regions)]}
    
    # every loop we switch between creating a linux, windows2012 and a windows2025 VM
    if (( $j % 3 == 0 )); then
        type="linux"   
        virtualMachineSize=$virtualLnxMachineSize
    elif (( $j % 3 == 1 )); then
        type="win2012"
        virtualMachineSize=$virtualWinMachineSize
    else
        type="win2025"
        virtualMachineSize=$virtualWinMachineSize
    fi

    vmName="vm-$type-mh$i"
    echo "Creating VM $vmName in $location"

    networkInterfaceName="$vmName-nic"
    publicIpAddressName="$vmName-pip"
    networkSecurityGroupName="$vmName-nsg"
    virtualNetworkName="$vmName-vnet"
    virtualMachineComputerName=$vmName
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
    if [ $type != "linux" ]; then
        echo "Running reconfig-win.ps1 on $vmName"
        az vm run-command create --name reconfigWin$i --vm-name $vmName -g $resourceGroupName --location $location --script @reconfig-win.ps1 --async-execution
    else
        echo "Running reconfig-ubuntu.sh on $vmName"
        az vm run-command invoke -g $resourceGroupName -n $vmName --command-id RunShellScript --scripts @reconfig-ubuntu.sh --no-wait
    fi

done
