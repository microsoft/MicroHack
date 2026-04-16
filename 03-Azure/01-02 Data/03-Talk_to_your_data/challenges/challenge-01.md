# Challenge 1 - Attack the Data Silos

**[Home](../README.md)** - [Next Challenge 2 Info](challenge-02.md)

## Goal 
The goal of this exercise is to replicate operational data from Azure SQL Managed Instance into Microsoft Fabric OneLake to enable real-time analytics and downstream AI workloads without impacting the source transactional system.


## Actions

* Create a Fabric‑managed mirrored database from Azure SQL Managed Instance  
* Start the database mirroring process in Microsoft Fabric 
* Monitor the mirroring status and synchronization in Fabric

## Success criteria

* You have successfully created a Fabric‑managed mirrored database  
* You have successfully verified that the mirroring status is Running / Synchronized in Microsoft Fabric  
* You have successfully confirmed that data changes in Azure SQL Managed Instance are automatically reflected in OneLake  
* You have successfully executed analytics queries in Fabric without connecting to the source Azure SQL Managed Instance

[Open the step-by-step solution for Challenge 1](../walkthrough/challenge-01/solution-01.md)

## Learning resources
* [SQL Server to Azure SQL Managed Instance: Migration guide - Azure SQL Managed Instance](https://learn.microsoft.com/en-us/azure/azure-sql/migration-guides/managed-instance/sql-server-to-managed-instance-guide?view=azuresql) 
* [Monitor Azure SQL Managed Instance - Azure SQL Managed Instance](https://learn.microsoft.com/en-us/azure/azure-sql/managed-instance/monitoring-sql-managed-instance-azure-monitor?view=azuresql)
* [Frequently Asked Questions for Mirroring Azure SQL Managed Instance - Microsoft Fabric | Microsoft Learn](https://learn.microsoft.com/en-us/fabric/mirroring/azure-sql-managed-instance-faq#how-do-i-know-fabric-is-replicating-data-on-my-azure-sql-managed-instance--)
* [Troubleshoot Fabric Mirrored Databases From Azure SQL Managed Instance - Microsoft Fabric | Microsoft Learn](https://learn.microsoft.com/en-us/fabric/mirroring/azure-sql-managed-instance-troubleshoot)
* [Limitations in Mirrored Databases From Azure SQL Managed Instance - Microsoft Fabric | Microsoft Learn](https://learn.microsoft.com/en-us/fabric/mirroring/azure-sql-managed-instance-limitations)