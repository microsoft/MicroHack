param(
    [Parameter(Mandatory)]
    [string]$ManagedInstanceServer,

    [Parameter(Mandatory)]
    [string] $sqlusername,

    [Parameter(Mandatory)]
    [string] $sqlpassword,

    [Parameter(Mandatory)]
    [string] $sqlMiSysadminUser
)

$ErrorActionPreference = 'Stop'

$logPath = 'C:\Windows\Temp\Configure-SQLMI-Sysadmins.log'
Start-Transcript -Path $logPath -Append

Write-Host 'Configuring SQL Managed Instance Sysadmins...'

$ConfigureSql = @"
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'$sqlMiSysadminUser')
BEGIN
    CREATE LOGIN [$sqlMiSysadminUser] FROM EXTERNAL PROVIDER;
END
ALTER SERVER ROLE [sysadmin] ADD MEMBER [$sqlMiSysadminUser];
"@

$connectionString = "Data Source=$ManagedInstanceServer;Initial Catalog=master;TrustServerCertificate=True;"
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
    $result = $command.ExecuteNonQuery()
    #$result = $command.ExecuteReader()
    #$table = New-Object System.Data.DataTable
    #$table.Load($result)
}
catch {
    Write-Host $result
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

Stop-Transcript