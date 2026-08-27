param(
    [Parameter(Mandatory)]
    [string]$ManagedInstanceServer,

    [Parameter(Mandatory)]
    [string] $sqlusername,

    [Parameter(Mandatory)]
    [string] $sqlpassword
)

$ErrorActionPreference = 'Stop'

$logPath = 'C:\Windows\Temp\Configure-SQLMI.log'
Start-Transcript -Path $logPath -Append

Write-Host 'Configuring SQL Managed Instance...'

$ConfigureSql = @"
USE master
GO
EXEC sp_configure 'CLR Enabled', 1
RECONFIGURE WITH OVERRIDE
GO

USE [msdb]
GO
IF EXISTS (SELECT job_id 
            FROM msdb.dbo.sysjobs_view 
            WHERE name = N'Workload01')
EXEC msdb.dbo.sp_delete_job @job_name=N'Workload01'
                            , @delete_unused_schedule=1

IF EXISTS (SELECT job_id 
            FROM msdb.dbo.sysjobs_view 
            WHERE name = N'Workload02')
EXEC msdb.dbo.sp_delete_job @job_name=N'Workload02'
                            , @delete_unused_schedule=1
GO
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0

IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'[Uncategorized (Local)]' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'[Uncategorized (Local)]'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'Workload01', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'No description available.', 
		@category_name=N'[Uncategorized (Local)]', 
		@owner_login_name=N'DemoUser', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Step1', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'
  DECLARE @i INT=0
  WHILE @i<100
  BEGIN
	EXEC  GetTransactionTotalPerReferenceOrderID 41590
	 EXEC uspGetManagerEmployees 263
	 EXEC [dbo].[uspGetEmployeeManagers] 264
	 EXEC [dbo].[uspGetBillOfMaterials] @StartProductID = 517, @CheckDate= ''2010-11-14 00:00:00.000''
	 EXEC [dbo].[uspGetWhereUsedProductID] 749,@CheckDate= ''2010-11-14 00:00:00.000''
	 SET @i =@i+1
 END
 WAITFOR DELAY ''00:01''

 SET @i =0
 WHILE @i<500
 BEGIN
	 EXEC uspGetManagerEmployees 263
	 EXEC [dbo].[uspGetEmployeeManagers] 264
	 EXEC [dbo].[uspGetBillOfMaterials] @StartProductID = 517, @CheckDate= ''2010-11-14 00:00:00.000''
	 EXEC [dbo].[uspGetWhereUsedProductID] 749,@CheckDate= ''2010-11-14 00:00:00.000''
	 SET @i =@i+1
 END
 WAITFOR DELAY ''00:02:30''
 SET @i =0
 WHILE @i<100
	BEGIN
	EXEC  GetTransactionTotalPerReferenceOrderID 41590
	 SET @i =@i+1
 END
WAITFOR DELAY ''00:01''
SET @i =0
	WHILE @i<1000
	 BEGIN
	 EXEC uspGetManagerEmployees 263
	 EXEC [dbo].[uspGetEmployeeManagers] 264
	 EXEC [dbo].[uspGetBillOfMaterials] @StartProductID = 517, @CheckDate= ''2010-11-14 00:00:00.000''
	 EXEC [dbo].[uspGetWhereUsedProductID] 749,@CheckDate= ''2010-11-14 00:00:00.000''
	 SET @i =@i+1
 END
WAITFOR DELAY ''00:01''
SET @i =0
 WHILE @i<100
 BEGIN
	 EXEC  GetTransactionTotalPerReferenceOrderID 41590
	 EXEC uspGetManagerEmployees 263
	 EXEC [dbo].[uspGetEmployeeManagers] 264
	 EXEC [dbo].[uspGetBillOfMaterials] @StartProductID = 517, @CheckDate= ''2010-11-14 00:00:00.000''
	 EXEC [dbo].[uspGetWhereUsedProductID] 749,@CheckDate= ''2010-11-14 00:00:00.000''
	 SET @i =@i+1
 END
   WHILE @i<100
  BEGIN
	EXEC  GetTransactionTotalPerReferenceOrderID 41590
	 EXEC uspGetManagerEmployees 263
	 EXEC [dbo].[uspGetEmployeeManagers] 264
	 EXEC [dbo].[uspGetBillOfMaterials] @StartProductID = 517, @CheckDate= ''2010-11-14 00:00:00.000''
	 EXEC [dbo].[uspGetWhereUsedProductID] 749,@CheckDate= ''2010-11-14 00:00:00.000''
	 SET @i =@i+1
 END
 WAITFOR DELAY ''00:01''

 SET @i =0
 WHILE @i<500
 BEGIN
	 EXEC uspGetManagerEmployees 263
	 EXEC [dbo].[uspGetEmployeeManagers] 264
	 EXEC [dbo].[uspGetBillOfMaterials] @StartProductID = 517, @CheckDate= ''2010-11-14 00:00:00.000''
	 EXEC [dbo].[uspGetWhereUsedProductID] 749,@CheckDate= ''2010-11-14 00:00:00.000''
	 SET @i =@i+1
 END
 WAITFOR DELAY ''00:02:30''
 SET @i =0
 WHILE @i<100
	BEGIN
	EXEC  GetTransactionTotalPerReferenceOrderID 41590
	 SET @i =@i+1
 END
