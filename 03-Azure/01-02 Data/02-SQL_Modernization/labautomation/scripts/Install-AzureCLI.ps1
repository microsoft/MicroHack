$ErrorActionPreference = 'Stop'

$logPath = 'C:\Windows\Temp\Install-AzureCLI.log'
Start-Transcript -Path $logPath -Append

$ProgressPreference = 'SilentlyContinue'
Invoke-WebRequest -Uri https://aka.ms/installazurecliwindows -OutFile .\AzureCLI.msi
Start-Process msiexec.exe -Wait -ArgumentList '/I', 'AzureCLI.msi', '/quiet'
Remove-Item .\AzureCLI.msi

$env:PATH = [System.Environment]::GetEnvironmentVariable(
    "PATH",
    [System.EnvironmentVariableTarget]::Machine
)

Stop-Transcript