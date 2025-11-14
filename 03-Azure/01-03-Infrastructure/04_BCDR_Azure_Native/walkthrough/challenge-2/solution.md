# Walkthrough Challenge 2 - Regional Protection and Disaster Recovery (DR)

⏰ Duration: 1 Hour

📋 [Challenge 2 Instructions](../../challenges/02_challenge.md)

## Prerequisites

Ensure you have successfully completed [challenge 1](../../challenges/01_challenge.md) before proceeding.

## Solution Walkthrough

- [**Challenge 2.1 - Protect in Azure - Backup / Restore**](#challenge-21---protect-in-azure---backup--restore)
  - [Task 1: Enable Azure Backup for Linux VM](#task-1-enable-azure-backup-for-linux-vm)
  - [Task 2: Enable Azure Backup for Blobs](#task-2-enable-azure-backup-for-blobs)
    - [Assign access permissions to perform backup](#enable-system-managed-identity-for-the-backup-vault-and-copy-the-mi-object-id)
  - [Task 3: Restore a VM in Azure](#task-3-restore-a-vm-in-azure)
- [**Challenge 2.2 - Protect in Azure with Disaster Recovery (DR) within an Azure Region**](#challenge-22---protect-in-azure-with-disaster-recover-dr-within-an-azure-region)
  - [Task 4: Set up disaster recovery for the Linux VM in the primary region](#task-4-set-up-disaster-recovery-for-the-linux-vm-in-the-primary-region)
    - [Assign access permissions to perform disaster recovery](#enable-system-managed-identity-for-the-recovery-services-vault)
  - [Task 5: Simulate a failover from one part of the primary region to another part within the same region](#task-5-simulate-a-failover-from-one-part-of-the-primary-region-to-another-part-within-the-same-region)


### Challenge 2.1 - Protect in Azure - Backup / Restore
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

### Create a New Custom Policy

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

## Task 2: Enable Azure Backup for Blobs

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
<br>

> **Note:** To enable backup for the storage account, you need to grant the Backup Vault appropriate **access permissions**. Please follow the guidance below.

### Enable System Managed Identity for the Backup Vault and Copy the MI Object ID

Go to the Backup Vault in the Primary Region (Germany West Central) and navigate to the **Identity** tab.

Status: **On**
![Identity Tab](./img/056.png)

Enable system assigned managed identity: **yes**
![Enable MI](./img/057.png)

Successfully enabled system assigned managed identity!
![Identity Tab](./img/058.png)

Successfully enabled system assigned managed identity!
Now you can proceed with one of the two options below.
![Enable System Managed Identity](./img/059.png)

### Solution Example 1 - **Azure role assignments** through MI Identity

Click **Azure role assignments** to proceed with role assignment.
![Enable MI](./img/060.png)

Select **scope**: you can select the specific Storage account Scope or larger scopes like the resource group or your subscription.

Select Role ["Storage Account Backup Contributor"](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/storage#storage-account-backup-contributor).

![Scope Selection](./img/061a.png)

Role assignment successfully configured
![image](./img/061b.png)

### Solution Example 2 -  Assign the "Storage Account Backup Contributor" Role to the Backup Vault Managed Identity

Go back to the Storage Account in the Primary Region (Germany West Central). Navigate to the **Access Control (IAM)** tab and add a role assignment.

![image](./img/061.png)

Select Role ["Storage Account Backup Contributor"](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/storage#storage-account-backup-contributor).

![Storage Account Backup Contributor](./img/062.png)

Under **Assign access to**, select **Managed Identity**.

![MI](./img/063.png)

Click **Select members** and choose the appropriate scope.

![MI](./img/063a.png)

Select the Managed Identity of the Backup Vault.

![Backup Vault MI](./img/064.png)

Review + Assign.

![Review + Assign](./img/065.png)

The Backup Vault now has the required permissions to perform backup operations on the storage account.
<br>

## Enable Azure Backup for Blobs

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

## Challenge 2.2 - Protect in Azure with Disaster Recovery (DR) within an Azure Region
* **Task 4:** Set up disaster recovery for the Linux VM in the primary region.
* **Task 5:** Simulate a failover from one part of the primary region to another part within the same region.

### Task 4: Set up disaster recovery for the Linux VM in the primary region.

Enable Disaster Recovery (DR) between **Availability Zones**

> **Note:** To enable disaster recovery (DR) between the regions, you might need to grant the Site Recovery Vault appropriate **access permissions**. If needed follow the instructions below.

<details>
<summary>💡 How-to: Access permissions for Disaster Recovery (DR)</summary>
<br>

### Enable System Managed Identity for the Recovery Services Vault

Navigate to the **Recovery Services Vault** in the Primary Region (Germany West Central) and select the **Identity** tab.

**Status:** On
![image](./img/066.png)

✅ System-assigned managed identity successfully enabled!

#### Assign Required Azure Roles

Click **Azure role assignments** to begin configuring permissions.

![image](./img/067.png)

Click **Add role assignment** to add the first required role.

![image](./img/068.png)

#### Role Assignment 1: Storage Blob Data Contributor

**Select scope:**
- Choose the specific Resource Group or a larger scope (e.g. your subscription) where disaster recovery will operate.

**Select Role:** ["Storage Blob Data Contributor"](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/storage#storage-blob-data-contributor)

![image](./img/068a.png)

#### Role Assignment 2: Contributor

Click **Add role assignment** again to add the second required role.

![image](./img/068b.png)

**Select scope:**
- Use the same scope as the previous role assignment.

**Select Role:** ["Contributor"](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/privileged#contributor)

![image](./img/068c.png)

✅ Successfully assigned all required permissions for disaster recovery (DR)!

![image](./img/069.png)

</details>
<br>

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

---

## Troubleshooting & FAQ

### Error: Installing Mobility Service and Preparing Target

**Error ID:** `151192`

**Error Message:**  
```
Site recovery configuration failed.
```

**Possible Causes:**  
Connection cannot be established to Office 365 authentication and identity IPv4 endpoints.

**Resolution:**  
Allow outbound access to required Azure Site Recovery endpoints in your **Network Security Group (NSG)**, **firewall**, or **proxy** settings.
- Use service tags like `AzureActiveDirectory` and `Office365` for NSG rules.

**Related Resources:**  
- [Azure Site Recovery - Firewall and Proxy Guidance](https://aka.ms/a2a-firewall-proxy-guidance)
