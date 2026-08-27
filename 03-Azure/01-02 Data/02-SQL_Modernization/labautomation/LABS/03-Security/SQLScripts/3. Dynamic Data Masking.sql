-- *** REPLACE XX WITH YOUR TEAM NUMBER ***---

--1.	Run the below script to mask the transaction amount in the UserTransactions table using the default masking function
USE TEAMXX_TenantDataDB; 
GO
ALTER TABLE [UserTransactions]
ALTER COLUMN [TranAmount] [decimal](18, 2) MASKED WITH (FUNCTION = 'DEFAULT()') 


--3. Check to see masked columns
SELECT c.name, tbl.name as table_name, c.is_masked, c.masking_function  
FROM sys.masked_columns AS c  
JOIN sys.tables AS tbl   
    ON c.[object_id] = tbl.[object_id]  
WHERE is_masked = 1;  


--4.	Check the table to ensure you are still able to see ALL the data
SELECT * FROM TEAMXX_TenantDataDB.dbo.UserTransactions
GO

--5.	Create a user for the developer and grant the read only access on the UserTransactions table
CREATE USER Peter WITHOUT LOGIN
GRANT SELECT ON dbo.UserTransactions TO Peter;

--6.	Run the query below to ensure we have been able to prevent the developer from accessing customers’ privacy information. This will run the SELECT statement as the new user, Peter, which was created in the previous step
EXECUTE AS USER = 'Peter';
SELECT * FROM TEAMXX_TenantDataDb.dbo.UserTransactions;
REVERT;

--7. Grant Peter permission to Peter to see unmasked data
GRANT UNMASK TO Peter;  
EXECUTE AS USER = 'Peter';  
SELECT * FROM TEAMXX_TenantDataDb.dbo.UserTransactions;
REVERT;   

--8. Clean up masked column
USE TEAMXX_TenantDataDB; 
GO
ALTER TABLE [UserTransactions]   
ALTER COLUMN [TranAmount] DROP MASKED;

