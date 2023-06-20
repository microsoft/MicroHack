param (
    [Parameter()]
    [ValidateRange(1, 64)]
    [Alias("GroupId")]
    [Int] $GroupNumber = 1,

    [Parameter()]
    [ValidateRange(1, 32)]
    [Alias("Labs")]
    [Int] $NumberOfNestedLabs = 4,

    [Parameter()]
    [Alias("IsAzureGovernment")] 
    [switch] $isMAG = $false
)

# constant variables
$Logfile = "C:\temp\bootstrap-nestedlabs.log"
$TempPath = "C:\temp"
$ExtractionPath = "C:\temp\avs-embedded-labs-auto"
$NestedLabScriptURL = "https://raw.githubusercontent.com/Azure/avslabs/main/scripts/labdeploy.ps1"

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

function Set-PowerCLI {
    #[void] (Set-PowerCLIConfiguration -Scope AllUsers -ParticipateInCEIP $false -Confirm:$false) 
    #[void] (Set-PowerCLIConfiguration -Scope AllUsers -InvalidCertificateAction Ignore -Confirm:$false)
    #[void] (Set-PowerCLIConfiguration -Scope AllUsers -DefaultVIServerMode Single -Confirm:$false)

    [void] (Set-PowerCLIConfiguration -Scope AllUsers -ParticipateInCEIP $false -InvalidCertificateAction Ignore -DefaultVIServerMode Single -Confirm:$false) 
}

#-------------------------------------------------------------------------------------------------------#

function Test-AuthenticationToAVS {

    $output = az login --identity | ConvertFrom-Json

    $statusFeedback = $false

    if ($output) {
        $statusFeedback = $true
    }

    $timeToWait = 5
    $totalTimeWaited = 0
    $maxWaitTime = 360

    while (!$output) {

        Write-Log "|--Test-AuthenticationToAVS - So far AVS Jumpbox VM managed identity does not have contributor permission over AVS"
        Write-Log "|--Test-AuthenticationToAVS - The script will wait for $timeToWait minutes before attempting again (total waited time: $totalTimeWaited minutes)"

        Start-Sleep -Duration (New-TimeSpan -Minutes $timeToWait)
    
        $totalTimeWaited += $timeToWait
    
        $output = az login --identity | ConvertFrom-Json

        if ($output) {
            $statusFeedback = $true
        }

        if ($totalTimeWaited -gt $maxWaitTime) {            
            $statusFeedback = $false
            Write-Log "|--Test-AuthenticationToAVS - Jumpbox VM managed identity could not be assigned on AVS with in $maxWaitTime minutes. Most probably that portion has failed. Please verify manually!"
            Write-Log "|--Test-AuthenticationToAVS - Waited more than $maxWaitTime minutes, but Azure CLI is not able to authenticate to AVS via Jumpbox VM managed identity. Make sure Jumpbox VM has MI and assigned on AVS resource with contributor permission."
            break
        }

    }
    
    if ($statusFeedback) {
        Write-Log "|--Test-AuthenticationToAVS - Waited about $totalTimeWaited minutes until Azure CLI is able to authenticate to AVS via Jumpbox VM MI"
    }

    return $statusFeedback
}

function Test-AvailableDiskSpace {

    $drive = Get-PSDrive C
    $requiredSpace = 15
    $freeSpaceGB = [math]::Round(($drive.Free / 1GB), 2)

    if ($freeSpaceGB -lt $requiredSpace) {
        Write-Log "|--Test-AvailableDiskSpace - C drive has less than $requiredSpace GB of free space. Current free space: $freeSpaceGB GB"
        return $false
    }
    else {
        Write-Log "|--Test-AvailableDiskSpace - C drive has more than $requiredSpace GB of free space. Current free space: $freeSpaceGB GB"
        return $true
    }
}

