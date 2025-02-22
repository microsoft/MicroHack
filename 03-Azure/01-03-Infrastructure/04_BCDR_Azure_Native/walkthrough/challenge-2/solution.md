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

Navigate to the **Backup** Tab and proceed with **Backup now**

![image](./img/040.png)

Backup Job is started

![image](./img/031.png)

Here can be seen what has been done by a Backup Job?
**Take Snapshot** and **Transfer data to vault**

![progress](./img/032.png)

### Wait for initial Backup of the VM

This might take a while

![completed](./img/033.png)

![backup](./img/034.png)

## Create a new Custom Policy

Go to the Backup Vault in the Primary Region (Germany West Central)

![image](./img/041.png)

Add a new Backup Policy

![Add Policy](./img/042.png)

Add a new Backup Policy for Disks

![Policy for Disks](./img/043.png)

### Schedule daily backups

Configure daily backup frequency

![image](./img/044.png)


### Review additional Deployment Options
-   Hourly Backup Schedule Optional

![image](./img/mh-ch2-screenshot-22.png)

Review the configuration 
* Backup Schedule
* Backup Retention settings
and proceed with **Create**

![Review + Create](./img/045.png)

Backup Policy is successfuly created!

![image](./img/043d.png)

The steps for the Data Science Virtual Machine are similar to this and will not be included here.

[Microsoft Learn - Azure Cross-region replication](https://learn.microsoft.com/en-us/azure/reliability/cross-region-replication-azure#cross-region-replication)

### Task 2: Enable Azure backup for blobs
Go to the Storage Account in the Primary Region
![Storage Account](./img/050.png)

<details close>
<summary>💡 Task 2: Enable Azure backup for blobs</summary>
<br>

<details close>

<summary>💡 How-to: Create a backup vault (if could not be create while the lab environment setup)</summary>
<br>

### Create a backup vault (not a recovery service vault)
![image](./img/mh-ch2-screenshot-71.png)

</details>


<details close>
<summary>💡 How-to: Create a container</summary>
<br>

![image](./img/019.png)
![image](./img/019a.png)
![image](./img/019b.png)
![image](./img/020.png)

</details>

To backup our storage account, we should assign the Backup Vault in Primary Region some access permissions.

### Enable system managed Identity for the backup vault and clipboard the MI object ID
Go to the Backup Vault in the Primary Region (Germany West Central) and navigate to the Identity Tab

![Identity Tab](./img/060.png)

Click **Azure role assignments**

![Enable system managed Identity](./img/060a.png)

### Assign the "Storage Backup Contributor" role to Backup vault managed identity
Go back to the Storage Account the Primary Region (Germany West Central). Navigate to **Access Control (IAM)** Tab and add a role assignment.

![image](./img/061.png)

Select Role

![Backup Contributor](./img/062.png)

Select Scope

![MI](./img/063.png)

Select Managed Identity of the Backup Vault

![Backup Vault MI](./img/064.png)

Review + Assign

![Review + Assign](./img/065.png)

### Enable Azure Backup for Blobs.

This will require to create a new backup policy:

![Create new policy](./img/051.png)
![Select Vault](./img/052.png)
![Create](./img/054.png)

![policy configured](./img/019c.png)

Backup Policy for storage successfully created!
![Create](./img/055.png)

</details>

### Task 3: Restore a VM in Azure

### Start Restore Procedure
![image](./img/035.png)

### Select restore Point
![image](./img/036.png)

### Set Restore Properties

Proceed with **Restore**

![image](./img/037.png)

![image](./img/039.png)

You successfully completed challenge 2! 🚀🚀🚀

There is a new Virtual Machine `mh-linux-restore` in the resource group, which is restored from the backup.
![image](./img/070.png)
