param (
    [string]$adminUsername,
    [securestring]$adminPassword
)

$securePassword = ConvertTo-SecureString -String $adminPassword -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($adminUsername, $securePassword)

Start-Process -FilePath 'powershell.exe' -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File C:\path\to\myscript.ps1' -Credential $credential
