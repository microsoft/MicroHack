param (
    [string]$adminUsername,
    [string]$tenantId,
    [string]$spnAuthority,
    [string]$subscriptionId,
    [string]$resourceGroup,
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$hostVmName,
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$keyVaultName,
    [string]$acceptEula,
    [string]$registryUsername,
    [string]$azureLocation,
    [string]$githubBranch,
    [string]$githubUser,
    [string]$templateBaseUrl,
    [string]$flavor,
    [string]$rdpPort,
    [string]$vmAutologon,
    [string]$namingPrefix,
    [string]$debugEnabled,
    [string]$sqlServerEdition,
    [string]$autoShutdownEnabled
)

$ErrorActionPreference = 'Stop'

trap {
    $failure = $_
    Write-Error -ErrorRecord $failure -ErrorAction Continue
    Remove-Item -LiteralPath 'C:\MHBox\lab-ready.json' -Force -ErrorAction SilentlyContinue
    $azFailureScriptPath = $null
    try {
        # Keep Az isolated from the parent's package-management assemblies.
        $azFailureScriptPath = Join-Path ([IO.Path]::GetTempPath()) "AzBootstrap-Failure-$([guid]::NewGuid().ToString('N')).ps1"
        $azFailureScript = @'
param(
    [string]$tenantId,
    [string]$subscriptionId,
    [string]$resourceGroup,
    [string]$hostVmName
)

$ErrorActionPreference = 'Stop'
Import-Module Az.Accounts -Force
Import-Module Az.Resources -Force
Connect-AzAccount -Identity -Tenant $tenantId -Subscription $subscriptionId | Out-Null
Set-AzContext -Subscription $subscriptionId | Out-Null
$groupId = "/subscriptions/$subscriptionId/resourceGroups/$resourceGroup"
foreach ($target in @($groupId, "$groupId/providers/Microsoft.Compute/virtualMachines/$hostVmName")) {
    Update-AzTag -ResourceId $target -Operation Merge -Tag @{ DeploymentProgress = 'Deployment Failed' } | Out-Null
}
'@
        $azFailureScript | Set-Content -LiteralPath $azFailureScriptPath -Encoding UTF8
        & "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe" `
            -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $azFailureScriptPath `
            -tenantId $tenantId -subscriptionId $subscriptionId -resourceGroup $resourceGroup -hostVmName $hostVmName
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Isolated bootstrap failure reporting failed with exit code $LASTEXITCODE. The original bootstrap error is retained."
        }
    }
    catch { Write-Warning "Could not report bootstrap failure: $($_.Exception.Message)" }
    finally {
        if ($azFailureScriptPath) {
            Remove-Item -LiteralPath $azFailureScriptPath -Force -ErrorAction SilentlyContinue
        }
    }
    exit 1
}