WAITFOR DELAY ''00:02''
SET @i =0
	WHILE @i<1000
	 BEGIN
	 EXEC uspGetManagerEmployees 263
	 EXEC [dbo].[uspGetEmployeeManagers] 264
	 EXEC [dbo].[uspGetBillOfMaterials] @StartProductID = 517, @CheckDate= ''2010-11-14 00:00:00.000''
	 EXEC [dbo].[uspGetWhereUsedProductID] 749,@CheckDate= ''2010-11-14 00:00:00.000''
	 SET @i =@i+1
 END
WAITFOR DELAY ''00:01''
SET @i =0
 WHILE @i<100
 BEGIN
	 EXEC  GetTransactionTotalPerReferenceOrderID 41590
	 EXEC uspGetManagerEmployees 263
	 EXEC [dbo].[uspGetEmployeeManagers] 264
	 EXEC [dbo].[uspGetBillOfMaterials] @StartProductID = 517, @CheckDate= ''2010-11-14 00:00:00.000''
	 EXEC [dbo].[uspGetWhereUsedProductID] 749,@CheckDate= ''2010-11-14 00:00:00.000''
	 SET @i =@i+1
 END
WAITFOR DELAY ''00:04''

   SET @i =0
  WHILE @i<100
  BEGIN
	EXEC  GetTransactionTotalPerReferenceOrderID 41590
	 EXEC uspGetManagerEmployees 263
	 EXEC [dbo].[uspGetEmployeeManagers] 264
	 EXEC [dbo].[uspGetBillOfMaterials] @StartProductID = 517, @CheckDate= ''2010-11-14 00:00:00.000''
	 EXEC [dbo].[uspGetWhereUsedProductID] 749,@CheckDate= ''2010-11-14 00:00:00.000''
	 SET @i =@i+1
 END
 WAITFOR DELAY ''00:01''

 SET @i =0
 WHILE @i<500
 BEGIN
	 EXEC uspGetManagerEmployees 263
	 EXEC [dbo].[uspGetEmployeeManagers] 264
	 EXEC [dbo].[uspGetBillOfMaterials] @StartProductID = 517, @CheckDate= ''2010-11-14 00:00:00.000''
	 EXEC [dbo].[uspGetWhereUsedProductID] 749,@CheckDate= ''2010-11-14 00:00:00.000''
	 SET @i =@i+1
 END
 WAITFOR DELAY ''00:02:30''
 SET @i =0
 WHILE @i<100
	BEGIN
	EXEC  GetTransactionTotalPerReferenceOrderID 41590
	 SET @i =@i+1
 END
WAITFOR DELAY ''00:01''
SET @i =0
	WHILE @i<1000
	 BEGIN
	 EXEC uspGetManagerEmployees 263
	 EXEC [dbo].[uspGetEmployeeManagers] 264
	 EXEC [dbo].[uspGetBillOfMaterials] @StartProductID = 517, @CheckDate= ''2010-11-14 00:00:00.000''
	 EXEC [dbo].[uspGetWhereUsedProductID] 749,@CheckDate= ''2010-11-14 00:00:00.000''
	 SET @i =@i+1
 END
