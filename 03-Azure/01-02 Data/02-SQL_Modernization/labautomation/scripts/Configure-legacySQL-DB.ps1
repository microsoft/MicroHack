param(
    [Parameter(Mandatory)]
    [string] $sqlusername,
    [Parameter(Mandatory)]
    [string] $sqlpassword,
    [string] $ServerInstance = "localhost",
    [string]$TeamName = 'TEAM01'
)

$ErrorActionPreference = 'Stop'

$logPath = 'C:\Windows\Temp\Configure-legacySQL-DB.log'
Start-Transcript -Path $logPath -Append

Write-Host 'Configuring SQL legacy Instance DB...'

$ConfigureSql = @"
DECLARE @DefaultLogPath NVARCHAR(500)
SELECT 
    @DefaultLogPath = LEFT(physical_name, LEN(physical_name) - CHARINDEX('\', REVERSE(physical_name)) + 1) 
FROM 
    sys.master_files
WHERE 
    database_id = DB_ID('$($TeamName)_TenantDataDB')
    AND file_id = 2;

DECLARE @DBName VARCHAR(255)
DECLARE @SQLCmd NVARCHAR(MAX)
DECLARE DB_Crs CURSOR READ_ONLY FORWARD_ONLY FOR SELECT name FROM sys.databases WHERE name = '$($TeamName)_TenantDataDB' AND state_desc = 'ONLINE'
OPEN DB_Crs
FETCH NEXT FROM DB_Crs INTO @DBName

WHILE @@FETCH_STATUS = 0
BEGIN
	SET @SQLCmd = 'USE [' + @DBName + ']
	ALTER ASSEMBLY CLRUFDS WITH PERMISSION_SET = UNSAFE;
	ALTER ASSEMBLY Database1 WITH PERMISSION_SET = UNSAFE;
	'
	--PRINT @SQLCmd
	EXEC (@SQLCmd)

	SET @SQLCmd = 'ALTER DATABASE [' + @DBName + ']
	ADD LOG FILE (NAME = N''' + @DBName + '_Log2'', FILENAME = N''' + @DefaultLogPath + @DBName + '_Log2.ldf'');
	'
	--PRINT @SQLCmd
	EXEC (@SQLCmd)

	FETCH NEXT FROM DB_Crs INTO @DBName
END
CLOSE DB_Crs
DEALLOCATE DB_Crs
"@

$connectionString = "Data Source=$ServerInstance;Initial Catalog=master;TrustServerCertificate=True;"
$Connection = New-Object System.Data.SqlClient.SqlConnection($connectionString)
[System.Security.SecureString]$SQLPwd = $sqlpassword | ConvertTo-SecureString -AsPlainText -Force
$SQLPwd.MakeReadOnly()
$cred = New-Object System.Data.SqlClient.SqlCredential($sqlusername,$SQLPwd)
$Connection.credential = $cred

try {
    $Connection.open()

    $command = New-Object system.Data.SqlClient.SqlCommand($Connection)
    $command.Connection = $Connection
    $command.CommandTimeout = $QueryTimeout

    $command.CommandText = $ConfigureSql
    $result = $command.ExecuteReader()
    $table = New-Object System.Data.DataTable
    $table.Load($result)
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
