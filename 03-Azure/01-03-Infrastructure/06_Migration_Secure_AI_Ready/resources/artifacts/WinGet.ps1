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

# The CLI and modules must share the elevated COM transport introduced in 1.29.380.
$winGetVersion = '1.29.380'
if (@(Get-Module -Name Microsoft.WinGet.Client | Where-Object Version -NE ([version]$winGetVersion)).Count -gt 0) {
    throw "Run WinGet.ps1 in a fresh PowerShell 7 process; another WinGet client version is already loaded."
}
Install-PSResource -Name Microsoft.WinGet.Client -Scope AllUsers -Quiet -AcceptLicense -TrustRepository -Version $winGetVersion
Install-PSResource -Name Microsoft.WinGet.DSC -Scope AllUsers -Quiet -AcceptLicense -TrustRepository -Version $winGetVersion
Import-Module -Name Microsoft.WinGet.Client -RequiredVersion $winGetVersion -Force

# Install DSC resources required for MHBox
Install-PSResource -Name HyperVDsc -Scope AllUsers -Quiet -AcceptLicense -TrustRepository -Prerelease
Install-PSResource -Name NetworkingDsc -Scope AllUsers -Quiet -AcceptLicense -TrustRepository

# Repeat repair for WinAppSDK registration; fresh installs require the v-prefixed GitHub release tag.
$winGetReleaseTag = "v$winGetVersion"
foreach ($repairPass in 1..2) {
    for ($attempt = 1; $attempt -le 3; $attempt++) {
        try {
            Repair-WinGetPackageManager -AllUsers -Force -Version $winGetReleaseTag -Verbose -ErrorAction Stop
            break
        }
        catch {
            $statusCode = ''
            for ($exception = $_.Exception; $null -ne $exception; $exception = $exception.InnerException) {
                $statusCode = [string]$exception.StatusCode
                if (-not $statusCode) { $statusCode = [string]$exception.Response.StatusCode }
                if ($statusCode) { break }
            }
            # Some module errors preserve only HttpClient's status message.
            if (-not $statusCode -and $_.Exception.Message -match 'Response status code does not indicate success:\s*(\d{3})\b') {
                $statusCode = $Matches[1]
            }
            $transient = $statusCode -match '^(408|429|500|502|503|504|RequestTimeout|TooManyRequests|InternalServerError|BadGateway|ServiceUnavailable|GatewayTimeout)$'
            if (-not $transient -or $attempt -eq 3) { throw }
            $retryDelay = 30 * $attempt
            Write-Warning "WinGet repair pass $repairPass, attempt $attempt/3 failed with HTTP $statusCode. Retrying in $retryDelay seconds."
            Start-Sleep -Seconds $retryDelay
        }
    }
}
$actualWinGetVersion = (winget --version | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or $actualWinGetVersion -ne $winGetReleaseTag) {
    throw "Expected WinGet $winGetReleaseTag; found '$actualWinGetVersion' (exit code $LASTEXITCODE)."
}
Get-WinGetPackage | Out-Null

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