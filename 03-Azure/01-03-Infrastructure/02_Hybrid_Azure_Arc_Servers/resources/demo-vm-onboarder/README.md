# Overview
As a coach (or consultant) you might want to quickly prepare a demo environment for Azure arc-enabled servers. You can use the scripts provided in this folder to
- create multiple VMs in Azure to mimick your on-prem machines. They will be prepared by removing the Azure agent using the 'create_vms.sh' script from folder [demo-vm-creator](../demo-vm-creator/).
- automatically onboard all VMs of a given resource group in Azure to Azure Arc using ansible onboarding playbooks. The VMs must be stripped of the Azure agent and Windows machines must be configured for remote WinRM and network connection must be possible via WinRM port. If creating the machines with the demo-vm-creator folder, this will automatically be configured. 

You can either create and onboard in separate steps, or you can use the 'create-and-onboard.sh' script to to both steps in one script.

*Note: Per default, the demo-vm-cerator.sh creates 30 VMs distributed to different regions*

## Deployment instructions
Open a bash shell and login to Azure:
```shell
az login
```
Make sure you are using the subscription you intent to (if not, set it to the correct subscription: ```az account set -s <your-subscription-guid>```).

Open the file ```arc-enable-vms.sh``` in an editor and adjust the parameters as needed.

|Parameter        |Description    |Default value    |
|-----------------           |---------------|------------|
|resourceGroupforOnprem      |The name of the resource group where the VMs are located which shall be onboarded to Azure arc     |mh-arc-onprem|
|resourceGroupforArc         |Name of resource group where the arc resources will get onboarded to. Will be created if not exists. |mh-arc-cloud|
|adminUsername          |local admin/root account in your VMs (same for all machines)|mhadmin|
|adminPassword          |local admin/root password (same for all machines). Use a password which honors complexity rules for Windows & Ubuntu|REPLACE-ME|
|arcRegion |the region to which vms will be onboarded | westeurope |
|triggerPolicyEvaluation                |If you onboard VMs to an environement where Azure Policies are used to install arc extensions such as Monitoring etc. you can set this to 'true' so the policy evaluation gets triggered after onboarding | true |

Save the file. Make sure the all shell scripts have execution permission in your directory (if not add it i.e.: ```chmod +x create_vms.sh```).

If you want to just onboard existing VMs, execute 
```shell
./arc-enable-vms.sh
```

If you want to create onprem-mimick VMs in Azure and afterwards onboard them, execute:
```shell
./create-and-onboard.sh
```

