<#
.SYNOPSIS
Downloads four SQL Server backup files and restores one database set per team.

.DESCRIPTION
For each team, the script restores:

    TEAMxx_LocalMasterDataDB
    TEAMxx_SharedMasterDataDB
    TEAMxx_TenantDataDB
    TEAMxx_GlobalDataDB

The physical database files are relocated to the SQL Server instance's
default data and log directories. Every restored database receives unique
physical file names, including backups containing multiple data or log files.

The script is designed for the local default SQL Server instance.

.REQUIREMENTS
- Windows PowerShell 5.1 or PowerShell 7
- SqlServer PowerShell module
- Local SQL Server default instance
- Permission to create and restore databases
- SQL Server service account must be able to read the download directory

.EXAMPLE
.\Restore-TeamDatabases.ps1 `
    -TeamCount 4 `
    -BackupBaseUri "https://raw.githubusercontent.com/organisation/repository/main/backups"

.EXAMPLE
.\Restore-TeamDatabases.ps1 `
    -TeamCount 4 `
    -BackupBaseUri "https://storageaccount.blob.core.windows.net/backups?<SAS-token>" `
    -ReplaceExisting

.NOTES
When the base URI contains a query string, such as a SAS token, the script
inserts the backup file name before the query string.
#>

[CmdletBinding()]
param
(
    [Parameter(Mandatory = $true)]
    [string]$TeamName = 'TEAM01',

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $BackupBaseUri,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string] $DownloadDirectory = "C:\SQLBackups\TeamDatabases",

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string] $ServerInstance = "localhost",

    [Parameter(Mandatory = $false)]
    [string] $sqlusername,

    [Parameter(Mandatory = $false)]
    [string] $sqlpassword,
    
    [Parameter(Mandatory = $false)]
    [switch] $ReplaceExisting,

    [Parameter(Mandatory = $false)]
    [switch] $ForceDownload
)

$logPath = 'C:\Windows\Temp\Restore-TeamDatabases.log'
Start-Transcript -Path $logPath -Append

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Windows PowerShell 5.1 can otherwise negotiate an older TLS version.
[Net.ServicePointManager]::SecurityProtocol =
    [Net.ServicePointManager]::SecurityProtocol -bor
    [Net.SecurityProtocolType]::Tls12

$backupNames = @(
    "LocalMasterDataDB",
    "SharedMasterDataDB",
    "TenantDataDB",
    "GlobalDataDB"
)

function Escape-SqlString
{
    param
    (
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string] $Value
    )

    return $Value.Replace("'", "''")
}

function Escape-SqlIdentifier
{
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $Value
    )

    return $Value.Replace("]", "]]")
}

function Get-BackupDownloadUri
{
    param
    (
        [Parameter(Mandatory = $true)]
        [string] $BaseUri,

        [Parameter(Mandatory = $true)]
        [string] $FileName
    )

    # Handles normal URLs:
    # https://server/backups + Database.bak
    #
    # Also handles URLs containing a query string:
    # https://server/container?sv=... becomes
    # https://server/container/Database.bak?sv=...

    $questionMarkPosition = $BaseUri.IndexOf("?")

    if ($questionMarkPosition -ge 0)
    {
        $uriPath  = $BaseUri.Substring(0, $questionMarkPosition).TrimEnd("/")
        $uriQuery = $BaseUri.Substring($questionMarkPosition)

        return "$uriPath/$FileName$uriQuery"
    }

    return "$($BaseUri.TrimEnd('/'))/$FileName"
}

function Invoke-DatabaseQuery
{
    param
    (
        [Parameter(Mandatory = $true)]
        [string] $Query,

        [Parameter(Mandatory = $false)]
        [int] $QueryTimeout = 0
    )

    # Invoke-Sqlcmd `
    #     -ServerInstance $ServerInstance `
    #     -Database "master" `
    #     -Query $Query `
    #     -TrustServerCertificate `
    #     -QueryTimeout $QueryTimeout `
    #     -AbortOnError `
    #     -ErrorAction Stop

    if (-not [string]::IsNullOrWhiteSpace($sqlusername) -and
        -not [string]::IsNullOrWhiteSpace($sqlpassword))
    {
        $connectionString = "Data Source=$ServerInstance;Initial Catalog=master;TrustServerCertificate=True;"
		$Connection = New-Object System.Data.SqlClient.SqlConnection($connectionString)
		[System.Security.SecureString]$SQLPwd = $sqlpassword | ConvertTo-SecureString -AsPlainText -Force
		$SQLPwd.MakeReadOnly()
		$cred = New-Object System.Data.SqlClient.SqlCredential($sqlusername,$SQLPwd)
		$Connection.credential = $cred
    }
    else
    {
        $connectionString = "Data Source=$ServerInstance;Initial Catalog=master;Integrated Security=True;TrustServerCertificate=True;"
        $Connection = New-Object System.Data.SqlClient.SqlConnection($connectionString)
    }
    $Connection.open()

    $command = New-Object system.Data.SqlClient.SqlCommand($Connection)
    $command.Connection = $Connection
    $command.CommandTimeout = $QueryTimeout

    $command.CommandText = $Query # "SELECT 1 FROM sys.databases WHERE name = '$Databasename'" 

    $result = $command.ExecuteReader()
    $table = New-Object System.Data.DataTable
    $table.Load($result)

    $Connection.Close()
    $table

}

