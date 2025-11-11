# Challenge 6 - Failback to the Primary Region (Germany West Central)

[Previous Challenge Solution](challenge-06.md) - **[Home](../Readme.md)**

### Goal 🎯

In Challenge 7, you will fail back the web application from Sweden Central to Germany West Central, along with the associated storage account.

### Actions 🛠️

* Failback the Web Application from Sweden Central to Germany West Central region (Source environment) and monitor the progress.
* Ensure web servers are re-protected for disaster recovery to the secondary region (Sweden Central) after the failback operation completes.
* Verify Traffic Manager endpoint status and ensure the Germany West Central endpoint is "Online" and receiving traffic.
* Failback Storage Account to Germany West Central.

### Success Criteria ✅

* The web application has been successfully failed back from Sweden Central to Germany West Central region.
* All web servers in Germany West Central are operational and serving traffic correctly.
* Web servers have been re-protected for disaster recovery with replication configured back to Sweden Central region.
* Traffic Manager shows Germany West Central endpoint as "Online" and is actively routing traffic to the primary region.
* Storage Account has been successfully failed back to Germany West Central region.
* Data integrity has been verified - all data is accessible and consistent after the failback operation.

### Learning Resources 📚

* [Reprotect Azure VMs](https://learn.microsoft.com/en-us/azure/site-recovery/azure-to-azure-how-to-reprotect)
* [Failback Azure VMs](https://learn.microsoft.com/en-us/azure/site-recovery/azure-to-azure-tutorial-failback)
* [Enable Replication for Azure VMs](https://learn.microsoft.com/en-us/azure/site-recovery/azure-to-azure-tutorial-enable-replication)


