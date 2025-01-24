## Challenge 2 - Protect in Azure - Backup / Restore

### Goal 🎯

In challenge 2, you will successfully onboard your Windows and Linux Virtual Machines to a centralized Recovery Services Vault and leverage Azure Backup Center to Protect with Backup in Azure. 

### Actions

* Deploy a Windows Server 2022 VM in Germany West Central Resource Group. Please use the "Data Science Virtual Machine - Windows 2022" image from the market place.
  > **Note:** The 'Data Science Virtual Machine (DSVM)' is a 'Windows Server 2022 with Containers' VM that has several popular tools for data exploration, analysis, modeling & development pre-installed.
  > You will use Microsoft SQL Server Management Studio to connect to the database and Storage Explorer to the storage Account.
* Deploy an Ubuntu Server VM in Sweden Central Resource Group.
* Deploy an Azure SQL database server with a database containing the sample data of AdventureWorksLT.
* From the Data Science Windows Server VM, connect to the database and to the storage account.
* Create a blob container and upload a sample file to it.
* Enable Azure Backup for both VMs.
* Enable Azure Backup for blobs on the storage account.
* Restore a VM in Azure.
* Delete and restore the sample blob file.

### Success Criteria ✅
* You have deployed two VMs in Azure (one with Windows Server 2022, the other one with Ubuntu Server).
* You have deployed an Azure SQL database with sample data (AdventureWorksLT) and can access the database from the Windows Server (Data Science Edition).
* You successfully connected to the database and the storage account from the Windows Server.
* You successfully enabled Azure Backup on the two virtual machines.
* You have successfully set up Azure Backup Policies for both virtual machines.
* You successfully enabled Azure Backup for blobs.
* You have successfully restored a VM of your choice to Azure.
* You have successfully restored blobs.

### 📚 Learning Resources

* [Create a single database in Azure SQL Database](https://learn.microsoft.com/en-us/azure/azure-sql/database/single-database-create-quickstart?view=azuresql&tabs=azure-portal)
* [Quickstart: Back up a VM with the Azure portal](https://learn.microsoft.com/en-us/azure/backup/quick-backup-vm-portal)
* [Apply a backup policy](https://learn.microsoft.com/en-us/azure/backup/quick-backup-vm-portal#apply-a-backup-policy)
* [Tutorial: Back up multiple VMs at scale](https://learn.microsoft.com/en-us/azure/backup/tutorial-backup-vm-at-scale)
* [Restore VMs from Azure Backup](https://learn.microsoft.com/en-us/azure/backup/backup-azure-arm-restore-vms)
* [Restore encrypted virtual machines](https://learn.microsoft.com/en-us/azure/backup/restore-azure-encrypted-virtual-machines)
* [Azure Blob Storage: Backup overview](https://learn.microsoft.com/en-us/azure/backup/blob-backup-overview)

### Solution - Spoiler Warning ⚠️

[Solution Steps](../walkthrough/challenge-2/solution.md)

---

**[> Next Challenge 3 - Protect in Azure with Disaster Recovery](./03_challange.md)** |

**[< Previous Challenge 1 - Prerequisites and landing zone preparation](./01_challenge.md)** 