[CmdletBinding()]
param(
    [string]$BootstrapId, [string]$SubscriptionId, [string]$ResourceGroupName,
    [string]$StartedAfter, [int]$TimeoutSeconds = 28800
)

function Get-LocalBoxStartupReport {
    param([string]$Path, [string]$Id, [string]$Subscription, [string]$Group)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return }
    try { $status = Get-Content -LiteralPath $Path -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop }
    catch { throw 'The upstream startup report could not be read or parsed.' }
    if ($status.BootstrapId -ne $Id -or $status.SubscriptionId -ne $Subscription -or $status.ResourceGroupName -ne $Group -or
        $status.State -notin @('Running', 'Succeeded', 'Failed') -or
        $status.Phase -notin @('Startup', 'BaseImages', 'NestedDeployment', 'Complete')) {
        throw 'The upstream startup report does not match this VM or has invalid state metadata.'
    }
    @{
        BootstrapId = $Id; SubscriptionId = $Subscription; ResourceGroupName = $Group
        State = $status.State; Phase = $status.Phase; Code = [string]$status.Code
        Message = ([string]$status.Message).Substring(0, [math]::Min(1000, ([string]$status.Message).Length))
    }
}

function Wait-LocalBoxStartupReport {
    param([string]$Id, [string]$Subscription, [string]$Group, [int]$TimeoutSeconds)
    $ErrorActionPreference = 'Stop'
    $started = (Get-Date).ToUniversalTime()
    $deadline = $started.AddSeconds($TimeoutSeconds)
    $report = @{
        BootstrapId = $Id; SubscriptionId = $Subscription; ResourceGroupName = $Group
        State = 'Failed'; Phase = 'Startup'; Code = 'StartupMonitorFailed'
        Message = 'Upstream startup could not be verified.'
    }
    try {
        do {
            $status = Get-LocalBoxStartupReport -Path 'C:\LocalBox\SovereignStartup\state.json' -Id $Id -Subscription $Subscription -Group $Group
            if ($status -and $status.State -in @('Succeeded', 'Failed')) { return $status }
            if (-not $status -and (Get-Date).ToUniversalTime() -ge $started.AddHours(1)) {
                $report.Code = 'StartupNotStarted'
                $report.Message = 'No correlated startup report appeared within one hour. Inspect WinGetLogonScript and LocalBoxLogonScript scheduled tasks; Azure Local validation has not started.'
                return $report
            }
            if ($status -and (Get-Date).ToUniversalTime() -ge $started.AddMinutes(2)) {
                $task = Get-ScheduledTask -TaskName LocalBoxLogonScript -ErrorAction Stop
                if ($task.State -ne 'Running') {
                    $report.Code = 'StartupExited'
                    $report.Message = 'The startup task stopped without a successful report. Inspect LocalBox logs; do not repeat storage initialization blindly.'
                    return $report
                }
            }
            if ((Get-Date).ToUniversalTime() -ge $deadline) {
                $report.Code = 'StartupTimedOut'
                $report.Message = 'Upstream startup did not finish within the nested-deployment budget.'
                return $report
            }
            Start-Sleep -Seconds 15
        } while ($true)
    }
    catch {
        $report.Message = 'Startup monitoring failed to verify the local report or scheduled task. Inspect sovereign-localbox-startup-watch and LocalBox logs.'
        return $report
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    $report = Wait-LocalBoxStartupReport -Id $BootstrapId -Subscription $SubscriptionId -Group $ResourceGroupName -TimeoutSeconds $TimeoutSeconds
    Write-Output ('LOCALBOX_STARTUP_REPORT:' + ($report | ConvertTo-Json -Depth 5 -Compress))
    if ($report.State -ne 'Succeeded') { exit 1 }
}
