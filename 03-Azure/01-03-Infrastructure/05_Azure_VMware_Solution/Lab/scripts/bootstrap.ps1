param (
    [Parameter()]
    [ValidateRange(1, 64)]
    [Alias("GroupId")]
    [Int] $GroupNumber = 1,

    [Parameter()]
    [ValidateRange(1, 32)]
    [Alias("Labs")]
    [Int] $NumberOfNestedLabs = 6,

    [Parameter()]
    [Alias("IsAzureGovernment")] 
    [switch] $isMAG = $false
)

# constant variables
$Logfile = "C:\temp\bootstrap.log"
$TempPath = "C:\temp"
$MainBootstrapScriptURL = "https://raw.githubusercontent.com/microsoft/MicroHack/AzureVMWareSolutionMicroHack/03-Azure/01-03-Infrastructure/05_Azure_VMware_Solution/Lab/scripts/bootstrap.ps1"
$BootstrapScriptURL = "https://raw.githubusercontent.com/microsoft/MicroHack/AzureVMWareSolutionMicroHack/03-Azure/01-03-Infrastructure/05_Azure_VMware_Solution/Lab/scripts/bootstrap-nestedlabs.ps1"
$PackageURL = "https://csuavsmicrohack.blob.core.windows.net/csuavsmicrohack/avs-embedded-labs-auto.zip"
#$NumberOfNestedLabs = 6

# initializing

# clear log file
<#
if (Test-Path $LogFile) {
    Clear-Content $LogFile
}
#>

# auxiliary functions
function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [String]$message
    )
    $timeStamp = (Get-Date).toString("yyyy/MM/dd HH:mm:ss")
    $logMessage = "[$timeStamp] $message"
    Add-content $LogFile -value $LogMessage
}

function Test-TempDirectory {

    if (-Not $(Test-Path -Path $TempPath)) {
        [void] (New-Item -Path $TempPath -ItemType Directory -Force)
    }
}

#-------------------------------------------------------------------------------------------------------#

function Disable-IEESC {

    $AdminKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}"
    $UserKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}"
    Set-ItemProperty -Path $AdminKey -Name "IsInstalled" -Value 0
    Set-ItemProperty -Path $UserKey -Name "IsInstalled" -Value 0
    Stop-Process -Name Explorer
    #Write-Host "IE Enhanced Security Configuration (ESC) has been disabled." -ForegroundColor Green
}

function Install-Applications {

    Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

    choco install powershell-core -y
    choco install azcopy10 -y
    choco install azure-cli -y
    choco install 7zip -y
    choco install VMRC -y

    #Optional
    #choco install vscode -y
    #choco install microsoftazurestorageexplorer -y
    #choco install microsoft-windows-terminal -y

    #refreshenv

    Write-Log "|--Install-Applications - Used Choco to install: PowerShell-Core, AzCopy, AzCli, 7zip and VMRC"
}

function Get-BootstrapScript {

    $MainBootstrapPackagePath = $TempPath + "\" + $MainBootstrapScriptURL.Split('/')[-1]
    
    if (Test-Path $MainBootstrapPackagePath -PathType Leaf) {
        Write-Log "|--Get-BootstrapScript - Nested labs bootstrap script 'bootstrap.ps1' already exists"
    }else {
        Write-Log "|--Get-BootstrapScript - Downloading nested labs bootstrap script 'bootstrap.ps1'"
        Start-BitsTransfer -Source $MainBootstrapScriptURL -Destination $TempPath -Priority High
    }

    #----------------------------------------------------------------------------------------------------------------------#

    $BootstrapPackagePath = $TempPath + "\" + $BootstrapScriptURL.Split('/')[-1]

    if (Test-Path $BootstrapPackagePath -PathType Leaf) {
        Write-Log "|--Get-BootstrapScript - Nested labs bootstrap script 'bootstrap-nestedlabs.ps1' already exists"
    }else {
        Write-Log "|--Get-BootstrapScript - Downloading nested labs bootstrap script 'bootstrap-nestedlabs.ps1'"
        Start-BitsTransfer -Source $BootstrapScriptURL -Destination $TempPath -Priority High
    }
}

