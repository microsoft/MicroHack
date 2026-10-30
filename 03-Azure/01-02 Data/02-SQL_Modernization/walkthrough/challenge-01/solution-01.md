# Walkthrough Challenge 1 - Assessment and migration with SQL Server Management Studio (SSMS) and GitHub Copilot

**[Home](../../Readme.md)** - [Next Challenge Solution](../challenge-02/solution-02.md)

## Assessment and migration with SQL Server Management Studio (SSMS) and GitHub Copilot

In this challenge **GitHub Copilot is your companion throughout the whole migration**. After the preparation steps you will find suggested Copilot prompts in every section. Use them to understand what you are doing, to analyze the results of the assessment, and to remove migration blockers.

### Contents

[Migration architecture and Azure components](#migration-architecture-and-azure-components)

[Generic Migration Content](#generic-migration-content)

[1. Preparation](#1-preparation)
* [1.1 Connect to your Win11 VM](#11-connect-to-your-win11-vm)
* [1.2 Connect SSMS with your Azure and GitHub Copilot accounts](#12-connect-ssms-with-your-azure-and-github-copilot-accounts)
* [1.3 Connect to the legacy SQL Server](#13-connect-to-the-legacy-sql-server)
* [1.4 Connect to the Azure SQL Managed Instance](#14-connect-to-the-azure-sql-managed-instance)
* [1.5 Say hello to GitHub Copilot](#15-say-hello-to-github-copilot)

[2. Understand the migration path and assess the databases with GitHub Copilot](#2-understand-the-migration-path-and-assess-the-databases-with-github-copilot)

[3. Remove the migration blockers with GitHub Copilot](#3-remove-the-migration-blockers-with-github-copilot)

[4. Migrate the application databases to Azure SQL Managed Instance](#4-migrate-the-application-databases-to-azure-sql-managed-instance)

[5. Confirm the application databases have been migrated to Azure SQL Managed Instance](#5-confirm-the-application-databases-have-been-migrated-to-azure-sql-managed-instance)

[6. Deepen your understanding with GitHub Copilot](#6-deepen-your-understanding-with-github-copilot)
* [6.1 Which migration options exist?](#61-which-migration-options-exist)
* [6.2 Which tools can assess my databases?](#62-which-tools-can-assess-my-databases)
* [6.3 Which target fits a rarely used database?](#63-which-target-fits-a-rarely-used-database)
* [6.4 Sizing, cost and licensing](#64-sizing-cost-and-licensing)
* [6.5 Downtime and cut-over strategy](#65-downtime-and-cut-over-strategy)
* [6.6 Features that are not part of the database](#66-features-that-are-not-part-of-the-database)
* [6.7 Networking and security for the migration](#67-networking-and-security-for-the-migration)
* [6.8 After the migration](#68-after-the-migration)

[Prompt cheat sheet](#prompt-cheat-sheet)

[Annotations](#annotations)

# Migration architecture and Azure components

![generated](../../Images/MigrationArchitecturev3.png)

# Generic Migration Content
| **Narrative**  | **Notes**  |
|:-----|:-------|
| *Notes for outside of the workshop:*  *Familiarise yourself with the new Microsoft migration capabilities with SQL Server Management Studio and Migration options by using Arc* | Migrate SQL Server to Azure SQL (SSMS): [https://learn.microsoft.com/en-us/ssms/migrate/migrate-sql-server-azure-sql?tabs=sql-standard](https://learn.microsoft.com/en-us/ssms/migrate/migrate-sql-server-azure-sql?tabs=sql-standard) This article covers the migration from Arc-Enabled SQL Server instances and Non Arc-Enabled SQL Server instances. For Non Arc-Enabled SQL Server instances there will be no performance-based sizing recommendation. |

# 1. Preparation

Before you start with the migration, you need to prepare your lab environment. You will connect to the lab machine, link your Azure and GitHub Copilot accounts, and connect to both the legacy SQL Server and the Azure SQL Managed Instance.

> ## ⚠️ WARNING - Only work with the databases of YOUR team!
>
> The legacy SQL Server and the Azure SQL Managed Instance are **shared with the other teams**. You will see the databases of all teams in Object Explorer.
>
> * 🚫 **Do NOT change, migrate, link, fail over, delete or otherwise touch databases of other teams.** This would break the challenge of the other team.
> * 🆔 **Know your team name before you start!** Your team name starts with **LABUSER-XXXX** (for example *LABUSER-0001*). It is part of your Entra ID user name and of the names of your databases.
> * ✅ **Before every action** (assessment, Managed Instance Link, failover, scripts) check that the selected databases carry **your** team name.
> * 🤖 **Review every Copilot proposal** (especially generated T-SQL scripts) for database names of other teams before you execute it.
>
> **If you are not sure what your team name is, ask your coach before you continue.**

## 1.1 Connect to your Win11 VM

|**Narrative**| **Screenshot**| **Notes**|
|:------------|:--------------|:---------|
|Connect to the Azure Portal with <secret group="Azure" name="Entra ID Username" show="true"></secret> and password <secret group="Azure" name="Entra ID TAP"></secret>.<br>In the Azure Portal open your Win11 VM <secret group="Lab-General" name="Team VM Name" show="true"></secret>.<br>Connect to the VM with Bastion with the following VM connection credentials Username <secret group="Lab-Credentials" name="VM User Name" show="true"></secret> and password <secret group="Lab-Credentials" name="VM User Password"></secret>.<br>Please make sure to select the correct keyboard language.|![Bastion Logon](../../Images/Bastion-VM11.png)| |
|On the Win11 VM you will find a shortcut for SQL Server Management Studio (SSMS).| ![Shortcuts](../../Images/shortcuts.png)| |
|Start SQL Server Management Studio (SSMS) from the Start menu or the desktop icon.|![SQL Server Management Studio](../../Images/SSMS%20start%20menu.png)|SQL Server Management Studio (SSMS) is a free download from Microsoft. Since SSMS 22.5 it supports the assessment and migration of SQL Server databases to Azure SQL and it has GitHub Copilot built in.|

## 1.2 Connect SSMS with your Azure and GitHub Copilot accounts

You need two accounts in SSMS: your **Azure account** (to select the Managed Instance during the migration) and your **GitHub account with a Copilot license** (to use the Copilot chat).

|**Narrative**| **Screenshot**| **Notes**|
|:------------|:--------------|:---------|
|In SSMS open the account settings and add your **Azure account**. Sign in with <secret group="Azure" name="Entra ID Username" show="true"></secret> and password <secret group="Azure" name="Entra ID TAP"></secret>.|![Add Azure account in SSMS](../../Images/Add_Azure_Account_00.png)|The Azure account is needed later to select the Managed Instance resource in the Managed Instance Link wizard.|
|Confirm that the Azure account and the subscription of the lab are shown in the account list.|![Azure account connected](../../Images/Add_Azure_Account_01.png)<br>![](../../Images/Add_Azure_Account_02.png)<br>![](../../Images/Add_Azure_Account_03.png)<br>![](../../Images/Add_Azure_Account_04.png)<br>![](../../Images/Add_Azure_Account_05.png)||
|Connect to GitHub in SSMS.|![](../../Images/Connect_Github.png)|**Note**: The GitHub credentials are provided during the Hack.|
|A browser window opens where you can enter your GitHub credentials.|![](../../Images/Github_Login.png)||
|Connect your account with Visual Studio. Click **Continue**.|![](../../Images/Github_Continue.png)||
|Authorize Visual Studio to connect with GitHub. Click **Authorize GitHub**.|![](../../Images/Github_Authorize.png)||
|Allow the website to open SQL Server Management Studio.|![](../../Images/Allow_to_open_SSMS.png)||
|GitHub is now connected with SSMS. You can now use the Copilot chat window.|![](../../Images/SSMS_Github_Chat.png)||

## 1.3 Connect to the legacy SQL Server

|**Narrative**| **Screenshot**| **Notes**|
|:------------|:--------------|:---------|
|In the **Connect to Server** dialog connect to **legacySQL2016**. Use **Windows Authentication** and check the **Trust server certificate** checkbox.|![Connect to legacySQL2016](../../Images/Connect_legacy_SQL_00.png)||
|In Object Explorer expand the **Databases** node. You should see the databases of your team.|![legacySQL2016 databases in Object Explorer](../../Images/Connect_legacy_SQL_01.png)|**⚠️ WARNING: Only work with the databases of your team (LABUSER-XXXX). Do NOT change the databases of other teams!**|

## 1.4 Connect to the Azure SQL Managed Instance

|**Narrative**| **Screenshot**| **Notes**|
|:------------|:--------------|:---------|
|Connect to your Azure SQL Managed Instance in the **Connect to Server** dialog. Use the Managed Instance host name, Entra MFA authentication and the Entra ID credentials of the lab.|![Connect to the Azure SQL Managed Instance](../../Images/Connect_SQLMI_00.png)<br>![](../../Images/Connect_SQLMI_01.png)<br>![](../../Images/Connect_SQLMI_02.png)|**Note**: The Managed Instance host name and the credentials are **Login:** **<secret group="Azure" name="Entra ID Username" show="true"></secret>** **TAP:**  **<secret group="Azure" name="Entra ID TAP"></secret>**. Check the **Trust server certificate** checkbox is optional here.|
|Both servers are now visible in Object Explorer. The Managed Instance does not contain your team databases yet.|![Object Explorer with legacy SQL Server and Managed Instance](../../Images/Connect_SQLMI_03.png)||

## 1.5 Say hello to GitHub Copilot

|**Narrative**| **Screenshot**| **Notes**|
|:------------|:--------------|:---------|
|Open the Copilot chat window and ask your first question to verify that everything works.|![](../../Images/SSMS_Github_Chat.png)|**Prompt**: *"How can I migrate my database from SQL Server to a Managed Instance?"*|

> **Copilot prompt suggestions in this walkthrough**
>
> Every section below contains a **Prompt** hint. You do not have to use the prompts word for word. Try your own variations, ask follow-up questions, and always **review what Copilot proposes before you execute it**.

# 2. Understand the migration path and assess the databases with GitHub Copilot

In this section we will use SQL Server Management Studio to assess the SQL Server instance databases for suitability for migration to Azure. Ask GitHub Copilot to explain the migration path and the assessment before and while you run it.

|**Narrative**| **Screenshot**| **Notes**|
|:------------|:--------------|:---------|
|Ask Copilot how the migration works.|![Copilot explains the migration path](../../Images/How_can_i_migrate_a_database_to_sqlmi.png)|**Prompt**: *"How can I migrate my database from SQL Server to a Managed Instance?"*|
|Ask Copilot what the migration assessment does before you run it.|![Copilot explains the migration assessment](../../Images/What_happens_during_the_migration_assessment.png)|**Prompt**: *"What exactly happens during the migration assessment?"*|
|We need to determine the suitability of the database(s) for migration to Azure. This includes checking for compatibility and feature support with Azure SQL. From the context menu of the **legacySQL2016** instance select **Migrate SQL Server**.|![Migrate SQL Server](../../Images/Migrate%20SQL%20Server.png)|If the context menu is not visible the Hybrid and Migration workload was not installed with SSMS.|
|This opens the main screen for the migration experience.|![Migrate SQL Server](../../Images/Migrate%20Screen.png)||
|Click **Run Readiness Assessment**.|![](../../Images/Run%20Readiness%20Assessment.png)|The assessment will take some seconds to minutes depending on the number of databases and the amount of database objects.|
|After the assessment completes we will see that only SQL Server on Azure Virtual Machine is available as a possible migration target.|![](../../Images/AssessmentResult01.png)||
|Click **View Details** to examine why the migration to Azure SQL Managed Instance will not work for your team databases.|||
|On the detail view you can see which objects are not ready for migration.|![](../../Images/AssessmentResultDetails01.png)||
|Select the **Compatibility Findings**. This will show why the instance cannot be migrated to Azure SQL Managed Instance.|![](../../Images/AssessmentResultDetails02.png)|**Note**: This problem seems to be solvable.|
<!--|Ask Copilot to explain the findings and to help you with the next step.|![Copilot explains the compatibility findings](../../Images/Help_me_remove_blocker_00.png)<br>![](../../Images/Help_me_remove_blocker_01.png)|**Prompt**: *"Can you analyze the blockers for the migration to SQL MI from the latest migration assessment \<add path to html file\> and help me to remove them?"*|-->

# 3. Remove the migration blockers with GitHub Copilot

In this section we will leverage GitHub Copilot to mitigate the migration blockers for the databases from SQL Server to Azure SQL Managed Instance.

|**Narrative**| **Screenshot**| **Notes**|
|:------------|:--------------|:---------|
|Use a prompt similar to the following: *The migration assessment tells me that I cannot migrate to Managed Instance. Can you analyze the blockers and give me instructions how I will be able to migrate to MI? "C:\Users\DemoUser\AppData\Local\Microsoft\SqlAssessment\SqlAssessment-LegacySQL2016-202608121317html"* |![](../../Images/Github_Prompt_Challenge01.png)|**Prompt**: *"Can you analyze the blockers for the migration to SQL MI and help me to remove them?"* You can also add the path of the assessment report to the prompt as shown here.|
|GitHub requests access to the provided assessment report. Please approve access.|![](../../Images/Github_Approve_Access_to_assessment_report.png)|**Note**: The access requests could occur several times.|
|GitHub identified the blocker and generates commands to mitigate the blocker.|![](../../Images/Github_Identifies_Blocker01.png)||
||![](../../Images/Github_Identifies_Blocker02.png)||
||![](../../Images/Github_Identifies_Blocker03.png)||
|You can copy over the commands to a query window to remove the migration blocker. Review the commands before you execute them.|![](../../Images/Github_Identifies_Blocker04.png)|**Hint**: If the database is in Full Recovery Model it might be easier to put the database into Simple Recovery Model, remove the second ldf file, and finally turn the database back into Full Recovery Model. Ask Copilot to generate the script for you.|
|After you removed the migration blocker run the assessment again. Azure SQL Managed Instance should now be a possible migration target without any compatibility blocker.|![](../../Images/AssessmentResult02.png)|**Prompt**: *"I removed the blocker. What should I check before I run the assessment again?"*|

**We are now ready to migrate the application databases to Azure SQL Managed Instance.**

# 4. Migrate the application databases to Azure SQL Managed Instance

In this section we will use SQL Server Management Studio (SSMS) to migrate the application databases to Azure SQL Managed Instance by using Managed Instance Link. Keep the Copilot chat open to ask questions about every wizard page.

|**Narrative**| **Screenshot**| **Notes**|
|:------------|:--------------|:---------|
|Ask Copilot what Managed Instance Link is and how the migration with minimal downtime works.|![Copilot explains Managed Instance Link](../../Images/What_is_MILink.png)|**Prompt**: *"How does the migration with Managed Instance Link work and what are the steps for the cut-over?"*|
|On the central migration experience in SSMS you can now select **Migrate Data** and select the option **Managed Instance Link**.|![](../../Images/Migrate_with_MI_Link.png)| **Note**: Managed Instance Link offers the option for a migration with minimal downtime. You create the Managed Instance Link first. Then you wait until the databases are synchronized. And finally you do the cut-over.|
|On the first screen of the Managed Instance Link Wizard please provide your team name (**LABUSER-XXXX**) to better distinguish between the migration objects.|![](../../Images/MILink-Wizard01.png)|**⚠️ WARNING**: Use exactly your own team name. Do not use or change the migration objects of other teams.|
|The Managed Instance Link will check for MI Link readiness of the instance.|![](../../Images/MILink-Wizard02.png)|**Note**: The mentioned Trace Flags will make sure that the migration performance is good enough during the migration. The requirements and limitations for Managed Instance Link are listed here [https://learn.microsoft.com/en-us/azure/azure-sql/managed-instance/managed-instance-link-feature-overview?view=azuresql#limitations](https://learn.microsoft.com/en-us/azure/azure-sql/managed-instance/managed-instance-link-feature-overview?view=azuresql#limitations).<br>**Prompt**: *"The Managed Instance Link readiness check shows trace flags. What do they do and do I have to change anything?"*|
|Select only the databases of your team. The databases can only be connected to one MI Link.|![](../../Images/MILink-Wizard03.png)|**⚠️ WARNING**: Select ONLY databases that belong to your team (**LABUSER-XXXX**). Never select databases of other teams.|
|Next add the SQL Managed Instance as a secondary replica.|![](../../Images/MILink-Wizard04.png)||
|You need to connect to Azure to select the SQL Managed Instance resource. In addition you need to connect to the Managed Instance itself.|![](../../Images/MILink-Wizard05.png)|**Note**: The credentials are provided during the Hack. You already connected both accounts in the preparation section.|
|The Wizard connects to the Managed Instance and checks the Managed Instance for compatibility. Click **Next**.|![](../../Images/MILink-Wizard06.png)||
|You will receive a final summary and an option to generate a script. Click **Finish**.|![](../../Images/MILink-Wizard07.png)|**Prompt**: *"Please explain the generated MI Link script step by step."*|
|The wizard creates MI Links for all selected databases.|![](../../Images/MILink-Wizard08.png)|**Note**: This process can take a long time if many databases are involved.|
|The databases are connected to MI Link.|<!--![](../../Images/MILink-Wizard09.png)-->||
|After the Link was established wait until the databases are synchronized.|![](../../Images/check_MILink_Sync.png)|**Prompt**: *"How can I check whether my databases are fully synchronized to the Managed Instance? Please use the T-SQL script from the annotations as a starting point."*|
|You will see multiple availability groups for every database. This is normal.|![](../../Images/MILink_AG_View.png)||
|For the cut-over stop the application connectivity to the legacy SQL Server and do the failover.|||
|For every database of your team use the context menu on the source legacy SQL Server and select **Azure SQL Managed Instance Link**->**Failover...**.|![](../../Images/MILink_Failover.png)||
|The Managed Instance Link Failover Wizard will check all prerequisites.|![](../../Images/MILink_Failover_Wizard01.png)||
|If the database is healthy we can only do a Planned Manual Failover. Click **Next**.|![](../../Images/MILink_Failover_Wizard02.png)|**Prompt**: *"What is the difference between a planned manual failover and a forced failover in Managed Instance Link?"*|
|We have to sign in to Azure and to the Managed Instance again. Click **Next**.|![](../../Images/MILink_Failover_Wizard03.png)||
|The Wizard checks the readiness for the failover. All looks good. Click **Next**.|![](../../Images/MILink_Failover_Wizard04.png)||
|Please acknowledge that you should stop application connectivity against the source database and select that the wizard will remove the distributed availability group.|![](../../Images/MILink_Failover_Wizard05.png)|**Note**: After this step you will have two writable copies of the databases on the legacy server and on the Managed Instance.|
|Click **Next**.|![](../../Images/MILink_Failover_Wizard06.png)||
|You will see a final summary and have the last option to generate a script. Click **Finish**.|<!--![](../../Images/MILink_Failover_Wizard07.png)-->||
|The failover was successful.|<!--![](../../Images/MILink_Failover_Wizard08.png)-->||
|The database is no longer member of the distributed availability group.|![](../../Images/DB_RemovedFrom_AG.png)||

# 5. Confirm the application databases have been migrated to Azure SQL Managed Instance

|**Narrative**| **Screenshot**| **Notes**|
|:------------|:--------------|:---------|
|In Object Explorer refresh the Managed Instance connection and expand **Databases**. The databases of your team must now be listed and online.|![Migrated databases on the Managed Instance](../../Images/MI_Migrated_Databases.png)||
|Ask Copilot to help you with a final check of the migration.|![Copilot verifies the migration](../../Images/Copilot_Verify_Migration.png)|**Prompt**: *"Which checks should I run on the Managed Instance to confirm that my databases have been migrated successfully?"*|

**Congratulations! You have migrated your application databases to Azure SQL Managed Instance with the help of GitHub Copilot.**

# 6. Deepen your understanding with GitHub Copilot

You have migrated with one specific path. In real projects you have to decide **which target, which method and which tool** fit your workload. This optional section contains prompts that help you to understand the whole picture. No screenshots are needed. Just ask, read the answer critically, and ask follow-up questions.

> **Tips for good answers**
>
> * Give Copilot your context: database size, downtime window, SQL Server version, features in use, budget.
> * Ask for **tables and comparisons** instead of long text.
> * Ask Copilot to name the **official Microsoft documentation** for its statements. Migration tools and offerings change quickly, and some tools have been retired. Always verify tool names, availability and limits in the current documentation.
> * Copilot in SSMS has access to your connected database. Prompts that mention *"my database"* or *"the connected instance"* can use real metadata, for example the size or the features in use.

## 6.1 Which migration options exist?

|**Narrative**| **Prompt and what you should learn**|
|:------------|:------------------------------------|
|Get the big picture of the possible targets.|**Prompt**: *"Which Azure targets exist for a SQL Server database (Azure SQL Database, Azure SQL Managed Instance, SQL Server on Azure VM)? Compare them in a table by compatibility, administration effort, features, scalability and typical use cases."*<br>**Learn**: PaaS versus IaaS, and why compatibility decreases from VM to Managed Instance to Azure SQL Database.|
|Get an overview of the migration methods.|**Prompt**: *"Which methods exist to migrate a SQL Server database to Azure SQL Managed Instance? Compare backup and restore, Log Replay Service, Managed Instance Link, Azure Database Migration Service, BACPAC and transactional replication in a table by downtime, database size, complexity and rollback options."*<br>**Learn**: Online versus offline migration, and which method supports a rollback.|
|Understand the difference between online and offline.|**Prompt**: *"Explain the difference between an online and an offline migration. Which one do I choose if my application can tolerate a downtime of 4 hours, and which one if it can only tolerate a few minutes?"*|
|Understand why the lab uses Managed Instance Link.|**Prompt**: *"Why is Managed Instance Link a good choice for a migration with minimal downtime? What are the prerequisites and limitations compared with Log Replay Service?"*|
|Learn the options if the target is Azure SQL Database.|**Prompt**: *"Which migration methods are available if the target is Azure SQL Database instead of Managed Instance? Why can I not restore a native .bak file there?"*<br>**Learn**: Azure SQL Database has no native restore. Typical methods are BACPAC/DACPAC, Azure Database Migration Service and transactional replication.|
|Learn the options if the target is a VM.|**Prompt**: *"When is SQL Server on an Azure VM the better migration target than Managed Instance? Which methods can I use to migrate to it?"*<br>**Learn**: OS access, unsupported features, third-party software and very old or very specific configurations.|
|Understand the 6 Rs of cloud migration.|**Prompt**: *"Explain rehost, replatform, refactor, rearchitect, rebuild and retire for databases. Where do the three Azure SQL targets fit in?"*|
|Find the right method for your situation.|**Prompt**: *"I have a 2 TB SQL Server 2016 database with 30 minutes of tolerated downtime and a 1 Gbit/s connection to Azure. Which migration method do you recommend and why? Please list the alternatives and their trade-offs."*<br>**Learn**: How a recommendation depends on size, bandwidth and downtime.|

## 6.2 Which tools can assess my databases?

|**Narrative**| **Prompt and what you should learn**|
|:------------|:------------------------------------|
|Get an overview of the assessment tools.|**Prompt**: *"Which tools exist today to assess SQL Server databases for a migration to Azure? Compare the migration experience in SSMS, Azure Migrate, Azure Arc, the Azure SQL migration extension for Azure Data Studio and Data Migration Assistant in a table by scope (single instance versus whole estate), SKU recommendation, output and current support status."*<br>**Learn**: Some tools are for one instance, others for hundreds of servers. Check the support status, because some tools have been retired or replaced.|
|Understand what an assessment checks.|**Prompt**: *"Which categories of findings does a migration assessment report (blockers, warnings, informational)? Give me examples for Azure SQL Managed Instance and tell me which category must be fixed before the migration."*|
|Understand the difference between assessment and SKU recommendation.|**Prompt**: *"What is the difference between a readiness assessment and a SKU recommendation? Which data does the SKU recommendation need and why is it more precise for Arc-enabled SQL Servers?"*<br>**Learn**: See the note at the top of this walkthrough. Without Azure Arc there is no performance-based sizing recommendation.|
|Assess a whole estate.|**Prompt**: *"I have 200 SQL Server instances in different data centers. Which tool should I use for discovery and assessment, and how do I collect performance data for sizing?"*|
|Find compatibility issues with T-SQL.|**Prompt**: *"Which T-SQL features and settings commonly block a migration to Azure SQL Managed Instance? Give me a checklist and the T-SQL queries to check for them on my connected instance."*|
|Use Copilot to read an assessment report.|**Prompt**: *"Summarize the migration assessment report <path to the report> in a table with the columns finding, severity, affected object and recommended action. Sort by severity."*|
|Plan the next steps after the assessment.|**Prompt**: *"Based on this assessment result, create a migration checklist with the steps before, during and after the migration."*|
|Check what Copilot does not know.|**Prompt**: *"Which statements in your previous answer might be outdated and should I verify in the current Microsoft documentation?"*|

## 6.3 Which target fits a rarely used database?

|**Narrative**| **Prompt and what you should learn**|
|:------------|:------------------------------------|
|Ask the direct question.|**Prompt**: *"My database is used only a few hours per week. Which Azure SQL target is the most cost-efficient one and why? Compare Azure SQL Database serverless, Azure SQL Database provisioned, Azure SQL Managed Instance and SQL Server on Azure VM."*<br>**Learn**: Serverless compute bills per second of usage and can pause automatically. A Managed Instance or a VM is billed for the provisioned resources, even if nobody uses the database.|
|Understand serverless.|**Prompt**: *"Explain the Azure SQL Database serverless compute tier: auto-pause, auto-resume, minimum and maximum vCores, and what the first connection after a pause feels like for my application."*<br>**Learn**: The resume delay after a pause, and that connection retry logic is required.|
|Understand the limits of serverless.|**Prompt**: *"What are the limitations of Azure SQL Database serverless? In which cases is it not a good fit, for example with constantly running background jobs or long-running connections?"*|
|Compare costs.|**Prompt**: *"Give me a cost comparison for a 50 GB database that is active 10 hours per week on serverless, provisioned General Purpose and Managed Instance. Please explain your assumptions and point me to the Azure pricing calculator."*<br>**Note**: Treat the numbers as an estimate. Always validate them with the Azure pricing calculator.|
|Consider many small databases.|**Prompt**: *"I have 40 small databases that are rarely used and have different peak times. When is an elastic pool the better choice than one serverless database per application?"*|
|Check if the database fits the target.|**Prompt**: *"Which features of my connected database would prevent a migration to Azure SQL Database, for example cross-database queries, SQL Agent jobs, linked servers or CLR? Please check the connected instance."*<br>**Learn**: The cheapest target is only an option if the database uses no features that are exclusive to Managed Instance or the VM.|
|Consider the trade-off between price and effort.|**Prompt**: *"If a rarely used database requires code changes to move to Azure SQL Database, is it worth it compared with a small Managed Instance? Which questions should I ask before I decide?"*|
|Reduce costs on the lab target.|**Prompt**: *"Which options do I have to reduce the costs of a Managed Instance that is used rarely? Think about instance pools, service tiers, stopping the instance and reserved capacity, and tell me which ones apply to which tier."*|
|Consider archive and decommissioning.|**Prompt**: *"If a database is almost never used and only kept for compliance, what are cheaper alternatives than a running database, for example a backup with long-term retention or an export to storage?"*|

## 6.4 Sizing, cost and licensing

|**Narrative**| **Prompt and what you should learn**|
|:------------|:------------------------------------|
|Understand the sizing basics.|**Prompt**: *"How do I size an Azure SQL Managed Instance? Explain vCores, memory per vCore, storage and the difference between General Purpose and Business Critical for my connected instance."*|
|Collect the right performance data.|**Prompt**: *"Which performance counters and metrics should I collect on the source server, and for how long, to get a reliable SKU recommendation?"*|
|Reduce license costs.|**Prompt**: *"Explain Azure Hybrid Benefit and reserved capacity for Azure SQL Managed Instance. How much can I save and which conditions must I fulfil?"*|
|Plan the budget.|**Prompt**: *"Which cost components besides compute and storage should I plan for a migration, for example backup storage, network traffic, monitoring and the migration tools themselves?"*|

## 6.5 Downtime and cut-over strategy

|**Narrative**| **Prompt and what you should learn**|
|:------------|:------------------------------------|
|Estimate the downtime.|**Prompt**: *"How do I estimate the downtime for the cut-over with Managed Instance Link? Which steps does the downtime consist of, and how can I reduce it?"*|
|Plan the cut-over.|**Prompt**: *"Create a cut-over runbook for a Managed Instance Link migration. Include the steps before, during and after the failover, the responsible roles and the checks after each step."*|
|Plan the rollback.|**Prompt**: *"What is my rollback option if the application does not work after the cut-over to the Managed Instance? Is it possible to fall back to the legacy SQL Server and what data would I lose?"*<br>**Learn**: After the planned failover and the removal of the distributed availability group, both copies are writable. Plan the rollback before you start.|
|Reduce the risk.|**Prompt**: *"Which risks exist in a database migration and which mitigations do you recommend? Please present them as a risk table with probability, impact and mitigation."*|
|Test before you migrate.|**Prompt**: *"How can I test my application against the Managed Instance before the final cut-over without losing data or stopping the source?"*|

## 6.6 Features that are not part of the database

A database migration is more than moving the data. Many dependencies live outside the user database.

|**Narrative**| **Prompt and what you should learn**|
|:------------|:------------------------------------|
|Find instance-level objects.|**Prompt**: *"Which objects live outside of my user databases on the connected instance and must be migrated separately, for example logins, SQL Agent jobs, linked servers, credentials, server triggers and database mail? Please give me queries to list them."*|
|Migrate logins and permissions.|**Prompt**: *"How do I migrate SQL logins and Windows logins to Azure SQL Managed Instance? What changes with Microsoft Entra authentication?"*|
|Migrate jobs.|**Prompt**: *"How do I migrate SQL Server Agent jobs to Managed Instance and which job step types are not supported?"*|
|Handle cross-database dependencies.|**Prompt**: *"Does my database have cross-database queries or dependencies to other databases or linked servers? What do I have to consider if only some of the databases are migrated?"*|
|Handle SSIS, SSRS and SSAS.|**Prompt**: *"What are the Azure alternatives for SSIS, SSRS and SSAS if the target is Azure SQL Managed Instance?"*|

## 6.7 Networking and security for the migration

|**Narrative**| **Prompt and what you should learn**|
|:------------|:------------------------------------|
|Understand the network requirements.|**Prompt**: *"Which network connectivity do I need between my on-premises SQL Server and the Managed Instance for Managed Instance Link? Which ports and which connection options such as VPN or ExpressRoute can I use?"*|
|Protect data in transit and at rest.|**Prompt**: *"How is the data protected during the migration with Managed Instance Link and at rest on the Managed Instance? What about TDE and customer-managed keys?"*|
|Plan the access.|**Prompt**: *"Which Azure roles and database permissions do I need to perform the migration, and how do I follow the least privilege principle?"*|
|Plan the post-migration security.|**Prompt**: *"After the migration, which security settings should I check first on the Managed Instance, for example authentication mode, public endpoint, auditing and Defender for SQL?"*<br>**Note**: Challenge 3 covers this topic in detail.|

## 6.8 After the migration

|**Narrative**| **Prompt and what you should learn**|
|:------------|:------------------------------------|
|Check the compatibility level.|**Prompt**: *"Which database compatibility level does my migrated database have, and should I change it? What is the safe way to do that with Query Store?"*|
|Update statistics and verify the performance.|**Prompt**: *"Which steps should I run after the migration to avoid performance regressions, for example updating statistics, enabling Query Store and comparing the baseline?"*<br>**Note**: Challenge 2 covers this topic in detail.|
|Plan backups and high availability.|**Prompt**: *"How are backups, point-in-time restore and long-term retention handled on Managed Instance? What do I have to configure myself compared with my legacy server?"*|
|Decommission the source.|**Prompt**: *"When and how should I decommission the legacy SQL Server after a successful migration? Create a checklist with the final backup, the access removal and the retention of evidence."*|
|Learn from the migration.|**Prompt**: *"Summarize our migration as lessons learned: which decisions did we make, what could have gone wrong and what would you do differently in the next migration?"*|

# Prompt cheat sheet

| Goal | Example prompt |
|:-----|:---------------|
| Start the conversation | *"How can I migrate my database from SQL Server to a Managed Instance?"* |
| Understand the assessment | *"What exactly happens during the migration assessment?"* |
| Analyze blockers | *"Can you analyze the blockers for the migration to SQL MI and help me to remove them?"* |
| Fix safely | *"Show me the scripts to remove the blocker and explain the impact, but do not execute anything."* |
| Compare targets | *"Compare Azure SQL Database, Azure SQL Managed Instance and SQL Server on Azure VM in a table by compatibility, administration effort and cost."* |
| Compare methods | *"Compare backup and restore, Log Replay Service, Managed Instance Link and Azure Database Migration Service by downtime, size and rollback options."* |
| Compare assessment tools | *"Which tools exist today to assess SQL Server for a migration to Azure and what is their current support status?"* |
| Choose a target for a rarely used database | *"My database is used only a few hours per week. Which Azure SQL target is the most cost-efficient and why?"* |
| Check feature compatibility | *"Which features of my connected database would prevent a migration to Azure SQL Database?"* |
| Size the target | *"How do I size an Azure SQL Managed Instance for my connected instance?"* |
| Plan the cut-over | *"Create a cut-over runbook for a Managed Instance Link migration including checks and rollback."* |
| Find hidden dependencies | *"Which objects live outside of my user databases and must be migrated separately?"* |
| Explain a wizard step | *"Please explain the generated MI Link script step by step."* |
| Verify the migration | *"Which checks should I run on the Managed Instance to confirm that my databases have been migrated successfully?"* |
| Verify Copilot's answer | *"Which statements in your previous answer might be outdated and should I verify in the current Microsoft documentation?"* |


# Annotations
### T-SQL script to check distributed AG status
``` SQL 
SELECT
    DB_NAME(drs.database_id) AS DatabaseName,
    drs.synchronization_state_desc,
    drs.synchronization_health_desc,
    drs.is_commit_participant,
    drs.log_send_queue_size,
    drs.redo_queue_size,
    drs.last_commit_time
FROM sys.dm_hadr_database_replica_states drs
WHERE 1=1 --AND DB_NAME(drs.database_id) LIKE 'TEAM01%'
ORDER BY DatabaseName;
````
