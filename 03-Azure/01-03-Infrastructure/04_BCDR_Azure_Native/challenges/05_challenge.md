## Challenge 5 - Failback to the Primary Region (Germany West Central) 

### Goal 🎯

In challenge 5, you will failback the VM, SQL DB from Sweden Central to Germany West Central. The storage account should be failed back as well to Germany West Central.

### Actions 🛠️

* Failback the VM from Sweden Central to Germany West Central region (Source environment) and monitor the progress.
* Failback Azure SQL DB to Germany West Central.
* Failback Storage Account to Germany West Central.
* Restore a VM in Azure.

## New Actions
* Deploy an Azure SQL database server with a database containing the sample data of AdventureWorksLT.
* From the Data Science Windows Server VM, connect to the database and to the storage account.
* Create a blob container and upload a sample file to it.
* Enable Azure Backup for blobs on the storage account.
* Delete and restore the sample blob file.

### Success Criteria ✅

* The failback of all resources to the Germany West Central region has been successfully performed.

* You have deployed an Azure SQL database with sample data (AdventureWorksLT) and can access the database from the Windows Server (Data Science Edition).
* You successfully connected to the database and the storage account from the Windows Server.
* You successfully enabled Azure Backup on the two virtual machines.
* You successfully enabled Azure Backup for blobs.
* You have successfully restored blobs.

### Learning Resources 📚

* [Reprotect Azure VMs](https://learn.microsoft.com/en-us/azure/site-recovery/azure-to-azure-how-to-reprotect)
* [Failback Azure VMs](https://learn.microsoft.com/en-us/azure/site-recovery/azure-to-azure-tutorial-failback)
* [Enable Replication for Azure VMs](https://learn.microsoft.com/en-us/azure/site-recovery/azure-to-azure-tutorial-enable-replication)

### Solution - Spoiler Warning ⚠️

[Solution Steps](./walkthrough/challenge-5/solution.md)

## Finish 🎉

Congratulations! You finished the MicroHack Business Continuity / Disaster Recovery. We hope you had the chance to learn about how to implement a successful DR strategy to protect resources in Azure and to Azure. 

Thank you for investing the time and see you next time!

---

**[< BCDR Micro Hack - Home Page](../Readme.md)** | **[< Challenge 4 - Protect your Azure PaaS with Disaster Recovery](./04_challenge.md)**