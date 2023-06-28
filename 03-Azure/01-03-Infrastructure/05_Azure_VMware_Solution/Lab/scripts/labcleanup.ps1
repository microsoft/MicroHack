param (
    [Parameter(Mandatory)]
    [ValidateRange(1, 50)]
    [Alias("GroupNumber")] 
    [Int] $group,
    
    [Parameter(Mandatory)]
    [ValidateRange(1, 50)]
    [Alias("LabNumber")] 
    [Int] $lab,

    [Parameter()]
    [hashtable] $AVSInfo
)
#Examples:
# labdeploy.ps1 -group 1 -lab 1

# Clear any existing NSX-T connection
Disconnect-NsxServer *

$confirmCleanup = 1
$cleanupHCX =1
$cleanupVAPP = 1
$cleanupNSX = 1


$ErrorActionPreference = "Stop"
$timeStamp = Get-Date -Format "MM-dd-yyyy_hh:mm:ss"
$timeStamp = $timeStamp.replace(':', '.')
$verboseLogFile = "nested-lab-cleanup-${group}-${lab}-${timeStamp}.log"
function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [String]$message
    )

    $timeStamp = Get-Date -Format "MM-dd-yyyy_hh:mm:ss"

    Write-Host -NoNewline -ForegroundColor White "[$timestamp]"
    Write-Host -ForegroundColor Green " $message"
    $logMessage = "[$timeStamp] $message"
    $logMessage | Out-File -Force -LiteralPath .\$verboseLogFile -Append
}

Write-Log "Reading argurments, starting cleanup process ........"
Write-Log " - Group Number is $group"
Write-Log " - Lab Number is $lab"

$groupNumber = $group
$labNumber = $lab

if ( $AVSInfo.Count -eq 0) {
    # Reading from nestedlabs.yml, setting variables for easier identification
    Write-Log "Reading from nestedlabs.yml file"
    [string[]]$fileContent = Get-Content 'nestedlabs.yml'
    $content = ''
    foreach ($line in $fileContent) { $content = $content + "`n" + $line }
    $config = ConvertFrom-YAML $content
}
else {
    Write-Log "Getting AVS SDDC Credentials through Parameter"
    $config = $AVSInfo
}

# vCenter Server Variables
$VIServer = $config.AVSvCenter.IP 
$VIUsername = $config.AVSvCenter.Username
$VIPassword = $config.AVSvCenter.Password

Write-Log "vCenter Host: $VIServer"

# NSX-T Server Variables
$nsxtHost = $config.AVSNSXT.IP
$nsxtUser = $config.AVSNSXT.Username
$nsxtPass = $config.AVSNSXT.Password

Write-Log "NSX-T Host: $nsxtHost"

# HCX Manager Variables
$hcxHost = $config.AVSHCX.IP
$hcxUser = $config.AVSHCX.Username
$hcxPass = $config.AVSHCX.Password

$VAppName = "Nested-SDDC-Lab-${groupNumber}-${labNumber}"

Write-Log "HCX Host: $hcxHost"

Write-Log "Connecting to Management vCenter Server $VIServer ..."

$viConnection = Connect-VIServer $VIServer -User $VIUsername -Password $VIPassword -WarningAction SilentlyContinue
Write-Log "Connecting to NSX-T Server $nsxtHost ..."
$nsxtConnection = Connect-NsxServer -Server $nsxtHost -User $nsxtUser -Password $nsxtPass -WarningAction SilentlyContinue
Write-Log "Connecting to HCX Manager Server $hcxHost ..."
$hcxConnection = Connect-HCXServer -Server $hcxHost -User $hcxUser -Password $hcxPass -WarningAction SilentlyContinue

# get HCX entities

# get vSphere entities
if ($VApp = Get-VApp -Name $VAppName -Server $viConnection -ErrorAction Ignore) {
    $VMList = Get-VM -Location $VApp -Server $viConnection
}

# get NSX-T entities
$Tier0 = ((Invoke-ListTier0s).Results).DisplayName
$Tier1 = $Tier0.replace("T0","T1")
$SegmentSecProfile = (Invoke-ListSegmentSecurityProfiles -Server $nsxtConnection).Results | Where-Object {$_.DisplayName -like "Group${groupNumber}*"}
$MacDiscoveryProfile = (Invoke-GetMacDiscoveryProfiles -Server $nsxtConnection).Results | Where-Object {$_.DisplayName -like "Group${groupNumber}*"}
$IpDiscoveryProfile = (Invoke-GetIPDiscoveryProfiles -Server $nsxtConnection).Results | Where-Object {$_.DisplayName -like "Group${groupNumber}*"}
$Segment = (Invoke-ListSegments -Server $nsxtConnection -Tier1Id $Tier1).Results | Where-Object {$_.DisplayName -like "Group-${groupNumber}-${labNumber}*"}



