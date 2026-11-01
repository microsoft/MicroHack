param(
    [Parameter(Mandatory)]
    [string] $sqlusername,
    [Parameter(Mandatory)]
    [string] $sqlpassword,
    [string]$ServerInstance = 'localhost'
)

$ErrorActionPreference = 'Stop'

$logPath = 'C:\Windows\Temp\Configure-legacySQL.log'
Start-Transcript -Path $logPath -Append

Write-Host 'Configuring SQL legacy Instance...'

$ConfigureSql = @"
USE [master];
GO
/* ============================================================
   SQL Server configuration for SSMS Migration Assessments

   - MAXDOP = 1
   - Optimize for Ad Hoc Workloads = ON
   - Network Packet Size = 8000
   - Max Server Memory = Physical RAM - 4 GB
   ============================================================ */
DECLARE @PhysicalMemoryMB bigint;
DECLARE @MaxServerMemoryMB bigint;
/* Get physical memory of the server */
SELECT
    @PhysicalMemoryMB = total_physical_memory_kb / 1024
FROM sys.dm_os_sys_memory;
/* Reserve 4 GB for Windows */
SET @MaxServerMemoryMB = @PhysicalMemoryMB - 4096;
/* Safety check */
IF @MaxServerMemoryMB < 1024
BEGIN
    THROW 50000, 'Not enough physical memory available.', 1;
END;
/* Enable advanced options */
EXEC sys.sp_configure 'show advanced options', 1;
RECONFIGURE;
/* MAXDOP = 1 */
EXEC sys.sp_configure 'max degree of parallelism', 1;
/* Optimize for Ad Hoc Workloads */
EXEC sys.sp_configure 'optimize for ad hoc workloads', 1;
/* Network Packet Size = 8000 bytes */
EXEC sys.sp_configure 'network packet size (B)', 8000;
/* Dynamically configure Max Server Memory */
EXEC sys.sp_configure
    'max server memory (MB)',
    @MaxServerMemoryMB;
RECONFIGURE;
GO
USE master
GO
EXEC sp_configure 'CLR Enabled', 1
RECONFIGURE WITH OVERRIDE
GO
USE [master]
GO
CREATE MASTER KEY ENCRYPTION BY PASSWORD = '$sqlpassword'
GO
"@

[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.ConnectionInfo") | Out-Null
[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.Smo") | Out-Null

$connectionString = "Data Source=$ServerInstance;Initial Catalog=master;TrustServerCertificate=True;"
$Connection = New-Object System.Data.SqlClient.SqlConnection($connectionString)
[System.Security.SecureString]$SQLPwd = $sqlpassword | ConvertTo-SecureString -AsPlainText -Force
$SQLPwd.MakeReadOnly()
$cred = New-Object System.Data.SqlClient.SqlCredential($sqlusername,$SQLPwd)
$Connection.credential = $cred

$serverConnection = New-Object Microsoft.SqlServer.Management.Common.ServerConnection($Connection)
$server = New-Object Microsoft.SqlServer.Management.Smo.Server($serverConnection)

try {
    # Ausführung des Skripts inkl. GO-Trenner
    [void]$server.ConnectionContext.ExecuteNonQuery($ConfigureSql)
    #Write-Host "Skript erfolgreich auf SQL MI ausgeführt." -ForegroundColor Green
}
catch {
    $ErrorString = $_ | format-list -force | Out-String
    Write-Error "ERR: $ErrorString"
}
finally {
    if ($null -ne $serverConnection -and $serverConnection.IsOpen) {
        $serverConnection.Disconnect()
    }
}
try {
	$Connection.Close()
}
catch {
}

Try {
    Write-Host "Installing and configuring Windows Failover Cluster..." -ForegroundColor Green
    Install-WindowsFeature -Name Failover-Clustering -IncludeManagementTools -IncludeAllSubFeature
    $clus = New-Cluster -Name "CLU01" -AdministrativeAccessPoint None -Verbose -Force
    Enable-SqlAlwaysOn -Path "SQLSERVER:\SQL\$($ServerInstance)\default" -Force    
    Restart-Service -Name "MSSQLSERVER" -Force
}
Catch {
    Write-Host "Error configuring SQL legacy Instance."
    $ErrorString = $_ | format-list -force | Out-String
    Write-Error "ERR: $ErrorString"
}

Stop-Transcript