function Test-AVSReadiness {
    [void] (az login --identity)
    [void] (az config set extension.use_dynamic_install=yes_without_prompt)

    $resourceGroup = az vmware private-cloud list --query [0].resourceGroup
    $avsPrivateCloud = az vmware private-cloud list --query [0].name

    $statusFeedback = $false

    $avsStatus = az vmware private-cloud show -n $avsPrivateCloud  -g $resourceGroup --query "provisioningState" -o tsv

    if ($avsStatus -match "Succeeded") {
        $statusFeedback = $true 
    }

    $timeToWait = 5
    $totalTimeWaited = 0
    $maxWaitTime = 360

    while ($avsStatus -notmatch "Succeeded") {

        Write-Log "|--Test-AVSReadiness - So far AVS Private Cloud is not in Ready state (i.e. provisioningState != Succeeded)"
        Write-Log "|--Test-AVSReadiness - The script will wait for $timeToWait minutes before attempting again (total waited time: $totalTimeWaited minutes)"

        Start-Sleep -Duration (New-TimeSpan -Minutes $timeToWait)
    
        $totalTimeWaited += $timeToWait
    
        $avsStatus = az vmware private-cloud show -n $avsPrivateCloud  -g $resourceGroup --query "provisioningState"

        if ($avsStatus -match "Succeeded") {
            $statusFeedback = $true 
        }

        if ($totalTimeWaited -gt $maxWaitTime) {            
            $statusFeedback = $false
            Write-Log "|--Test-AVSReadiness - AVS could not reach ready state with in $maxWaitTime minutes. Most probably the deployment has failed. Please verify manually!"
            Write-Log "|--Test-AVSReadiness - Waited more than $maxWaitTime minutes, but AVS Private Cloud is still not in Ready state (i.e. provisioningState != Succeeded). Make sure AVS has been deployed successfully"
            break
        }
    }

    if ($statusFeedback) {
        Write-Log "|--Test-AVSReadiness - Waited about $totalTimeWaited minutes until AVS is in Ready state (i.e. provisioningState = Succeeded)"
    }

    return $statusFeedback
}

function Set-NestedLabRequirement {
    #This script is to needed to run from PowerShell core before running nested lab deployment script

    # Change PowerShell ExecutionPolicy
    Set-ExecutionPolicy Unrestricted
    
    # Install VMware PowerCLI
    $result = (Get-Module -ListAvailable -Name VMware.PowerCLI) ? $true : (Install-Module VMware.PowerCLI -Scope AllUsers -Force -SkipPublisherCheck -AllowClobber -ErrorAction Ignore)
    
    # Configure PowerCLI
    Set-PowerCLI
    
    # Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force

    # Start-Sleep -Seconds 30

    # Install YAML PowerShell Module
    # $result = (Get-Module -ListAvailable -Name powershell-yaml) ? $true : (Install-Module powershell-yaml -Scope AllUsers -Force -SkipPublisherCheck -AllowClobber -ErrorAction Ignore)

    # Extra Verification 
    $result = (Get-Module -ListAvailable -Name VMware.PowerCLI) ? $true : $false

    return $result
}

function Set-NestedLabPackage {

    #Setting up Paths
    $ZipPath = $TempPath + "\avs-embedded-labs-auto.zip"
    
    if (Test-Path $ExtractionPath -PathType Container) {
        Write-Log "|--Set-NestedLabPackage - Directory already exists"
        return $true
    }

    if (Test-Path $ZipPath -PathType Leaf) {
        
        Set-Location $TempPath

        #Checking if there is enough diskspace before extracting the file
        if (Test-AvailableDiskSpace) {
            #Extracting Lab Package (zip) using 7zip
            Write-Log "|--Set-NestedLabPackage - Extracting '$ZipPath'"
            7z x $ZipPath -o*
        }

        #Downloading latest version of labdeploy.ps1
        $NestedLabScriptPath = $ExtractionPath + "\" + $NestedLabScriptURL.Split('/')[-1]
        if (Test-Path $NestedLabScriptPath -PathType Leaf) {
            Remove-Item -Path $NestedLabScriptPath -Force -Confirm:$false -ErrorAction Continue
        }

        Start-BitsTransfer -Source $NestedLabScriptURL -Destination $ExtractionPath -Priority High

        return (Test-Path $ExtractionPath)
    }
    else {
        return $false
    }

}


