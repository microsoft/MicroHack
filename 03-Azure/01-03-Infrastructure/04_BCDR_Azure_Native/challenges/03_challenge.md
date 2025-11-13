## Challenge 3 - Protect in Azure with Disaster Recovery (Inter-regional)

## Prerequisites

Please ensure that you successfully passed [challenge 2](./02_challenge.md) before continuing with this challenge.

### Goal 🎯

In Challenge 3, you will learn how to protect Azure VMs with Azure Site Recovery, and how to enable replication to a secondary site. Additionally, you will successfully run test & production failovers from Germany West Central to Sweden Central, and fail back again from Sweden to Germany.

### Actions

* Task 1: Set up and enable disaster recovery with Azure Site Recovery and monitor the progress.
* Task 2: Perform a disaster recovery drill, create recovery plan and run a test failover.
* Task 3: Run a production failover from Germany West Central to Sweden Central region and failback again from Sweden to Germany.

> [!IMPORTANT]
> To enable inter-regional disaster recovery (DR), you may need to grant the Recovery Services Vault appropriate **access permissions**.
> 
> 💡 **Need help?** Refer to the [step-by-step guidance](../walkthrough/challenge-3/solution.md#enable-system-managed-identity-for-the-recovery-services-vault) in the solution.

### Success Criteria ✅

* You enabled the replication for all related components of the web application to the Sweden Central region.
* You successfully initiated a test failover from Azure Region Germany West Central to Sweden Central with near-zero downtime.
* You successfully ran the production failover to the Sweden Central region.

### 📚 Learning Resources

* [Enable Replication](https://learn.microsoft.com/en-us/azure/site-recovery/azure-to-azure-how-to-enable-replication)
* [Create Recovery Plans](https://learn.microsoft.com/en-us/azure/site-recovery/site-recovery-create-recovery-plans)
* [Test Failover to Azure](https://learn.microsoft.com/en-us/azure/site-recovery/site-recovery-test-failover-to-azure)

### Solution - Spoiler Warning ⚠️

[Solution Steps](../walkthrough/challenge-3/solution.md)

---

**[➡️ Next Challenge 4 - Protect your Azure PaaS with Disaster recovery](./04_challenge.md)** |

**[⬅️ Previous Challenge 2 - Regional Protection and Disaster Recovery (DR)](./02_challenge.md)** 