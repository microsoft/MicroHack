# Walkthrough Challenge 3 - Security on Azure SQL Managed Instance with GitHub Copilot

[Previous Challenge Solution](../challenge-02/solution-02.md) - **[Home](../../Readme.md)**

## Security on Azure SQL Managed Instance with GitHub Copilot

In this challenge **GitHub Copilot is your security assistant**. You will start with a security review of your database, then walk through the layers of the Azure SQL security model (data classification, vulnerability assessment, threat protection), and finally fix a real vulnerability in a stored procedure. In every section Copilot helps you to understand, analyze and mitigate, and the Azure Portal and SSMS help you to verify the results.

### Table of Contents

[1. Introduction](#1-introduction)

[2. Preparation](#2-preparation)
* [2.1 Lab details](#21-lab-details)
* [2.2 Connect to the Managed Instance](#22-connect-to-the-managed-instance)
* [2.3 Open the GitHub Copilot chat](#23-open-the-github-copilot-chat)

[3. Get a first security overview with GitHub Copilot](#3-get-a-first-security-overview-with-github-copilot)

[4. Data Discovery & Classification](#4-data-discovery--classification)

[5. Azure Defender for SQL: Vulnerability Assessment](#5-azure-defender-for-sql-vulnerability-assessment)

[6. Azure Defender for SQL: Advanced Threat Protection](#6-azure-defender-for-sql-advanced-threat-protection)

[7. Fix the SQL injection vulnerability with GitHub Copilot](#7-fix-the-sql-injection-vulnerability-with-github-copilot)

[8. Deepen your understanding with GitHub Copilot](#8-deepen-your-understanding-with-github-copilot)
* [8.1 The security model and shared responsibility](#81-the-security-model-and-shared-responsibility)
* [8.2 Authentication and authorization](#82-authentication-and-authorization)
* [8.3 Protecting data](#83-protecting-data)
* [8.4 Network security](#84-network-security)
* [8.5 Auditing and threat detection](#85-auditing-and-threat-detection)
* [8.6 Compliance and governance](#86-compliance-and-governance)
* [8.7 Secure development](#87-secure-development)
* [8.8 Incident response and recovery](#88-incident-response-and-recovery)

[Prompt cheat sheet](#prompt-cheat-sheet)

# 1. Introduction

This hands-on lab introduces you to the layered security model available when running databases in Azure. The activities within this hands-on lab will progress from the outer security layers that protect the perimeter of Azure SQL through to the inner layers that protect the information contained within the data.

![](../../Images/e978dd39c792bae310e16883257d560c.png)

Because SQL Managed Instance always runs in a private network the Network Security layer has already been implemented at the vNet level. Equally we have already defined and implemented Azure AD and SQL Server logins, roles and permissions so the Access Management tier has also been pre-built.

So this lab will focus on the Threat Protection, Information Protection and Customer Data layers of the security model and how these are implemented in Azure SQL Managed Instance through:

- Data Discovery & Classification
- Azure Defender for SQL
  - Vulnerability Assessment
  - Advanced Threat Protection

# 2. Preparation

## 2.1 Lab details

The labs run against the **\<Team\>_TenantDataDb** database that you migrated earlier using  SQL Server Management Studio. The Copilot security review in sections 3 and 7 uses the shared **TenantCRM** database.

## 2.2 Connect to the Managed Instance

|**Narrative/Instructions**| **Screenshot**| **Notes**|
|:------------|:--------------|:---------|
|On your Team Win11 VM open **SQL Server Management Studio (SSMS)** and connect to the Azure SQL Managed Instance XXXXXX. **Authentication: Microsoft Entra MFA** **Login:** **<secret group="Azure" name="Entra ID Username" show="true"></secret>** **TAP:**  **<secret group="Azure" name="Entra ID TAP"></secret>**| **![](../../Images/Connect_SQLMI_00.png)**|If SSMS is not connected to your Azure and GitHub accounts anymore, repeat the account steps from [Challenge 1](../challenge-01/solution-01.md#12-connect-ssms-with-your-azure-and-github-copilot-accounts).|
|In a browser open the Azure Portal (portal.azure.com) and sign in with the Azure credentials. Keep the portal open, you will need it in the next sections.|![Azure Portal signed in](../../Images/Add_Azure_Account_02.png)||
|In Object Explorer expand **Databases**, right-click **TenantCRM** and select **New Query**. Make sure the query window is connected to **TenantCRM**.|![New query window on TenantCRM](../../Images/SSMS_TenantCRM_NewQuery.png)|Copilot uses the connection of the active query window as context.|

## 2.3 Open the GitHub Copilot chat

|**Narrative/Instructions**| **Screenshot**| **Notes**|
|:------------|:--------------|:---------|
|Open the GitHub Copilot chat window in SSMS and verify that you are signed in.|![](../../Images/SSMS_Github_Chat.png)||
|Verify that Copilot sees your database context by asking a first question.|![Copilot confirms the database context](../../Images/Copilot_Database_Context.png)|**Prompt**: *"Which database am I connected to and which tables, views and stored procedures does it contain?"*|

> **Prompting tips (from Challenge 2)**
> * Be specific about the database and the goal.
> * Ask Copilot to explain how it came to a conclusion.
> * Ask for scripts first and tell Copilot **not to execute** changes. Review everything before you run it.
> * Copilot may ask for approval before it executes queries. Read the query and approve it.
> * GitHub Copilot in SSMS cannot see the Azure Portal. Use it there as a guide that explains terms and findings.

# 3. Get a first security overview with GitHub Copilot

Before we look at the individual security features, let Copilot give us a first overview of the security posture of the database. This is also a good way to explain the layered security model.

|**Narrative/Instructions**| **Screenshot**| **Notes**|
|:------------|:--------------|:---------|
|Ask Copilot to explain the layered security model of Azure SQL Managed Instance.|![Copilot explains the layered security model](../../Images/Copilot_Security_Layers.png)|**Prompt**: *"Explain the layered security model of Azure SQL Managed Instance. Which layers are already covered by the platform and which layers do I have to take care of myself?"*|
|Ask Copilot to check the database for security issues. Enter a prompt similar to the following into the GitHub Copilot chat window.|![](../../Images/GithubCopilot_performance_prompt.png)|**Prompt**: *"Please check for security issues and options to mitigate them in the TenantCRM database."*|
|GitHub Copilot may request approval several times to execute queries to analyze the problem. Please approve the requests.|![](../../Images/GithubCopilot_Approve.png)|**Note**: Look at the queries Copilot executes. They read metadata, for example about permissions, stored procedures, and database configuration.|
|Copilot gives you a list of findings. **Keep this list.** We will come back to it in section 7 and compare it with the findings of the Azure tools.|![Copilot security findings overview](../../Images/Copilot_Security_Findings.png)|**Prompt**: *"Please summarize the findings in a table with the columns finding, risk, affected object and recommended action. Sort by risk."*|

# 4. Data Discovery & Classification

Data Discovery & Classification is a built-in capability for discovering, classifying, labelling and protecting sensitive data in databases. It can be used to support many use cases including financial, healthcare, personally identifiable (PII) data and help meet data privacy standards and regulatory compliance.

More information on Data Discovery & Classification can be found in the [official documentation](https://docs.microsoft.com/en-us/azure/azure-sql/database/data-discovery-and-classification-overview).

|**Narrative/Instructions**| **Screenshot/Code**| **Notes**|
|:------------|:--------------|:---------|
|Ask Copilot to explain the feature before you use it.||**Prompt**: *"What is Data Discovery & Classification in Azure SQL and what is the difference between an information type and a sensitivity label?"*|
|Ask Copilot to find potentially sensitive columns in your database. You will compare the result with the recommendations of the Azure Portal.|![Copilot finds sensitive columns](../../Images/Copilot_Sensitive_Columns.png)|**Prompt**: *"Which columns in the SalesLT schema of \<Team\>_TenantDataDb might contain personal data or financial data? Please list schema, table, column and the reason."*|

## Viewing Data Classification Recommendations

Whenever a database is deployed or schema changes are made to an existing database, the Data Discovery & Classification engine automatically performs a scan to identify columns that may potentially contain sensitive data.

|**Narrative**| **Screenshot/Code**| **Notes**|
|:------------|:--------------|:---------|
|Within the Azure Portal navigate to the shared Azure SQL Managed Instance screen. Scroll down to the list of databases and click on your teams **\<Team\>_TenantDataDb** database.|||
|On the blade on the left, under the **Security** section click **Data Discovery & Classification**.|||
|The Data Discovery and Classification **Overview** shows that no data classifications have been made but based on the automatic classification scan there are a number of potential data classification recommendations as shown at the top of the report. Click the blue information bar (highlighted in yellow) to view the data classification recommendations.|![](../../Images/77f07ddfaec5bb313ca73bcc36af4c0b.png)||
|The recommendations show the name of the schema, table and column with intelligent information type classification and sensitivity recommendations. As can be seen the **Customer** table in the **SalesLT** schema contains the columns **FirstName** and **LastName**. The initial data classification scan has identified that the **Information type** of these columns from a data classification perspective is **Name** and the **Sensitivity Label** for these columns is recommended to be **Confidential – GDPR**.|![](../../Images/8dfe7cd131156b72ff7c659924919e03.png)|Compare the recommendations with the list from Copilot. Did Copilot find additional columns?|
|Select the **FirstName** and **LastName** classification recommendations by selecting the recommendation rows, click **Accept selected recommendations** and then click **Save**. Click the **Overview** tab on the Data Discovery & Classification report to look at the saved data classifications. There are now two columns classified from the Customer table with the information type of **Name** and the sensitivity label **Confidential – GDPR**.| ![](../../Images/b21f2a93ac8bc7713174058ad42439e4.png)||
|Now let’s add a custom data classification which is not based on the auto recommendations. Switch back to the **Classification** tab at the top of the report and click **+ Add classification**.| ![](../../Images/16591a75d63422cb521b90d8c702fd52.png)||
|On the **Add Classification** blade on the far right of the screen set the following values and then click **Add Classification** and then **Save** to save your new classification. Click the **Overview** tab to look at the saved data classifications. <br> <br> **Schema name**: 	SalesLT <br> **Table name**: 	Product <br> **Column name**: 	ListPrice <br> **Information type**: 	Financial <br> **Sensitivity Label**: 	Highly Confidential <br> <br> **Click:** 	Add Classification <br>**Click:** 	Save |![](../../Images/1230233d11cd470db39b3987f2816fdf.png)||
|In SSMS open a new T-SQL query window connected to your **\<Team\>_TenantDataDb** database and run the SELECT statements shown on the right.|<code>-- 1 Data Discovery & Classification<br>SELECT<br>&nbsp;&nbsp;c.FirstName,<br>&nbsp;&nbsp;c.LastName,<br>&nbsp;&nbsp;c.*<br>FROM SalesLT.Customer c;<br>SELECT<br>&nbsp;&nbsp;p.ListPrice<br>FROM SalesLT.Product p;</code>||
|Nothing out of the ordinary happens - two simple result sets are returned containing the FirstName, LastName and ListPrice columns.||Ask Copilot why the classification did not change the result.<br>**Prompt**: *"I classified the columns FirstName, LastName and ListPrice. Why can I still read them with a simple SELECT? How do I really protect sensitive columns?"*|
|Ask Copilot how to turn classification into real protection.|![Copilot explains Dynamic Data Masking and Always Encrypted](../../Images/Copilot_Protect_Columns.png)|**Prompt**: *"Compare Dynamic Data Masking, Always Encrypted and row-level security for protecting the classified columns. When should I use which?"*|

**REMEMBER: Data Discovery and Classification is not a security mechanism – it’s a data tagging and management tool.**

# 5. Azure Defender for SQL: Vulnerability Assessment

When provisioning an Azure SQL Managed Instance or an Azure SQL Database logical server there is the option to enable the security feature Azure Defender for SQL.

This security feature offers two security components:

- Vulnerability Assessments
- Advanced Threat Protection

This section focuses on Vulnerability Assessments, section 6 deals with Advanced Threat Protection.

A Vulnerability Assessment is an output position (or report) from a vulnerability scan. A Vulnerability Assessment scan is the application of SQL Server best practices based on a rules engine, the goal being to improve the security posture of your Azure SQL Managed Instance or Azure SQL Database. The first scan will produce the initial vulnerability scan baseline. The first scan happens automatically once a database is deployed.

More details on Azure SQL vulnerability assessments can be found in the [official documentation](https://docs.microsoft.com/en-us/azure/azure-sql/database/sql-vulnerability-assessment).

|**Narrative**| **Screenshot/Code**| **Notes**|
|:------------|:--------------|:---------|
|Ask Copilot what a vulnerability assessment checks and how it differs from the analysis that Copilot did for you.||**Prompt**: *"What does the Azure SQL Vulnerability Assessment check, and how is a rules-based scan different from your own analysis of my database?"*|
|In the Azure portal navigate to the shared SQL Managed Instance.|||
|Scroll down the Overview screen until you see the list of databases and click on your **\<Team\>_TenantDataDB** database.|||
|In the **\<Team\>_TenantDataDB** database screen, on the left hand blade click **Microsoft Defender for Cloud** in the Security section. <br> <br>Scroll down the screen to the bottom and click the **View additional findings in Vulnerability Assessment** link.| **![](../../Images/Defender_Entry.png)**||
|The Vulnerability Assessment page can be used to run a scan, view scan history and will show the number of checks that have been passed and failed for the last scan with failed checks listed in the table below.<br><br> Run a scan if prompted to do so which should only take a few minutes.|![](../../Images/Defender_Details.png)||
|Review the lists of passed and failed checks. Notice that the report is specific to the database you ran the scan for but does also include events against the system database and therefore flag server configuration issues.|![](../../Images/Defender_Details.png)||
|Pick a failed check and ask Copilot to explain it. Copy the rule ID and the title of the finding into the prompt.|![Copilot explains a vulnerability assessment finding](../../Images/Copilot_Explains_VA_Finding.png)|**Prompt**: *"Explain the Vulnerability Assessment finding VA1256 'User CLR assemblies should not be defined in the database'. What is the risk and how would I remediate it?"*|
|In the **Findings** tab, which lists the failed checks, click on finding: **ID:** VA1256 **Security Check:** User CLR assemblies should not be defined in the database.|||
|Note the detailed report lists the rule’s details, the offending CLRs and a remediation script to remove them. <br> However, because these 2 CLRs are an integral part of our migrated legacy application we need to keep them. But equally we don’t want them to be continuously flagged as an issue in the Vulnerability Assessment reports. To do this we can add exceptions to the Vulnerability Assessment’s baseline position.| **![](../../Images/513774bfdaa4a39a5a52c78e2ab1051c.png)**|**Prompt**: *"My legacy application needs two user CLR assemblies. What are the risks and which compensating controls should I put in place if I keep them?"*|
|On the details page for VA1256 click **Add all results as baseline** and select **Yes** in the Set baseline message. Adding the results as the baseline will update the Vulnerability Assessment rules engine to accept the current CLR Assemblies as allowable and set a new baseline position for the rule. <br> <br> Notice, in the upper side of the details page for VA1256, a warning saying there are pending baseline changes. Run a new scan to see updated results.|![](../../Images/dd88f48958763545c8790b7ede6d3655.png)![](../../Images/b5659230dc09a911ebc6391b0c836c58.png)||
|Close the details page for VA1256 to get back to the Assessment summary page and notice the same warning.|![](../../Images/9bbb41c86fe1d57f00cbfd7e80ff87e1.png)||
|Click the **Scan** button to run a manual scan which will take about a minute. Once the scan completes the finding VA1256 will be removed from the Findings list.<br> When making changes to a Vulnerability Assessment baseline it may be necessary for compliance reasons to export a Scan Findings report to show the security posture of the Azure SQL Database in relation to the amended baseline. <br> <br>To export the results of a scan to reflect the current baseline click **Export Scan Results** at the top of the portal screen:<br><br>**NOTE: Excel is \*not\* installed on your lab VMs** *so you will have to copy the report to your own desktop to have a look at it.*|![](../../Images/c2a55a83a6bda8f54771b591df69541c.png)||
|Compare the remaining findings of the Vulnerability Assessment with the list that Copilot created in section 3. Which findings were found by both, and which by only one of them?||**Prompt**: *"Here are the remaining findings of my Vulnerability Assessment: [paste the finding titles]. Please prioritize them and tell me which I should fix first."*|

# 6. Azure Defender for SQL: Advanced Threat Protection

The other security component of Azure Defender for SQL is Advanced Threat Protection.

Advanced Threat Protection provides a layer of security that can detect and respond to potential threats as they occur by providing security alerts on anomalous activities. Alerts can be generated based on suspicious database activities, potential vulnerabilities, and SQL injection attacks, as well as anomalous database access and queries patterns.

More information in Azure Defender for SQL – Advanced Threat Protection can be found in the [official documentation](https://docs.microsoft.com/en-us/azure/azure-sql/database/threat-detection-overview).

|**Narrative**| **Screenshot/Code**| **Notes**|
|:------------|:--------------|:---------|
|Ask Copilot to explain SQL injection before you simulate it.||**Prompt**: *"What is a SQL injection attack, and how does Advanced Threat Protection detect it in Azure SQL?"*|
|In the Azure portal navigate to the shared SQL Managed Instance.|||
|Scroll down the Overview screen until you see the list of databases and click on your **\<Team\>_TenantDataDB** database.|||
|In the **\<Team\>_TenantDataDB** database screen, on the left-hand blade click **Microsoft Defender for Cloud** in the Security section. Scroll down to the **Security incidents and alerts** heading – note no incidents or alerts are listed.|**![](../../Images/eec68b37bb4694ee925c4cc6f5c34938.png)**||
|On the team VM, open a new query window in SQL Server Management Studio connected to your **\<Team\>_TenantDataDB** database.|||
|To simulate a potential SQL injection query copy the following SELECT into the new query window **BUT DON’T RUN IT YET**:|<code>--Advanced Threat Protection<br>DECLARE @UserInput nvarchar(max) = ''' OR 1=1--';<br>DECLARE @SQL nvarchar(max) = 'SELECT * FROM sys.databases WHERE name = ''' + @UserInput + '''';<br>EXEC(@SQL);</code>|Notice that the logic in the WHERE clause will always equate to true and the positioning of single-quotes including in the comment represents a potential SQL injection vulnerability.<br>**Prompt**: *"Explain why this script is vulnerable to SQL injection and how to write it safely."* (select the script in the editor first)|
|Before running the query change the connection properties as shown on the right using the **Query\\Connection\\Change Connection**… menu in SSMS.<br><br>Click **Connect**.| Specify the name of the team Azure SQL Database: **\<Team\>_TenantDataDB**  ![Change connection](../../Images/SSMS_ATP_DatabaseConnection.png) <br> On **Additional Connection Parameters** add a connection string option to specify the application name: **Application Name=webappname** <br> ![](../../Images/SSMS_ATP_AppNameConnection.png) ||
|Run the query. <br> <br>It will return a list of databases on the server.|||
|Back in the Azure Portal **Microsoft Defender for Cloud** screen, after a few minutes an alert should be generated.|![Alert generated](../../Images/a181cd65084cdd5f3515875e20bea999.png)|**NOTE:** It might take up to 10 minutes for the alert to appear in the portal.|
|Once the alert appears click on it to see the details. <br><br> Depending on the progress of other teams you may see multiple entries in the details table.|![Alert details](../../Images/619ec45260df07ebfec33d52e66706f2.png)||
|Try clicking on the alert.<br><br> Note that you can drill further into the alert to see more details, get explanations and links to documentation on the alert and even advice on how to negate and remediate the problem.|||
|Ask Copilot to help you with the interpretation of the alert.|![Copilot interprets the Advanced Threat Protection alert](../../Images/Copilot_Interprets_ATP_Alert.png)|**Prompt**: *"Defender for Cloud raised the alert 'Potential SQL Injection' for my database. What does this mean, how do I investigate it, and which stored procedures in my databases could be the source?"*|

# 7. Fix the SQL injection vulnerability with GitHub Copilot

In this section we close the loop. The simulated attack showed what a SQL injection looks like. Now we use Copilot to find the vulnerable code in the **TenantCRM** database and fix it.

|**Narrative/Instructions**| **Screenshot**| **Notes**|
|:------------|:--------------|:---------|
|Go back to the findings list from section 3. GitHub Copilot identified the stored procedure **AdminExecuteSQLCommand** to be vulnerable to SQL code injection. Copilot recommends to use **sp_executesql** for proper parameter handling.|![](../../Images/GithubCopilot_SqlInjectionProc.png)|**Note**: If your list does not show this finding, ask Copilot specifically for it with the prompt in the next row.|
|Ask Copilot to search for dynamic SQL in the whole database.|![Copilot lists procedures with dynamic SQL](../../Images/Copilot_Dynamic_SQL.png)|**Prompt**: *"Find all stored procedures in TenantCRM that build and execute dynamic SQL with string concatenation or EXEC(). List the procedure name and the risky statement."*|
|Ask Copilot to explain the vulnerability in AdminExecuteSQLCommand.|![Copilot explains the vulnerability](../../Images/Copilot_Explains_Injection.png)|**Prompt**: *"Explain how an attacker could exploit the stored procedure AdminExecuteSQLCommand. Show me an example input, but do not execute it."*|
|Ask Copilot for a safe version of the procedure. Tell Copilot not to execute the script.|![Copilot proposes a fixed procedure](../../Images/Copilot_Fixed_Procedure.png)|**Prompt**: *"Rewrite AdminExecuteSQLCommand so that it is not vulnerable to SQL injection. Use sp_executesql with parameters where possible and QUOTENAME for object names. Show me the ALTER PROCEDURE script and explain the changes, but do not execute anything."*|
|Review the script. Ask Copilot critical follow-up questions before you apply it.||**Prompt**: *"Does the new version change the behavior for legitimate callers? Which permissions should I restrict on this procedure?"*|
|Execute the **ALTER PROCEDURE** script in the query window connected to **TenantCRM**.|<!--![PLACEHOLDER: ALTER PROCEDURE executed successfully](../../Images/PLACEHOLDER_AlterProcedure_Success.png)-->||
|Verify the fix. Ask Copilot to test the procedure with a harmless input and with the injection example.|![Copilot verifies the fixed procedure](../../Images/Copilot_Verify_Fix.png)|**Prompt**: *"Please give me a test script that calls the fixed procedure with a normal input and with an injection attempt, and tell me which result I should expect in both cases."*|
|Optional: Ask Copilot for further hardening measures.|![Copilot suggests further hardening](../../Images/Copilot_Hardening.png)|**Prompt**: *"Which additional security measures should I implement for the TenantCRM database, for example permissions, auditing, Dynamic Data Masking or Microsoft Entra authentication? Please prioritize them."*|

We have seen how GitHub Copilot can help us analyze and mitigate security issues, and how the Azure security features help us to verify the results and to detect attacks.

# 8. Deepen your understanding with GitHub Copilot

This optional section contains additional prompts that help you to understand the bigger picture of security on Azure SQL Managed Instance. No screenshots are needed. Run the prompts in the Copilot chat of SSMS and ask follow-up questions.

> **Tips**
>
> * Give Copilot your context: compliance requirements, types of data, who accesses the database and from where.
> * Ask for **tables** when you compare features, and for **priorities** when you get long lists.
> * Security features and defaults change. Ask Copilot to point to the **official documentation** and verify the details there.
> * Never paste secrets, passwords, connection strings or real personal data into a prompt.
> * Tell Copilot **not to execute** scripts that change permissions, keys or configuration.

## 8.1 The security model and shared responsibility

|**Narrative**| **Prompt and what you should learn**|
|:------------|:------------------------------------|
|Understand the shared responsibility.|**Prompt**: *"Explain the shared responsibility model for Azure SQL Managed Instance. Which security tasks does Microsoft handle and which tasks remain with me?"*|
|Compare with your legacy server.|**Prompt**: *"Which security tasks did I have to do on my legacy SQL Server on-premises that Azure SQL Managed Instance now does for me, for example patching, encryption and backups? What is new?"*|
|Get a security checklist.|**Prompt**: *"Create a security baseline checklist for a new Azure SQL Managed Instance, grouped by network, identity, data protection, monitoring and governance."*|
|Understand defense in depth.|**Prompt**: *"Explain defense in depth with an example attack path against a database and show which layer stops the attacker at which point."*|
|Compare the targets.|**Prompt**: *"Compare the security features of Azure SQL Managed Instance, Azure SQL Database and SQL Server on an Azure VM in a table."*|

## 8.2 Authentication and authorization

|**Narrative**| **Prompt and what you should learn**|
|:------------|:------------------------------------|
|Compare the authentication methods.|**Prompt**: *"Compare SQL authentication, Windows authentication, and Microsoft Entra authentication on Azure SQL Managed Instance. Which one do you recommend and why?"*|
|Understand Entra-only authentication.|**Prompt**: *"What does Microsoft Entra-only authentication mean for Azure SQL Managed Instance, and what do I have to prepare before I enable it?"*|
|Review the permissions.|**Prompt**: *"Show me a query that lists all users, roles and explicit permissions in TenantCRM, and highlight users with db_owner or other powerful permissions."*|
|Apply least privilege.|**Prompt**: *"My application connects with a user that has db_owner. Which minimal permissions does an application normally need? Show me a script for a restricted role, but do not execute it."*|
|Use managed identities.|**Prompt**: *"How can my application connect to the Managed Instance without a password, using a managed identity? What are the benefits compared with a SQL login in the connection string?"*|
|Understand roles at all levels.|**Prompt**: *"Explain the difference between Azure RBAC roles, server-level roles and database-level roles for Managed Instance. Who can do what?"*|
|Find orphaned and stale accounts.|**Prompt**: *"How do I find orphaned users and accounts that have not been used for a long time? What should I do with them?"*|
|Plan privileged access.|**Prompt**: *"How can I reduce standing administrator access, for example with Privileged Identity Management and just-in-time access?"*|

## 8.3 Protecting data

|**Narrative**| **Prompt and what you should learn**|
|:------------|:------------------------------------|
|Understand Transparent Data Encryption.|**Prompt**: *"What does Transparent Data Encryption protect and what does it not protect? Is it enough to meet a requirement for encryption at rest?"*|
|Compare the key options.|**Prompt**: *"Compare service-managed keys and customer-managed keys (Azure Key Vault) for TDE on Managed Instance. What are the risks if the key is lost or access is revoked?"*|
|Understand Always Encrypted.|**Prompt**: *"Explain how Always Encrypted works, what the DBA can and cannot see, and which operations on encrypted columns are limited."*|
|Compare the techniques.|**Prompt**: *"Create a table that compares Dynamic Data Masking, Always Encrypted, row-level security, TDE and column permissions by threat, performance impact and application changes."*|
|Use Dynamic Data Masking.|**Prompt**: *"Show me how I could mask the columns FirstName and LastName with Dynamic Data Masking and which roles see the real data. Also tell me the weaknesses of masking. Do not execute anything."*<br>**Learn**: Masking is not a strong security boundary on its own.|
|Use row-level security.|**Prompt**: *"Explain row-level security with a multi-tenant example. How can I make sure that a tenant only sees its own rows?"*|
|Understand the ledger.|**Prompt**: *"What is the ledger feature in Azure SQL and in which cases would I use it?"*|
|Protect backups.|**Prompt**: *"How are backups of a Managed Instance protected and who can restore them? How do I secure the long-term retention backups?"*|
|Protect data in transit.|**Prompt**: *"Which TLS version is used for connections to Managed Instance and how do I enforce a minimum TLS version?"*|

## 8.4 Network security

|**Narrative**| **Prompt and what you should learn**|
|:------------|:------------------------------------|
|Understand the network isolation.|**Prompt**: *"Explain how a Managed Instance is isolated in its subnet, and which network security group and route table rules are required and managed by the service."*|
|Understand the public endpoint.|**Prompt**: *"What is the public endpoint of Azure SQL Managed Instance, when should I enable it, and how do I secure it if I must use it?"*|
|Compare the connection options.|**Prompt**: *"Compare connecting to Managed Instance via VNet peering, private endpoint, VPN, ExpressRoute and public endpoint. Which one is the most secure and which one the most convenient?"*|
|Understand the connection policy.|**Prompt**: *"What is the difference between the Proxy and Redirect connection policy and what do I have to open on the firewall for each?"*|
|Control outbound traffic.|**Prompt**: *"How can I control outbound connectivity from my Managed Instance, for example to prevent data exfiltration?"*|
|Review the network setup.|**Prompt**: *"Which questions should I ask to review the network security of our Managed Instance deployment?"*|

## 8.5 Auditing and threat detection

|**Narrative**| **Prompt and what you should learn**|
|:------------|:------------------------------------|
|Understand auditing.|**Prompt**: *"Explain SQL Audit on Azure SQL Managed Instance. What can I log, where can the logs be stored and how do I analyze them?"*|
|Choose the audit destination.|**Prompt**: *"Compare storage account, Log Analytics and Event Hubs as audit destinations by cost, query options and retention."*|
|Find suspicious activity.|**Prompt**: *"Which signals in the audit logs point to a compromised account, for example failed logins, logins from new locations, permission changes or unusual data volumes? Write a KQL query for failed logins."*|
|Understand the Defender plans.|**Prompt**: *"What does Microsoft Defender for SQL include? What is the difference between the vulnerability assessment and Advanced Threat Protection, and what does it cost?"*|
|Understand the alert types.|**Prompt**: *"Which alert types can Advanced Threat Protection raise, and which of them are most important for a database with personal data?"*|
|Handle false positives.|**Prompt**: *"An alert shows access from an unusual location. How do I decide whether it is an attack or a legitimate administrator, and how do I suppress known good activity?"*|
|Build the monitoring concept.|**Prompt**: *"Create a simple security monitoring concept: which logs, which alerts, who is notified and how often are the findings reviewed?"*|

## 8.6 Compliance and governance

|**Narrative**| **Prompt and what you should learn**|
|:------------|:------------------------------------|
|Understand the regulatory requirements.|**Prompt**: *"Which technical measures does GDPR require for a database with personal data, and which of them can I implement with Azure SQL features?"*|
|Use Azure Policy.|**Prompt**: *"Which Azure Policy definitions help me to enforce a secure configuration of Managed Instances, for example auditing, minimum TLS and Entra-only authentication?"*|
|Use Microsoft Defender for Cloud.|**Prompt**: *"How do the secure score and the recommendations in Microsoft Defender for Cloud relate to the findings of the Vulnerability Assessment?"*|
|Understand the data lifecycle.|**Prompt**: *"How do I handle the right to erasure in a database with backups and long-term retention?"*|
|Connect classification and governance.|**Prompt**: *"How can the sensitivity labels from Data Discovery & Classification be used for auditing and in Microsoft Purview?"*|
|Prepare for an audit.|**Prompt**: *"Which evidence should I collect from Azure SQL Managed Instance for an auditor, for example configuration, access reviews and audit logs?"*|

## 8.7 Secure development

|**Narrative**| **Prompt and what you should learn**|
|:------------|:------------------------------------|
|Understand SQL injection more broadly.|**Prompt**: *"Show me the most common SQL injection patterns in stored procedures and in application code, and how to prevent them. Use harmless examples only."*|
|Review code.|**Prompt**: *"Review all stored procedures in TenantCRM that take string parameters for security problems other than SQL injection, for example missing permission checks, excessive EXECUTE AS or insecure error handling. Do not change anything."*|
|Understand EXECUTE AS and ownership chaining.|**Prompt**: *"Explain EXECUTE AS and ownership chaining in stored procedures and how they can be used to give limited access to data."*|
|Manage secrets.|**Prompt**: *"How should the application store its database connection information? Compare connection strings in a config file with Azure Key Vault and managed identities."*|
|Use secure test data.|**Prompt**: *"How can I create test data from the TenantCRM database without exposing personal data?"*|
|Automate checks.|**Prompt**: *"How can I add automated security checks for database code to a CI/CD pipeline?"*|

## 8.8 Incident response and recovery

|**Narrative**| **Prompt and what you should learn**|
|:------------|:------------------------------------|
|Respond to an alert.|**Prompt**: *"Defender raised a SQL injection alert. Create a step-by-step response plan: what do I check first, how do I contain the issue, and which evidence do I collect?"*|
|Contain a compromised login.|**Prompt**: *"A login might be compromised. Which steps do I take on the Managed Instance, for example disabling the login, ending sessions and reviewing the audit logs? Show me the scripts, but do not execute anything."*|
|Recover data.|**Prompt**: *"How can I restore a Managed Instance database to a point in time before a malicious change, and what are the effects on the application?"*|
|Prepare for ransomware or deletion.|**Prompt**: *"Which protections prevent the loss of backups and data when an administrator account is compromised, for example immutable backups and resource locks?"*|
|Learn from the incident.|**Prompt**: *"Create a post-incident review template with timeline, root cause, impact, corrective actions and the security controls we want to add."*|

# Prompt cheat sheet

| Goal | Example prompt |
|:-----|:---------------|
| Understand the context | *"Which database am I connected to and which tables, views and stored procedures does it contain?"* |
| Get a security overview | *"Please check for security issues and options to mitigate them in the TenantCRM database."* |
| Structure the result | *"Please summarize the findings in a table with the columns finding, risk, affected object and recommended action."* |
| Find sensitive data | *"Which columns in the SalesLT schema might contain personal data or financial data?"* |
| Explain a finding | *"Explain the Vulnerability Assessment finding VA1256. What is the risk and how would I remediate it?"* |
| Prioritize | *"Here are my remaining findings: [...]. Please prioritize them and tell me which I should fix first."* |
| Find vulnerable code | *"Find all stored procedures in TenantCRM that build and execute dynamic SQL with string concatenation or EXEC()."* |
| Fix safely | *"Rewrite this stored procedure so that it is not vulnerable to SQL injection. Show me the script and explain the changes, but do not execute anything."* |
| Verify the fix | *"Please give me a test script that calls the fixed procedure with a normal input and with an injection attempt."* |
| Harden further | *"Which additional security measures should I implement for this database? Please prioritize them."* |
| Review the permissions | *"Show me all users, roles and explicit permissions in TenantCRM and highlight users with powerful permissions."* |
| Apply least privilege | *"Which minimal permissions does my application need? Show me a script for a restricted role, but do not execute it."* |
| Compare protection features | *"Compare Dynamic Data Masking, Always Encrypted, row-level security, TDE and column permissions by threat and application changes."* |
| Compare connection options | *"Compare VNet peering, private endpoint, VPN, ExpressRoute and public endpoint for Managed Instance by security and convenience."* |
| Plan auditing | *"Explain SQL Audit on Managed Instance and compare the audit destinations by cost, query options and retention."* |
| Find suspicious activity | *"Write a KQL query for failed logins and tell me which other audit signals point to a compromised account."* |
| Check compliance | *"Which technical measures does GDPR require for a database with personal data, and which Azure SQL features support them?"* |
| Respond to an incident | *"Create a step-by-step response plan for this alert: what do I check first, how do I contain it and which evidence do I collect?"* |
| Share results safely | *"Replace all names, e-mail addresses and connection details in this result with placeholders so that I can share it."* |
