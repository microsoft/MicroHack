param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $BackupBaseUri,

    [Parameter(Mandatory = $true)]
    [string]$StorageAccountName,

    [Parameter(Mandatory)]
    [string]$ManagedInstanceServer,

    [Parameter(Mandatory)]
    [string] $sqlusername,

    [Parameter(Mandatory)]
    [string] $sqlpassword,

    [string]$ContainerName = 'backups'
)


$logPath = 'C:\Windows\Temp\Restore-TeamDatabasesMI.log'
Start-Transcript -Path $logPath -Append

$ErrorActionPreference = 'Stop'

Write-Host 'Checking Storage RBAC propagation...'

for($i=1; $i -le 30; $i++)
{
    try
    {
        az storage blob list `
            --account-name $StorageAccountName `
            --container-name $ContainerName `
            --auth-mode login `
            --output none

        Write-Host "RBAC active."
        break
    }
    catch
    {
        Start-Sleep -Seconds 20
    }
}

Write-Host 'Authenticating with VM Managed Identity...'

az login --identity --allow-no-subscriptions | Out-Null

$BackupFiles = @(
    "LocalMasterDataDB.bak"
    "SharedMasterDataDB.bak"
    "TenantDataDB.bak"
    "GlobalDataDB.bak"
    "TenantCRM.bak"
)

$CredentialUrl = "https://$StorageAccountName.blob.core.windows.net/$ContainerName"

#
# Create MI Credential
#
$CredentialSql = @"
IF NOT EXISTS
(
    SELECT 1
    FROM sys.credentials
    WHERE name = '$CredentialUrl'
)
BEGIN
    CREATE CREDENTIAL [$CredentialUrl]
    WITH IDENTITY = 'Managed Identity';
END
"@

# Invoke-Sqlcmd `
#     -ServerInstance $ManagedInstanceServer `
#     -Database master `
#     -Username $SqlUser `
#     -Password $SqlPassword `
#     -Encrypt Mandatory `
#     -TrustServerCertificate `
#     -Query $CredentialSql

$connectionString = "Data Source=$ManagedInstanceServer;Initial Catalog=master;TrustServerCertificate=True;"
$Connection = New-Object System.Data.SqlClient.SqlConnection($connectionString)
[System.Security.SecureString]$SQLPwd = $sqlpassword | ConvertTo-SecureString -AsPlainText -Force
$SQLPwd.MakeReadOnly()
$cred = New-Object System.Data.SqlClient.SqlCredential($sqlusername,$SQLPwd)
$Connection.credential = $cred
$Connection.open()

$command = New-Object system.Data.SqlClient.SqlCommand($Connection)
$command.Connection = $Connection
$command.CommandTimeout = $QueryTimeout

$command.CommandText = $CredentialSql

$result = $command.ExecuteReader()
$table = New-Object System.Data.DataTable
$table.Load($result)

$Connection.Close()
#$table

foreach ($BackupFile in $BackupFiles)
{
    $DatabaseName = [System.IO.Path]::GetFileNameWithoutExtension($BackupFile)

    $GithubUrl =
        "$BackupBaseUri/$BackupFile"

    $LocalFile =
        Join-Path $env:TEMP $BackupFile

    $BlobUrl =
        "https://$StorageAccountName.blob.core.windows.net/$ContainerName/$BackupFile"

    Write-Host "Downloading $BackupFile"

    $lastProgressPreference = $ProgressPreference
    $ProgressPreference = 'SilentlyContinue'

    Invoke-WebRequest `
        -Uri $GithubUrl `
        -OutFile $LocalFile

    $ProgressPreference = $lastProgressPreference

    Write-Host "Uploading $BackupFile"

    az storage blob upload `
        --auth-mode login `
        --account-name $StorageAccountName `
        --container-name $ContainerName `
        --name $BackupFile `
        --file $LocalFile `
        --overwrite true

    if ($LASTEXITCODE -ne 0)
    {
        throw "Upload failed for $BackupFile"
    }

    $RestoreSql = @"
IF DB_ID('$DatabaseName') IS NULL
BEGIN

    RESTORE DATABASE [$DatabaseName]
    FROM URL = '$BlobUrl'

END
ELSE
BEGIN

    PRINT 'Database [$DatabaseName] already exists. Skipping restore.'

END
"@

    Write-Host "Restoring $DatabaseName"

    # Invoke-Sqlcmd `
    #     -ServerInstance $ManagedInstanceServer `
    #     -Database master `
    #     -Username $SqlUser `
    #     -Password $SqlPassword `
    #     -Encrypt Mandatory `
    #     -TrustServerCertificate `
    #     -QueryTimeout 0 `
    #     -Query $RestoreSql

    $connectionString = "Data Source=$ManagedInstanceServer;Initial Catalog=master;TrustServerCertificate=True;"
    $Connection = New-Object System.Data.SqlClient.SqlConnection($connectionString)
    [System.Security.SecureString]$SQLPwd = $sqlpassword | ConvertTo-SecureString -AsPlainText -Force
    $SQLPwd.MakeReadOnly()
    $cred = New-Object System.Data.SqlClient.SqlCredential($sqlusername,$SQLPwd)
    $Connection.credential = $cred
    $Connection.open()

    $command = New-Object system.Data.SqlClient.SqlCommand($Connection)
    $command.Connection = $Connection
    $command.CommandTimeout = $QueryTimeout

    $command.CommandText = $RestoreSql

    $result = $command.ExecuteReader()
    $table = New-Object System.Data.DataTable
    $table.Load($result)

    $Connection.Close()
    #$table

    Remove-Item $LocalFile -Force -ErrorAction SilentlyContinue
}

Write-Host 'All databases processed.'

Stop-Transcript