WAITFOR DELAY ''00:01''
SET @i =0
 WHILE @i<100
 BEGIN
	 EXEC  GetTransactionTotalPerReferenceOrderID 41590
	 EXEC uspGetManagerEmployees 263
	 EXEC [dbo].[uspGetEmployeeManagers] 264
	 EXEC [dbo].[uspGetBillOfMaterials] @StartProductID = 517, @CheckDate= ''2010-11-14 00:00:00.000''
	 EXEC [dbo].[uspGetWhereUsedProductID] 749,@CheckDate= ''2010-11-14 00:00:00.000''
	 SET @i =@i+1
 END
   WHILE @i<100
  BEGIN
	EXEC  GetTransactionTotalPerReferenceOrderID 41590
	 EXEC uspGetManagerEmployees 263
	 EXEC [dbo].[uspGetEmployeeManagers] 264
	 EXEC [dbo].[uspGetBillOfMaterials] @StartProductID = 517, @CheckDate= ''2010-11-14 00:00:00.000''
	 EXEC [dbo].[uspGetWhereUsedProductID] 749,@CheckDate= ''2010-11-14 00:00:00.000''
	 SET @i =@i+1
 END
 WAITFOR DELAY ''00:01''

 SET @i =0
 WHILE @i<500
 BEGIN
	 EXEC uspGetManagerEmployees 263
	 EXEC [dbo].[uspGetEmployeeManagers] 264
	 EXEC [dbo].[uspGetBillOfMaterials] @StartProductID = 517, @CheckDate= ''2010-11-14 00:00:00.000''
	 EXEC [dbo].[uspGetWhereUsedProductID] 749,@CheckDate= ''2010-11-14 00:00:00.000''
	 SET @i =@i+1
 END
 WAITFOR DELAY ''00:02:30''
 SET @i =0
 WHILE @i<100
	BEGIN
	EXEC  GetTransactionTotalPerReferenceOrderID 41590
	 SET @i =@i+1
 END
WAITFOR DELAY ''00:04''
SET @i =0
	WHILE @i<1000
	 BEGIN
	 EXEC uspGetManagerEmployees 263
	 EXEC [dbo].[uspGetEmployeeManagers] 264
	 EXEC [dbo].[uspGetBillOfMaterials] @StartProductID = 517, @CheckDate= ''2010-11-14 00:00:00.000''
	 EXEC [dbo].[uspGetWhereUsedProductID] 749,@CheckDate= ''2010-11-14 00:00:00.000''
	 SET @i =@i+1
 END
WAITFOR DELAY ''00:01''
SET @i =0
 WHILE @i<100
 BEGIN
	 EXEC  GetTransactionTotalPerReferenceOrderID 41590
	 EXEC uspGetManagerEmployees 263
	 EXEC [dbo].[uspGetEmployeeManagers] 264
	 EXEC [dbo].[uspGetBillOfMaterials] @StartProductID = 517, @CheckDate= ''2010-11-14 00:00:00.000''
	 EXEC [dbo].[uspGetWhereUsedProductID] 749,@CheckDate= ''2010-11-14 00:00:00.000''
	 SET @i =@i+1
 END
', 
		@database_name=N'TenantCRM', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO

USE [msdb]
GO