[System.Environment]::SetEnvironmentVariable('adminUsername', $adminUsername, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('spnAuthority', $spnAuthority, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('tenantId', $tenantId, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('resourceGroup', $resourceGroup, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('hostVmName', $hostVmName, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('keyVaultName', $keyVaultName, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('ACCEPT_EULA', $acceptEula, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('registryUsername', $registryUsername, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('subscriptionId', $subscriptionId, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('azureLocation', $azureLocation, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('githubBranch', $githubBranch, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('githubUser', $githubUser, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('templateBaseUrl', $templateBaseUrl, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('flavor', $flavor, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('namingPrefix', $namingPrefix, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('MHBoxDir', 'C:\MHBox', [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('sqlServerEdition', $sqlServerEdition, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('autoShutdownEnabled', $autoShutdownEnabled, [System.EnvironmentVariableTarget]::Machine)

[System.Environment]::SetEnvironmentVariable('ErrorActionPreference', 'Stop', [System.EnvironmentVariableTarget]::Machine)

function Initialize-LabDataDisk {
    # This host contract is OS + one data disk at LUN 0; never guess among RAW disks.
    $dataDisks = @(Get-Disk | Where-Object { -not $_.IsBoot -and -not $_.IsSystem })
    if ($dataDisks.Count -ne 1) {
        throw "Expected exactly one non-system data disk; found $($dataDisks.Count). No disk was changed."
    }
    $disk = $dataDisks[0]
    $scsiDisks = @(Get-CimInstance -ClassName Win32_DiskDrive -Filter "Index = $($disk.Number)")
    if ($scsiDisks.Count -ne 1 -or $null -eq $scsiDisks[0].SCSILogicalUnit -or $scsiDisks[0].SCSILogicalUnit -ne 0) {
        throw "Cannot identify disk $($disk.Number) as the expected LUN 0 data disk. No disk was changed."
    }

    $volumes = @(Get-Volume | Where-Object DriveLetter -eq 'F')
    if ($volumes.Count -gt 0) {
        $partitions = @(Get-Partition -DiskNumber $disk.Number | Where-Object DriveLetter -eq 'F')
        if ($volumes.Count -ne 1 -or $partitions.Count -ne 1 -or
            $volumes[0].FileSystemLabel -ne 'VMsDisk' -or $volumes[0].FileSystem -ne 'NTFS') {
            throw 'F: is not the expected NTFS VMsDisk volume on the LUN 0 data disk. No disk was changed.'
        }
        return
    }
    if ($disk.PartitionStyle -ne 'RAW') {
        throw "Expected an uninitialized LUN 0 data disk or an existing F: VMsDisk volume. Disk $($disk.Number) will not be formatted."
    }
    $disk | Initialize-Disk -PartitionStyle MBR -PassThru |
        New-Partition -UseMaximumSize -DriveLetter F |
        Format-Volume -FileSystem NTFS -NewFileSystemLabel 'VMsDisk' -Confirm:$false -Force |
        Out-Null
    $volume = Get-Volume -DriveLetter F
    if ($volume.FileSystemLabel -ne 'VMsDisk' -or $volume.FileSystem -ne 'NTFS' -or
        (Get-Partition -DriveLetter F).DiskNumber -ne $disk.Number) {
        throw 'The initialized data disk did not produce the expected F: VMsDisk volume.'
    }
}

# Creating MHBox path
Write-Output 'Creating MHBox path'
$Env:MHBoxDir = 'C:\MHBox'
$Env:MHBoxDscDir = "$Env:MHBoxDir\DSC"
$Env:MHBoxLogsDir = "$Env:MHBoxDir\Logs"
$Env:MHBoxVMDir = 'F:\Virtual Machines'
$Env:tempDir = 'C:\Temp'
$Env:MHBoxDemoPageDir = "$Env:MHBoxDir\DemoPage"

New-Item -Path $Env:MHBoxDir -ItemType Directory -Force | Out-Null
New-Item -Path $Env:MHBoxDscDir -ItemType Directory -Force | Out-Null
New-Item -Path $Env:MHBoxLogsDir -ItemType Directory -Force | Out-Null
New-Item -Path $Env:tempDir -ItemType Directory -Force | Out-Null
New-Item -Path $Env:MHBoxDemoPageDir -ItemType Directory -Force | Out-Null

Start-Transcript -Path "$Env:MHBoxLogsDir\Bootstrap.log"
if (Test-Path -LiteralPath "$Env:MHBoxDir\lab-ready.json") {
    Remove-Item -LiteralPath "$Env:MHBoxDir\lab-ready.json" -Force
}
Initialize-LabDataDisk
New-Item -Path $Env:MHBoxVMDir -ItemType Directory -Force | Out-Null

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

# Extending C:\ partition to the maximum size
Write-Host 'Extending C:\ partition to the maximum size'
$maximumSystemPartitionSize = (Get-PartitionSupportedSize -DriveLetter C).SizeMax
if ((Get-Partition -DriveLetter C).Size -lt $maximumSystemPartitionSize) {
    Resize-Partition -DriveLetter C -Size $maximumSystemPartitionSize
}

# Installing PowerShell Modules
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force

Install-Module -Name Microsoft.PowerShell.PSResourceGet -Force
Install-PSResource -Name Az -Scope AllUsers -Quiet -AcceptLicense -TrustRepository

# Azure init in isolated child process
$azInitScriptPath = "$Env:tempDir\AzBootstrap-Init.ps1"
$azInitLogPath = "$Env:MHBoxLogsDir\AzBootstrap-Init.log"

$azInitScript = @'
param(
    [string]$tenantId,
    [string]$subscriptionId,
    [string]$resourceGroup,
    [string]$hostVmName,
    [string]$keyVaultName,
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

    $initializationTimer = [Diagnostics.Stopwatch]::StartNew()
    function Invoke-InitialAzureOperation {
        param([scriptblock]$Operation, [string]$Description)
        while ($true) {
            try { return & $Operation }
            catch {
                $reason = $_.Exception.Message
                $statusCode = $_.Exception.Response.StatusCode
                $retryable = [string]$statusCode -match '^(401|403|408|429|500|502|503|504|Unauthorized|Forbidden|TooManyRequests|ServiceUnavailable)$' -or
                    $reason -match '(?i)\b(401|403|408|429|500|502|503|504|Forbidden|ForbiddenByRbac|AuthorizationFailed)\b|role assignment|RBAC|managed identity.*(unavailable|not found)|identity not found|identity.*endpoint|IMDS|temporarily unavailable|timed out'
                if (-not $retryable) { throw }
                $remaining = 300 - $initializationTimer.Elapsed.TotalSeconds
                if ($remaining -le 0) {
                    throw "Timed out after 300 seconds waiting for $Description. Last error: $reason"
                }
                Write-Warning "Waiting for $Description (identity/RBAC propagation): $reason"
                Start-Sleep -Seconds ([Math]::Min(10, [Math]::Ceiling($remaining)))
                if ($initializationTimer.Elapsed.TotalSeconds -ge 300) {
                    throw "Timed out after 300 seconds waiting for $Description. Last error: $reason"
                }
            }
        }
    }

    Invoke-InitialAzureOperation -Description 'managed identity authentication' -Operation {
        Connect-AzAccount -Identity -Tenant $tenantId -Subscription $subscriptionId | Out-Null
        Set-AzContext -Subscription $subscriptionId | Out-Null
    }
    $adminPassword = Invoke-InitialAzureOperation -Description "secret access to vault '$keyVaultName'" -Operation {
        Get-AzKeyVaultSecret -VaultName $keyVaultName -Name 'windowsAdminPassword' -AsPlainText
    }
    if ([string]::IsNullOrWhiteSpace($adminPassword)) { throw 'The Windows administrator secret is empty.' }
    $groupId = "/subscriptions/$subscriptionId/resourceGroups/$resourceGroup"
    foreach ($target in @($groupId, "$groupId/providers/Microsoft.Compute/virtualMachines/$hostVmName")) {
        Invoke-InitialAzureOperation -Description "progress tag access to '$target'" -Operation {
            Update-AzTag -ResourceId $target -Operation Merge -Tag @{ DeploymentProgress = 'Started bootstrap-script...' } | Out-Null
        }
    }

    if ($vmAutologon -eq 'true') {
        Write-Host 'Configuring VM Autologon'
        Set-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' 'AutoAdminLogon' '1'
        Set-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' 'DefaultUserName' $adminUsername
        Set-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' 'DefaultPassword' $adminPassword
    } else {
        Write-Host 'Not configuring VM Autologon'
    }

    if ($autoShutdownEnabled -eq 'true') {
        $scheduleId = "$groupId/providers/Microsoft.DevTestLab/schedules/shutdown-computevm-$hostVmName"
        $Uri = "https://management.azure.com${scheduleId}?api-version=2018-09-15"

        Invoke-InitialAzureOperation -Description "shutdown schedule access to '$scheduleId' and its target VM" -Operation {
            $Schedule = Invoke-AzRestMethod -Uri $Uri
            if ($Schedule.StatusCode -ne 200) { throw "Reading shutdown schedule failed: HTTP $($Schedule.StatusCode). $($Schedule.Content)" }
            $ScheduleSettings = $Schedule.Content | ConvertFrom-Json
            $ScheduleSettings.properties.status = 'Disabled'

            $result = Invoke-AzRestMethod -Uri $Uri -Method PUT -Payload ($ScheduleSettings | ConvertTo-Json -Depth 10)
            if ($result.StatusCode -notin @(200, 201, 202)) { throw "Disabling shutdown schedule failed: HTTP $($result.StatusCode). $($result.Content)" }
        }
    }

    Stop-Transcript
    exit 0
}
catch {
    $failure = $_
    Write-Error -ErrorRecord $failure -ErrorAction Continue
    try {
        if (Get-AzContext -ErrorAction Stop) {
            $groupId = "/subscriptions/$subscriptionId/resourceGroups/$resourceGroup"
            foreach ($target in @($groupId, "$groupId/providers/Microsoft.Compute/virtualMachines/$hostVmName")) {
                try {
                    Update-AzTag -ResourceId $target -Operation Merge -Tag @{ DeploymentProgress = 'Deployment Failed' } -ErrorAction Stop | Out-Null
                }
                catch { Write-Warning "Could not report failure on '$target': $($_.Exception.Message)" }
            }
        }
    }
    catch { Write-Warning "Could not report bootstrap initialization failure: $($_.Exception.Message)" }
    Stop-Transcript -ErrorAction SilentlyContinue
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
  -hostVmName $hostVmName `
  -keyVaultName $keyVaultName `
  -adminUsername $adminUsername `
  -vmAutologon $vmAutologon `
  -autoShutdownEnabled $autoShutdownEnabled `
  -logPath $azInitLogPath

if ($LASTEXITCODE -ne 0) {
    throw "AzBootstrap-Init.ps1 failed with exit code $LASTEXITCODE"
}

# Installing tools
Write-Host "`n### Installing PowerShell 7 ###`n"

$ProgressPreference = 'SilentlyContinue'
$url = 'https://github.com/PowerShell/PowerShell/releases/latest'
$latestVersion = (Invoke-WebRequest -UseBasicParsing -Uri $url).Content |
    Select-String -Pattern 'v[0-9]+\.[0-9]+\.[0-9]+' |
    Select-Object -ExpandProperty Matches |
    Select-Object -ExpandProperty Value

$downloadUrl = "https://github.com/PowerShell/PowerShell/releases/download/$latestVersion/PowerShell-$($latestVersion.Substring(1,5))-win-x64.msi"
Invoke-WebRequest -UseBasicParsing -Uri $downloadUrl -OutFile .\PowerShell7.msi
$installation = Start-Process msiexec.exe -Wait -PassThru -ArgumentList '/I PowerShell7.msi /quiet ADD_EXPLORER_CONTEXT_MENU_OPENPOWERSHELL=1 ADD_FILE_CONTEXT_MENU_RUNPOWERSHELL=1 ENABLE_PSREMOTING=1 REGISTER_MANIFEST=1 USE_MU=1 ENABLE_MU=1 ADD_PATH=1'
if ($installation.ExitCode -notin @(0, 3010)) { throw "PowerShell installation failed with exit code $($installation.ExitCode)." }
Remove-Item .\PowerShell7.msi -Force

Write-Host "`n### Fetching GitHub Artifacts ###`n"

# All flavors
Write-Host 'Fetching Artifacts for All Flavors'
Invoke-WebRequest ($templateBaseUrl + 'artifacts/dsc/common.dsc.yml') -OutFile "$Env:MHBoxDscDir\common.dsc.yml"
Invoke-WebRequest ($templateBaseUrl + 'artifacts/dsc/virtual_machines_sql.dsc.yml') -OutFile "$Env:MHBoxDscDir\virtual_machines_sql.dsc.yml"
Invoke-WebRequest ($templateBaseUrl + 'artifacts/WinGet.ps1') -OutFile "$Env:MHBoxDir\WinGet.ps1"
Invoke-WebRequest ($templateBaseUrl + 'artifacts/demopage/deploy-webapp.sh') -OutFile "$Env:MHBoxDemoPageDir\deploy-webapp.sh"
Invoke-WebRequest ($templateBaseUrl + 'artifacts/demopage/deployWebApp.ps1') -OutFile "$Env:MHBoxDemoPageDir\deployWebApp.ps1"

# ITPro
if ($flavor -eq 'ITPro') {
    Write-Host 'Fetching Artifacts for ITPro Flavor'
    Invoke-WebRequest ($templateBaseUrl + 'artifacts/MHServersLogonScript.ps1') -OutFile "$Env:MHBoxDir\MHServersLogonScript.ps1"
    Invoke-WebRequest ($templateBaseUrl + 'artifacts/dsc/itpro.dsc.yml') -OutFile "$Env:MHBoxDscDir\itpro.dsc.yml"
    Invoke-WebRequest ($templateBaseUrl + 'artifacts/dsc/virtual_machines_itpro.dsc.yml') -OutFile "$Env:MHBoxDscDir\virtual_machines_itpro.dsc.yml"
}

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
    if ($LASTEXITCODE -ne 0) { throw "RDP firewall configuration failed with exit code $LASTEXITCODE." }

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

Write-Host "`n### Configuring Logon Scripts ###`n"

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
    [string]$hostVmName,
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

    $groupId = "/subscriptions/$subscriptionId/resourceGroups/$resourceGroup"
    foreach ($target in @($groupId, "$groupId/providers/Microsoft.Compute/virtualMachines/$hostVmName")) {
        Update-AzTag -ResourceId $target -Operation Merge -Tag @{ DeploymentProgress = $deploymentProgressString } | Out-Null
    }

    Stop-Transcript
    exit 0
}
catch {
    $failure = $_
    Write-Error -ErrorRecord $failure -ErrorAction Continue
    try {
        if (Get-AzContext -ErrorAction Stop) {
            $groupId = "/subscriptions/$subscriptionId/resourceGroups/$resourceGroup"
            foreach ($target in @($groupId, "$groupId/providers/Microsoft.Compute/virtualMachines/$hostVmName")) {
                try {
                    Update-AzTag -ResourceId $target -Operation Merge -Tag @{ DeploymentProgress = 'Deployment Failed' } -ErrorAction Stop | Out-Null
                }
                catch { Write-Warning "Could not report failure on '$target': $($_.Exception.Message)" }
            }
        }
    }
    catch { Write-Warning "Could not report bootstrap progress failure: $($_.Exception.Message)" }
    Stop-Transcript -ErrorAction SilentlyContinue
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
  -hostVmName $hostVmName `
  -deploymentProgressString $DeploymentProgressString `
  -logPath $azProgressLogPath

if ($LASTEXITCODE -ne 0) {
    throw "AzBootstrap-Progress.ps1 failed with exit code $LASTEXITCODE"
}

if ($flavor -eq 'ITPro') {
    # Creating scheduled task for WinGet.ps1
    $Trigger = New-ScheduledTaskTrigger -AtLogOn
    $Action = New-ScheduledTaskAction -Execute $ScheduledTaskExecutable -Argument "-NoProfile -File $Env:MHBoxDir\WinGet.ps1"
    Register-ScheduledTask -TaskName 'WinGetLogonScript' -Trigger $Trigger -User $adminUsername -Action $Action -RunLevel Highest -Force | Out-Null

    # Creating scheduled task for MHServersLogonScript.ps1
    $Action = New-ScheduledTaskAction -Execute $ScheduledTaskExecutable -Argument $Env:MHBoxDir\MHServersLogonScript.ps1
    Register-ScheduledTask -TaskName 'MHServersLogonScript' -User $adminUsername -Action $Action -RunLevel Highest -Force | Out-Null
}

# Disabling Windows Server Manager Scheduled Task
Get-ScheduledTask -TaskName ServerManager | Disable-ScheduledTask | Out-Null

if ($flavor -eq 'ITPro') {
    Write-Host "`n### Installing Hyper-V ###`n"

    Write-Host 'Installing Hyper-V without restarting the extension host'
    Enable-WindowsOptionalFeature -Online -FeatureName Containers -All -NoRestart | Out-Null
    Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -NoRestart | Out-Null
    $hyperVInstallation = Install-WindowsFeature -Name Hyper-V -IncludeAllSubFeature -IncludeManagementTools
    if (-not $hyperVInstallation.Success) {
        throw "Hyper-V installation failed: $($hyperVInstallation.ExitCode)."
    }
}

# Clean up Bootstrap.log
Write-Host 'Clean up Bootstrap.log'
Stop-Transcript
$logSuppress = Get-Content "$Env:MHBoxLogsDir\Bootstrap.log" | Where-Object { $_ -notmatch "Host Application: $ScheduledTaskExecutable" }
$logSuppress | Set-Content "$Env:MHBoxLogsDir\Bootstrap.log" -Force

# Let CSE report success before the host reboots and starts the logon stage.
$restartAction = New-ScheduledTaskAction -Execute "$env:WINDIR\System32\shutdown.exe" `
    -Argument '/r /t 0 /d p:2:4 /c "MicroHack bootstrap completed"'
$restartTrigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(2)
$restartPrincipal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
Register-ScheduledTask -TaskName 'MHBox-BootstrapRestart' -Action $restartAction -Trigger $restartTrigger `
    -Principal $restartPrincipal -Force | Out-Null
Write-Host 'Bootstrap completed; the host restart is scheduled in two minutes.'
exit 0
