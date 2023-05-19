# Walkthrough Challenge 2 - Protect in Azure - Backup/Restore

Duration: 30 minutes

[Previous Challenge Solution](../challenge-1/solution.md) - **[Home](../../Readme.md)** - [Next Challenge Solution](../challenge-3/solution.md)

## Prerequisites

Please ensure that you successfully passed [challenge 1](../../Readme.md#challenge-1) before continuing with this challenge.

In this challenge you will learn how to setup Azure Backup to Protect a Virtual Machine in Azure. In addition we will have a look on the configuration and necessary Backup Policies that are available.

Actions:

- Deploy a Windows Server 2022 VM in West Europe Resource Group
- Deploy a Ubuntu Server VM in North Europe Resource Group
- Enable Azure Backup for both VMs
- Restore a VM in Azure


### Task 1: Create a new Virtual Machine in Azure Region Western Europe

As a first step, we will create a VM (Name: server01) in Azure in the resource group "mh-bcdr-weu-rg" that we created in the last challenge. This should be a Windows Server 2022 (Azure Edition) using a VM Type of Standard DS1v2. 

### Choose OS
![image](./img/mh-ch2-screenshot-01.png)

### Configure Details
![image](./img/mh-ch2-screenshot-02.png)

### Configure Details (part 2)
![image](./img/mh-ch2-screenshot-02.png)

Please don't forget to put the VM into the public network and open up Port 3389 to connect to it (or alternatively use Azure Bastion to access it). 
### Enable RDP Port
![image](./img/mh-ch2-screenshot-03.png)

### Review deployed VM
![image](./img/mh-ch2-screenshot-09.png)

### Task 2: Deploy a Ubuntu Server VM in Norh Europe Resource Group
The steps for the Ubunutu Server VM are similar to this and will not be included here.

### Task 3: Enable Azure Backup for both VMs

### Enable Azure Backup
![image](./img/mh-ch2-screenshot-10.png)

### Create a new Custom Policy
![image](./img/mh-ch2-screenshot-11.png)
![image](./img/mh-ch2-screenshot-12.png)
![image](./img/mh-ch2-screenshot-22.png)

### Review additional Deployment Options
![image](./img/mh-ch2-screenshot-18.png)

### Review additional Deployment Options
![image](./img/mh-ch2-screenshot-25.png)

### Wait for intial Backup of the VM
![image](./img/mh-ch2-screenshot-18.png)


The steps for the Ubuntu Server VM are similar to this and will not be included here.

### Task 4: Restore a VM in Azure

### Start Restore Procedure
![image](./img/mh-ch2-screenshot-29.png)

### Select restore Point
![image](./img/mh-ch2-screenshot-30.png)

### Set Restore Properties
![image](./img/mh-ch2-screenshot-31.png)

You successfully completed challenge 3! 🚀🚀🚀
