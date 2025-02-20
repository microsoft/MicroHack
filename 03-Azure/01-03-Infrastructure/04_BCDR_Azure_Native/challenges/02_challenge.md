## Challenge 2 - Protect in Azure - Backup / Restore (Regional)

### Goal 🎯

In challenge 2, you will successfully onboard your Windows and Linux Virtual Machines to a centralized Recovery Services Vault and leverage Azure Backup Center to Protect with Backup in Azure.

[Datacenter & Availability Zone](image) 

### Actions

* Enable Azure Backup for Linux VM in the primary Region.
* Disaster recovery for LInux VM in the primary Region
* Failover from Primary Region AZ1 to Primary Region AZ2  

### Success Criteria ✅
* You have deployed two VMs in Azure (one with Windows Server 2022, the other one with Ubuntu Server).
* You have successfully set up Azure Backup Policies for both virtual machines.
* You have successfully restored a VM of your choice to Azure.


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

**[> Next Challenge 3 - Protect in Azure with Disaster Recovery](./03_challenge.md)** |

**[< Previous Challenge 1 - Prerequisites and landing zone preparation](./01_challenge.md)** 