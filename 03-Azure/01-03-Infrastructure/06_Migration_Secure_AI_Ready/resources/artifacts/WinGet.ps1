$ErrorActionPreference = 'Stop'

trap {
    $failure = $_
    Write-Error -ErrorRecord $failure -ErrorAction Continue
    Remove-Item -LiteralPath 'C:\MHBox\lab-ready.json' -Force -ErrorAction SilentlyContinue
    try {
        Connect-AzAccount -Identity -Tenant $env:tenantId -Subscription $env:subscriptionId -ErrorAction Stop | Out-Null
        $groupId = "/subscriptions/$env:subscriptionId/resourceGroups/$env:resourceGroup"
        foreach ($target in @($groupId, "$groupId/providers/Microsoft.Compute/virtualMachines/$env:hostVmName")) {
            try {
                Update-AzTag -ResourceId $target -Operation Merge -Tag @{ DeploymentProgress = 'Deployment Failed' } -ErrorAction Stop | Out-Null
            }
            catch { Write-Warning "Could not report failure on '$target': $($_.Exception.Message)" }
        }
    }
    catch { Write-Warning "Could not authenticate to report WinGet failure: $($_.Exception.Message)" }
    exit 1
}

$Env:MHBoxDir = 'C:\MHBox'
$Env:MHBoxLogsDir = "$Env:MHBoxDir\Logs"

$tenantId = $env:tenantId
$subscriptionId = $env:subscriptionId
$resourceGroup = $env:resourceGroup

$logFilePath = Join-Path -Path $Env:MHBoxLogsDir -ChildPath ('WinGet-provisioning-' + (Get-Date -Format 'yyyyMMddHHmmss') + '.log')

Start-Transcript -Path $logFilePath -Force
if (Test-Path -LiteralPath "$Env:MHBoxDir\lab-ready.json") {
    Remove-Item -LiteralPath "$Env:MHBoxDir\lab-ready.json" -Force
}

$DeploymentProgressString = "Installing WinGet packages..."

Connect-AzAccount -Identity -Tenant $tenantId -Subscription $subscriptionId

if ([string]::IsNullOrWhiteSpace($env:hostVmName)) { throw 'The hostVmName machine environment variable is required.' }
$groupId = "/subscriptions/$subscriptionId/resourceGroups/$resourceGroup"
foreach ($target in @($groupId, "$groupId/providers/Microsoft.Compute/virtualMachines/$env:hostVmName")) {
    Update-AzTag -ResourceId $target -Operation Merge -Tag @{ DeploymentProgress = $DeploymentProgressString } | Out-Null
}

# Pinned to version 1.11.460 to avoid known issue: https://github.com/microsoft/winget-cli/issues/5826
Install-PSResource -Name Microsoft.WinGet.Client -Scope AllUsers -Quiet -AcceptLicense -TrustRepository -Version 1.11.460
Install-PSResource -Name Microsoft.WinGet.DSC -Scope AllUsers -Quiet -AcceptLicense -TrustRepository -Version 1.11.460

# Install DSC resources required for MHBox
Install-PSResource -Name HyperVDsc -Scope AllUsers -Quiet -AcceptLicense -TrustRepository -Prerelease
Install-PSResource -Name NetworkingDsc -Scope AllUsers -Quiet -AcceptLicense -TrustRepository

# Update WinGet package manager to the latest version (running twice due to a known issue regarding WinAppSDK)
Repair-WinGetPackageManager -AllUsers -Force -Latest -Verbose
Repair-WinGetPackageManager -AllUsers -Force -Latest -Verbose

# Apply WinGet Configuration files
winget configure --file C:\MHBox\DSC\common.dsc.yml --accept-configuration-agreements --disable-interactivity
if ($LASTEXITCODE -ne 0) { throw "Common WinGet configuration failed with exit code $LASTEXITCODE." }
winget configure --file C:\MHBox\DSC\itpro.dsc.yml --accept-configuration-agreements --disable-interactivity
if ($LASTEXITCODE -ne 0) { throw "ITPro WinGet configuration failed with exit code $LASTEXITCODE." }

# Start remaining logon scripts
# Remove this logon trigger before handing off so a reboot cannot start both stages.
Unregister-ScheduledTask -TaskName 'WinGetLogonScript' -Confirm:$false
Start-ScheduledTask -TaskName 'MHServersLogonScript'
Stop-Transcript