function Get-NestedLabConfigurations {
    # This script block grabs AVS credentials and store them in a variable that is required to run the nested lab deployment script.
    # It uses a Managed Identity of the Jumpbox VM that has Contributor access over AVS Private Cloud

    [void] (az login --identity)
    [void] (az config set extension.use_dynamic_install=yes_without_prompt)

    $resourceGroup = az vmware private-cloud list --query [0].resourceGroup
    $avsPrivateCloud = az vmware private-cloud list --query [0].name

    $creds = az vmware private-cloud list-admin-credentials -c $avsPrivateCloud  -g $resourceGroup

    $credsString = [system.String]::Join(" ", $creds)
    $credsJson = ConvertFrom-Json $credsString

    $endpoints = az vmware private-cloud show -n $avsPrivateCloud  -g $resourceGroup --query "endpoints"

    $endpointsString = [system.String]::Join(" ", $endpoints)
    $endpointsJson = ConvertFrom-Json $endpointsString

    $nsxtURL = $endpointsJson.nsxtManager
    $vcsaURL = $endpointsJson.vcsa

    $vcsaIP = $vcsaURL.Substring(8)
    $vcsaIP = $vcsaIP.Substring(0, $vcsaIP.Length - 1)

    $nsxtIP = $nsxtURL.Substring(8)
    $nsxtIP = $nsxtIP.Substring(0, $nsxtIP.Length - 1)

    $configs = @{"AVSvCenter" = @{"IP" = $vcsaIP; "Username" = $credsJson.vcenterUsername; "Password" = $credsJson.vcenterPassword }; "AVSNSXT" = @{"IP" = $nsxtIP; "Username" = $credsJson.nsxtUsername; "Password" = $credsJson.nsxtPassword } }
    
    Write-Log "|--Get-NestedLabConfigurations - Grabbed AVS Credentials"
    
    #$configs | ConvertTo-Json

    #Set-Location $ExtractionPath
    #$configs = @{"AVSvCenter" = @{"URL" = $vcsaIP; "Username" = $credsJson.vcenterUsername; "Password" = $credsJson.vcenterPassword }; "AVSNSXT" = @{"Host" = $nsxtIP; "Username" = $credsJson.nsxtUsername; "Password" = $credsJson.nsxtPassword } }
    #ConvertTo-Yaml $configs -OutFile $ExtractionPath\nestedlabs.yml -Force
    ##$configs | Out-File -FilePath .\nestedlabs.yml

    #return (Test-Path $ExtractionPath\nestedlabs.yml)
    return $configs
}

function Enable-AVSPrivateCloudInternetViaSNAT {
    
    [void] (az login --identity)
    [void] (az config set extension.use_dynamic_install=yes_without_prompt)

    $resourceGroup = az vmware private-cloud list --query [0].resourceGroup
    $avsPrivateCloud = az vmware private-cloud list --query [0].name

    #Get Internet status
    $avsPrivateCloudInternetStatus = az vmware private-cloud show --name $avsPrivateCloud --resource-group $resourceGroup --query internet -o tsv

    $status = $false

    if ( $avsPrivateCloudInternetStatus -match "Enabled" ) {
        Write-Log "|--Enable-AVSPrivateCloudInternetViaSNAT - Internet is enabled on AVS Private Cloud instance: $avsPrivateCloud"
        $status = $true
    }
    elseif ( $avsPrivateCloudInternetStatus -match "Disabled" ) {
        Write-Log "|--Enable-AVSPrivateCloudInternetViaSNAT - Internet is disabled on AVS Private Cloud instance: $avsPrivateCloud"
        Write-Log "|--Enable-AVSPrivateCloudInternetViaSNAT - Enabling Internet on AVS Private Cloud instance: $avsPrivateCloud"
        [void] (az vmware private-cloud update --name $avsPrivateCloud --resource-group $resourceGroup --internet "Enabled")
        $status = $true
    }
    else {
        $status = $false
    }

    return $status
}

