# Walkthrough Challenge 1 - Assessment and migration with SQL Server Management Studio (SSMS)

**[Home](../../Readme.md)** - [Next Challenge Solution](../challenge-02/solution-02.md)

## Assessment and migration with SQL Server Management Studio (SSMS)

### Contents

[Migration architecture and Azure components](#migration-architecture-and-azure-components)

[Generic Migration Content](#generic-migration-content)

[1. Connect to your Win11 VM](#connect-to-your-win11-vm)

[2. Assess the application databases for Azure SQL suitability using the SQL Server Management Studio (SSMS)](#assess-the-application-databases-for-azure-sql-suitability-using-the-sql-server-management-studio-ssms)

[3. Migrate the application databases to Azure SQL Managed Instance using SQL Server Management Studio (SSMS)](#migrate-the-application-databases-to-azure-sql-managed-instance-using-sql-server-management-studio-ssms)

[4. Confirm application databases have been migrated to Azure SQL Managed Instance](#confirm-application-databases-have-been-migrated-to-azure-sql-managed-instance)

[5. Optional: Leverage Github Copilot to remove migration blockers](#optional-leverage-github-copilot-to-remove-migration-blockers)

# Migration architecture and Azure components 

![generated](../../Images/MigrationArchitecturev2.png)

# Generic Migration Content

| **Narrative**  | **Notes**  |
|:-----|:-------|
| *Notes for outside of the workshop:*  *Familiarise yourself with the new Microsoft migration capabilities with SQL Server Management Studio and Migration options by using Arc* | Migrate SQL Server to Azure SQL (SSMS): [https://learn.microsoft.com/en-us/ssms/migrate/migrate-sql-server-azure-sql?tabs=sql-standard](https://learn.microsoft.com/en-us/ssms/migrate/migrate-sql-server-azure-sql?tabs=sql-standard) This article covers the migration from Arc-Enabled SQL Server instances and Non Arc-Enabled SQL Server instances. For Non Arc-Enabled SQL Server instances there will be no performance-based sizing recommendation. |

# Connect to your Win11 VM
|**Narrative**| **Screenshot**| **Notes**|
|:------------|:--------------|:---------|
|The instructors will share URLs to connect to your Win11 VM. Credentials will be provided during the Hack.|![Bastion Logon](<../../Images/Bastion-VM11.png>)| |



|**Narrative**| **Screenshot**| **Notes**|
|:------------|:--------------|:---------|
| On the Win11 VM you will find a shortcurt for SQL Server Management Studio (SSMS) and a readme.txt that comtains the information about the lab environment | ![Shortcuts](<../../Images/shortcuts.png>)

# Assess the application databases for Azure SQL suitability using the SQL Server Management Studio (SSMS)

In this section we will use the SQL Server Management Studio to assess the SQL Server instance databases for suitability for migration to Azure Cloud.

|**Narrative**| **Screenshot**| **Notes**|
|:------------|:--------------|:---------|
|We need to determine the suitability of the database(s) for migration to Azure. This includes checking for compatibility and feature support with Azure Database. You should already have a remote (Bastion) session open to your teams Win11 Management VM**,** if so run SSMS from the Start menus or Desktop icon.|![SQL Server Management Studio](<../../Images/SSMS start menu.png>)|SQL Server Management Studio (SSMS) is a free download from Microsoft. Since SSMS 22.5 it supports the assessment and migration of SQL Server databases to Azure SQL.|
|Connect to legacySQL2016 by using Wndows Authentivation. Please check the Trust Server Certifcate checkbox|||
|From the context menu of the SQL Server instance select Migrate SQL Server|![Migrate SQL Server](../../Images/Migrate%20SQL%20Server.png)|If the context menu is not visible the Hybrid and Migration workload was not installed with SSMS |
|This opens the main screen for the migration experience|![Migrate SQL Server](../../Images/Migrate%20Screen.png)||
|Click  **Run Readiness Assessment**|![](../../Images/Run%20Readiness%20Assessment.png)|The assessment will take some seconds to minutes depending on the number of databases and the amount of database objects.|
|After the assessment completes we will see that only SQL Server on Azure Virtual Machine will be available as possible migration target|![](../../Images/AssessmentResult01.png)|||
|Click on **View Details** to examine why the migration to Azure SQL Managed Instance will not work for your team databases.|||
|On the detail view you can see which objects are not ready for migration|![](../../Images/AssessmentResultDetails01.png)||
|Select the **Compatibility Finindings**. This will show why the instance cannot be migrated to Azure SQL Managed Instance|![](../../Images/AssessmentResultDetails02.png)|**Note**: This problem seems to be solvable.|
|Remove the second ldf file. **Hint**: If the database is in Full Recovery Model it might be easier to put the database into Simple Recovery Model, remove the ldf file, and finally turn the database back into Full Recovery Model.|||
|After you removed the migration blocker run the assessment again. Azure SQL Managed Instance should now be a possible migration target without any compatibility blocker.|![](../../Images/AssessmentResult02.png)||

**We are now ready to migrate the application databases to Azure SQL Database Managed Instance**


# Migrate the application databases to Azure SQL Managed Instance using SQL Server Management Studio (SSMS)

In this section we will use SQL Server Management Studio (SSMS) to migrate the application databases to Azure SQL Managed Instance by using Managed Instance Link.   

|**Narrative**| **Screenshot**| **Notes**|
|:------------|:--------------|:---------|
|On the central migration experience in SSMS you can now select **Migrate Data** and selecting the option **Managed Instance Link** .|![](../../Images/Migrate_with_MI_Link.png)| **Note**: Managed Instance Link offers the option for a migration with minimal downtime. You create the Managed Instance Link first. Then you wait until the databases are synchronized. And finally you do the cut-over.|
|On the first screen of the Managed Instance Link Wizard please provide your team name to better distinguish between the migration objects|![](../../Images/MILink-Wizard01.png)||
|The Managed Instance Link will check for MI Link readiness of the instance|![](../../Images/MILink-Wizard02.png)|**Note**: The mentioned Trace Flags will make sure that the migration performance is good enough during the migration. The requirements and limitation for Managed Instance Link are listed here [https://learn.microsoft.com/en-us/azure/azure-sql/managed-instance/managed-instance-link-feature-overview?view=azuresql#limitations](https://learn.microsoft.com/en-us/azure/azure-sql/managed-instance/managed-instance-link-feature-overview?view=azuresql#limitations).|
|Select only the databases of your team. The databases can only be connected to one MI Link|![](../../Images/MILink-Wizard03.png)||
|Next add the SQL Server Managed Instance as a secondary replica.|![](../../Images/MILink-Wizard04.png)||
|You need to connect to Azure to select the SQL Managed Instance resource. In addition you need to connect to the Managed Instance itself.|![](../../Images/MILink-Wizard05.png)|**Note**; The credentials are being provided during the Hack.|
|The Wizard connects to the Managed Instance and checks the Managed Instance for compatibility. Click **Next** |![](../../Images/MILink-Wizard06.png)||
|You will receive a final summary and an option to generate a script. Click **Finish** |![](../../Images/MILink-Wizard07.png)||
|The wizard creates MI Links for all selected databases.|![](../../Images/MILink-Wizard08.png)|**Note**: This process can take a long time if many databases are involved.|
|The databasee are connected to MI Link.|![](../../Images/MILink-Wizard09.png)||
|After the Link was established wait until the databases are synchronized.|![](../../Images/check_MILink_Sync.png)||
|You will see multiple availability groups for every databases. This is notmal.|![](../../Images/MILink_AG_View.png)||
|For the cut-over stop the application connectivity to the legacy SQL Server and do the failover.|||
|For every database of your team use the context menu on the source legacy SQL Server and select **Azure SQL Managed Instance Link**->**Failover...**.|![](../../Images/MILink_Failover.png)||
|The Managed Instance Link Failover Wizard will check all prerequisites.|![](../../Images/MILink_Failover_Wizard01.png)||
|If the database is healthy we can only do a Planned Manuel Failover. Click **Next**.|![](../../Images/MILink_Failover_Wizard02.png)||
|We have to sign in to Azure and to the Managed Instance again. Click **Next**.|![](../../Images/MILink_Failover_Wizard03.png)||
|The Wizard checks the readiness for the failover. All looks good. Click **Next**.|![](../../Images/MILink_Failover_Wizard04.png)||
|Please aknowledge that you should stop application connectivity against the source database and select that the wizard will remove the distributed availability group.|![](../../Images/MILink_Failover_Wizard05.png)|**Note**: After this step you will have two writable copies of the databases on the legacy server and on the Managed Instance.|
|Click **Next**.|![](../../Images/MILink_Failover_Wizard06.png)||
|You will see a final summary and have the last option to generate a script. Click **Finish**.|![](../../Images/MILink_Failover_Wizard07.png)||
|The Failover was successful.|![](../../Images/MILink_Failover_Wizard08.png)||
|The database is no longer member of the distributed availability group.|![](../../Images/DB_RemovedFrom_AG.png)||


# Confirm application databases have been migrated to Azure SQL Managed Instance

# Optional: Leverage Github Copilot to remove migration blockers

In this section we will leverage Github Cpoliot to mitigate migration blockers for databases from SQL Server to SQL Azure Managed Instance.

|**Narrative**| **Screenshot**| **Notes**|
|:------------|:--------------|:---------|
|Connect to Github.|![](../../Images/Connect_Github.png)|**Note**: The credentials are provided during the Hack.|
|A browser window open where you can enter your credentials|![](../../Images/Github_Login.png)||
|Connect your account with Visual Studio. Click **Continue**.|![](../../Images/Github_Continue.png)||
|Authorize Visual Studio to connect with Github. Click **authorize github**|![](../../Images/Github_Authorize.png)||
|Allow the website to open SQL Server Management Studio|![](../../Images/Allow_to_open_SSMS.png)||
|Github is now connected with SSMS. You can now use the chat function|![](../../Images/SSMS_Github_Chat.png)||
|Use a prompt similar to the following: *The migration assessment tells me that I cannot migrate to Managed Instance. Can you give me instructions how I will be able to migrate to MI? "C:\Users\DemoUser\AppData\Local\Microsoft\SqlAssessment\SqlAssessment-LegacySQL2016-202608121317html"* |![](../../Images/Github_Prompt_Challenge01.png)||
|Github requests access to the provided assessment report. Please approve access.|![](../../Images/Github_Approve_Access_to_assessment_report.png)|**Note**: The access requests could occur several times.|
|Github identified the blocker and generates commands to mitigate the blocker.|![](../../Images/Github_Identifies_Blocker01.png)||
||![](../../Images/Github_Identifies_Blocker02.png)||
||![](../../Images/Github_Identifies_Blocker03.png)||
|You can copy over the commands to query window to remove the migration block.|![](../../Images/Github_Identifies_Blocker04.png)||


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
WHERE DB_NAME(drs.database_id) LIKE 'TEAM01%'
ORDER BY DatabaseName;
````