if ($confirmCleanup -eq 1) {
    Write-Host -ForegroundColor Magenta "`nPlease confirm the following configuration will be cleaned up:"
    
    # NSX-T entities
    if ($Segment) {
        Write-Host -ForegroundColor Magenta "`nNSX-T Segment"
        Write-Host -ForegroundColor Magenta "  " ($Segment.Id)
    }
    if ($SegmentSecProfile -or $MacDiscoveryProfile -or $IpDiscoveryProfile) {
        Write-Host -ForegroundColor Magenta "`nNSX-T Profiles (only deleted if no longer in use)"
    }
    if ($SegmentSecProfile) {
        Write-Host -ForegroundColor Magenta "  " ($SegmentSecProfile.Id)
    }
    if ($MacDiscoveryProfile) {
        Write-Host -ForegroundColor Magenta "  " ($MacDiscoveryProfile.Id)
    }
    if ($IpDiscoveryProfile) {
        Write-Host -ForegroundColor Magenta "  " ($IpDiscoveryProfile.Id)
    }

    # vSphere entities
    if ($VApp) {
        Write-Host -ForegroundColor Magenta "`n`nvApp $VApp`n"
        foreach ($VM in $VMList) {
            Write-Host -ForegroundColor Magenta "  VM $VM"
        }
    }

    $answer = Read-Host -Prompt "Do you accept (Y or N)"
    if ($answer -ne "Y" -or $answer -ne "y") {
        exit
    }
}

if ( $cleanupHCX -eq 1 ) {
    # Remove network extensions, service meshes and site pairings
}

if ( ($cleanupVAPP -eq 1) -and ($VApp)) {
    Write-Host -ForegroundColor DarkGreen "Stopping VApp"
    Stop-VApp -VApp $VApp -Server $viConnection -Force -Confirm:$false -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
    Write-Host -ForegroundColor DarkGreen "Deleting VApp"
    Remove-VApp -VApp $VApp -Server $viConnection -DeletePermanently:$true -Confirm:$false
    Write-Host -ForegroundColor DarkGreen "Waiting for NSX-T to update"
    Start-Sleep -Seconds 60
}

if ( $cleanupNSX -eq 1 ) {
    # Remove Segments and Segment Profiles
    if ($Segment) {
        Write-Host -ForegroundColor DarkGreen "Deleting Segment" ($Segment.Id)
        $SegSecProBindList = (Invoke-ListSegmentSecurityProfileBindings -Server $nsxtConnection -Tier1Id $Tier1 -SegmentId $Segment.Id).Results
        foreach ($SegSecProBind in $SegSecProBindList) {
            Invoke-DeleteSegmentSecurityProfileBinding -Server $nsxtConnection -Tier1Id $Tier1 -SegmentId $Segment.Id -SegmentSecurityProfileBindingMapId $SegSecProBind.Id
        }
        $SegDisBindList = (Invoke-ListSegmentDiscoveryBindings -Server $nsxtConnection -Tier1Id $Tier1 -SegmentId $Segment.Id).Results
        foreach ($SegDisBind in $SegDisBindList) {
            Invoke-DeleteSegmentDiscoveryBinding -Server $nsxtConnection -Tier1Id $Tier1 -SegmentId $Segment.Id -SegmentDiscoveryProfileBindingMapId $SegDisBind.Id
        }
        Invoke-DeleteSegment -Server $nsxtConnection -Tier1Id $Tier1 -SegmentId $Segment.Id
    }
    if ($SegmentSecProfile) {
        Write-Host -ForegroundColor DarkGreen "Deleting Segment Security Profile" ($SegmentSecProfile.Id)
        Invoke-DeleteSegmentSecurityProfile -Server $nsxtConnection -SegmentSecurityProfileId $SegmentSecProfile.Id -ErrorAction SilentlyContinue
    }
    if ($MacDiscoveryProfile) {
        Write-Host -ForegroundColor DarkGreen "Deleting MAC Discovery Profile" ($MacDiscoveryProfile.Id)
        Invoke-DeleteMacDiscoveryProfile -Server $nsxtConnection -MacDiscoveryProfileId $MacDiscoveryProfile.Id -ErrorAction SilentlyContinue
    }
    if ($IpDiscoveryProfile) {
        Write-Host -ForegroundColor DarkGreen "Deleting IP Discovery Profile" ($IpDiscoveryProfile.Id)
        Invoke-DeleteIPDiscoveryProfile -Server $nsxtConnection -IpDiscoveryProfileId $IpDiscoveryProfile.Id -ErrorAction SilentlyContinue
    }
}


