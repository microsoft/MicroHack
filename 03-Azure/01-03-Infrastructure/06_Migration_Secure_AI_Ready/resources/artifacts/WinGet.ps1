$ErrorActionPreference = $env:ErrorActionPreference

$Env:MHBoxDir = 'C:\MHBox'
$Env:MHBoxLogsDir = "$Env:MHBoxDir\Logs"

# Path to the flag file
$FlagFile = "$Env:MHBoxLogsDir\WINGET_Restart_done.flag"
$tenantId = $env:tenantId
$subscriptionId = $env:subscriptionId
$resourceGroup = $env:resourceGroup

$logFilePath = Join-Path -Path $Env:MHBoxLogsDir -ChildPath ('WinGet-provisioning-' + (Get-Date -Format 'yyyyMMddHHmmss') + '.log')

Start-Transcript -Path $logFilePath -Force -ErrorAction SilentlyContinue

$DeploymentProgressString = "Installing WinGet packages..."

Connect-AzAccount -Identity -Tenant $tenantId -Subscription $subscriptionId

$tags = Get-AzResourceGroup -Name $resourceGroup | Select-Object -ExpandProperty Tags

if ($null -ne $tags) {
    $tags["DeploymentProgress"] = $DeploymentProgressString
} else {
    $tags = @{"DeploymentProgress" = $DeploymentProgressString}
}

$null = Set-AzResourceGroup -ResourceGroupName $resourceGroup -Tag $tags
$null = Set-AzResource -ResourceName $env:computername -ResourceGroupName $resourceGroup -ResourceType "microsoft.compute/virtualmachines" -Tag $tags -Force

# Pinned to version 1.11.460 to avoid known issue: https://github.com/microsoft/winget-cli/issues/5826
Install-PSResource -Name Microsoft.WinGet.Client -Scope AllUsers -Quiet -AcceptLicense -TrustRepository -Version 1.11.460
Install-PSResource -Name Microsoft.WinGet.DSC -Scope AllUsers -Quiet -AcceptLicense -TrustRepository -Version 1.11.460
    <# # Update WinGet package manager to the latest version (running twice due to a known issue regarding WinAppSDK)
    Repair-WinGetPackageManager -AllUsers -Force -Latest -Verbose

    # Check if the flag file exists
    if (Test-Path $FlagFile) {
        Write-Host "Restart already performed previously. Suppressing restart."
    } else {
        Write-Host "Restart not yet performed. Creating flag and restarting..."

        # Create the flag file
        New-Item -ItemType File -Path $FlagFile -Force | Out-Null

        # Restart the computer
        start-sleep -Seconds 5
        Restart-Computer -Force
    }
    # The script will resume here after the restart #>
# Install DSC resources required for MHBox
Install-PSResource -Name DSCR_Font -Scope AllUsers -Quiet -AcceptLicense -TrustRepository
Install-PSResource -Name HyperVDsc -Scope AllUsers -Quiet -AcceptLicense -TrustRepository -Prerelease
Install-PSResource -Name NetworkingDsc -Scope AllUsers -Quiet -AcceptLicense -TrustRepository

# Update WinGet package manager to the latest version (running twice due to a known issue regarding WinAppSDK)
Repair-WinGetPackageManager -AllUsers -Force -Latest -Verbose
Repair-WinGetPackageManager -AllUsers -Force -Latest -Verbose

# Apply WinGet Configuration files
winget configure --file C:\MHBox\DSC\common.dsc.yml --accept-configuration-agreements --disable-interactivity

switch ($env:flavor) {
    'DevOps' { winget configure --file C:\MHBox\DSC\devops.dsc.yml --accept-configuration-agreements --disable-interactivity }
    'DataOps' { winget configure --file C:\MHBox\DSC\dataops.dsc.yml --accept-configuration-agreements --disable-interactivity }
    'ITPro' { winget configure --file C:\MHBox\DSC\itpro.dsc.yml --accept-configuration-agreements --disable-interactivity }
}

# Start remaining logon scripts
Get-ScheduledTask *LogonScript* | Start-ScheduledTask

#Cleanup
Unregister-ScheduledTask -TaskName 'WinGetLogonScript' -Confirm:$false
Stop-Transcript