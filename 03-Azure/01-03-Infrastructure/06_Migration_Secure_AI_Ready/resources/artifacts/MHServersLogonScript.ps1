$ErrorActionPreference = $env:ErrorActionPreference

$Env:MHBoxDir = 'C:\MHBox'
$Env:MHBoxLogsDir = "$Env:MHBoxDir\Logs"
$Env:MHBoxVMDir = 'F:\Virtual Machines'
$Env:MHBoxDscDir = "$Env:MHBoxDir\DSC"

# Set variables to execute remote powershell scripts on guest VMs
$tenantId = $env:tenantId
$subscriptionId = $env:subscriptionId
$namingPrefix = $env:namingPrefix
$templateBaseUrl = [Environment]::GetEnvironmentVariable(
    'templateBaseUrl',
    [EnvironmentVariableTarget]::Machine
)

$templateBaseUri = $null
if (
    [string]::IsNullOrWhiteSpace($templateBaseUrl) -or
    -not [Uri]::TryCreate($templateBaseUrl, [UriKind]::Absolute, [ref]$templateBaseUri) -or
    $templateBaseUri.Scheme -ne [Uri]::UriSchemeHttps
) {
    throw 'The machine-level templateBaseUrl must be an absolute HTTPS URL.'
}

$demoAssetSourceRoot = "$($templateBaseUrl.Trim().TrimEnd('/'))/artifacts/demopage"

function Wait-Until {
    param(
        [Parameter(Mandatory)]
        [scriptblock]$Condition,

        [Parameter(Mandatory)]
        [string]$Description,

        [ValidateRange(1, 3600)]
        [int]$TimeoutSeconds = 600,

        [ValidateRange(1, 60)]
        [int]$PollIntervalSeconds = 5
    )

    $stopwatch = [Diagnostics.Stopwatch]::StartNew()
    $lastError = $null

    while ($stopwatch.Elapsed.TotalSeconds -lt $TimeoutSeconds) {
        try {
            if (& $Condition) {
                return
            }
        }
        catch {
            $lastError = $_.Exception.Message
        }

        Start-Sleep -Seconds $PollIntervalSeconds
    }

    $errorDetail = if ($lastError) {
        " Last error: $lastError"
    }
    else {
        ''
    }
    throw "Timed out after $TimeoutSeconds seconds waiting for $Description.$errorDetail"
}

function Wait-VMCommand {
    param(
        [Parameter(Mandatory)]
        [string]$VMName,

        [Parameter(Mandatory)]
        [pscredential]$Credential,

        [scriptblock]$ScriptBlock = { $true },

        [object[]]$ArgumentList = @(),

        [string]$Description = 'PowerShell Direct readiness',

        [int]$TimeoutSeconds = 600
    )

    Wait-Until -Description "$Description on '$VMName'" -TimeoutSeconds $TimeoutSeconds -Condition {
        $result = Invoke-Command -VMName $VMName `
            -Credential $Credential `
            -ScriptBlock $ScriptBlock `
            -ArgumentList $ArgumentList `
            -ErrorAction Stop
        @($result) -contains $true
    }
}

function Get-VMIPv4AddressWithRetry {
    param(
        [Parameter(Mandatory)]
        [string]$VMName,

        [int]$TimeoutSeconds = 600
    )

    $address = $null
    $addressReference = [ref]$address

    Wait-Until -Description "a usable IPv4 address on '$VMName'" -TimeoutSeconds $TimeoutSeconds -Condition {
        $candidates = Get-VM -Name $VMName -ErrorAction Stop |
            Select-Object -ExpandProperty NetworkAdapters |
            Select-Object -ExpandProperty IPAddresses

        foreach ($candidate in $candidates) {
            $parsedAddress = $null
            if (
                [IPAddress]::TryParse([string]$candidate, [ref]$parsedAddress) -and
                $parsedAddress.AddressFamily -eq [Net.Sockets.AddressFamily]::InterNetwork -and
                -not $parsedAddress.IsIPv6LinkLocal -and
                $candidate -notlike '127.*' -and
                $candidate -notlike '169.254.*'
            ) {
                $addressReference.Value = [string]$candidate
                return $true
            }
        }

        return $false
    }

    return $address
}

