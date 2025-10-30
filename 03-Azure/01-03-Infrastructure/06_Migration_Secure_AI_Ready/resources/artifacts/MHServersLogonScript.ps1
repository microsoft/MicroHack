$ErrorActionPreference = $env:ErrorActionPreference

$Env:MHBoxDir = 'C:\MHBox'
$Env:MHBoxLogsDir = "$Env:MHBoxDir\Logs"
$Env:MHBoxVMDir = 'F:\Virtual Machines'
$Env:MHBoxIconDir = "$Env:MHBoxDir\Icons"
$Env:MHBoxTestsDir = "$Env:MHBoxDir\Tests"
$Env:MHBoxDscDir = "$Env:MHBoxDir\DSC"
$agentScript = "$Env:MHBoxDir\agentScript"

# Set variables to execute remote powershell scripts on guest VMs
$nestedVMMHBoxDir = $Env:MHBoxDir
$tenantId = $env:tenantId
$subscriptionId = $env:subscriptionId
$azureLocation = $env:azureLocation
$resourceGroup = $env:resourceGroup
$resourceTags = $env:resourceTags
$namingPrefix = $env:namingPrefix

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

    # Install Azure CLI extensions
    Write-Header 'Az CLI extensions'

    az config set extension.use_dynamic_install=yes_without_prompt --only-show-errors

    @('ssh', 'log-analytics-solution', 'connectedmachine', 'monitor-control-service') |
    ForEach-Object -Parallel {
        az extension add --name $PSItem --yes --only-show-errors
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
    Start-Sleep -Seconds 5
    Invoke-Command -VMName $SQLvmName -ScriptBlock { Get-NetAdapter | Restart-NetAdapter } -Credential $winCreds
    Start-Sleep -Seconds 20

    # Rename server if hostname is not as MHBox-SQL or doesn't match naming prefix
    $hostname = Invoke-Command -VMName $SQLvmName -ScriptBlock { hostname } -Credential $winCreds

    if ($hostname -ne $SQLvmName) {

        Write-Header 'Renaming the nested SQL VM'
        Invoke-Command -VMName $SQLvmName -ScriptBlock { Rename-Computer -NewName $using:SQLvmName -Restart } -Credential $winCreds

        Get-VM *SQL* | Wait-VM -For IPAddress

        Write-Host 'Waiting for the nested Windows SQL VM to come back online...waiting for 30 seconds'
        Start-Sleep -Seconds 30

        # Wait for VM to start again
        while ((Get-VM -vmName $SQLvmName).State -ne 'Running') {
            Write-Host 'Waiting for VM to start...'
            Start-Sleep -Seconds 5
        }
        Write-Host 'VM has rebooted successfully!'
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
        
        Start-Sleep -Seconds 30

        Write-Header 'Creating VM Credentials'
        # Hard-coded username and password for the nested VMs
        $nestedLinuxUsername = 'jumpstart'
        $nestedLinuxPassword = 'JS123!!'

        # Create Linux credential object
        $secLinuxPassword = ConvertTo-SecureString $nestedLinuxPassword -AsPlainText -Force
        $linCreds = New-Object System.Management.Automation.PSCredential ($nestedLinuxUsername, $secLinuxPassword)

        # Restarting Windows VM Network Adapters
        Write-Header 'Restarting Network Adapters'
        Start-Sleep -Seconds 5
        Invoke-Command -VMName $Win2k22vmName -ScriptBlock { Get-NetAdapter | Restart-NetAdapter } -Credential $winCreds
        Invoke-Command -VMName $AzMigSrvvmName -ScriptBlock { Get-NetAdapter | Restart-NetAdapter } -Credential $winCreds
        #Invoke-Command -VMName $AzRepSrvvmName -ScriptBlock { Get-NetAdapter | Restart-NetAdapter } -Credential $winCreds
        Start-Sleep -Seconds 10

        if ($namingPrefix -ne 'ArcBox') {

            # Renaming the nested VMs
            Write-Header 'Renaming the nested Windows VMs'
            Invoke-Command -VMName $Win2k22vmName -ScriptBlock {

                if ($env:computername -cne $using:Win2k22vmName) {
                    Rename-Computer -NewName $using:Win2k22vmName -Restart
                }

            } -Credential $winCreds

            Invoke-Command -VMName $AzMigSrvvmName -ScriptBlock {

                if ($env:computername -cne $using:AzMigSrvvmName) {
                    Rename-Computer -NewName $using:AzMigSrvvmName -Restart
                }

            } -Credential $winCreds 
<#
            Invoke-Command -VMName $AzRepSrvvmName -ScriptBlock {

                if ($env:computername -cne $using:AzRepSrvvmName) {
                    Rename-Computer -NewName $using:AzRepSrvvmName -Restart
                }

            } -Credential $winCreds             
#>
            Write-Host 'Waiting for the nested Windows VMs to come back online...'

            start-sleep -Seconds 30

            Get-VM $Win2k22vmName | Restart-VM -Force
            Get-VM $Win2k22vmName | Wait-VM -For Heartbeat -Timeout 600

            Get-VM $AzMigSrvvmName | Restart-VM -Force
            Get-VM $AzMigSrvvmName | Wait-VM -For Heartbeat -Timeout 600

            #Get-VM $AzRepSrvvmName | Restart-VM -Force
            #Get-VM $AzRepSrvvmName | Wait-VM -For Heartbeat

        }

        # Getting the Ubuntu nested VM IP address
        $Ubuntu01VmIp = Get-VM -Name $Ubuntu01vmName | Select-Object -ExpandProperty NetworkAdapters | Select-Object -ExpandProperty IPAddresses | Select-Object -Index 0    

        # Configuring SSH for accessing Linux VMs
        Write-Output 'Generating SSH key for accessing nested Linux VMs'

        $null = New-Item -Path ~ -Name .ssh -ItemType Directory
        ssh-keygen -t rsa -N '' -f $Env:USERPROFILE\.ssh\id_rsa

        Copy-Item -Path "$Env:USERPROFILE\.ssh\id_rsa.pub" -Destination "$Env:TEMP\authorized_keys"

        # Automatically accept unseen keys but will refuse connections for changed or invalid hostkeys.
        Add-Content -Path "$Env:USERPROFILE\.ssh\config" -Value 'StrictHostKeyChecking=accept-new'

        Get-VM *Ubuntu*  | Wait-VM -For Heartbeat
        Get-VM *Ubuntu* | Copy-VMFile -SourcePath "$Env:TEMP\authorized_keys" -DestinationPath "/home/$nestedLinuxUsername/.ssh/" -FileSource Host -Force -CreateFullPath

        if ($namingPrefix -ne 'ArcBox') {

            # Renaming the nested linux VMs
            Write-Output 'Renaming the nested Linux VMs'

            Invoke-Command -HostName $Ubuntu01VmIp -KeyFilePath "$Env:USERPROFILE\.ssh\id_rsa" -UserName $nestedLinuxUsername -ScriptBlock {
                Invoke-Expression "sudo hostnamectl set-hostname $using:ubuntu01vmName;sudo systemctl reboot"
            }
            Restart-VM -Name $ubuntu01vmName -Force
         }

        Get-VM *Ubuntu* | Wait-VM -For IPAddress

        Write-Host 'Waiting for the nested Linux VMs to come back online...waiting for 10 seconds'

        Start-Sleep -Seconds 10

        Write-Output 'Activating operating system on Windows VMs...'

        Invoke-Command -VMName $Win2k22vmName -ScriptBlock {

            cscript C:\Windows\system32\slmgr.vbs -ipk VDYBN-27WPP-V4HQT-9VMD4-VMK7H
            cscript C:\Windows\system32\slmgr.vbs -skms kms.core.windows.net
            cscript C:\Windows\system32\slmgr.vbs -ato
            cscript C:\Windows\system32\slmgr.vbs -dlv

        } -Credential $winCreds

        Invoke-Command -VMName $AzMigSrvvmName -ScriptBlock {

            cscript C:\Windows\system32\slmgr.vbs -ipk VDYBN-27WPP-V4HQT-9VMD4-VMK7H
            cscript C:\Windows\system32\slmgr.vbs -skms kms.core.windows.net
            cscript C:\Windows\system32\slmgr.vbs -ato
            cscript C:\Windows\system32\slmgr.vbs -dlv

        } -Credential $winCreds      

        Invoke-Command -VMName $SQLvmName -ScriptBlock {

            cscript C:\Windows\system32\slmgr.vbs -ipk VDYBN-27WPP-V4HQT-9VMD4-VMK7H
            cscript C:\Windows\system32\slmgr.vbs -skms kms.core.windows.net
            cscript C:\Windows\system32\slmgr.vbs -ato
            cscript C:\Windows\system32\slmgr.vbs -dlv

        } -Credential $winCreds           

        # Install Demo Web App on Windows VM
        Write-Header 'Installing Web App on Windows and Linux Server'

        # Copy WebApp to Windows VM
        Copy-VMFile $Win2k22vmName -SourcePath "$Env:MHBoxDir\DemoPage\deployWebApp.ps1" -DestinationPath "C:\MHDir\DemoPage\deployWebApp.ps1" -CreateFullPath -FileSource Host -Force

        # Install IIS and clean default web files on Windows VM
        Invoke-Command -VMName $Win2k22vmName -ScriptBlock {
            Add-WindowsFeature Web-Server -IncludeManagementTools
            Remove-Item -Path "C:\inetpub\wwwroot\*.*"
            powershell -ExecutionPolicy Unrestricted -File "C:\MHDir\DemoPage\deployWebApp.ps1"
        } -Credential $winCreds                 

        # Install Apache and clean default web files on Linux VM
        Write-Output 'Installing Apache Web Server on Linux VM...'
        $UbuntuSessions = New-PSSession -HostName $Ubuntu01VmIp -KeyFilePath "$Env:USERPROFILE\.ssh\id_rsa" -UserName $nestedLinuxUsername
        Copy-VMFile $Ubuntu01vmName -SourcePath "$Env:MHBoxDir\DemoPage\deploy-webapp.sh" -DestinationPath "/home/$nestedLinuxUsername" -FileSource Host -Force
        Invoke-JSSudoCommand -Session $UbuntuSessions -Command "sh /home/$nestedLinuxUsername/deploy-webapp.sh"

    }

    # Removing the LogonScript Scheduled Task so it won't run on next reboot
    Write-Header 'Removing Logon Task'
    if ($null -ne (Get-ScheduledTask -TaskName 'MHServersLogonScript' -ErrorAction SilentlyContinue)) {
        Unregister-ScheduledTask -TaskName 'MHServersLogonScript' -Confirm:$false
    }
}


#Changing to Jumpstart MHBox wallpaper
Write-Header 'Changing wallpaper'

# bmp file is required for BGInfo
#Convert-JSImageToBitMap -SourceFilePath "$Env:MHBoxDir\wallpaper.png" -DestinationFilePath "$Env:MHBoxDir\wallpaper.bmp"

Set-JSDesktopBackground -ImagePath "$Env:MHBoxDir\MHWallpaper.bmp"

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