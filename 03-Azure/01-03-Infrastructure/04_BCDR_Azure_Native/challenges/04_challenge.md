## Challenge 4 - Protect your Azure PaaS (Storage Account) with Disaster recovery

### Goal 🎯

In challenge 4, you will focus on implementing disaster recovery strategies for Azure storage accounts using replication. The primary objective is to ensure business continuity by protecting critical data stored in Azure storage accounts against potential disasters.

### Actions
* Disaster Recovery for Azure Storage Account:
  * Task 1: Set up and configure Azure Storage Account replication to another region using Geo-redundant storage (GRS) or Geo-zone-redundant storage (GZRS) to ensure data availability in case of regional outages.
  * Task 2: Perform a failover test for the storage account to validate the disaster recovery setup.
  * Task 3: Load Balancer discussion

<details close>
<summary>💡 Enable GRS on storage account</summary>
<br>

![grs1](../walkthrough/challenge-1/exploration/5.png)
![grs2](../walkthrough/challenge-1/exploration/6.png)
![grs3](../walkthrough/challenge-1/exploration/7.png)

</details>

### Success Criteria ✅
* You have implemented disaster recovery for an Azure Storage Account using GRS or GZRS, protecting against regional outages.
* You have conducted failover tests for the Azure Storage Account, demonstrating the effectiveness of your disaster recovery strategy.
* You were able to connect to the failed-over Storage Account from the failed-over VM.

### 📚 Learning Resources
* [Geo-redundant storage (GRS) for cross-regional durability](https://learn.microsoft.com/en-us/azure/storage/common/storage-redundancy-grs)
* [Disaster recovery and storage account failover](https://learn.microsoft.com/en-us/azure/storage/common/storage-disaster-recovery-guidance)
* [Testing for disaster recovery](https://learn.microsoft.com/en-us/azure/site-recovery/site-recovery-test-failover-to-azure)
    
### Solution - Spoiler Warning ⚠️

[Solution Steps](../walkthrough/challenge-4/solution.md)

---

**[> Next Challenge 5 - Failback to the primary region](./05_challenge.md)** |

**[< Previous Challenge 3 - Protect in Azure with Disaster Recovery](./03_challenge.md)** 