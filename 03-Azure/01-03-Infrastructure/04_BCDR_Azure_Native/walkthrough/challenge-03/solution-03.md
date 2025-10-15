# Walkthrough Challenge 3 - Regional Protection and Disaster Recovery (DR)

[Previous Challenge Solution](../challenge-02/solution-02.md) - **[Home](../../Readme.md)** - [Next Challenge Solution](../challenge-04/solution-04.md)

⏰ Duration: 1 Hour


### Challenge 3.1 - Protect in Azure - Backup / Restore
In this challenge, you will onboard your Linux Virtual Machine to a centralized Recovery Services Vault and use Azure Backup Center to protect it with Azure Backup.

* Task 1: Enable Azure Backup for Linux VM.
* Task 2: Enable Azure Backup for Blobs.
* Task 3: Restore a VM in Azure.

If you have not created the Linux Machine successfully, follow this guide to create it on the portal:

<details>
<summary>💡 How-to: Deploy a Ubuntu Server VM in Azure Region Sweden Central</summary>
<br>

### Choose OS
![image](./img/006.png)
> **Note:** Choose the source resource group.

### Configure Details - Basics
![image](./img/007.png)
> **Note:** Choose the source resource group.

### Configure Details - Basics (Option 2)
![image](./img/007a.png)

Ensure the VM is in the public network and open Port 3389 to connect to it (or use Azure Bastion to access it).

### Enable RDP Port
![image](./img/008.png)

### Configure Details - Networking (Option 2)
![image](./img/008a.png)

### Review Deployed VM
![image](./img/009.png)
![image](./img/010.png)

</details>

### Task 1: Enable Azure Backup for Linux VM

#### Enable Azure Backup
![image](./img/030.png)

Navigate to the **Backup** tab and proceed with **Backup now**.

![image](./img/040.png)

Backup job is started.

![image](./img/031.png)

The backup job includes **Take Snapshot** and **Transfer data to vault**.

![progress](./img/032.png)

#### Wait for Initial Backup of the VM

This might take a while.

![completed](./img/033.png)
![backup](./img/034.png)

## Create a New Custom Policy

Go to the Azure Site Recovery **ASR Vault** in the Primary Region (Germany West Central).

![image](./img/041.png)

Add a new Backup Policy.

![Add Policy](./img/042.png)

Add a new Backup Policy for Azure Virtual Machines.

![Policy for Disks](./img/043.png)

### Schedule Daily Backups

Configure **daily** backup frequency.

![image](./img/044.png)

### Review Additional Deployment Options
- **Hourly** Backup Schedule (Optional)

![image](./img/mh-ch2-screenshot-22.png)

Review the configuration:
* Backup Schedule
* Backup Retention settings

Proceed with **Create**.

Backup Policy is successfully created!

![image](./img/045.png)

<!-- The steps for the Data Science Virtual Machine are similar and will not be included here. -->

### Task 2: Enable Azure Backup for Blobs

Go to the Storage Account in the Primary Region.

![Storage Account](./img/050.png)

<details>
<summary>💡 Task 2: Enable Azure Backup for Blobs</summary>
<br>

<details>
<summary>💡 How-to: Create a Backup Vault (if not created during lab setup)</summary>
<br>

### Create a Backup Vault (not a Recovery Service Vault)
![image](./img/mh-ch2-screenshot-71.png)

</details>

<details>
<summary>💡 How-to: Create a Container</summary>
<br>

![image](./img/019.png)
![image](./img/019a.png)
![image](./img/019b.png)
![image](./img/020.png)

</details>

To backup our storage account, assign the Backup Vault in the Primary Region some access permissions.

### Enable System Managed Identity for the Backup Vault and Copy the MI Object ID

Go to the Backup Vault in the Primary Region (Germany West Central) and navigate to the Identity tab.

![Identity Tab](./img/060.png)

Click **Azure role assignments**.

![Enable System Managed Identity](./img/060a.png)

### Assign the "Storage Backup Contributor" Role to Backup Vault Managed Identity

Go back to the Storage Account in the Primary Region (Germany West Central). Navigate to the **Access Control (IAM)** tab and add a role assignment.

![image](./img/061.png)

Select Role.

![Backup Contributor](./img/062.png)

Select Scope.

![MI](./img/063.png)

Select Managed Identity of the Backup Vault.

![Backup Vault MI](./img/064.png)

Review + Assign.

![Review + Assign](./img/065.png)

### Enable Azure Backup for Blobs

This will require creating a new backup policy:

![Create New Policy](./img/051.png)
![Select Vault](./img/052.png)
![Create](./img/054.png)

Backup Policy for storage successfully created!

![Create](./img/055.png)

</details>

### Task 3: Restore a VM in Azure
- Backup job from Task 1 should be finished before proceeding here!

#### Start Restore Procedure
![image](./img/035.png)

#### Select Restore Point
![image](./img/036.png)

#### Set Restore Properties

Proceed with **Restore**.

![image](./img/037.png)
![image](./img/038.png)
![image](./img/039.png)

A new Virtual Machine `mh-linux-restore` has been created in the resource group, restored from the backup.

![image](./img/070.png)

You have successfully completed Challenge 2.1! 🚀

### Challenge 3.2 - Protect in Azure with Disaster Recover (DR) within an Azure Region
* Task 4: Set up disaster recovery for the Linux VM in the primary region.
* Task 5: Simulate a failover from one part of the primary region to another part within the same region.

### Task 4: Set up disaster recovery for the Linux VM in the primary region.

Enable Disaster Recovery (DR) between **Availability Zones**

Navigate to **mh-linux | Disaster recovery**

Choose a different Availability Zone than the current one as **Target**

![image](./img/071.png)

Review and Start Replication

![image](./img/074.png)

Wait until the replication is finished

![image](./img/075.png)

The Linux Virtual Machine is protected with Azure Site Recovery between Availability Zones.

![image](./img/076.png)

### Task 5: Simulate a failover from one part of the primary region to another part within the same region.

Conduct an unplanned failover

![image](./img/077.png)

![image](./img/078.png)

![image](./img/079.png)

![image](./img/080.png)

![image](./img/081.png)

![image](./img/082.png)

![image](./img/083.png)

You have successfully completed Challenge 2! 🚀🚀

[➡️ Next Challenge 3 Instructions](../../challenges/03_challenge.md)