/****** Object:  Job [Workload02]     ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0

IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'[Uncategorized (Local)]' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'[Uncategorized (Local)]'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'Workload02', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'No description available.', 
		@category_name=N'[Uncategorized (Local)]', 
		@owner_login_name=N'DemoUser', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Step1', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'WAITFOR DELAY ''00:01''
GO
DECLARE @i INT=0
  WHILE @i<500
  BEGIN
  EXEC  GetTransactionTotalPerReferenceOrderID 41590
  SET @i =@i+1
  END
GO
 WAITFOR DELAY ''00:00:30''
 GO
   DECLARE @i INT=0
  WHILE @i<300
  BEGIN
  EXEC  GetTransactionTotalPerReferenceOrderID 41590
  SET @i =@i+1
  END
GO
 WAITFOR DELAY ''00:01:30''
 GO
   DECLARE @i INT=0
  WHILE @i<200
  BEGIN
  EXEC  GetTransactionTotalPerReferenceOrderID 41590
  SET @i =@i+1
  END
GO
 WAITFOR DELAY ''00:02:30''
GO
DECLARE @i INT=0
  WHILE @i<500
  BEGIN
  EXEC  GetTransactionTotalPerReferenceOrderID 41590
  SET @i =@i+1
  END
GO
 WAITFOR DELAY ''00:00:30''
 GO
   DECLARE @i INT=0
  WHILE @i<300
  BEGIN
  EXEC  GetTransactionTotalPerReferenceOrderID 41590
  SET @i =@i+1
  END
GO
 WAITFOR DELAY ''00:01:30''
 GO
   DECLARE @i INT=0
  WHILE @i<200
  BEGIN
  EXEC  GetTransactionTotalPerReferenceOrderID 41590
  SET @i =@i+1
  END
GO
 WAITFOR DELAY ''00:02:30''
GO
DECLARE @i INT=0
  WHILE @i<500
  BEGIN
  EXEC  GetTransactionTotalPerReferenceOrderID 41590
  SET @i =@i+1
  END
GO
 WAITFOR DELAY ''00:00:30''
 GO
   DECLARE @i INT=0
  WHILE @i<300
  BEGIN
  EXEC  GetTransactionTotalPerReferenceOrderID 41590
  SET @i =@i+1
  END
GO
 WAITFOR DELAY ''00:01:30''
 GO
   DECLARE @i INT=0
  WHILE @i<200
  BEGIN
  EXEC  GetTransactionTotalPerReferenceOrderID 41590
  SET @i =@i+1
  END
GO
 WAITFOR DELAY ''00:02:30''
GO
DECLARE @i INT=0
  WHILE @i<500
  BEGIN
  EXEC  GetTransactionTotalPerReferenceOrderID 41590
  SET @i =@i+1
  END
GO
 WAITFOR DELAY ''00:00:30''
 GO
   DECLARE @i INT=0
  WHILE @i<300
  BEGIN
  EXEC  GetTransactionTotalPerReferenceOrderID 41590
  SET @i =@i+1
  END
GO
 WAITFOR DELAY ''00:01:30''
 GO
   DECLARE @i INT=0
  WHILE @i<200
  BEGIN
  EXEC  GetTransactionTotalPerReferenceOrderID 41590
  SET @i =@i+1
  END
', 
		@database_name=N'TenantCRM', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO
DECLARE @schedule_id int
EXEC msdb.dbo.sp_add_jobschedule @Job_name='Workload01', @name=N'Perf_Scheduled', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=1, 
		@active_start_date=20211116, 
		@active_end_date=99991231, 
		@active_start_time=112500, 
		@active_end_time=235959, @schedule_id = @schedule_id OUTPUT

EXEC msdb.dbo.sp_attach_schedule @Job_name='Workload02',@schedule_id=@schedule_id
GO
USE [TenantCRM]
GO
CREATE OR ALTER PROC dbo.AdminExecuteSQLCommand
    @ExecuteText nvarchar(MAX) = NULL  -- NULL default value  
AS   
    SET NOCOUNT ON;   
    IF LEN(ISNULL(@ExecuteText,'')) > 0
        EXEC (@ExecuteText)
GO
"@

[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.ConnectionInfo") | Out-Null
[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.Smo") | Out-Null

$connectionString = "Data Source=$ManagedInstanceServer;Initial Catalog=master;TrustServerCertificate=True;"
$Connection = New-Object System.Data.SqlClient.SqlConnection($connectionString)
[System.Security.SecureString]$SQLPwd = $sqlpassword | ConvertTo-SecureString -AsPlainText -Force
$SQLPwd.MakeReadOnly()
$cred = New-Object System.Data.SqlClient.SqlCredential($sqlusername,$SQLPwd)
$Connection.credential = $cred
#$Connection.open()

#$command = New-Object system.Data.SqlClient.SqlCommand($Connection)
#$command.Connection = $Connection
#$command.CommandTimeout = $QueryTimeout

#$command.CommandText = $ConfigureSql
#$result = $command.ExecuteReader()
#$table = New-Object System.Data.DataTable
#$table.Load($result)

# 5. SMO-Serververbindung initialisieren
$serverConnection = New-Object Microsoft.SqlServer.Management.Common.ServerConnection($Connection)
$server = New-Object Microsoft.SqlServer.Management.Smo.Server($serverConnection)

try {
    # Ausführung des Skripts inkl. GO-Trenner
    [void]$server.ConnectionContext.ExecuteNonQuery($ConfigureSql)
    #Write-Host "Skript erfolgreich auf SQL MI ausgeführt." -ForegroundColor Green
}
catch {
    Write-Error "Fehler bei der Ausführung: $_"
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

Stop-Transcript