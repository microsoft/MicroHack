USE [msdb]
GO

/****** Job: [2 Fabric Space Ranger Workload] ******/
-- Rewritten for the MicroHack framework: both job steps now discover the per-attendee
-- databases by name pattern instead of iterating a fixed TailspinToys_User001..100 range.
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'[Uncategorized (Local)]' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'[Uncategorized (Local)]'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'2 Fabric Space Ranger Workload', 
		@enabled=0, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'No description available.', 
		@category_name=N'[Uncategorized (Local)]', 
		@owner_login_name=N'sa', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Step [Insert Space Ranger sales data] ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Insert Space Ranger sales data', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'

-- Insert Space Ranger sales rows into every per-attendee TailspinToys database.

SET NOCOUNT ON

DECLARE @SQLCMD_TEMPLATE NVARCHAR(MAX)
DECLARE @SQLCMD NVARCHAR(MAX)
DECLARE @DBNAME NVARCHAR(128)
DECLARE @DBFBNAME NVARCHAR(128)

SET @SQLCMD_TEMPLATE = ''
DECLARE @NumberOfRows INT = 10;
DECLARE @ProductID INT;
    SELECT @ProductID = [ProductID]
    FROM [##db-name##].[dbo].[Product]
    WHERE [ProductName] = ''''Fabric Space Ranger'''';

;WITH Numbers AS (
    SELECT 1 AS n
    UNION ALL
    SELECT n + 1 FROM Numbers WHERE n + 1 <= @NumberOfRows
)
INSERT INTO [##db-name##].[dbo].[Sales] (
    [OrderDate], [ShipDate], [CustomerStateID], [ProductID], [Quantity],
    [UnitPrice], [DiscountAmount], [PromotionCode], [CustomerID], [TotalPrice]
)
SELECT
    CAST(GETDATE() AS DATE) AS [OrderDate],
    NULL AS [ShipDate],
    1 + ABS(CHECKSUM(NEWID())) % 51 AS [CustomerStateID],
    @ProductID AS [ProductID],
    1 + ABS(CHECKSUM(NEWID())) % 5 AS [Quantity],
    49.99 AS [UnitPrice],
    CASE WHEN ABS(CHECKSUM(NEWID())) % 2 = 1
         THEN ROUND((ABS(CHECKSUM(NEWID())) % 21) * 0.01 * 49.99, 2)
         ELSE 0.00
    END AS [DiscountAmount],
    CASE WHEN ABS(CHECKSUM(NEWID())) % 2 = 1
         THEN CONCAT(''''FIRSTMISSION'''', REPLACE(STR(ROUND((ABS(CHECKSUM(NEWID())) % 21) * 0.01 * 49.99, 2), 6, 2), ''''.'''', ''''''''))
         ELSE NULL
    END AS [PromotionCode],
    1 + ABS(CHECKSUM(NEWID())) % 1000 AS [CustomerID],
    (1 + ABS(CHECKSUM(NEWID())) % 5) * 49.99
        - CASE WHEN ABS(CHECKSUM(NEWID())) % 2 = 1
               THEN ROUND((ABS(CHECKSUM(NEWID())) % 21) * 0.01 * 49.99, 2)
               ELSE 0.00
          END AS [TotalPrice]
FROM Numbers
--OPTION (MAXRECURSION 32767);''

DECLARE db_cursor CURSOR LOCAL FAST_FORWARD FOR
	SELECT name FROM sys.databases
	WHERE name LIKE ''TailspinToys[_]%''
	  AND name NOT LIKE ''TailspinToysFeedback[_]%''
	  AND name NOT LIKE ''%[_]Demo[_]%''
OPEN db_cursor
FETCH NEXT FROM db_cursor INTO @DBNAME
WHILE @@FETCH_STATUS = 0
BEGIN
	SET @DBFBNAME = REPLACE(@DBNAME, ''TailspinToys_'', ''TailspinToysFeedback_'')
	SET @SQLCMD = REPLACE(REPLACE(@SQLCMD_TEMPLATE,''##db-name##'',@DBNAME),''##db-fb-name##'',@DBFBNAME)
	BEGIN TRY
		EXECUTE (@SQLCMD)
	END TRY
	BEGIN CATCH
		PRINT ERROR_MESSAGE()
	END CATCH
	FETCH NEXT FROM db_cursor INTO @DBNAME
END
CLOSE db_cursor
DEALLOCATE db_cursor', 
		@database_name=N'master', 
		@flags=8
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Step [Insert Space Ranger feedback data] ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Insert Space Ranger feedback data', 
		@step_id=2, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'-- Insert Space Ranger feedback into every per-attendee TailspinToysFeedback database.

SET NOCOUNT ON

DECLARE @SQLCMD_TEMPLATE NVARCHAR(MAX)
DECLARE @SQLCMD NVARCHAR(MAX)
DECLARE @DBNAME NVARCHAR(128)
DECLARE @DBFBNAME NVARCHAR(128)

SET @SQLCMD_TEMPLATE = ''
DECLARE @CustomerID INT;
DECLARE @Rating INT;
DECLARE @ReviewText NVARCHAR(4000);
DECLARE @ProductID INT
SELECT @ProductID = [ProductID] from [##db-name##].[dbo].[Product] WHERE [ProductName] = ''''Fabric Space Ranger''''

SELECT TOP 1 @CustomerID = [CustomerID]
FROM [##db-name##].[dbo].[Sales]
WHERE [ProductID] = @ProductID
ORDER BY [OrderNumber] DESC;

SET @Rating = 1 + ABS(CHECKSUM(NEWID())) % 5;
SET @ReviewText = CASE @Rating
    WHEN 1 THEN N''''Very poor experience. Would not recommend.''''
    WHEN 2 THEN N''''Below average. Product did not meet expectations.''''
    WHEN 3 THEN N''''Average product. Satisfactory but not outstanding.''''
    WHEN 4 THEN N''''Good quality, I am satisfied with my purchase.''''
    WHEN 5 THEN N''''Very satisfied! Exceeded all my expectations. I love the Fabric Space Ranger''''
    END;

INSERT INTO [##db-fb-name##].[dbo].[ProductFeedback] ([ProductID], [CustomerID], [FeedbackDate], [Rating], [ReviewText])
VALUES (@ProductID, @CustomerID, GETDATE(), @Rating, @ReviewText)''

DECLARE db_cursor CURSOR LOCAL FAST_FORWARD FOR
	SELECT name FROM sys.databases
	WHERE name LIKE ''TailspinToys[_]%''
	  AND name NOT LIKE ''TailspinToysFeedback[_]%''
	  AND name NOT LIKE ''%[_]Demo[_]%''
OPEN db_cursor
FETCH NEXT FROM db_cursor INTO @DBNAME
WHILE @@FETCH_STATUS = 0
BEGIN
	SET @DBFBNAME = REPLACE(@DBNAME, ''TailspinToys_'', ''TailspinToysFeedback_'')
	SET @SQLCMD = REPLACE(REPLACE(@SQLCMD_TEMPLATE,''##db-name##'',@DBNAME),''##db-fb-name##'',@DBFBNAME)
	BEGIN TRY
		EXECUTE (@SQLCMD)
	END TRY
	BEGIN CATCH
		PRINT ERROR_MESSAGE()
	END CATCH
	FETCH NEXT FROM db_cursor INTO @DBNAME
END
CLOSE db_cursor
DEALLOCATE db_cursor', 
		@database_name=N'master', 
		@flags=8
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'data every minute', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=4, 
		@freq_subday_interval=1, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20260219, 
		@active_end_date=99991231, 
		@active_start_time=0, 
		@active_end_time=235959, 
		@schedule_uid=N'10d16eeb-c871-463b-9572-03d5179cf62a'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO
