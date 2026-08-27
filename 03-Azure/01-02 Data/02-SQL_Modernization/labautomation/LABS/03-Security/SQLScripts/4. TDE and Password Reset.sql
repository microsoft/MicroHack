--Enable TDE for databases
USE [master]
GO
ALTER DATABASE [TEAMXX_LocalMasterDataDB] SET ENCRYPTION ON
GO

ALTER DATABASE [TEAMXX_SharedMasterDataDB] SET ENCRYPTION ON
GO

ALTER DATABASE [TEAMXX_TenantDataDB] SET ENCRYPTION ON
GO

-- ALTER LOGIN [$0] WITH PASSWORD = '<insert a strong password >'
ALTER LOGIN [TEAMXX] DISABLE;
-- DBA must change the password before re-enable.
ALTER LOGIN [teamXX] WITH PASSWORD = '<insert a strong password >'