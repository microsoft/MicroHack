# Challenge 1 - Assessment and migration with SQL Server Management Studio

**[Home](../Readme.md)** - [Next Challenge Solution](challenge-02.md)

## Lab environment

![Lab environment architecture](../Images/MigrationArchitecturev3.png)

All workshop resources are deployed into one Virtual Network (**SQLHACK-SHARED-VNET**) with three subnets:

* **TeamJumpServers subnet**: Every team has its own Windows 11 VM (**Team-VMXX**, accessible via Azure Bastion/RDP). It mimics your company desktop and has SQL Server Management Studio (SSMS) installed. You do all your work from this VM.
* **Management subnet**: The **LegacySQL2016** Azure VM mimics your on-premises SQL Server 2016. It hosts **4 databases per team** (*LABUSER-XXXX_LocalMasterDataDB*, *LABUSER-XXXX_SharedMasterDataDB*, *LABUSER-XXXX_TenantDataDB* and *LABUSER-XXXX_GlobalDataDB*). A storage account is only used during the deployment of the lab.
* **ManagedInstance subnet**: The **Azure SQL Managed Instance** is the migration target. It is shared by all teams.

> ## ⚠️ WARNING - Only work with the databases of YOUR team!
>
> The legacy SQL Server and the Azure SQL Managed Instance are **shared with the other teams**.
>
> * 🚫 **Do NOT change, migrate, link, fail over, delete or otherwise touch databases of other teams.**
> * 🆔 **Know your team name!** It starts with **LABUSER-XXXX** and is the prefix of your database names. Always check it before you select or change a database.

## Goal 

The goal of this exercise is to migrate an on-premises SQL Server 2016 database to Azure SQL Database Managed Instance (SQL MI).

## Actions

* Perform assessments to reveal any feature parity and compatibility issues 
* Analyze workload to identify the appropriate SKU size
* Use Github Copilot to get detailed instructions to remove migration blockers
* Migrate the on-premises databases into Azure, using SSMS

## Success criteria

* You successfully assessed the databases against the SQL PaaS target architectures 
* You successfully captured the workload and received SKU sizing guidance
* You successfully used Github Copilot to identify and remove migration blockers
* You have successfully migrated the on-premises databases to Azure SQL MI 
* You have successfully logged in via SSMS to Azure SQL MI

## Learning resources
* [SQL Server to Azure SQL Managed Instance: Migration guide - Azure SQL Managed Instance](https://learn.microsoft.com/en-us/azure/azure-sql/migration-guides/managed-instance/sql-server-to-managed-instance-guide?view=azuresql) 

