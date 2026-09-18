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

[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.ConnectionInfo") | Out-Null
[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.Smo") | Out-Null

$connectionString = "Data Source=$ManagedInstanceServer;Initial Catalog=master;TrustServerCertificate=True;"
$Connection = New-Object System.Data.SqlClient.SqlConnection($connectionString)
[System.Security.SecureString]$SQLPwd = $sqlpassword | ConvertTo-SecureString -AsPlainText -Force
$SQLPwd.MakeReadOnly()
$cred = New-Object System.Data.SqlClient.SqlCredential($sqlusername,$SQLPwd)
$Connection.credential = $cred

# 5. SMO-Serververbindung initialisieren
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

Stop-Transcript