param(
    [string]$BackupUri,
    [string]$adminUsername,
    [string]$adminPassword,
    [string]$sqlMiAdminUsername,
    [string]$sqlMiAdminPassword
)

$ErrorActionPreference = 'Stop'

$logPath = 'C:\Windows\Temp\bootstrap-newsql.log'
Start-Transcript -Path $logPath -Append

Write-Host "Configuring SQL Firewall..."
& .\Set-FW-ForAllInstances.ps1

Write-Host "Restoring Sample Database..."

& .\Restore-SampleDatabases.ps1 -BackupUri $BackupUri -sqlusername $sqlMiAdminUsername -sqlpassword $sqlMiAdminPassword

Write-Host "Bootstrap completed."

Stop-Transcript