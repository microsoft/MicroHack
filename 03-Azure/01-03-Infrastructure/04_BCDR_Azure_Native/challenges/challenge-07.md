# Extra Challenge 7 - Monitor & Protect your Azure PaaS (Azure SQL Database)

[Previous Challenge Solution](challenge-06.md) - **[Home](../Readme.md)** - [Next Challenge Solution](finish.md)

In this chapter we have extra challanges for the fast participants or the participants who wants to go further more. We will focus on Application 2 - Customer Help Desk Services. 

## Challenge 7.0 - Setup - Application 2

You can use [the guide](../Infra/App2/setup.md) to deploy an N-tier application, which will be useful for the challenges.

## Challenge 7.1 - Monitor the resources

### Task 1 - Open the Application Insights dashboard

- Use [`azd monitor`](https://learn.microsoft.com/azure/developer/azure-developer-cli/monitor-your-app) to monitor the application 

Run the following Terminal Command in the directory

    azd monitor

### Task 2 - Navigate through the metrics

Navigate to the Application Insights dashboards:
- overview
- live metrics
- logs

![image](../walkthrough/challenge-6/img/01_App_Insights_dashboards.png)

## Success Criteria

- Successfully execute the ``azd monitor`` command.
- Navigate and review the Application Insights dashboards.

<!--
## Challenge 7.2 - Protect your Azure PaaS (Azure SQL Database) with Failover Groups

### Goal 🎯

In challenge 7, you will focus on implementing disaster recovery strategies for Azure SQL databases using Failover Groups. The primary objective is to ensure business continuity by protecting critical data stored in Azure SQL databases.

### Actions
* Implement Failover Groups for Azure SQL Database:
  * Task 1: Create a Failover Group between two Azure SQL databases located in different Azure regions (Germany West Central and Sweden Central).
  * Task 2: Configure automatic failover policies and test the failover mechanism to ensure seamless transition in case of a disaster.

### Success Criteria ✅
* You have successfully created and configured a Failover Group for Azure SQL Database, ensuring data is replicated and accessible across regions.
* You have conducted failover tests for the Azure SQL Database, demonstrating the effectiveness of your disaster recovery strategy.
* You were able to connect to the failed-over SQL DB from the failed-over VM.
 -->
<!-- ### 📚 Learning Resources
* [Azure SQL Database Failover Groups and Active Geo-Replication](https://learn.microsoft.com/en-us/azure/azure-sql/database/auto-failover-group-overview)
* [Testing for disaster recovery](https://learn.microsoft.com/en-us/azure/site-recovery/site-recovery-test-failover-to-azure)
* [Create a single database in Azure SQL Database](https://learn.microsoft.com/en-us/azure/azure-sql/database/single-database-create-quickstart?view=azuresql&tabs=azure-portal) -->


