--- **** REPLACE TEAMXX with your TEAM number e.g TEAM01 **----

--1.	Create an audit for your Managed Instance and define the target
-- Create the server audit.
-- Change the path to a path to Blob Storage Path for auditing 
USE MASTER
GO
CREATE SERVER AUDIT [TEAMXX_server_audit]
TO URL(PATH ='https://sqlhacksapfu2ietzqrxem.blob.core.windows.net/auditlogs')
GO


--2.	Create a database audit specification that maps to the audit by running the following query in Management Studio

USE [TEAMXX_TenantDataDb]
GO  
-- Create the database audit specification.  
CREATE DATABASE AUDIT SPECIFICATION TEAMXX_Audit_Data --change xx to team number
FOR SERVER AUDIT [TEAMXX_server_audit] --change to server audit name created in step 1  
ADD (INSERT, UPDATE, DELETE, SELECT
     ON UserTransactions BY dbo )  --[UserTransactions] is the target table we're going to audit
WITH (STATE = ON);    
GO  

/**
--- You will need to configure blob storage for audit logs using the SQL Server Management Studio (SSMS) 18 (Preview):
-- 1. Connect to the managed instance using SQL Server Management Studio (SSMS) UI
-- 2. Expand the Security node, right-click on the Audits node, and click on "TEAMXX_server_audit"
-- 3. Make sure "URL" is selected in Audit destination and click on Browse:
-- 4. Sign in to your Azure account
-- 5. Select your subscription, sqlhacksapfu2ietzqrxem, and sqlaudits from the dropdowns. Once you have finished click OK.
**/


-- enable the audit
-- ensure you have connected to the audit log file location

USE MASTER
GO
ALTER SERVER AUDIT [TEAMXX_server_audit] WITH (STATE = ON)

--3.	Run a couple of SELECT and DELETE Statements on TEAMXX_TenantDataDb which you have enabled.

-- Run select statements and delete statments below:
USE [TEAMXX_TenantDataDb]
GO 
SELECT * FROM TEAMXX_TenantDataDb.dbo.usertransactions
WHERE UserTranID < 1000

SELECT * FROM TEAMXX_TenantDataDb.dbo.usertransactions
WHERE UserTranID > 1000

-- delete transaction
DELETE FROM TEAMXX_TenantDataDb.dbo.usertransactions
WHERE UserTranID = 1000


--4.	Read the audit events by using the fn_get_audit_file function. The directory hierarchy within the container is of the form <ServerName>/<DatabaseName>/<AuditName>/<Date>/.

-- check the audit logs
SELECT event_time, 
action_id, 
client_ip,
session_server_principal_name, 
database_principal_name, 
statement, 
application_name, 
data_sensitivity_information, --new column added to audit log
host_name
FROM sys.fn_get_audit_file ('https://sqlhacksapfu2ietzqrxem.blob.core.windows.net/auditlogs/sqlhackmi-pfu2ietzqrxem/master/', default, default) -- change the location to reflect the directory of the XEL file in your blob storage
WHERE data_sensitivity_information like '%confidential%'
AND database_name = 'TEAMXX_TenantDataDb'
GO-- change the location to reflect the directory of the XEL file in your blob storage
