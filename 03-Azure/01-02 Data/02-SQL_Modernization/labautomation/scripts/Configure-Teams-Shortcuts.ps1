[CmdletBinding()]
param
(
    [string] $ManagedInstanceServer,
    [string] $StorageAccountName
)

$ErrorActionPreference = 'Stop'

$logPath = 'C:\Windows\Temp\Configure-Teams-Shortcuts.log'
Start-Transcript -Path $logPath -Append

if (-not (Test-Path -LiteralPath "C:\MicroHack"))
{
    New-Item `
        -ItemType Directory `
        -Path "C:\MicroHack" `
        -Force |
        Out-Null
}

$EnvironmentInfoPath = Join-Path "C:\MicroHack" "Readme.txt"

if (Test-Path $EnvironmentInfoPath) {
    Remove-Item -LiteralPath $EnvironmentInfoPath -ErrorAction SilentlyContinue -Force
}

"Your Hack-Environment" | Out-File -FilePath $EnvironmentInfoPath -Encoding utf8 -Force
"---------------------------------------------------------------------------" | Out-File -FilePath $EnvironmentInfoPath -Encoding utf8 -Force -Append
"SQL Server 2016:      legacysql2016" | Out-File -FilePath $EnvironmentInfoPath -Encoding utf8 -Force -Append
"SQL Server (Auth):    Windows Authentication" | Out-File -FilePath $EnvironmentInfoPath -Encoding utf8 -Force -Append
"" | Out-File -FilePath $EnvironmentInfoPath -Encoding utf8 -Force -Append
"SQL Managed Instance: $ManagedInstanceServer" | Out-File -FilePath $EnvironmentInfoPath -Encoding utf8 -Force -Append
"SQL MI (Auth):        SQL Authentication" | Out-File -FilePath $EnvironmentInfoPath -Encoding utf8 -Force -Append
"SQL MI (Username):    DemoUser" | Out-File -FilePath $EnvironmentInfoPath -Encoding utf8 -Force -Append
"SQL MI (Password):    Demo@pass1234567" | Out-File -FilePath $EnvironmentInfoPath -Encoding utf8 -Force -Append
"" | Out-File -FilePath $EnvironmentInfoPath -Encoding utf8 -Force -Append
"Storage Account:      $StorageAccountName" | Out-File -FilePath $EnvironmentInfoPath -Encoding utf8 -Force -Append

$TargetFile = $EnvironmentInfoPath
$ShortcutPath = "$env:Public\Desktop\Readme.lnk"

$WshShell = New-Object -ComObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut($ShortcutPath)
$Shortcut.TargetPath = $TargetFile
$Shortcut.WorkingDirectory = Split-Path $TargetFile
$Shortcut.IconLocation = "$env:SystemRoot\System32\shell32.dll,0"
$Shortcut.Save()

$Target = "C:\Program Files\Microsoft SQL Server Management Studio 22\Release\Common7\IDE\SSMS.exe"
if (Test-Path $Target) {
    $Shell = New-Object -ComObject WScript.Shell
    $Link = $Shell.CreateShortcut("$env:Public\Desktop\SSMS 22.lnk")
    $Link.TargetPath = $Target
    $Link.IconLocation = "$Target,0"
    $Link.Save()
}

$Target = "C:\MicroHack\Labs"
if (Test-Path $Target) {
    $Shell = New-Object -ComObject WScript.Shell
    $Link = $Shell.CreateShortcut("$env:Public\Desktop\Labs.lnk")
    $Link.TargetPath = $Target
    $Link.IconLocation = "$Target,0"
    $Link.Save()
}

Stop-Transcript