# Walkthrough Challenge 6 - Azure NetApp Files Backup

[Previous Challenge Solution](../challenge-05/solution-05.md) - **[Home](../../Readme.md)** - [Next Challenge Solution](../challenge-07/solution-07.md)

Duration: 20 minutes

### **Task 1: Create a backup vault**

1. In your NetApp account on the left side navigate to **Backup Vaults**

2. Select **Add Backup Vault** and assign a name to your backup vault then select **Create**

![image](../img/solution-05-backup-vault-create.png)


### **Task 2: Configure a backup policy**

1. Select your NetApp account.

2. On the left side under **Storage service**, select Backups.

3. Select **Backup Policies**

4. Select **Add**

5. In the Backup Policy page, specify the **Backup Policy Name**. Enter the number of backups that you want to keep for daily, weekly, and monthly backups. Select **Save**

The minimum value for Daily Backups to Keep is 2.

![image](../img/solution-05-backup-policy-window-daily.png)

**Example of a valid configuration**
Backup policy:
Daily: Daily Backups to Keep = 15
Weekly: Weekly Backups to Keep = 6
Monthly: Monthly Backups to Keep = 4

### **Task 3: Assign backup vault and backup policy to a volume**

1. Navigate to Volumes then select the volume for which you want to configure backups.

2. From the selected volume, select **Backups** then **Configure Backups**.

3. Select your backup vault 

4. Select the previously created backup policy 

![image](../img/solution-05-backup-configure-enabled.png)


You successfully completed challenge 6! 🚀🚀🚀