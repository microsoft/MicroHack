# Enable WinRM HTTPS for Ansible management
$ErrorActionPreference = "Stop"

# Enable PowerShell remoting
Enable-PSRemoting -Force -SkipNetworkProfileCheck

# Create self-signed certificate for WinRM HTTPS
$cert = New-SelfSignedCertificate `
    -DnsName $env:COMPUTERNAME `
    -CertStoreLocation Cert:\LocalMachine\My `
    -NotAfter (Get-Date).AddYears(1)

# Remove any existing HTTPS WinRM listeners
Get-ChildItem WSMan:\localhost\Listener |
    Where-Object { $_.Keys -match "Transport=HTTPS" } |
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue

# Create HTTPS WinRM listener with self-signed certificate
New-Item -Path WSMan:\localhost\Listener `
    -Transport HTTPS `
    -Address * `
    -CertificateThumbPrint $cert.Thumbprint `
    -Force

# Configure WinRM service authentication
Set-Item WSMan:\localhost\Service\Auth\Basic -Value $true
Set-Item WSMan:\localhost\Shell\MaxMemoryPerShellMB -Value 1024

# Open Windows Firewall for WinRM HTTPS
New-NetFirewallRule `
    -Name "WinRM-HTTPS-Inbound" `
    -DisplayName "WinRM HTTPS Inbound" `
    -Enabled True `
    -Direction Inbound `
    -Protocol TCP `
    -Action Allow `
    -LocalPort 5986

# Restart WinRM service
Restart-Service WinRM
