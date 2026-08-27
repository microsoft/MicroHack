param(
    [string]$BackupBaseUri,
    [string]$StorageAccountName,
    [string]$ManagedInstanceServer,    
    [string]$adminUsername,
    [string]$adminPassword,
    [string]$sqlMiAdminUsername,
    [string]$sqlMiAdminPassword
)

$ErrorActionPreference = 'Stop'

$logPath = 'C:\Windows\Temp\bootstrap-legacy.log'
Start-Transcript -Path $logPath -Append

Write-Host "Configuring SQL Firewall..."
& .\Set-FW-ForAllInstances.ps1

#Write-Host "Restoring Team Databases..."
#
#& .\Restore-TeamDatabases.ps1 -LabCount $LabCount -BackupBaseUri $BackupBaseUri -sqlusername $adminUsername -sqlpassword $adminPassword

Write-Host "Downloading Team Databases..."

& .\Download-TeamDatabases.ps1 -BackupBaseUri $BackupBaseUri

Write-Host "Configuring legacy SQL Server..."

& .\Configure-legacySQL.ps1 -sqlusername $adminUsername -sqlpassword $adminPassword

Write-Host "Installing AzureCLI..."

& .\Install-AzureCLI.ps1

Write-Host "Restoring Team Databases on SQLMI..."

& .\Restore-TeamDatabasesMI.ps1 -BackupBaseUri $BackupBaseUri -sqlusername $sqlMiAdminUsername -sqlpassword $sqlMiAdminPassword -StorageAccountName $StorageAccountName -ManagedInstanceServer $ManagedInstanceServer

Write-Host "Configuring SQLMI..."

& .\Configure-SQLMI.ps1 -ManagedInstanceServer $ManagedInstanceServer -sqlusername $sqlMiAdminUsername -sqlpassword $sqlMiAdminPassword

Write-Host "Bootstrap completed."

Stop-Transcript