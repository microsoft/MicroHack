
# set the environment variable to override the ARC on an Azure VM installation.
[System.Environment]::SetEnvironmentVariable("MSFT_ARC_TEST",'true', [System.EnvironmentVariableTarget]::Machine)

# disable the Azure VM guest agent
Set-Service WindowsAzureGuestAgent -StartupType Disabled -Verbose
Stop-Service WindowsAzureGuestAgent -Force -Verbose

# Block access to the Azure IMDS endpoint
New-NetFirewallRule -Name BlockAzureIMDS -DisplayName "Block access to Azure IMDS" -Enabled True -Profile Any -Direction Outbound -Action Block -RemoteAddress 169.254.169.254

# the following commands are prerequisite for automatic onboarding of the VM to Azure Arc via remote ansible playbook

# Enable WinRM
winrm quickconfig -q

# Allow basic authentication
winrm set winrm/config/service/auth '@{Basic="true"}'

# Allow unencrypted traffic
winrm set winrm/config/service '@{AllowUnencrypted="true"}'

# Configure the WinRM listener
try {
    winrm create winrm/config/Listener?Address=*+Transport=HTTP
} catch {
    Write-Host "Listener already exists"
}

# Open the WinRM port in the firewall
netsh advfirewall firewall add rule name="WinRM" dir=in action=allow protocol=TCP localport=5985