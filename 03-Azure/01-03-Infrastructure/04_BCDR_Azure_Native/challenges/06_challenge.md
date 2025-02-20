## Challenge 6 - Protect your Azure PaaS (Azure SQL Database) with Disaster recovery

### Goal 🎯

In challenge 6, you will focus on implementing disaster recovery strategies for Azure SQL databases using Failover Groups. The primary objective is to ensure business continuity by protecting critical data stored in Azure SQL databases.

### Actions
* Implement Failover Groups for Azure SQL Database:
  * Task 1: Create a Failover Group between two Azure SQL databases located in different Azure regions (Germany West central and Sweden Central).
  * Task 2: Configure automatic failover policies and test the failover mechanism to ensure seamless transition in case of a disaster.

### Success Criteria ✅
* You have successfully created and configured a Failover Group for Azure SQL Database, ensuring data is replicated and accessible across regions.
* You have conducted failover tests for the Azure SQL Database, demonstrating the effectiveness of your disaster recovery strategy.
* You were able to connect to the failed-over SQL DB from the failed-over VM.

### 📚 Learning Resources
* [Azure SQL Database Failover Groups and Active Geo-Replication](https://learn.microsoft.com/en-us/azure/azure-sql/database/auto-failover-group-overview)
* [Testing for disaster recovery](https://learn.microsoft.com/en-us/azure/site-recovery/site-recovery-test-failover-to-azure)
* [Create a single database in Azure SQL Database](https://learn.microsoft.com/en-us/azure/azure-sql/database/single-database-create-quickstart?view=azuresql&tabs=azure-portal)


**[< BCDR Micro Hack - Home Page](../Readme.md)** | **[< Challenge 5 - Failback to the Primary Region (Germany West Central) ](./05_challenge.md)**
  
Extra Challenge
Azd monitor command -> Dashboards (through LAW)
Deploy with 'Deploy to Azure' Button (N-tier App)
Failover PaaS Cosmos DB
Check WebApp SKUs (Basic (w/o redundancy) -> Standard (w red.)