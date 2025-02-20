## Challenge 2 - Protect in Azure - Backup / Restore (Regional)

### Goal 🎯

In this challenge, you will learn how to back up and restore your Windows and Linux Virtual Machines using Azure's Recovery Services Vault. You will also practice simulating a regional failover between two datacenters to handle a regional failure, such as a datacenter outage.

![Datacenter & Availability Zone](../img/AZs.png)

### Actions

1. Enable Azure Backup for a Linux VM in the primary region.
2. Set up disaster recovery for the Linux VM in the primary region.
3. Simulate a failover from one part of the primary region to another part within the same region.

### Success Criteria ✅

- You have successfully set up Azure Backup Policies for both virtual machines.
- You have successfully restored a VM of your choice to Azure.

### 📚 Learning Resources

- [Quickstart: Back up a VM with the Azure portal](https://learn.microsoft.com/en-us/azure/backup/quick-backup-vm-portal)
- [Apply a backup policy](https://learn.microsoft.com/en-us/azure/backup/quick-backup-vm-portal#apply-a-backup-policy)
- [Tutorial: Back up multiple VMs at scale](https://learn.microsoft.com/en-us/azure/backup/tutorial-backup-vm-at-scale)
- [Restore VMs from Azure Backup](https://learn.microsoft.com/en-us/azure/backup/backup-azure-arm-restore-vms)
- [Restore encrypted virtual machines](https://learn.microsoft.com/en-us/azure/backup/restore-azure-encrypted-virtual-machines)
- [Azure Blob Storage: Backup overview](https://learn.microsoft.com/en-us/azure/backup/blob-backup-overview)

### Solution - Spoiler Warning ⚠️

For detailed steps, refer to the [Solution Steps](../walkthrough/challenge-2/solution.md).

---

**[> Next Challenge 3 - Protect in Azure with Disaster Recovery](./03_challenge.md)**

**[< Previous Challenge 1 - Prerequisites and landing zone preparation](./01_challenge.md)**