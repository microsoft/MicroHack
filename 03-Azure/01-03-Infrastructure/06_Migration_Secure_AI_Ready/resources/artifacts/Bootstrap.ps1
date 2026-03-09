param (
    [string]$adminUsername,
    [string]$spnClientId,
    [string]$tenantId,
    [string]$spnAuthority,
    [string]$subscriptionId,
    [string]$resourceGroup,
    [string]$azdataUsername,
    [string]$acceptEula,
    [string]$registryUsername,
    [string]$azureLocation,
    [string]$githubBranch,
    [string]$githubUser,
    [string]$templateBaseUrl,
    [string]$flavor,
    [string]$rdpPort,
    [string]$sshPort,
    [string]$vmAutologon,
    [object]$resourceTags,
    [string]$namingPrefix,
    [string]$debugEnabled,
    [string]$sqlServerEdition,
    [string]$autoShutdownEnabled
)

[System.Environment]::SetEnvironmentVariable('adminUsername', $adminUsername, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('spnAuthority', $spnAuthority, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('tenantId', $tenantId, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('resourceGroup', $resourceGroup, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('ACCEPT_EULA', $acceptEula, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('registryUsername', $registryUsername, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('subscriptionId', $subscriptionId, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('azureLocation', $azureLocation, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('githubBranch', $githubBranch, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('githubUser', $githubUser, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('templateBaseUrl', $templateBaseUrl, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('flavor', $flavor, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('automationTriggerAtLogon', $automationTriggerAtLogon, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('resourceTags', $resourceTags, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('namingPrefix', $namingPrefix, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('MHBoxDir', 'C:\MHBox', [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('sqlServerEdition', $sqlServerEdition, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('autoShutdownEnabled', $autoShutdownEnabled, [System.EnvironmentVariableTarget]::Machine)

if ($debugEnabled -eq 'true') {
    [System.Environment]::SetEnvironmentVariable('ErrorActionPreference', 'Break', [System.EnvironmentVariableTarget]::Machine)
}
else {
    [System.Environment]::SetEnvironmentVariable('ErrorActionPreference', 'Continue', [System.EnvironmentVariableTarget]::Machine)
}

# Formatting VMs disk
$disk = (Get-Disk | Where-Object partitionstyle -eq 'raw')[0]
$driveLetter = 'F'
$label = 'VMsDisk'
$disk | Initialize-Disk -PartitionStyle MBR -PassThru | `
    New-Partition -UseMaximumSize -DriveLetter $driveLetter | `
    Format-Volume -FileSystem NTFS -NewFileSystemLabel $label -Confirm:$false -Force

# Creating MHBox path
Write-Output 'Creating MHBox path'
$Env:MHBoxDir = 'C:\MHBox'
$Env:MHBoxDscDir = "$Env:MHBoxDir\DSC"
$Env:MHBoxLogsDir = "$Env:MHBoxDir\Logs"
$Env:MHBoxVMDir = 'F:\Virtual Machines'
$Env:MHBoxKVDir = "$Env:MHBoxDir\KeyVault"
$Env:MHBoxGitOpsDir = "$Env:MHBoxDir\GitOps"
$Env:MHBoxIconDir = "$Env:MHBoxDir\Icons"
$Env:agentScript = "$Env:MHBoxDir\agentScript"
$Env:MHBoxTestsDir = "$Env:MHBoxDir\Tests"
$Env:ToolsDir = 'C:\Tools'
$Env:tempDir = 'C:\Temp'
$Env:MHBoxDataOpsDir = "$Env:MHBoxDir\DataOps"
$Env:MHBoxDemoPageDir = "$Env:MHBoxDir\DemoPage"

New-Item -Path $Env:MHBoxDir -ItemType Directory -Force | Out-Null
New-Item -Path $Env:MHBoxDscDir -ItemType Directory -Force | Out-Null
New-Item -Path $Env:MHBoxLogsDir -ItemType Directory -Force | Out-Null
New-Item -Path $Env:MHBoxVMDir -ItemType Directory -Force | Out-Null
New-Item -Path $Env:MHBoxKVDir -ItemType Directory -Force | Out-Null
New-Item -Path $Env:MHBoxGitOpsDir -ItemType Directory -Force | Out-Null
New-Item -Path $Env:MHBoxIconDir -ItemType Directory -Force | Out-Null
New-Item -Path $Env:ToolsDir -ItemType Directory -Force | Out-Null
New-Item -Path $Env:tempDir -ItemType Directory -Force | Out-Null
New-Item -Path $Env:agentScript -ItemType Directory -Force | Out-Null
New-Item -Path $Env:MHBoxDataOpsDir -ItemType Directory -Force | Out-Null
New-Item -Path $Env:MHBoxTestsDir -ItemType Directory -Force | Out-Null
New-Item -Path $Env:MHBoxDemoPageDir -ItemType Directory -Force | Out-Null

Start-Transcript -Path "$Env:MHBoxLogsDir\Bootstrap.log"

Write-Host "Script path: $PSCommandPath"
Write-Host "Script dir : $PSScriptRoot"
Write-Host "MyCommand  : $($MyInvocation.MyCommand.Path)"
Write-Host 'Process command line:'
Write-Host ([Environment]::CommandLine)

Write-Host 'Bound parameters:'
$PSBoundParameters.GetEnumerator() | Sort-Object Name | ForEach-Object {
    Write-Host " -$($_.Key) = $($_.Value)"
}

# Set SyncForegroundPolicy to 1 to ensure that the scheduled task runs after the client VM joins the domain
Set-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' 'SyncForegroundPolicy' 1

# Copy PowerShell Profile and Reload
Invoke-WebRequest ($templateBaseUrl + 'artifacts/PSProfile.ps1') -OutFile $PsHome\Profile.ps1
. $PsHome\Profile.ps1

# Extending C:\ partition to the maximum size
Write-Host 'Extending C:\ partition to the maximum size'
Resize-Partition -DriveLetter C -Size $(Get-PartitionSupportedSize -DriveLetter C).SizeMax

# Installing PowerShell Modules
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force

Install-Module -Name Microsoft.PowerShell.PSResourceGet -Force
$modules = @('Az', 'Azure.Arc.Jumpstart.Common', 'Microsoft.PowerShell.SecretManagement', 'Pester')

foreach ($module in $modules) {
    Install-PSResource -Name $module -Scope AllUsers -Quiet -AcceptLicense -TrustRepository
}

# Azure init in isolated child process
$azInitScriptPath = "$Env:tempDir\AzBootstrap-Init.ps1"
$azInitLogPath = "$Env:MHBoxLogsDir\AzBootstrap-Init.log"

$azInitScript = @'
param(
    [string]$tenantId,
    [string]$subscriptionId,
    [string]$resourceGroup,
    [string]$adminUsername,
    [string]$vmAutologon,
    [string]$autoShutdownEnabled,
    [string]$logPath
)

$ErrorActionPreference = 'Stop'
Start-Transcript -Path $logPath -Force

try {
    Import-Module Az.Accounts -Force
    Import-Module Az.Resources -Force
    Import-Module Az.KeyVault -Force

    Connect-AzAccount -Identity -Tenant $tenantId -Subscription $subscriptionId | Out-Null
    Set-AzContext -Subscription $subscriptionId | Out-Null

    $DeploymentProgressString = 'Started bootstrap-script...'

    $tags = Get-AzResourceGroup -Name $resourceGroup | Select-Object -ExpandProperty Tags
    if ($null -ne $tags) {
        $tags['DeploymentProgress'] = $DeploymentProgressString
    } else {
        $tags = @{ 'DeploymentProgress' = $DeploymentProgressString }
    }

    $null = Set-AzResourceGroup -ResourceGroupName $resourceGroup -Tag $tags

    $KeyVault = Get-AzKeyVault -ResourceGroupName $resourceGroup
    [System.Environment]::SetEnvironmentVariable('keyVaultName', $KeyVault.VaultName, [System.EnvironmentVariableTarget]::Machine)

    $adminPassword = Get-AzKeyVaultSecret -VaultName $KeyVault.VaultName -Name 'windowsAdminPassword' -AsPlainText

    if ($vmAutologon -eq 'true') {
        Write-Host 'Configuring VM Autologon'
        Set-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' 'AutoAdminLogon' '1'
        Set-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' 'DefaultUserName' $adminUsername
        Set-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' 'DefaultPassword' $adminPassword
    } else {
        Write-Host 'Not configuring VM Autologon'
    }

    if ($autoShutdownEnabled -eq 'true') {
        $ScheduleResource = Get-AzResource -ResourceGroup $resourceGroup -ResourceType Microsoft.DevTestLab/schedules
        $Uri = "https://management.azure.com$($ScheduleResource.ResourceId)?api-version=2018-09-15"

        $Schedule = Invoke-AzRestMethod -Uri $Uri
        $ScheduleSettings = $Schedule.Content | ConvertFrom-Json
        $ScheduleSettings.properties.status = 'Disabled'

        Invoke-AzRestMethod -Uri $Uri -Method PUT -Payload ($ScheduleSettings | ConvertTo-Json -Depth 10) | Out-Null
    }

    Stop-Transcript
    exit 0
}
catch {
    Write-Error $_
    Stop-Transcript
    exit 1
}
'@

$azInitScript | Set-Content -Path $azInitScriptPath -Encoding UTF8

& "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe" `
  -NoProfile `
  -NonInteractive `
  -ExecutionPolicy Bypass `
  -File $azInitScriptPath `
  -tenantId $tenantId `
  -subscriptionId $subscriptionId `
  -resourceGroup $resourceGroup `
  -adminUsername $adminUsername `
  -vmAutologon $vmAutologon `
  -autoShutdownEnabled $autoShutdownEnabled `
  -logPath $azInitLogPath

if ($LASTEXITCODE -ne 0) {
    throw "AzBootstrap-Init.ps1 failed with exit code $LASTEXITCODE"
}

# Installing tools
Write-Header 'Installing PowerShell 7'

$ProgressPreference = 'SilentlyContinue'
$url = 'https://github.com/PowerShell/PowerShell/releases/latest'
$latestVersion = (Invoke-WebRequest -UseBasicParsing -Uri $url).Content |
    Select-String -Pattern 'v[0-9]+\.[0-9]+\.[0-9]+' |
    Select-Object -ExpandProperty Matches |
    Select-Object -ExpandProperty Value

$downloadUrl = "https://github.com/PowerShell/PowerShell/releases/download/$latestVersion/PowerShell-$($latestVersion.Substring(1,5))-win-x64.msi"
Invoke-WebRequest -UseBasicParsing -Uri $downloadUrl -OutFile .\PowerShell7.msi
Start-Process msiexec.exe -Wait -ArgumentList '/I PowerShell7.msi /quiet ADD_EXPLORER_CONTEXT_MENU_OPENPOWERSHELL=1 ADD_FILE_CONTEXT_MENU_RUNPOWERSHELL=1 ENABLE_PSREMOTING=1 REGISTER_MANIFEST=1 USE_MU=1 ENABLE_MU=1 ADD_PATH=1'
Remove-Item .\PowerShell7.msi -Force

Copy-Item $PsHome\Profile.ps1 -Destination 'C:\Program Files\PowerShell\7\' -Force

Write-Header 'Fetching GitHub Artifacts'

# All flavors
Write-Host 'Fetching Artifacts for All Flavors'
Invoke-WebRequest ($templateBaseUrl + 'artifacts/dsc/common.dsc.yml') -OutFile "$Env:MHBoxDscDir\common.dsc.yml"
Invoke-WebRequest ($templateBaseUrl + 'artifacts/dsc/virtual_machines_sql.dsc.yml') -OutFile "$Env:MHBoxDscDir\virtual_machines_sql.dsc.yml"
Invoke-WebRequest ($templateBaseUrl + 'artifacts/WinGet.ps1') -OutFile "$Env:MHBoxDir\WinGet.ps1"
Invoke-WebRequest ($templateBaseUrl + 'artifacts/MHWallpaper.bmp') -OutFile "$Env:MHBoxDir\MHWallpaper.bmp"
Invoke-WebRequest ($templateBaseUrl + 'artifacts/demopage/deploy-webapp.sh') -OutFile "$Env:MHBoxDemoPageDir\deploy-webapp.sh"
Invoke-WebRequest ($templateBaseUrl + 'artifacts/demopage/deployWebApp.ps1') -OutFile "$Env:MHBoxDemoPageDir\deployWebApp.ps1"

# ITPro
if ($flavor -eq 'ITPro') {
    Write-Host 'Fetching Artifacts for ITPro Flavor'
    Invoke-WebRequest ($templateBaseUrl + 'artifacts/MHServersLogonScript.ps1') -OutFile "$Env:MHBoxDir\MHServersLogonScript.ps1"
    Invoke-WebRequest ($templateBaseUrl + 'artifacts/dsc/itpro.dsc.yml') -OutFile "$Env:MHBoxDscDir\itpro.dsc.yml"
    Invoke-WebRequest ($templateBaseUrl + 'artifacts/dsc/virtual_machines_itpro.dsc.yml') -OutFile "$Env:MHBoxDscDir\virtual_machines_itpro.dsc.yml"
}

New-Item -Path alias:azdata -Value 'C:\Program Files (x86)\Microsoft SDKs\Azdata\CLI\wbin\azdata.cmd' -Force

# Disable Microsoft Edge sidebar
$RegistryPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'
$Name = 'HubsSidebarEnabled'
$Value = '00000000'
if (-not (Test-Path $RegistryPath)) {
    New-Item -Path $RegistryPath -Force | Out-Null
}
New-ItemProperty -Path $RegistryPath -Name $Name -Value $Value -PropertyType DWORD -Force | Out-Null

# Disable Microsoft Edge first-run Welcome screen
$RegistryPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'
$Name = 'HideFirstRunExperience'
$Value = '00000001'
if (-not (Test-Path $RegistryPath)) {
    New-Item -Path $RegistryPath -Force | Out-Null
}
New-ItemProperty -Path $RegistryPath -Name $Name -Value $Value -PropertyType DWORD -Force | Out-Null

# Set Diagnostic Data settings
$telemetryPath = 'HKLM:\Software\Policies\Microsoft\Windows\DataCollection'
$telemetryProperty = 'AllowTelemetry'
$telemetryValue = 3

$oobePath = 'HKLM:\Software\Policies\Microsoft\Windows\OOBE'
$oobeProperty = 'DisablePrivacyExperience'
$oobeValue = 1

if (-not (Test-Path $telemetryPath)) {
    New-Item -Path $telemetryPath -Force | Out-Null
}
Set-ItemProperty -Path $telemetryPath -Name $telemetryProperty -Value $telemetryValue

if (-not (Test-Path $oobePath)) {
    New-Item -Path $oobePath -Force | Out-Null
}
Set-ItemProperty -Path $oobePath -Name $oobeProperty -Value $oobeValue

Write-Host 'Registry keys and values for Diagnostic Data settings have been set successfully.'

# Change RDP Port
Write-Host "RDP port number from configuration is $rdpPort"
if (($rdpPort -ne $null) -and ($rdpPort -ne '') -and ($rdpPort -ne '3389')) {
    Write-Host "Configuring RDP port number to $rdpPort"
    $TSPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server'
    $RDPTCPpath = $TSPath + '\Winstations\RDP-Tcp'
    Set-ItemProperty -Path $TSPath -Name 'fDenyTSConnections' -Value 0

    $portNumber = (Get-ItemProperty -Path $RDPTCPpath -Name 'PortNumber').PortNumber
    Write-Host "Current RDP PortNumber: $portNumber"
    if (-not ($portNumber -eq $rdpPort)) {
        Write-Host "Setting RDP PortNumber to $rdpPort"
        Set-ItemProperty -Path $RDPTCPpath -Name 'PortNumber' -Value $rdpPort
        Restart-Service TermService -Force
    }

    if ($rdpPort -eq 3389) {
        netsh advfirewall firewall set rule group='remote desktop' new Enable=Yes | Out-Null
    }
    else {
        $systemroot = Get-Content env:systemroot
        netsh advfirewall firewall add rule name='Remote Desktop - Custom Port' dir=in program=$systemroot\system32\svchost.exe service=termservice action=allow protocol=TCP localport=$rdpPort enable=yes | Out-Null
    }

    Write-Host 'RDP port configuration complete.'
}

# Define firewall rule name
$ruleName = 'Block RDP UDP 3389'

# Check if the rule already exists
$existingRule = Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue

if ($existingRule) {
    Write-Host "Firewall rule '$ruleName' already exists. No changes made."
}
else {
    New-NetFirewallRule -DisplayName $ruleName -Direction Inbound -Protocol UDP -LocalPort 3389 -Action Block -Enabled True | Out-Null
    Write-Host "Firewall rule '$ruleName' created successfully. RDP UDP is now blocked."
}

# Define the registry path
$registryPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services'

# Define the registry key name
$registryName = 'fClientDisableUDP'

# Define the value
$registryValue = 1

if (-not (Test-Path $registryPath)) {
    New-Item -Path $registryPath -Force | Out-Null
}

Set-ItemProperty -Path $registryPath -Name $registryName -Value $registryValue -Type DWord
Write-Host "Registry setting applied successfully. fClientDisableUDP set to $registryValue"

Write-Header 'Configuring Logon Scripts'

$ScheduledTaskExecutable = 'pwsh.exe'

# Progress tag update in isolated child process
$DeploymentProgressString = 'Restarting and installing WinGet packages...'

$azProgressScriptPath = "$Env:tempDir\AzBootstrap-Progress.ps1"
$azProgressLogPath = "$Env:MHBoxLogsDir\AzBootstrap-Progress.log"

$azProgressScript = @'
param(
    [string]$tenantId,
    [string]$subscriptionId,
    [string]$resourceGroup,
    [string]$deploymentProgressString,
    [string]$logPath
)

$ErrorActionPreference = 'Stop'
Start-Transcript -Path $logPath -Force

try {
    Import-Module Az.Accounts -Force
    Import-Module Az.Resources -Force

    Connect-AzAccount -Identity -Tenant $tenantId -Subscription $subscriptionId | Out-Null
    Set-AzContext -Subscription $subscriptionId | Out-Null

    $tags = Get-AzResourceGroup -Name $resourceGroup | Select-Object -ExpandProperty Tags
    if ($null -ne $tags) {
        $tags['DeploymentProgress'] = $deploymentProgressString
    } else {
        $tags = @{ 'DeploymentProgress' = $deploymentProgressString }
    }

    $null = Set-AzResourceGroup -ResourceGroupName $resourceGroup -Tag $tags

    Stop-Transcript
    exit 0
}
catch {
    Write-Error $_
    Stop-Transcript
    exit 1
}
'@

$azProgressScript | Set-Content -Path $azProgressScriptPath -Encoding UTF8

& "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe" `
  -NoProfile `
  -NonInteractive `
  -ExecutionPolicy Bypass `
  -File $azProgressScriptPath `
  -tenantId $tenantId `
  -subscriptionId $subscriptionId `
  -resourceGroup $resourceGroup `
  -deploymentProgressString $DeploymentProgressString `
  -logPath $azProgressLogPath

if ($LASTEXITCODE -ne 0) {
    throw "AzBootstrap-Progress.ps1 failed with exit code $LASTEXITCODE"
}

if ($flavor -eq 'ITPro') {
    # Creating scheduled task for WinGet.ps1
    $Trigger = New-ScheduledTaskTrigger -AtLogOn
    $Action = New-ScheduledTaskAction -Execute $ScheduledTaskExecutable -Argument $Env:MHBoxDir\WinGet.ps1
    Register-ScheduledTask -TaskName 'WinGetLogonScript' -Trigger $Trigger -User $adminUsername -Action $Action -RunLevel Highest -Force | Out-Null

    # Creating scheduled task for MHServersLogonScript.ps1
    $Action = New-ScheduledTaskAction -Execute $ScheduledTaskExecutable -Argument $Env:MHBoxDir\MHServersLogonScript.ps1
    Register-ScheduledTask -TaskName 'MHServersLogonScript' -User $adminUsername -Action $Action -RunLevel Highest -Force | Out-Null
}

# Disabling Windows Server Manager Scheduled Task
Get-ScheduledTask -TaskName ServerManager | Disable-ScheduledTask | Out-Null

if ($flavor -eq 'ITPro') {
    Write-Header 'Installing Hyper-V'

    # Install Hyper-V and reboot
    Write-Host 'Installing Hyper-V and restart'
    Enable-WindowsOptionalFeature -Online -FeatureName Containers -All -NoRestart | Out-Null
    Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -NoRestart | Out-Null
    Install-WindowsFeature -Name Hyper-V -IncludeAllSubFeature -IncludeManagementTools -Restart
}

# Clean up Bootstrap.log
Write-Host 'Clean up Bootstrap.log'
Stop-Transcript
$logSuppress = Get-Content "$Env:MHBoxLogsDir\Bootstrap.log" | Where-Object { $_ -notmatch "Host Application: $ScheduledTaskExecutable" }
$logSuppress | Set-Content "$Env:MHBoxLogsDir\Bootstrap.log" -Force

# Restart computer
Restart-Computer
