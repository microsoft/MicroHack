


### For Azure Resources

* [Create Resource Group](https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/manage-resource-groups-portal#create-resource-groups)

* [Create Service Principal](https://learn.microsoft.com/en-us/azure/azure-arc/servers/onboard-service-principal#create-a-service-principal-for-onboarding-at-scale)

* Enable Azure Resource Provider 
  [Azure Arc Azure resource providers](https://learn.microsoft.com/en-us/azure/azure-arc/servers/prerequisites#azure-resource-providers)

### For Arc enabled Servers

* Have a server, windows or linux ready
For windows, pls use if possible Windows Server 2019 or 2022 with the latest patch level

  [Supported operating systems @ Connected Machine agent prerequisites - Azure Arc | Microsoft Docs](https://docs.microsoft.com/en-us/azure/azure-arc/servers/prerequisites#supported-operating-systems)
	
  This Server OS could be hosted as a VM on VMware, Hyper-V, Nutanix, AWS, GCP or bare metal.
	
#### Additional:
  * These servers should be able to reach the internet and Azure.
  * You need to have full access and admin or root permissions on these Server OS

* If you need to install and deploy your own server OS from scratch, then, download the following ISO files and save them on your own PC / Environment with your preferred Hypervisor e.g. Hyper-V or Virtualization Client (Windows 10/11 Hyper-V or Virtual Box).
  * [Ubuntu](https://ubuntu.com/download)
  * [Windows Server 2022](https://www.microsoft.com/en-us/evalcenter/download-windows-server-2022)

* Install from the downloaded ISO your preferred OS. 

#### Using Azure Arc with Azure VMs
* In case you want to use an Azure VM for this MicroHack, you need to follow the guidance 
  * [Evaluate Azure Arc-enabled servers on an Azure virtual machine](https://learn.microsoft.com/en-us/azure/azure-arc/servers/plan-evaluate-on-azure-virtual-machine)

With these prerequisites in place, we can focus on building the differentiated knowledge in the hybrid world with Azure Arc to enable your on-prem, Multi-Cloud environment for the Cloud operations model.

