## Challenge 4 - Protect your Azure PaaS (Azure SQL Database and Storage Account) with Disaster recovery

### Goal 🎯

In challenge 4, you will focus on implementing disaster recovery strategies for Azure SQL databases using Failover Groups, and for Azure storage accounts using replication. The primary objective is to ensure business continuity by protecting critical data stored in Azure SQL databases and Azure storage accounts against potential disasters.

### Actions
* Disaster Recovery for Azure Storage Account:
  * Set up and configure Azure Storage Account replication to another region using Geo-redundant storage (GRS) or Geo-zone-redundant storage (GZRS) to ensure data availability in case of regional outages.
  * Perform a failover test for the storage account to validate the disaster recovery setup.
  * Load Balancer discussion

### Success Criteria ✅
* You have successfully created and configured a Failover Group for Azure SQL Database, ensuring data is replicated and accessible across regions.
* You have implemented disaster recovery for an Azure Storage Account using GRS or GZRS, protecting against regional outages.
* You have conducted failover tests for both the Azure SQL Database and Azure Storage Account, demonstrating the effectiveness of your disaster recovery strategy.
* You were able to connect to the failed-over SQL DB and the failed-over Storage Account from the failed-over VM.

### 📚 Learning Resources
* [Azure SQL Database Failover Groups and Active Geo-Replication](https://learn.microsoft.com/en-us/azure/azure-sql/database/auto-failover-group-overview)
* [Geo-redundant storage (GRS) for cross-regional durability](https://learn.microsoft.com/en-us/azure/storage/common/storage-redundancy-grs)
* [Disaster recovery and storage account failover](https://learn.microsoft.com/en-us/azure/storage/common/storage-disaster-recovery-guidance)
* [Testing for disaster recovery](https://learn.microsoft.com/en-us/azure/site-recovery/site-recovery-test-failover-to-azure)
    
### Solution - Spoiler Warning ⚠️

[Solution Steps](../walkthrough/challenge-4/solution.md)

---

**[> Next Challenge 5 - Failback to the primary region](./05_challenge.md)** |

**[< Previous Challenge 3 - Protect in Azure with Disaster Recovery](./03_challenge.md)** 