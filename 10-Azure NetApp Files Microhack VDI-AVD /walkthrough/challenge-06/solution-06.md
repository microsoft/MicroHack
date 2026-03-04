# Walkthrough Challenge 6 - Azure NetApp Files Backup

[Previous Challenge Solution](../challenge-05/solution-05.md) - **[Home](../../Readme.md)** - [Next Challenge Solution](../challenge-07/solution-07.md)

Duration: 20 minutes

## Prerequisites

Please ensure that you successfully verified the [General prerequisits](../../Readme.md#general-prerequisites) before continuing with this challenge.

### **Task 1: Configure a backup policy**

1. Sign in to the Azure portal and navigate to Azure NetApp Files.

2. Select your Azure NetApp Files account.

3. Select Backups.

4. Select Backup Policies.

5. Select Add.

6. In the Backup Policy page, specify the backup policy name. Enter the number of backups that you want to keep for daily, weekly, and monthly backups. Select Save.

The minimum value for Daily Backups to Keep is 2.


### **Task 2: Assign backup vault and backup policy to a volume**

1. Navigate to Volumes then select the volume for which you want to configure backups.

2. From the selected volume, select Backup then Configure.

3. In the Configure Backups page, select the backup vault from the Backup vaults drop-down. For information about creating a backup vault, see Create a backup vault.

4. In the Backup Policy drop-down menu, assign the backup policy to use for the volume. Select OK.

5. The Vault information is prepopulated.



You successfully completed challenge 6! 🚀🚀🚀