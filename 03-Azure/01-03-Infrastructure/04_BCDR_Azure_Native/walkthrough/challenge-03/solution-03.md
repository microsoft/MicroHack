# Walkthrough Challenge 3 - Regional Protection (Backup)

[Previous Challenge Solution](../challenge-02/solution-02.md) - **[Home](../../Readme.md)** - [Next Challenge Solution](../challenge-04/solution-04.md)

⏰ Duration: 1 Hour

## Solution Overview

This challenge focuses on implementing Azure Backup for virtual machines and blob storage, and performing restore operations. You will configure backup policies, execute backups, and restore resources to demonstrate business continuity capabilities.

## Prerequisites

Ensure the lab environment from Challenge 2 is successfully deployed with:
- Linux VM (`mh-linux`) in Germany West Central
- Recovery Services Vault in Germany West Central
- Backup Vault in Germany West Central
- Storage Account with blob containers

## Task 1: Enable Azure Backup for Linux VM

### Configure VM Backup

Navigate to the Linux VM and enable backup:

1. Navigate to the Linux VM in the Azure Portal. Go to the **Backup** blade and configure settings and enable backup.
   
   ![Navigate to Backup](./img/030.png)

2. Verify backup settings and start the initial backup by clicking **Backup now**.
   
   ![Enable Backup](./img/040.png)

3. Monitor the backup job progress, click on **View details** for backup.
   
   ![Backup Started](./img/031.png)

4. Monitor the backup job details (includes snapshot and vault transfer)
   
   ![Backup Progress](./img/032.png)

5. Wait for the backup to complete
   
   ![Backup Completed](./img/033.png)
   ![Backup Details](./img/034.png)

### Create a Custom Backup Policy (Optional)

You can create custom backup policies to meet specific retention and scheduling requirements:

1. Navigate to the Recovery Services Vault in Germany West Central
   ![Recovery Services Vault](./img/041.png)

2. Add a new Backup Policy
   ![Add Policy](./img/042.png)

3. Select policy type for Azure Virtual Machines
   ![Policy for VMs](./img/043.png)

4. Configure backup schedule (daily or hourly)
   ![Daily Backup Schedule](./img/044.png)
   
   Optional: Configure hourly backup schedule
   ![Hourly Backup Schedule](./img/mh-ch2-screenshot-22.png)

5. Review retention settings and create the policy
   ![Policy Created](./img/045.png)

## Task 2: Enable Azure Backup for Blobs

### Configure Backup Vault Permissions

1. Navigate to the Backup Vault in Germany West Central
   ![Backup Vault](./img/060.png)

2. Enable System Managed Identity and note the Object ID
   ![Enable Managed Identity](./img/060a.png)

3. Go to the Storage Account in Germany West Central
   ![Storage Account](./img/050.png)

4. Navigate to **Access Control (IAM)** and add role assignment
   ![IAM](./img/061.png)

5. Select the **Storage Account Backup Contributor** role
   ![Select Role](./img/062.png)

6. Assign to the Backup Vault's Managed Identity
   ![Select Scope](./img/063.png)
   ![Select Managed Identity](./img/064.png)

7. Review and assign the role
   ![Review Assignment](./img/065.png)

### Configure Blob Backup

1. Create a backup policy for blobs
   ![Create Policy](./img/051.png)
   ![Select Vault](./img/052.png)
   ![Configure Policy](./img/054.png)

2. Verify the backup policy is created
   ![Policy Created](./img/055.png)

## Task 3: Restore a VM in Azure

> **Important:** Ensure the backup job from Task 1 is completed before proceeding.

### Perform VM Restore

1. Navigate to the VM backup and start the restore procedure
   ![Start Restore](./img/035.png)

2. Select a restore point
   ![Select Restore Point](./img/036.png)

3. Configure restore properties and proceed
   ![Restore Properties](./img/037.png)
   ![Review Restore](./img/038.png)
   ![Confirm Restore](./img/039.png)

4. Verify the restored VM is created
   ![Restored VM](./img/070.png)

## Task 4 (Optional): Restore Azure Blob

For restoring blob storage, refer to the [Azure Blob Backup documentation](https://learn.microsoft.com/en-us/azure/backup/blob-restore).

## Success Criteria Validation ✅

Confirm you have completed:
- ✅ Enabled Azure Backup for the Linux VM
- ✅ Configured Azure Backup for Blob Storage
- ✅ Successfully restored a VM from backup
- ✅ (Optional) Restored a blob container

You have successfully completed Challenge 3! 🚀

