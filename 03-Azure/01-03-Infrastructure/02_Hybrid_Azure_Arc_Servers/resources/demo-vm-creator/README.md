# Overview
As a coach (or participant) you might need to have some VMs available which you can use in this microhack to onboard via Arc to Azure. This folder provides scripts and templates to quickly create such VMs. As deployment platform Azure IaaS will be used. Azure VMs need to be [reconfigured](https://learn.microsoft.com/en-us/azure/azure-arc/servers/plan-evaluate-on-azure-virtual-machine) in order to simulate on-prem VMs, so that the Azure Guest agent does not interfere with the Azure Arc agent. The scripts to reconfigure this are included in the ```create_vms.sh```. 

For each participant, you will need one Windows 2012 R2, one Windows 2025 and one Linux VM. You can provide the number of participants in the script. The script will then create 1 Windows 2012 R2, 1 Windows 2025 and 1 Ubuntu 24_04-lts-gen2 VM for each participant. 

## Deployment instructions
Open a bash shell and login to Azure:
```shell
az login
```
Make sure you are using the subscription you intent to (if not, set it to the correct subscription: ```az account set -s <your-subscription-guid>```).

Open the file ```create_vms.sh``` in an editor and adjust the parameters as needed.

|Parameter        |Description    |Default value    |
|-----------------      |---------------|------------|
|resourceGroupName      |The name of the resource group the VMs willl get deployed to. Will be created if not existing|rg-on-prem-vms|
|resourceGroupLocation  |Azure region where your resource group will be created in|germanywestcentral|
|adminUsername          |local admin/root account in your VMs (will be the same for all machines)|mhadmin|
|adminPassword          |local admin/root password (will be the same for all machines). Use a password which honors complexity rules for Windows & Ubuntu|SecretP@$$W0rd|
|number_of_participants |Adjust this to the number of participants in your cohort. For each particpants 2 VMs are created|10|
|regions                |An array of regions to which you want to deploy. If using a Sponsored subscription, you might have core limits per region. If providing more than one region in the array, the script will iterate through the regions and distribute the VMs evenly to the named regions. 1 Win and 1 Linux VM will be deployed to a region before moving on in the iteration|("germanywestcentral" "northeurope" "swedencentral" "francecentral" "westeurope")|
|virtualMachineSize     |You can adjust the VM size if needed|Standard_D2ads_v5|

Save the file. Make sure the shell script has execution permission in your directory (if not add it: ```chmod +x create_vms.sh```). Now, execute the shell script
```shell
./create_vms.sh
```

