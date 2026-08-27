param(
    [string]$SamplesBaseUri,
    [string]$LabsBaseUri,
    [string]$BackupBaseUri,
    [string]$adminUsername,
    [string]$adminPassword,
    [string]$WallpaperUri,  
    [string]$TeamName,
    [string]$ManagedInstanceServer,
    [string]$StorageAccountName,
    [string]$ServerInstance
)

$ErrorActionPreference = 'Stop'

$logPath = 'C:\Windows\Temp\bootstrap-teamvm.log'
Start-Transcript -Path $logPath -Append

Write-Host "Configuring TEAM VM..."

##Not working with Bastion, so we will not set wallpaper for now.  If you want to set wallpaper, you can run the following command after you RDP into the VM.
Write-Host "Configure Team Wallpaper..."
& .\Configure-TeamWallpaper.ps1 -WallpaperUri $WallpaperUri -TeamName $TeamName

Write-Host "Restoring Team Databases..."
& .\Restore-TeamDatabases.ps1 -TeamName $TeamName -BackupBaseUri $BackupBaseUri -sqlusername $adminUsername -sqlpassword $adminPassword -ServerInstance $ServerInstance

Write-Host "Configuring Team Databases..."
& .\Configure-legacySQL-DB.ps1 -TeamName $TeamName -sqlusername $adminUsername -sqlpassword $adminPassword -ServerInstance $ServerInstance

Write-Host "Installing Team Tools..."
& .\install-team-tools.ps1

Write-Host "Downloading Sample Files..."
& .\Download-Samples.ps1 -SamplesBaseUri $SamplesBaseUri -ForceDownload

Write-Host "Downloading LAB Files..."
& .\Download-Labs.ps1 -LabsBaseUri $LabsBaseUri -ForceDownload

Write-Host "Configuring Teams Shortcuts..."
& .\Configure-Teams-Shortcuts.ps1 -ManagedInstanceServer $ManagedInstanceServer -StorageAccountName $StorageAccountName

Write-Host "Bootstrap completed."

Stop-Transcript