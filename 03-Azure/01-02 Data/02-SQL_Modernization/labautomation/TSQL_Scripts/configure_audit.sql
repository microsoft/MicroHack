-- Managed Identity must be enabled on the SQL Managed Instance for this to work
-- Configure the Managed Identity for the SQL Managed Instance to have access to the storage account (Storage Blob Data Contributor role) and the storage account must have a container named "auditlogs" created in it.
-- Please replace <storage-account> with the name of your storage account in the below script.

USE master;
CREATE CREDENTIAL [https://<storage-account>.blob.core.windows.net/auditlogs]
WITH IDENTITY='MANAGED IDENTITY'
GO

CREATE SERVER AUDIT [sqlmi_auditlog]
TO URL ( PATH ='https://<storage-account>.blob.core.windows.net/auditlogs' 
, RETENTION_DAYS =  30 )
GO

ALTER SERVER AUDIT [sqlmi_auditlog]
WITH (STATE = ON)
GO
