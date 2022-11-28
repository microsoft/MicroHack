# Walkthrough Challenge 1 - Azure Arc prerequisites & onboarding

Duration: 20 minutes

 **[Home](../../Readme.md)** - [Next Challenge Solution](../challenge-2/solution.md)

## Prerequisites

Please ensure that you successfully verified the [General prerequisits](../../Readme.md#general-prerequisites) before continuing with this challenge.

### Task 1: Create Azure Resource Group

Sign in to the [Azure Portal](https://portal.azure.com/).

* [Create Resource Group](https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/manage-resource-groups-portal#create-resource-groups)

### Task 2: Create Service Principal 

* [Create Service Principal](https://learn.microsoft.com/en-us/azure/azure-arc/servers/onboard-service-principal#create-a-service-principal-for-onboarding-at-scale)

### Task 3: Enable Service providers

* Enable Azure Resource Provider 
  [Azure Arc Azure resource providers](https://learn.microsoft.com/en-us/azure/azure-arc/servers/prerequisites#azure-resource-providers)

### Task 4: Prepare on-prem Server OS

* Have a server, windows or linux ready, perhaps on your own laptop/notebook 
* For windows, please use Windows Server 2019 or 2022 with the latest patch level. 💡 ATTENTION: Use Windows Update to apply the latest patch level!!

  [Supported operating systems @ Connected Machine agent prerequisites - Azure Arc | Microsoft Docs](https://docs.microsoft.com/en-us/azure/azure-arc/servers/prerequisites#supported-operating-systems)
	
  This Server OS could be hosted as a VM on VMware, Hyper-V, Nutanix, AWS, GCP or bare metal. We are focused on-prem. 
	
#### Additional:
  * These servers should be able to reach the internet and Azure.
  * You need to have full access and admin or root permissions on this Server OS.

* If you need to install and deploy your own server OS from scratch, then, download the following ISO files and save them on your own PC / Environment with your preferred Hypervisor e.g. Hyper-V or Virtualization Client (Windows 10/11 Hyper-V or Virtual Box).
  * [Ubuntu](https://ubuntu.com/download)
  * [Windows Server 2022](https://www.microsoft.com/en-us/evalcenter/download-windows-server-2022)

* Install from the downloaded ISO your preferred OS. 

#### Using Azure Arc with Azure VMs
* In case you want to use an Azure VM for this MicroHack, you need to follow the guidance 
  * [Evaluate Azure Arc-enabled servers on an Azure virtual machine](https://learn.microsoft.com/en-us/azure/azure-arc/servers/plan-evaluate-on-azure-virtual-machine)

With these prerequisites in place, we can focus on building the differentiated knowledge in the hybrid world with Azure Arc to enable your on-prem, Multi-Cloud environment for the Cloud operations model.

### Task 5: Onboard Windows Server OS to Azure Arc

* Onboard the recent installed or prepared Windows Server OS to Azure Arc, by using the documented steps
1. Generate the installation script from the Azure portal [Link](https://learn.microsoft.com/en-us/azure/azure-arc/servers/onboard-service-principal#generate-the-installation-script-from-the-azure-portal)
* Step by step
![image](./img/1.png)
![image](./img/2.png)
![image](./img/3.png)
![image](./img/4.png)
![image](./img/5.png)
![image](./img/6.png)
2. Add the passphrase for the service principal the downloaded script
![image](./img/7.png)
3. Login into the Server OS on-prem and run the script [Link](https://learn.microsoft.com/en-us/azure/azure-arc/servers/onboard-portal#install-with-the-scripted-method)

4. Check in the Azure portal that the Server OS is visible.

### Task 6: Onboard Linux Server OS to Azure Arc

* Onboard the recent installed or prepared Linux Server OS to Azure Arc, by using the documented steps or create a new VM based on the following steps
1. Create Hyper-V VM for Linux

* Step by step

![image](./img/8.png)
![image](./img/9.png)
![image](./img/10.png)
![image](./img/11.png)
![image](./img/12.png)
![image](./img/13.png)
* Select the downloaded ISO; here the download [link](https://ubuntu.com/download/server) for Ubuntu 22.04 ISO

![image](./img/14.png)
![image](./img/15.png)
![image](./img/16.png)
* Important step! Change the template for Secure Boot [Reference Link](https://www.thomasmaurer.ch/2018/06/how-to-install-ubuntu-in-a-hyper-v-generation-2-virtual-machine/)

2. Setup of Linux Ubuntu 22.04

![image](./img/17.png)
![image](./img/18.png)
![image](./img/19.png)
![image](./img/20.png)
![image](./img/21.png)
![image](./img/22.png)
![image](./img/23.png)
![image](./img/24.png)
![image](./img/25.png)
![image](./img/26.png)
* Select OpenSSH

![image](./img/27.png)

3. Generate the installation script from the Azure portal [Link](https://learn.microsoft.com/en-us/azure/azure-arc/servers/onboard-service-principal#generate-the-installation-script-from-the-azure-portal)

![image](./img/28.png)
![image](./img/29.png)
![image](./img/30.png)
![image](./img/31.png)
![image](./img/32.png)
4. Add the passphrase for the service principal the downloaded script
![image](./img/33.png)
5. Connect to Linux Server via PowerShell SSH [Link] (https://devblogs.microsoft.com/powershell/using-the-openssh-beta-in-windows-10-fall-creators-update-and-windows-server-1709/)
* Use the account and password from setup

![image](./img/34.png)
6. run the script [Link](https://learn.microsoft.com/en-us/azure/azure-arc/servers/onboard-portal#install-with-the-scripted-method)
* Copy step by step the script to the SSH console
7. Check in the Azure portal that the Server OS is visible.
![image](./img/35.png)

You successfully completed challenge 1! 🚀🚀🚀