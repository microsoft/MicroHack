# Walkthrough Challenge 4 - Protect your Azure PaaS (Azure SQL Database and Storage Account) with Disaster recovery

Duration: 50 minutes

[Previous Challenge Solution](../challenge-3/solution.md) - **[Home](../../Readme.md)** - [Next Challenge Solution](../challenge-5/solution.md)

## Prerequisites

Please ensure that you successfully passed [challenge 3](../../Readme.md#challenge-3) before continuing with this challenge.

In challenge 4, you will focus on implementing disaster recovery strategies for Azure SQL databases using Failover Groups and for Azure storage accounts. The primary objective is to ensure business continuity by protecting critical data stored in Azure SQL databases and Azure storage accounts against potential disasters.

### Actions
* Implement Failover Groups for Azure SQL Database:
  * Task 1: Create a Failover Group between two Azure SQL databases located in different Azure regions (Germany West central and Sweden Central).
  * Task 2: Configure automatic failover policies and test the failover mechanism to ensure seamless transition in case of a disaster.
* Disaster Recovery for Azure Storage Account:
  * Task 1: Set up and configure Azure Storage Account replication to another region using Geo-redundant storage (GRS) or Geo-zone-redundant storage (GZRS) to ensure data availability in case of regional outages.
  * Task 2: Perform a failover test for the storage account to validate the disaster recovery setup.

### Learning resources
* [Azure SQL Database Failover Groups and Active Geo-Replication](https://learn.microsoft.com/en-us/azure/azure-sql/database/auto-failover-group-overview)
* [Testing for disaster recovery](https://learn.microsoft.com/en-us/azure/site-recovery/site-recovery-test-failover-to-azure)

# Solution

## Implement Failover Groups for Azure SQL Database

## Task 1: Create a Failover Group between two Azure SQL databases located in different Azure regions (Germany West central and Sweden Central)

Navigate to the **SQL Server** in the Germany West Central Region. Open the tab **Failover groups**:
![image](./img/03.png)

### Create a Failover Group and select your **SQL Server** in the Sweden Central Region
![image](./img/04.png)

## Task 2: Configure automatic failover policies and test the failover mechanism to ensure seamless transition in case of a disaster.
Open the created **Failover group**
![image](./img/05.png)

### Test failover
![image](./img/06.png)

### When the failover is complete, you should see **SQL Server** in Sweden Central as the Primary server.
![image](./img/07.png)

### Open the Data Science Virtual Machine, and test the connection to the Server using the new **fail over group listener endpoint**:
![image](./img/08.png)

### Connection established! 
![image](./img/09.png)

### Learning resources
* [Geo-redundant storage (GRS) for cross-regional durability](https://learn.microsoft.com/en-us/azure/storage/common/storage-redundancy-grs)
* [Disaster recovery and storage account failover](https://learn.microsoft.com/en-us/azure/storage/common/storage-disaster-recovery-guidance)

## Disaster Recovery for Azure Storage Account

## Task 1: Set up and configure Azure Storage Account replication to another region using Geo-redundant storage (GRS) or Geo-zone-redundant storage (GZRS) to ensure data availability in case of regional outages.

Navigate to the **Azure Storage Account** in the Germany West Central Region. Open the tab **Redundancy**:
![image](./img/01.png)

### Choose Geo-redundant storage (GRS) as redundancy option. This will enable cross-replication of your storage account with the paired region Germany North. 
![image](./img/02.png)

### You can see now Germany North as the Secondary Region of the Storage Account:
![image](./img/11.png)

![Microsoft Learn - Azure Cross-region replication](https://learn.microsoft.com/en-us/azure/reliability/cross-region-replication-azure#cross-region-replication)

## Task 2: Perform a failover test for the storage account to validate the disaster recovery setup.

### Run the test failover from Germany West Central to the Sweden Central Region
![image](./img/12.png)

### Failover Completed
![image](./img/13.png)

## Check connection and restore your sample file.

### From the Data Science Virtual Machine, use **Microsoft Azure Storage Explorer** to restore your file:
![image](./img/16.png)

**You successfully completed challenge 4!** 🚀🚀🚀