function Set-BootstrapScheduledTask {

    $filePath = "c:\temp\bootstrap-nestedlabs.ps1"
    
    $scriptParams = "-GroupId " + $GroupNumber + " -Labs " + $NumberOfNestedLabs

    if($isMAG){
        $scriptParams+= " -isMAG"
    }

    $workingDirectory = "c:\temp"

    $taskName = "Build Nested Labs"

    $taskDescription = "Task for building nested labs inside AVS SDDC"

    $action = New-ScheduledTaskAction -Execute 'PWSH.exe' -WorkingDirectory $workingDirectory -Argument "-ExecutionPolicy Unrestricted -NonInteractive -NoProfile -WindowStyle Hidden -WorkingDirectory `"$workingDirectory`" -File `"$filePath`" $scriptParams"

    $trigger = New-ScheduledTaskTrigger -AtStartup
    #$trigger = New-ScheduledTaskTrigger -Once -At (get-date).AddMinutes(10) -RandomDelay (New-TimeSpan -Minutes 5)

    $principal = New-ScheduledTaskPrincipal -UserId "S-1-5-18" -RunLevel Highest

    $settings = New-ScheduledTaskSettingsSet -MultipleInstances IgnoreNew -DontStopIfGoingOnBatteries -AllowStartIfOnBatteries -Priority 7 -ExecutionTimeLimit $(New-TimeSpan -Hours 24)

    Register-ScheduledTask -Action $action -Trigger $trigger -TaskName $taskName -Description $taskDescription -Principal $principal -Settings $settings -Force
    
    Write-Log "|--Set-BootstrapScheduledTask - bootstrap-nestedlabs.ps1 will be deploying $NumberOfNestedLabs nested labs for group $GroupNumber"

}

function Get-NestedLabPackage {
 
    $ZipPackagePath = $TempPath + "\" + $PackageURL.Split('/')[-1]

    if (Test-Path $ZipPackagePath -PathType Leaf) {
        Write-Log "|--Get-NestedLabPackage - Nested labs zip package already exists"
        return $true
    }
    else { 

        Start-BitsTransfer -Source $PackageURL -Destination $TempPath -Priority High

        if (Test-Path $ZipPackagePath -PathType Leaf) {
            Write-Log "|--Get-NestedLabPackage - Nested labs zip package downloaded successfully"
            return $true
        }
        else {
            Write-Log "|--Get-NestedLabPackage - Failed to download nested labs zip package. Please run bootstrap.ps1 again to make sure package is downloaded properly before you proceed"
            return $false
        }
    }
}

function Set-Jumpbox {
    Restart-Computer
}


#-------------------------------------------------------------------------------------------------------#

# Execution:

Write-Log " "
Write-Log "#---===---===---===---===---===---===---===---===---===---===---===---===---===---#"
Write-Log "Starting Execution"

Write-Log "Disabling Internet Explorer Enhanced Security Configuration"
Disable-IEESC

Write-Log "Installing essential Apps and Tools (i.e.: PowerShell Core, 7zip, AzCopy, AzCLI, VMRC)"
Install-Applications

Write-Log "Check if $TempPath exist. If it did not exist, then create it"
Test-TempDirectory

Write-Log "Downloading bootstrap-nestedlabs.ps1 script"
Get-BootstrapScript

Write-Log "Creating a Windows Scheduled Task to register bootstrap-nestedlabs.ps1 script, and trigger it on Jumpbox VM startup"
Set-BootstrapScheduledTask

Write-Log "Downloading nested labs Zip package"
if (Get-NestedLabPackage) {
    Write-Log "Rebooting Jumpbox VM"
    Set-Jumpbox
}

Write-Log "Concluding Execution"
Write-Log " "