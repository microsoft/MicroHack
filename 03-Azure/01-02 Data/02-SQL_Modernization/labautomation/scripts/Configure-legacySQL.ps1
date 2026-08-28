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