function Get-SqlDefaultDirectories
{
    $query = @"
SELECT
    CONVERT(nvarchar(4000), SERVERPROPERTY('InstanceDefaultDataPath'))
        AS DataPath,
    CONVERT(nvarchar(4000), SERVERPROPERTY('InstanceDefaultLogPath'))
        AS LogPath,
    (
        SELECT TOP (1)
            LEFT(
                physical_name,
                LEN(physical_name) -
                CHARINDEX('\', REVERSE(physical_name)) + 1
            )
        FROM master.sys.database_files
        WHERE type = 0
        ORDER BY file_id
    ) AS FallbackDataPath,
    (
        SELECT TOP (1)
            LEFT(
                physical_name,
                LEN(physical_name) -
                CHARINDEX('\', REVERSE(physical_name)) + 1
            )
        FROM master.sys.database_files
        WHERE type = 1
        ORDER BY file_id
    ) AS FallbackLogPath;
"@

    $result = Invoke-DatabaseQuery -Query $query |
        Select-Object -First 1

    $dataPath = [string] $result.DataPath
    $logPath  = [string] $result.LogPath

    if ([string]::IsNullOrWhiteSpace($dataPath))
    {
        $dataPath = [string] $result.FallbackDataPath
    }

    if ([string]::IsNullOrWhiteSpace($logPath))
    {
        $logPath = [string] $result.FallbackLogPath
    }

    if ([string]::IsNullOrWhiteSpace($dataPath))
    {
        throw "The default SQL Server data directory could not be determined."
    }

    if ([string]::IsNullOrWhiteSpace($logPath))
    {
        throw "The default SQL Server log directory could not be determined."
    }

    [PSCustomObject] @{
        DataPath = $dataPath.TrimEnd('\')
        LogPath  = $logPath.TrimEnd('\')
    }
}

function Get-BackupFileList
{
    param
    (
        [Parameter(Mandatory = $true)]
        [string] $BackupFile
    )

    $escapedBackupFile = Escape-SqlString -Value $BackupFile

    $fileList = @(
        Invoke-DatabaseQuery -Query @"
RESTORE FILELISTONLY
FROM DISK = N'$escapedBackupFile';
"@
    )

    if ($fileList.Count -eq 0)
    {
        throw "The backup does not contain any database files: $BackupFile"
    }

    return $fileList
}

function Get-TargetFileExtension
{
    param
    (
        [Parameter(Mandatory = $true)]
        [object] $BackupFileInformation,

        [Parameter(Mandatory = $true)]
        [int] $FileNumberForType
    )

    $originalExtension = [System.IO.Path]::GetExtension(
        [string] $BackupFileInformation.PhysicalName
    )

    if (-not [string]::IsNullOrWhiteSpace($originalExtension))
    {
        return $originalExtension
    }

    if ([string] $BackupFileInformation.Type -eq "L")
    {
        return ".ldf"
    }

    if ($FileNumberForType -eq 1)
    {
        return ".mdf"
    }

    return ".ndf"
}

function New-RestoreMoveClauses
{
    param
    (
        [Parameter(Mandatory = $true)]
        [string] $DatabaseName,

        [Parameter(Mandatory = $true)]
        [object[]] $BackupFileList,

        [Parameter(Mandatory = $true)]
        [string] $DefaultDataPath,

        [Parameter(Mandatory = $true)]
        [string] $DefaultLogPath
    )

    $moveClauses = @()
    $dataFileNumber = 0
    $logFileNumber  = 0

    foreach ($backupFileInformation in $BackupFileList)
    {
        $logicalName = [string] $backupFileInformation.LogicalName
        $fileType    = [string] $backupFileInformation.Type

        if ([string]::IsNullOrWhiteSpace($logicalName))
        {
            throw "A backup file entry has no logical file name."
        }

        switch ($fileType)
        {
            "D"
            {
                $dataFileNumber++

                $extension = Get-TargetFileExtension `
                    -BackupFileInformation $backupFileInformation `
                    -FileNumberForType $dataFileNumber

                if ($dataFileNumber -eq 1)
                {
                    $targetFileName = "$DatabaseName$extension"
                }
                else
                {
                    $targetFileName = "{0}_Data{1:D2}{2}" -f `
                        $DatabaseName,
                        $dataFileNumber,
                        $extension
                }

                $targetFilePath = Join-Path `
                    -Path $DefaultDataPath `
                    -ChildPath $targetFileName
            }

            "S"
            {
                $dataFileNumber++

                $extension = Get-TargetFileExtension `
                    -BackupFileInformation $backupFileInformation `
                    -FileNumberForType $dataFileNumber

                if ($dataFileNumber -eq 1)
                {
                    $targetFileName = "$DatabaseName$extension"
                }
                else
                {
                    $targetFileName = "{0}_Data{1:D2}{2}" -f `
                        $DatabaseName,
                        $dataFileNumber,
                        $extension
                }

                $targetFilePath = Join-Path `
                    -Path $DefaultDataPath `
                    -ChildPath $targetFileName
            }

            "L"
            {
                $logFileNumber++

                $extension = Get-TargetFileExtension `
                    -BackupFileInformation $backupFileInformation `
                    -FileNumberForType $logFileNumber

                if ($logFileNumber -eq 1)
                {
                    $targetFileName = "${DatabaseName}_log$extension"
                }
                else
                {
                    $targetFileName = "{0}_Log{1:D2}{2}" -f `
                        $DatabaseName,
                        $logFileNumber,
                        $extension
                }

                $targetFilePath = Join-Path `
                    -Path $DefaultLogPath `
                    -ChildPath $targetFileName
            }

            default
            {
                throw @"
The backup contains unsupported file type '$fileType' for logical file
'$logicalName'. The script currently supports normal data files (D) and
transaction log files (L).
"@
            }
        }

        $escapedLogicalName = Escape-SqlString -Value $logicalName
        $escapedTargetPath  = Escape-SqlString -Value $targetFilePath

        $moveClauses += "MOVE N'$escapedLogicalName' TO N'$escapedTargetPath'"
    }

    return $moveClauses
}

function Restore-TeamDatabase
{
    param
    (
        [Parameter(Mandatory = $true)]
        [string] $DatabaseName,

        [Parameter(Mandatory = $true)]
        [string] $BackupFile,

        [Parameter(Mandatory = $true)]
        [string] $DefaultDataPath,

        [Parameter(Mandatory = $true)]
        [string] $DefaultLogPath
    )

    $escapedDatabaseName    = Escape-SqlIdentifier -Value $DatabaseName
    $escapedDatabaseLiteral = Escape-SqlString -Value $DatabaseName
    $escapedBackupFile      = Escape-SqlString -Value $BackupFile

    $databaseExistsQuery = @"
SELECT
    CASE
        WHEN DB_ID(N'$escapedDatabaseLiteral') IS NULL THEN 0
        ELSE 1
    END AS DatabaseExists;
"@

    $databaseExists = [int] (
        Invoke-DatabaseQuery -Query $databaseExistsQuery |
        Select-Object -First 1
    ).DatabaseExists

    if ($databaseExists -eq 1 -and -not $ReplaceExisting.IsPresent)
    {
        Write-Warning @"
Database [$DatabaseName] already exists and will be skipped.
Use -ReplaceExisting if the database should be overwritten.
"@
        return
    }

    $backupFileList = @(
        Get-BackupFileList -BackupFile $BackupFile
    )

    $moveClauses = @(
        New-RestoreMoveClauses `
            -DatabaseName $DatabaseName `
            -BackupFileList $backupFileList `
            -DefaultDataPath $DefaultDataPath `
            -DefaultLogPath $DefaultLogPath
    )

    if ($moveClauses.Count -eq 0)
    {
        throw "No MOVE clauses were generated for [$DatabaseName]."
    }

    $restoreOptions = @()

    foreach ($moveClause in $moveClauses)
    {
        $restoreOptions += $moveClause
    }

    $restoreOptions += "RECOVERY"
    $restoreOptions += "STATS = 5"

    if ($ReplaceExisting.IsPresent)
    {
        $restoreOptions += "REPLACE"
    }

    $restoreOptionText = $restoreOptions -join ",`r`n    "

    $prepareExistingDatabase = ""

    if ($databaseExists -eq 1)
    {
        $prepareExistingDatabase = @"
ALTER DATABASE [$escapedDatabaseName]
    SET SINGLE_USER
    WITH ROLLBACK IMMEDIATE;
"@
    }

    $restoreQuery = @"
$prepareExistingDatabase

RESTORE DATABASE [$escapedDatabaseName]
FROM DISK = N'$escapedBackupFile'
WITH
    $restoreOptionText;

ALTER DATABASE [$escapedDatabaseName]
    SET MULTI_USER;
"@

    Write-Host ""
    Write-Host "Restoring [$DatabaseName]..."
    Write-Host ""

    try
    {
        Invoke-DatabaseQuery `
            -Query $restoreQuery `
            -QueryTimeout 0 |
            Out-Host

        Write-Host "Restored [$DatabaseName]." -ForegroundColor Green
    }
    catch
    {
        if ($databaseExists -eq 1)
        {
            try
            {
                Invoke-DatabaseQuery -Query @"
IF DB_ID(N'$escapedDatabaseLiteral') IS NOT NULL
BEGIN
    ALTER DATABASE [$escapedDatabaseName]
        SET MULTI_USER;
END;
"@
            }
            catch
            {
                Write-Warning "Could not return [$DatabaseName] to MULTI_USER after a failed restore."
            }
        }

        throw
    }
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

Write-Host "Testing SQL Server connection to [$ServerInstance]..."

$serverInformation = Invoke-DatabaseQuery -Query @"
SELECT
    CONVERT(nvarchar(128), SERVERPROPERTY('ServerName')) AS ServerName,
    CONVERT(nvarchar(128), SERVERPROPERTY('ProductVersion')) AS ProductVersion,
    CONVERT(nvarchar(128), SERVERPROPERTY('Edition')) AS Edition;
"@ | Select-Object -First 1

Write-Host (
    "Connected to [{0}], SQL Server {1}, {2}." -f
    $serverInformation.ServerName,
    $serverInformation.ProductVersion,
    $serverInformation.Edition
) -ForegroundColor Green

$defaultDirectories = Get-SqlDefaultDirectories

Write-Host "Default data path: $($defaultDirectories.DataPath)"
Write-Host "Default log path:  $($defaultDirectories.LogPath)"

$downloadedBackups = @{}

foreach ($backupName in $backupNames)
{
    $fileName       = "$backupName.bak"
    $destination    = Join-Path $DownloadDirectory $fileName
    $downloadedBackups[$backupName] = $destination
}

Write-Host ""
Write-Host (
    "Starting database restores team {0}." -f
    $TeamName
) -ForegroundColor Cyan

$teamPrefix = $TeamName

foreach ($backupName in $backupNames)
{
    $targetDatabaseName = "${teamPrefix}_${backupName}"

    Restore-TeamDatabase `
        -DatabaseName $targetDatabaseName `
        -BackupFile $downloadedBackups[$backupName] `
        -DefaultDataPath $defaultDirectories.DataPath `
        -DefaultLogPath $defaultDirectories.LogPath
}

Write-Host ""
Write-Host (
    "Completed. Team database for team {0} were processed." -f $TeamName
) -ForegroundColor Green

Stop-Transcript