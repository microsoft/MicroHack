# Challenge 5 - Protect your Azure PaaS with Disaster Recovery

[Previous Challenge](challenge-05.md) - **[Home](../Readme.md)** - [Next Challenge](challenge-07.md)

### Goal 🎯

In this challenge, you will re-establish the connection to your web application from the failed-over region and then test disaster recovery for an Azure Storage account with GRS enabled. The primary objective is to ensure business continuity by protecting critical data stored in Azure storage accounts against potential disasters.

### Actions
* Task 1: Re-establish your connection to the Web Application from the secondary region.
  * Add your failed-over Virtual Machines in the secondary region to the backend pool of your Load Balancer.
  * Test the connection to the Web Application.
* Task 2: Disaster Recovery for Azure Storage Account.
  * Verify the configuration of the Azure Storage Account redudancy, and confirm GRS is enabled and data is replicated to a secondary region. Which region is used as secondary region?
  * Perform a failover test for the storage account to validate the disaster recovery setup.


<details close>
<summary>💡 Storage Account with GRS enabled</summary>
<br>

![grs3](./exploration/7.png)

</details>

---

### Success Criteria ✅
* You have successfully re-established connection to your web application from the secondary region.
* You have verified that the Azure Storage Account has GRS enabled and identified the secondary region used for data replication.
* You have successfully performed a failover test for the Azure Storage Account.

### 📚 Learning Resources
* [Geo-redundant storage (GRS) for cross-regional durability](https://learn.microsoft.com/en-us/azure/storage/common/storage-redundancy-grs)
* [Disaster recovery and storage account failover](https://learn.microsoft.com/en-us/azure/storage/common/storage-disaster-recovery-guidance)
