## Challenge 1 - Prerequisites and landing zone preparation

### Goal 🎯

In challenge 1, you will understand and prepare your environment with the needed infrastructure to enable business continuity with Cloud Native / PaaS Services on Azure.

### Actions

Create all necessary Azure resources
* Region 1: Germany West Central (Source enviroment)
  * Resource Group: mh-bcdr-gwc-rg<your assigned number>
  * Recovery Services Vault: mh-rsv-gwc
  * Storage Account with GRS (geo-redundant storage) redundancy option: mhstweu\<Suffix\>
* Region 2: Sweden Central (Target environment)
  * Resource Group: mh-bcdr-sc-rg<your assigned number>
  * Recovery Services Vault: mh-rsv-sc


### Success Criteria ✅

* You've created Resource Groups in both regions (Germany West Central & Sweden Central).
* Recovery Services Vaults have been created in both regions.
* A geo-redundant Storage Account has been created.

### 📚 Learning Resources

* [Manage resource groups - Azure Portal - Azure Resource Manager | Microsoft Learn](https://learn.microsoft.com/azure/azure-resource-manager/management/manage-resource-groups-portal)
* [Create a storage account - Azure Storage | Microsoft Learn](https://learn.microsoft.com/azure/storage/common/storage-account-create)
* [Create and configure Recovery Services vaults - Azure Backup | Microsoft Learn](https://learn.microsoft.com/azure/backup/backup-create-recovery-services-vault)


### Solution - Spoiler Warning ⚠️

[Solution Steps](../walkthrough/challenge-1/solution.md)

---

**[> Next Challenge 2 - Protect in Azure - Backup / Restore](./02_challenge.md)** |

**[< Previous Challenge 0 - 🚀 Deploying a Ready-to-Go N-tier App with Awesome Azure Developer CLI](./00_challenge.md)** 
