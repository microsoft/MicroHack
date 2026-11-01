# Challenge 3 - Security on Azure SQL Managed Instance

[Previous Challenge Solution](challenge-02.md) - **[Home](../Readme.md)** - [Next Challenge Solution](finish.md)

## Lab environment

![Lab environment architecture](../Images/MigrationArchitecturev3.png)

All workshop resources are deployed into one Virtual Network (**SQLHACK-SHARED-VNET**) with three subnets:

* **TeamJumpServers subnet**: Every team has its own Windows 11 VM (**Team-VMXX**, accessible via Azure Bastion/RDP). It mimics your company desktop and has SQL Server Management Studio (SSMS) installed. You do all your work from this VM.
* **Management subnet**: The **LegacySQL2016** Azure VM mimics your on-premises SQL Server 2016. It hosts **4 databases per team** (*LABUSER-XXXX_LocalMasterDataDB*, *LABUSER-XXXX_SharedMasterDataDB*, *LABUSER-XXXX_TenantDataDB* and *LABUSER-XXXX_GlobalDataDB*). A storage account is only used during the deployment of the lab.
* **ManagedInstance subnet**: The **Azure SQL Managed Instance** is the migration target. It is shared by all teams.

> ## ⚠️ WARNING - Only work with the databases of YOUR team!
>
> The Azure SQL Managed Instance is **shared with the other teams**.
>
> * 🚫 **Do NOT change, migrate, link, fail over, delete or otherwise touch databases of other teams.**
> * 🆔 **Know your team name!** It starts with **LABUSER-XXXX** and is the prefix of your database names. Always check it before you select or change a database.

## Goal 

The goal of this exercise is to understand the layered security model available when running databases in Azure.

## Actions

* Perform data discovery & classification as a built-in capability for discovering, classifying, labelling and protecting sensitive data in databases
* Review the Azure Defender for SQL – Vulnerability Assessment
* Azure Defender for SQL – Advanced Threat Protection
* Use Github Copilot to identify and mitigate security issues on your Azure SQL MI

## Success criteria

* You have successfully created data classification recommendations and added custom data classification
* You successfully used Vulnerability Assessment to generate the initial vulnerability scan baseline
* You have successfully reviewed Advanced Threat Protection and created a security alerts on an anomalous activity.
* You have successfully leveraged Github Copilot to identify and mitigate the most important security issues on your Azure SQL MI

## Learning resources
* [Security Overview - Azure SQL Database & Azure SQL Managed Instance & Azure Synapse Analytics](https://learn.microsoft.com/en-us/azure/azure-sql/database/security-overview?view=azuresql)