<#
function Get-GroupNumber {

    [void] (az login --identity)
    [void] (az config set extension.use_dynamic_install=yes_without_prompt)

    $resourceGroup = az vmware private-cloud list --query [0].resourceGroup

    $middlePartOfRGName = $resourceGroup.Split("-")[1]

    $groupNumber = $middlePartOfRGName -Replace "[^0-9]", ''

    Write-Log "|--Get-GroupNumber - Group Number is $groupNumber"

    return $groupNumber
}
#>

function Build-NestedLab {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateRange(1, 50)]
        [Alias("GroupId")]
        [Int] $GroupNumber,

        [Parameter(Mandatory)]
        [ValidateRange(1, 32)]
        [Int]
        $NumberOfNestedLabs,
        
        [Parameter()]
        [hashtable]
        $AVSInfo
    )

    Set-Location $ExtractionPath

    #$groupNumber = Get-GroupNumber

    Set-PowerCLI

    Write-Log "|--Build-NestedLab - Started deploying $NumberOfNestedLabs nested labs for GroupID $GroupNumber"

    for ($i = 1; $i -le $NumberOfNestedLabs; $i++) {
        #Start-Process -Wait -FilePath PWSH.exe -WorkingDirectory $ExtractionPath -ArgumentList "-ExecutionPolicy Unrestricted -NonInteractive -NoProfile -WindowStyle Hidden", "-Command .\labdeploy.ps1 -group $groupNumber -lab $i -automated"
        Write-Log "|--Build-NestedLab - Started building Nested Lab #$i "
        .\labdeploy.ps1 -group $GroupNumber -lab $i -automated -AVSInfo $AVSInfo
        Write-Log "|--Build-NestedLab - Done building Nested Lab #$i "
    }
    
    Set-Location $TempPath

    Write-Log "|--Build-NestedLab - Done deploying $NumberOfNestedLabs nested labs for GroupID $GroupNumber"
}

function Complete-NestedLabDeployment {
    Disable-ScheduledTask -TaskName "Build Nested Labs"
}

#-------------------------------------------------------------------------------------------------------#

# Execution:

Write-Log " "
Write-Log "#---===---===---===---===---===---===---===---===---===---===---===---===---===---#"
Write-Log "Starting Execution"

if ($isMAG){
    Write-Log "Setting Cloud to Azure Government Cloud"
    az cloud set --name AzureUsGovernment
}

Write-Log "Setting basic requirements for labdeploy.ps1 script (i.e.: installing PowerShell modules: VMware.PowerCLI)"
if (Set-NestedLabRequirement) {
    Write-Log "Extracting nested labs Zip package"
    if (Set-NestedLabPackage) {
        Write-Log "Validation authentication to AVS from Jumpbox VM (i.e.: making sure Jumpbox VM managed identity has contributor permission over AVS Private Cloud resource)"
        if (Test-AuthenticationToAVS) {
            Write-Log "Getting AVS credentials information that is required by labdeploy.ps1 script"
            $AVSInfo = Get-NestedLabConfigurations
            if ($AVSInfo.Count -eq 2) {
                Write-Log "Checking if AVS provisioning state is 'Succeeded' (i.e. making sure AVS is ready for next steps)"
                if (Test-AVSReadiness) {
                    Write-Log "Enabling outbound Internet access from AVS which is required by labdeploy.ps1 script"
                    if (Enable-AVSPrivateCloudInternetViaSNAT) {
                        # $NumberOfNestedLabs = 6
                        Write-Log "Executing labdeploy.ps1 script for building $NumberOfNestedLabs nested VMware vSphere labs inside AVS Private Cloud"
                        Build-NestedLab -GroupNumber $GroupNumber -NumberOfNestedLabs $NumberOfNestedLabs -AVSInfo $AVSInfo
                    }
                }
            }
        }
    }
}
Write-Log "Finalizing execution by disabling Windows Scheduled Task"
Complete-NestedLabDeployment

Write-Log "Concluding Execution"
Write-Log " "