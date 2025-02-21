# Walkthrough Challenge 2 - Regional Protection and Disaster Recovery (DR)

⏰ Duration: 1 Hour

📋  [Challenge 2 Instructions](../../challenges/02_challenge.md)

⬅️ [Previous Challenge Solution](../challenge-1/solution.md) - **[Home](../../Readme.md)** - [Next Challenge Solution](../challenge-3/solution.md) ➡️

## Prerequisites

Please ensure that you successfully passed [challenge 1](../../Readme.md#challenge-1) before continuing with this challenge.

In this challenge, you will successfully onboard your Linux Virtual Machine to a centralized Recovery Services Vault and leverage Azure Backup Center to Protect with Backup in Azure. 

* Task 1: Enable Azure Backup for Linux VM.
* Task 2: Enable Azure Backup for Blobs
* Task 3: Restore a VM in Azure.

If you have not created the Linux Machine Successfully follow this guide to create it on the portal

<details close>
<summary>💡 How-to: Deploy a Ubuntu Server VM in Azure Region Sweden Central</summary>
<br>

### Choose OS
![image](./img/006.png)
> **Note:** choose the source resource group

### Configure Details - Basics
![image](./img/007.png)
> **Note:** choose the source resource group

### Configure Details - Basics (option 2)
![image](./img/007a.png)

Please don't forget to put the VM into the public network and open up Port 3389 to connect to it (or alternatively use Azure Bastion to access it). 
### Enable RDP Port
![image](./img/008.png)

### Configure Details - Networking (option 2)
![image](./img/008a.png)

### Review deployed VM
![image](./img/009.png)
![image](./img/010.png)

</details>

### Task 1: Enable Azure Backup for Linux VM

### Enable Azure Backup
![image](./img/030.png)
![image](./img/36.png)

### Create a new Custom Policy
![image](./img/mh-ch2-screenshot-11.png)
![image](./img/mh-ch2-screenshot-12.png)
![image](./img/mh-ch2-screenshot-22.png)

### Review additional Deployment Options
![image](./img/mh-ch2-screenshot-25.png)

### Wait for intial Backup of the VM
![image](./img/31.png)
![image](./img/32.png)

The steps for the Ubuntu Server VM are similar to this and will not be included here.

![Microsoft Learn - Azure Cross-region replication](https://learn.microsoft.com/en-us/azure/reliability/cross-region-replication-azure#cross-region-replication)

### Task 2: Enable Azure backup for blobs

### Create a backup vault (not a recovery service vault)
![image](./img/mh-ch2-screenshot-71.png)

### Enable system managed Identity for the backup vault and clipboard the MI object ID
![image](./img/mh-ch2-screenshot-72.png)

### Assign the "Backup Contributor" role to Backup vault managed identity
![image](./img/mh-ch2-screenshot-73.png)
![image](./img/mh-ch2-screenshot-74.png)
![image](./img/mh-ch2-screenshot-75.png)

### Enable Azure Backup for Blobs. This will require to create a new backup policy.
![image](./img/mh-ch2-screenshot-76.png)
![image](./img/mh-ch2-screenshot-77.png)
![image](./img/mh-ch2-screenshot-78.png)
![image](./img/mh-ch2-screenshot-79.png)

### Task 3: Restore a VM in Azure

### Start Restore Procedure
![image](./img/35.png)

### Select restore Point
![image](./img/mh-ch2-screenshot-30.png)

### Set Restore Properties
![image](./img/mh-ch2-screenshot-31.png)


You successfully completed challenge 2! 🚀🚀🚀
