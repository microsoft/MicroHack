## Challenge 5 - Failback to the Primary Region (Germany West Central) 

### Goal 🎯

In challenge 5, you will failback the VM, SQL DB from Sweden Central to Germany West Central. The storage account should be failed back as well to Germany West Central.

### Actions 🛠️

* Failback the VM from Sweden Central to Germany West Central region (Source environment) and monitor the progress.
* Failback Azure SQL DB to Germany West Central.
* Failback Storage Account to Germany West Central.

### Success Criteria ✅

* The failback of all resources to the Germany West Central region has been successfully performed.

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

**[< BCDR Micro Hack - Home Page](../Readme.md)** | **[< Challenge 4 - Protect your Azure PaaS (Azure SQL Database and Storage Account) with Disaster Recovery](./03_challange.md)**