# Overview
As a coach (or participant) you might need to have some VMs available which you can use in this microhack to onboard via Arc to Azure. This folder provides scripts and templates to quickly create such VMs and resource groups. As deployment platform Azure IaaS will be used. Azure VMs need to be [reconfigured](https://learn.microsoft.com/en-us/azure/azure-arc/servers/plan-evaluate-on-azure-virtual-machine) in order to simulate on-prem VMs, so that the Azure Guest agent does not interfere with the Azure Arc agent. The scripts to reconfigure this are included in the ```create-vms-and-rgs.sh```. 

For each participant, you will need one Windows 2012 R2, one Windows 2025 and one Linux VM. You can provide the number of participants in the script. The script will then create 1 Windows 2012 R2, 1 Windows 2025 and 1 Ubuntu 24_04-lts-gen2 VM for each participant. The VMs will be created in one individual resource group per particpant. Additionally, the script creates another resource group for each participant to deploy their arc resources during the MicroHack.

## Deployment instructions
Open a bash shell and login to Azure:
```shell
az login
```
Make sure you are using the subscription you intent to (if not, set it to the correct subscription: ```az account set -s <your-subscription-guid>```).

Now that you're ready to deploy, the next steps are to create the VMs, resource groups, and users, and then assign each user to their respective resource groups. Each participant will receive one on-prem and one Arc resource group. This is done using two scripts: ```create-vms-and-rgs.sh``` and ```assign-users.sh```. You can run them individually as described below, or simply use ```create-and-assign.sh``` to execute both in sequence. Just make sure to run ```create-vms-and-rgs.sh``` **before** ```assign-users.sh```. Follow the instructions to adjust the parameters and make the files executable:

Open the file ```create-vms-and-rgs.sh``` in an editor and adjust the parameters as needed.

|Parameter        |Description    |Default value    |
|-----------------      |---------------|------------|
|resourceGroupforOnpremBase      |The base name of the resource groups the VMs willl get deployed to. Will be created if it does not exist|mh-arc-onprem- + ID|
|resourceGroupforOnpremLocation  |Azure region where your resource groups for the VMs will be created in|germanywestcentral|
|resourceGroupforArcBase      |The base name of the empty resource groups that are created for arc resources. Will be created if it does not exist|mh-arc-cloud- + ID|
|resourceGroupforArcLocation  |Azure region where your resource groups for the arc resources be created in|westeurope|
|adminUsername          |local admin/root account in your VMs (will be the same for all machines)|mhadmin|
|adminPassword          |local admin/root password (will be the same for all machines). Use a password which honors complexity rules for Windows & Ubuntu|Pick a safe one|
|number_of_participants |Adjust this to the number of participants in your cohort. For each particpants 2 VMs are created|10|
|regions                |An array of regions to which you want to deploy. If using a Sponsored subscription, you might have core limits per region. If providing more than one region in the array, the script will iterate through the regions and distribute the VMs evenly to the named regions. 2 Win and 1 Linux VM will be deployed to a region before moving on in the iteration|("germanywestcentral" "swedencentral" "francecentral")|
|virtualMachineSize     |You can adjust the VM size if needed|Standard_D2ads_v5|

Save the file. Make sure the shell script has execution permission in your directory (if not add it: ```chmod +x create-vms-and-rgs.sh```). Now, execute the shell script
```shell
./create_vms-and-rgs.sh
```

Afterward creating the VMs and resource groups, you can create the users assign them to the resource groups with ```assign-users.sh``` script. First, open the file ```assign-users.sh``` in an editor and adjust the parameters as needed. Make sure the match your values for resource group names and number of participants defined in ```create-vms-and-rgs.sh```.

|Parameter        |Description    |Default value    |
|-----------------      |---------------|------------|
|resourceGroupforOnpremBase      |The base name of the resource groups the VMs willl get deployed to. Will be created if it does not exist. Must match the base name in create-vms-and-rgs.sh |mh-arc-onprem- + ID|
|resourceGroupforArcBase      |The base name of the empty resource groups that are created for arc resources. Will be created if it does not exist. Must match the base name in create-vms-and-rgs.sh |mh-arc-cloud- + ID|
|password | Microsoft Entra password of all users, used for logging into the Azure Portal.  | Pick a safe one that fulfills the complexity requirements|
|number_of_participants |Adjust this to the number of participants in your cohort. Must match the number of participants in create-vms-and-rgs.sh. |10|

Save the file. Make sure the shell script has execution permission in your directory (if not add it: ```chmod +x assign-users.sh```). Now, execute the shell script
```shell
./assign-users.sh.sh
```