function Wait-TcpPort {
    param(
        [Parameter(Mandatory)]
        [string]$ComputerName,

        [Parameter(Mandatory)]
        [int]$Port,

        [int]$TimeoutSeconds = 300
    )

    Wait-Until -Description "TCP $Port on '$ComputerName'" -TimeoutSeconds $TimeoutSeconds -Condition {
        $client = [Net.Sockets.TcpClient]::new()
        try {
            $connection = $client.BeginConnect($ComputerName, $Port, $null, $null)
            $waitHandle = $connection.AsyncWaitHandle
            try {
                if (-not $waitHandle.WaitOne(3000)) {
                    return $false
                }
            }
            finally {
                $waitHandle.Dispose()
            }

            $client.EndConnect($connection)
            return $true
        }
        finally {
            $client.Dispose()
        }
    }
}

function Restart-VMNetworkAdapters {
    param(
        [Parameter(Mandatory)]
        [string]$VMName,

        [Parameter(Mandatory)]
        [pscredential]$Credential
    )

    $completionMarker = "C:\Windows\Temp\MHBox-network-restart-$([guid]::NewGuid()).done"
    $errorMarker = "$completionMarker.error"
    $restartScript = @"
`$ErrorActionPreference = 'Stop'
try {
    Get-NetAdapter | Restart-NetAdapter
    New-Item -Path '$completionMarker' -ItemType File -Force | Out-Null
}
catch {
    `$_ | Out-String | Set-Content -LiteralPath '$errorMarker'
    exit 1
}
"@
    $encodedRestartScript = [Convert]::ToBase64String(
        [Text.Encoding]::Unicode.GetBytes($restartScript)
    )

    Invoke-Command -VMName $VMName -Credential $Credential -ErrorAction Stop -ScriptBlock {
        param($markerPath, $failurePath, $encodedCommand)

        Remove-Item -LiteralPath $markerPath -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $failurePath -Force -ErrorAction SilentlyContinue
        Start-Process `
            -FilePath "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" `
            -ArgumentList '-NoProfile', '-NonInteractive', '-EncodedCommand', $encodedCommand `
            -WindowStyle Hidden
    } -ArgumentList $completionMarker, $errorMarker, $encodedRestartScript

    Wait-VMCommand `
        -VMName $VMName `
        -Credential $Credential `
        -ScriptBlock {
            param($markerPath, $failurePath)
            (Test-Path -LiteralPath $markerPath) -or (Test-Path -LiteralPath $failurePath)
        } `
        -ArgumentList $completionMarker, $errorMarker `
        -Description 'network adapter restart completion' `
        -TimeoutSeconds 180

    $restartStatus = Invoke-Command -VMName $VMName -Credential $Credential -ErrorAction Stop -ScriptBlock {
        param($markerPath, $failurePath)

        $errorMessage = if (Test-Path -LiteralPath $failurePath) {
            Get-Content -LiteralPath $failurePath -Raw
        }
        else {
            $null
        }
        $status = [pscustomobject]@{
            Succeeded = Test-Path -LiteralPath $markerPath
            Error = $errorMessage
        }
        if (Test-Path -LiteralPath $failurePath) {
            Remove-Item -LiteralPath $failurePath -Force
        }
        Remove-Item -LiteralPath $markerPath -Force -ErrorAction SilentlyContinue
        return $status
    } -ArgumentList $completionMarker, $errorMarker

    if (-not $restartStatus.Succeeded) {
        $restartError = if ($restartStatus.Error) {
            $restartStatus.Error
        }
        else {
            'The detached restart process reported failure without an error message.'
        }
        throw "Network adapter restart failed on '$VMName': $restartError"
    }
}

function Restart-VMAndWait {
    param(
        [Parameter(Mandatory)]
        [string]$VMName,

        [Parameter(Mandatory)]
        [pscredential]$Credential
    )

    $previousBootTime = Invoke-Command -VMName $VMName -Credential $Credential -ErrorAction Stop -ScriptBlock {
        (Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime
    }
    Restart-VM -Name $VMName -Force -ErrorAction Stop
    Wait-VMCommand `
        -VMName $VMName `
        -Credential $Credential `
        -ScriptBlock {
            param($bootTime)
            (Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime -gt [datetime]$bootTime
        } `
        -ArgumentList $previousBootTime `
        -Description 'a new Windows boot and PowerShell Direct readiness after restart'
}

function Restart-LinuxVMAndWaitForSsh {
    param(
        [Parameter(Mandatory)]
        [string]$VMName
    )

    $previousUptime = (Get-VM -Name $VMName -ErrorAction Stop).Uptime
    Restart-VM -Name $VMName -Force -ErrorAction Stop
    Wait-Until -Description "a completed restart of '$VMName'" -Condition {
        $vm = Get-VM -Name $VMName -ErrorAction Stop
        $vm.State -eq 'Running' -and $vm.Uptime -lt $previousUptime
    }

    $address = Get-VMIPv4AddressWithRetry -VMName $VMName
    Wait-TcpPort -ComputerName $address -Port 22
    return $address
}

# Moved VHD storage account details here to keep only in place to prevent duplicates.
$vhdSourceFolder = 'https://jumpstartprodsg.blob.core.windows.net/arcbox/prod/*'

# Archive existing log file and create new one
$logFilePath = "$Env:MHBoxLogsDir\MHServersLogonScript.log"
if (Test-Path $logFilePath) {
    $archivefile = "$Env:MHBoxLogsDir\MHServersLogonScript-" + (Get-Date -Format 'yyyyMMddHHmmss')
    Rename-Item -Path $logFilePath -NewName $archivefile -Force
}

Start-Transcript -Path $logFilePath -Force -ErrorAction SilentlyContinue

# Remove registry keys that are used to automatically logon the user (only used for first-time setup)
$registryPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
$keys = @('AutoAdminLogon', 'DefaultUserName', 'DefaultPassword')

foreach ($key in $keys) {
    try {
        $property = Get-ItemProperty -Path $registryPath -Name $key -ErrorAction Stop
        Remove-ItemProperty -Path $registryPath -Name $key
        Write-Host "Removed registry key that are used to automatically logon the user: $key"
    } catch {
        Write-Verbose "Key $key does not exist."
    }
}

# Create desktop shortcut for Logs-folder
$WshShell = New-Object -ComObject WScript.Shell
$LogsPath = 'C:\MHBox\Logs'
$Shortcut = $WshShell.CreateShortcut("$Env:USERPROFILE\Desktop\Logs.lnk")
$Shortcut.TargetPath = $LogsPath
$shortcut.WindowStyle = 3
$shortcut.Save()

# Configure Windows Terminal as the default terminal application
$registryPath = 'HKCU:\Console\%%Startup'

if (Test-Path $registryPath) {
    Set-ItemProperty -Path $registryPath -Name 'DelegationConsole' -Value '{2EACA947-7F5F-4CFA-BA87-8F7FBEEFBE69}'
    Set-ItemProperty -Path $registryPath -Name 'DelegationTerminal' -Value '{E12CFF52-A866-4C77-9A90-F570A7AA2C6B}'
} else {
    New-Item -Path $registryPath -Force | Out-Null
    Set-ItemProperty -Path $registryPath -Name 'DelegationConsole' -Value '{2EACA947-7F5F-4CFA-BA87-8F7FBEEFBE69}'
    Set-ItemProperty -Path $registryPath -Name 'DelegationTerminal' -Value '{E12CFF52-A866-4C77-9A90-F570A7AA2C6B}'
}


################################################
# Setup Hyper-V server before deploying VMs for each flavor
################################################
if ($Env:flavor -ne 'DevOps') {
    # Install and configure DHCP service (used by Hyper-V nested VMs)
    Write-Host 'Configuring DHCP Service'
    $dnsClient = Get-DnsClient | Where-Object { $_.InterfaceAlias -eq 'Ethernet' }
    $dhcpScope = Get-DhcpServerv4Scope
    if ($dhcpScope.Name -ne 'MHBox') {
        Add-DhcpServerv4Scope -Name 'MHBox' `
            -StartRange 10.10.1.100 `
            -EndRange 10.10.1.200 `
            -SubnetMask 255.255.255.0 `
            -LeaseDuration 1.00:00:00 `
            -State Active
    }

    $dhcpOptions = Get-DhcpServerv4OptionValue
    if ($dhcpOptions.Count -lt 3) {
        Set-DhcpServerv4OptionValue -ComputerName localhost `
            -DnsDomain $dnsClient.ConnectionSpecificSuffix `
            -DnsServer 168.63.129.16, 10.16.2.100 `
            -Router 10.10.1.1 `
            -Force
    }


    # Create the NAT network
    Write-Host 'Creating Internal NAT'
    $natName = 'InternalNat'
    $netNat = Get-NetNat
    if ($netNat.Name -ne $natName) {
        New-NetNat -Name $natName -InternalIPInterfaceAddressPrefix 10.10.1.0/24
    }

    Write-Host 'Creating VM Credentials'
    # Hard-coded username and password for the nested VMs
    $nestedWindowsUsername = 'Administrator'
    $nestedWindowsPassword = 'JS123!!'

    # Create Windows credential object
    $secWindowsPassword = ConvertTo-SecureString $nestedWindowsPassword -AsPlainText -Force
    $winCreds = New-Object System.Management.Automation.PSCredential ($nestedWindowsUsername, $secWindowsPassword)

    # Creating Hyper-V Manager desktop shortcut
    Write-Host 'Creating Hyper-V Shortcut'
    Copy-Item -Path 'C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Administrative Tools\Hyper-V Manager.lnk' -Destination 'C:\Users\All Users\Desktop' -Force

    $cliDir = New-Item -Path "$Env:MHBoxDir\.cli\" -Name '.servers' -ItemType Directory -Force
    if (-not $($cliDir.Parent.Attributes.HasFlag([System.IO.FileAttributes]::Hidden))) {
        $folder = Get-Item $cliDir.Parent.FullName -ErrorAction SilentlyContinue
        $folder.Attributes += [System.IO.FileAttributes]::Hidden
    }

    # Required for CLI commands
    Write-Header 'Az CLI Login'
    az login --identity
    az account set -s $subscriptionId

    Write-Header 'Az PowerShell Login'
    Connect-AzAccount -Identity -Tenant $tenantId -Subscription $subscriptionId

    $DeploymentProgressString = 'Started MHServersLogonScript'

    $tags = Get-AzResourceGroup -Name $env:resourceGroup | Select-Object -ExpandProperty Tags

    if ($null -ne $tags) {
        $tags['DeploymentProgress'] = $DeploymentProgressString
    } else {
        $tags = @{'DeploymentProgress' = $DeploymentProgressString }
    }

    $null = Set-AzResourceGroup -ResourceGroupName $env:resourceGroup -Tag $tags
    $null = Set-AzResource -ResourceName $env:computername -ResourceGroupName $env:resourceGroup -ResourceType 'microsoft.compute/virtualmachines' -Tag $tags -Force

    $existingVMDisk = Get-AzDisk -ResourceGroupName $env:resourceGroup | Where-Object name -Like *VMsDisk

    # Update disk IOPS and throughput before downloading nested VMs
    az disk update --resource-group $env:resourceGroup --name $existingVMDisk.Name --disk-iops-read-write 80000 --disk-mbps-read-write 1200

    ##############################
    ### SKIPP nested SQL VM
    ##############################

    $vhdImageToDownload = 'ArcBox-SQL-DEV.vhdx'
    if ($Env:sqlServerEdition -eq 'Standard') {
        $vhdImageToDownload = 'ArcBox-SQL-STD.vhdx'
    } elseif ($Env:sqlServerEdition -eq 'Enterprise') {
        $vhdImageToDownload = 'ArcBox-SQL-ENT.vhdx'
    }


    $DeploymentProgressString = 'Downloading and configuring nested SQL VM'

    $tags = Get-AzResourceGroup -Name $env:resourceGroup | Select-Object -ExpandProperty Tags

    if ($null -ne $tags) {
        $tags['DeploymentProgress'] = $DeploymentProgressString
    } else {
        $tags = @{'DeploymentProgress' = $DeploymentProgressString }
    }

    $null = Set-AzResourceGroup -ResourceGroupName $env:resourceGroup -Tag $tags
    $null = Set-AzResource -ResourceName $env:computername -ResourceGroupName $env:resourceGroup -ResourceType 'microsoft.compute/virtualmachines' -Tag $tags -Force

    Write-Host 'Fetching SQL VM'
    $SQLvmName = "$namingPrefix-SQL"
    $SQLvmvhdPath = "$Env:MHBoxVMDir\$namingPrefix-SQL.vhdx"

    # Verify if VHD files already downloaded especially when re-running this script
    if (!(Test-Path $SQLvmvhdPath)) {
        Write-Output 'Downloading nested VMs VHDX file for SQL. This can take some time, hold tight...'
        azcopy cp $vhdSourceFolder $Env:MHBoxVMDir --include-pattern "$vhdImageToDownload" --recursive=true --check-length=false --log-level=ERROR

        # Rename VHD file
        Rename-Item -Path "$Env:MHBoxVMDir\$vhdImageToDownload" -NewName $SQLvmvhdPath -Force
    }

    # Create the nested VMs if not already created
    Write-Header 'Create Hyper-V VMs'

    # Create the nested SQL VMs
    $sqlDscConfigurationFile = "$Env:MHBoxDscDir\virtual_machines_sql.dsc.yml"
    (Get-Content -Path $sqlDscConfigurationFile) -replace 'namingPrefixStage', $namingPrefix | Set-Content -Path $sqlDscConfigurationFile
    winget configure --file C:\MHBox\DSC\virtual_machines_sql.dsc.yml --accept-configuration-agreements --disable-interactivity

    # Restarting Windows VM Network Adapters
    Write-Host 'Restarting Network Adapters'
    Restart-VMNetworkAdapters -VMName $SQLvmName -Credential $winCreds

    # Rename server if hostname is not as MHBox-SQL or doesn't match naming prefix
    $hostname = Invoke-Command -VMName $SQLvmName -ScriptBlock { hostname } -Credential $winCreds

    if ($hostname -ne $SQLvmName) {

        Write-Header 'Renaming the nested SQL VM'
        Invoke-Command -VMName $SQLvmName -ScriptBlock { Rename-Computer -NewName $using:SQLvmName } -Credential $winCreds
        Restart-VMAndWait -VMName $SQLvmName -Credential $winCreds
    }

    # Enable Windows Firewall rule for SQL Server
    Invoke-Command -VMName $SQLvmName -ScriptBlock { New-NetFirewallRule -DisplayName 'Allow SQL Server TCP 1433' -Direction Inbound -Protocol TCP -LocalPort 1433 -Action Allow } -Credential $winCreds

    # Onboard nested Windows and Linux VMs to Azure Arc
    if ($Env:flavor -eq 'ITPro') {
        Write-Header 'Fetching Nested VMs'

        $Win2k22vmName = "$namingPrefix-Win2K22"
        $Win2k22vmvhdPath = "${Env:MHBoxVMDir}\$namingPrefix-Win2K22.vhdx"

        $Ubuntu01vmName = "$namingPrefix-Ubuntu-01"
        $Ubuntu01vmvhdPath = "${Env:MHBoxVMDir}\$namingPrefix-Ubuntu-01.vhdx"

        $AzMigSrvvmName = "$namingPrefix-AzMigSrv"
        $AzMigSrvvmvhdPath = "${Env:MHBoxVMDir}\$namingPrefix-AzMigSrv.vhdx"

        #$AzRepSrvvmName = "$namingPrefix-AzRepSrv"
        #$AzRepSrvvmvhdPath = "${Env:MHBoxVMDir}\$namingPrefix-AzRepSrv.vhdx"

        $files = 'ArcBox-Win2K22.vhdx;ArcBox-Ubuntu-01.vhdx;'        

        $DeploymentProgressString = 'Downloading and configuring nested VMs'

        $tags = Get-AzResourceGroup -Name $env:resourceGroup | Select-Object -ExpandProperty Tags

        if ($null -ne $tags) {
            $tags['DeploymentProgress'] = $DeploymentProgressString
        } else {
            $tags = @{'DeploymentProgress' = $DeploymentProgressString }
        }

        $null = Set-AzResourceGroup -ResourceGroupName $env:resourceGroup -Tag $tags
        $null = Set-AzResource -ResourceName $env:computername -ResourceGroupName $env:resourceGroup -ResourceType 'microsoft.compute/virtualmachines' -Tag $tags -Force

        # Verify if VHD files already downloaded especially when re-running this script
        if (!((Test-Path $Win2k22vmvhdPath) -and (Test-Path $Ubuntu01vmvhdPath))) {            
            <# Action when all if and elseif conditions are false #>
            $Env:AZCOPY_BUFFER_GB = 4
            Write-Output 'Downloading nested VMs VHDX files. This can take some time, hold tight...'
            azcopy cp $vhdSourceFolder $Env:MHBoxVMDir --include-pattern $files --recursive=true --check-length=false --log-level=ERROR
        }

            if ($namingPrefix -ne 'ArcBox') {

            # Split the string into an array
            $fileList = $files -split ';' | Where-Object { $_ -ne '' }

            # Set the path to search for files
            $searchPath = $Env:MHBoxVMDir

            # Loop through each file and rename if found
            foreach ($file in $fileList) {
                $filePath = Join-Path -Path $searchPath -ChildPath $file
                if (Test-Path $filePath) {
                    $newFileName = $file -replace 'ArcBox', $namingPrefix

                    Rename-Item -Path $filePath -NewName $newFileName
                    Write-Output "Renamed $file to $newFileName"
                } else {
                    Write-Output "$file not found in $searchPath"
                }
              }

            }

            if ((Test-Path $Win2k22vmvhdPath) ) {            
            <# Local Copy of Win2K22 Disk for Azure Migrate Appliances #>            
            Write-Output 'Local Copy of Win2K22 Disk for Azure Migrate Appliance. This can take some time, hold tight...'

            Copy-Item -Path $Win2k22vmvhdPath -Destination $AzMigSrvvmvhdPath -Force
            #Copy-Item -Path $Win2k22vmvhdPath -Destination $AzRepSrvvmvhdPath -Force
            }         

        # Update disk IOPS and throughput after downloading nested VMs (note: a disk's performance tier can be downgraded only once every 12 hours)
        az disk update --resource-group $env:resourceGroup --name $existingVMDisk.Name --disk-iops-read-write $existingVMDisk.DiskIOPSReadWrite --disk-mbps-read-write $existingVMDisk.DiskMBpsReadWrite

        # Create the nested VMs if not already created
        Write-Header 'Create Hyper-V VMs'
        $serversDscConfigurationFile = "$Env:MHBoxDscDir\virtual_machines_itpro.dsc.yml"
        (Get-Content -Path $serversDscConfigurationFile) -replace 'namingPrefixStage', $namingPrefix | Set-Content -Path $serversDscConfigurationFile
        winget configure --file C:\MHBox\DSC\virtual_machines_itpro.dsc.yml --accept-configuration-agreements --disable-interactivity

        # Configure automatic start & stop action for the nested VMs
        Get-VM | Where-Object {$_.State -eq "Running"} |
            ForEach-Object -Parallel {
                Stop-VM -Force -Name $PSItem.Name
                Set-VM -Name $PSItem.Name -AutomaticStopAction ShutDown -AutomaticStartAction Start
                Start-VM -Name $PSItem.Name
            }

        foreach ($vmName in @($SQLvmName, $Win2k22vmName, $AzMigSrvvmName)) {
            Wait-VMCommand -VMName $vmName -Credential $winCreds
        }

        Write-Header 'Creating VM Credentials'
        # Hard-coded username for the nested Linux VM
        $nestedLinuxUsername = 'jumpstart'

        # Restarting Windows VM Network Adapters
        Write-Header 'Restarting Network Adapters'
        Restart-VMNetworkAdapters -VMName $Win2k22vmName -Credential $winCreds
        Restart-VMNetworkAdapters -VMName $AzMigSrvvmName -Credential $winCreds

        if ($namingPrefix -ne 'ArcBox') {

            # Renaming the nested VMs
            Write-Header 'Renaming the nested Windows VMs'
            Invoke-Command -VMName $Win2k22vmName -ScriptBlock {

                if ($env:computername -cne $using:Win2k22vmName) {
                    Rename-Computer -NewName $using:Win2k22vmName
                }

            } -Credential $winCreds

            Invoke-Command -VMName $AzMigSrvvmName -ScriptBlock {

                if ($env:computername -cne $using:AzMigSrvvmName) {
                    Rename-Computer -NewName $using:AzMigSrvvmName
                }

            } -Credential $winCreds 
<#
            Invoke-Command -VMName $AzRepSrvvmName -ScriptBlock {

                if ($env:computername -cne $using:AzRepSrvvmName) {
                    Rename-Computer -NewName $using:AzRepSrvvmName -Restart
                }

            } -Credential $winCreds             
#>
            Restart-VMAndWait -VMName $Win2k22vmName -Credential $winCreds
            Restart-VMAndWait -VMName $AzMigSrvvmName -Credential $winCreds

        }

        # Configuring SSH for accessing Linux VMs
        Write-Output 'Generating SSH key for accessing nested Linux VMs'

        $null = New-Item -Path ~ -Name .ssh -ItemType Directory
        ssh-keygen -t rsa -N '' -f $Env:USERPROFILE\.ssh\id_rsa

        Copy-Item -Path "$Env:USERPROFILE\.ssh\id_rsa.pub" -Destination "$Env:TEMP\authorized_keys"

        # Automatically accept unseen keys but will refuse connections for changed or invalid hostkeys.
        Add-Content -Path "$Env:USERPROFILE\.ssh\config" -Value 'StrictHostKeyChecking=accept-new'

        $Ubuntu01VmIp = Get-VMIPv4AddressWithRetry -VMName $Ubuntu01vmName
        Wait-TcpPort -ComputerName $Ubuntu01VmIp -Port 22
        Get-VM *Ubuntu* | Copy-VMFile -SourcePath "$Env:TEMP\authorized_keys" -DestinationPath "/home/$nestedLinuxUsername/.ssh/" -FileSource Host -Force -CreateFullPath

        if ($namingPrefix -ne 'ArcBox') {

            # Renaming the nested linux VMs
            Write-Output 'Renaming the nested Linux VMs'

            Invoke-Command -HostName $Ubuntu01VmIp -KeyFilePath "$Env:USERPROFILE\.ssh\id_rsa" -UserName $nestedLinuxUsername -ScriptBlock {
                param($newHostName)

                $renameOutput = @(& sudo hostnamectl set-hostname -- $newHostName 2>&1)
                $renameExitCode = $LASTEXITCODE
                foreach ($outputLine in $renameOutput) {
                    Write-Output ([string]$outputLine)
                }
                if ($renameExitCode -ne 0) {
                    throw "hostnamectl failed with exit code $renameExitCode."
                }
            } -ArgumentList $Ubuntu01vmName -ErrorAction Stop
            $Ubuntu01VmIp = Restart-LinuxVMAndWaitForSsh -VMName $Ubuntu01vmName
        }
        else {
            $Ubuntu01VmIp = Get-VMIPv4AddressWithRetry -VMName $Ubuntu01vmName
            Wait-TcpPort -ComputerName $Ubuntu01VmIp -Port 22
         }

        Write-Output 'Activating operating system on Windows VMs...'

        $activationScript = {
            cscript C:\Windows\system32\slmgr.vbs -ipk VDYBN-27WPP-V4HQT-9VMD4-VMK7H
            cscript C:\Windows\system32\slmgr.vbs -skms kms.core.windows.net
            cscript C:\Windows\system32\slmgr.vbs -ato
            cscript C:\Windows\system32\slmgr.vbs -dlv
        }

        foreach ($vmName in @($Win2k22vmName, $AzMigSrvvmName, $SQLvmName)) {
            Invoke-Command -VMName $vmName -ScriptBlock $activationScript -Credential $winCreds
        }

        # Install Demo Web App on Windows VM
        Write-Header 'Installing Web App on Windows and Linux Servers'

        # Copy WebApp to Windows VM
        Copy-VMFile $Win2k22vmName -SourcePath "$Env:MHBoxDir\DemoPage\deployWebApp.ps1" -DestinationPath "C:\MHDir\DemoPage\deployWebApp.ps1" -CreateFullPath -FileSource Host -Force

        # Install IIS and deploy the demo page on Windows VM
        Invoke-Command -VMName $Win2k22vmName -ScriptBlock {
            param($sourceRoot)

            Add-WindowsFeature Web-Server -IncludeManagementTools
            & powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass `
                -File 'C:\MHDir\DemoPage\deployWebApp.ps1' `
                -SourceRoot $sourceRoot
            if ($LASTEXITCODE -ne 0) {
                throw "deployWebApp.ps1 failed with exit code $LASTEXITCODE."
            }
        } -ArgumentList $demoAssetSourceRoot -Credential $winCreds -ErrorAction Stop

        # Install Apache and deploy the demo page on Linux VM
        Write-Output 'Installing Apache Web Server on Linux VM...'
        $UbuntuSessions = $null
        try {
            $UbuntuSessions = New-PSSession -HostName $Ubuntu01VmIp -KeyFilePath "$Env:USERPROFILE\.ssh\id_rsa" -UserName $nestedLinuxUsername -ErrorAction Stop
            $linuxDeploymentScript = "/home/$nestedLinuxUsername/deploy-webapp.sh"
            Copy-VMFile $Ubuntu01vmName -SourcePath "$Env:MHBoxDir\DemoPage\deploy-webapp.sh" -DestinationPath "/home/$nestedLinuxUsername" -FileSource Host -Force

            $sourceRootBase64 = [Convert]::ToBase64String(
                [Text.Encoding]::UTF8.GetBytes($demoAssetSourceRoot)
            )
            Invoke-Command -Session $UbuntuSessions -ScriptBlock {
                param($deploymentScript, $encodedSourceRoot)

                try {
                    $sourceRoot = [Text.Encoding]::UTF8.GetString(
                        [Convert]::FromBase64String($encodedSourceRoot)
                    )
                }
                catch {
                    throw 'The demo asset source URL could not be decoded.'
                }

                $deploymentOutput = @(& sudo /bin/sh $deploymentScript $sourceRoot 2>&1)
                $deploymentExitCode = $LASTEXITCODE
                foreach ($outputLine in $deploymentOutput) {
                    Write-Output ([string]$outputLine)
                }

                if ($deploymentExitCode -ne 0) {
                    throw "deploy-webapp.sh failed with exit code $deploymentExitCode."
                }
            } -ArgumentList $linuxDeploymentScript, $sourceRootBase64 -ErrorAction Stop
        }
        finally {
            if ($null -ne $UbuntuSessions) {
                Remove-PSSession -Session $UbuntuSessions -ErrorAction Continue
            }
        }

    }

    # Removing the LogonScript Scheduled Task so it won't run on next reboot
    Write-Header 'Removing Logon Task'
    if ($null -ne (Get-ScheduledTask -TaskName 'MHServersLogonScript' -ErrorAction SilentlyContinue)) {
        Unregister-ScheduledTask -TaskName 'MHServersLogonScript' -Confirm:$false
    }
}


    # Enabling Azure VM Auto-shutdown
    if ($env:autoShutdownEnabled -eq "true") {

        Write-Header "Enabling Azure VM Auto-shutdown"

        $ScheduleResource = Get-AzResource -ResourceGroup $env:resourceGroup -ResourceType Microsoft.DevTestLab/schedules
        $Uri = "https://management.azure.com$($ScheduleResource.ResourceId)?api-version=2018-09-15"

        $Schedule = Invoke-AzRestMethod -Uri $Uri

        $ScheduleSettings = $Schedule.Content | ConvertFrom-Json
        $ScheduleSettings.properties.status = "Enabled"

        Invoke-AzRestMethod -Uri $Uri -Method PUT -Payload ($ScheduleSettings | ConvertTo-Json)

    } else {

        Write-Header "Auto-shutdown is not enabled, skipping."

    }


    $DeploymentProgressString = 'Deployment Completed'

    $tags = Get-AzResourceGroup -Name $env:resourceGroup | Select-Object -ExpandProperty Tags

    if ($null -ne $tags) {
        $tags['DeploymentProgress'] = $DeploymentProgressString
    } else {
        $tags = @{'DeploymentProgress' = $DeploymentProgressString }
    }

    $null = Set-AzResourceGroup -ResourceGroupName $env:resourceGroup -Tag $tags
    $null = Set-AzResource -ResourceName $env:computername -ResourceGroupName $env:resourceGroup -ResourceType 'microsoft.compute/virtualmachines' -Tag $tags -Force