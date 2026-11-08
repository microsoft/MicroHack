BeforeAll {
    $root = (Resolve-Path "$PSScriptRoot/../..").Path
    . "$root/labautomation/localbox-startup.ps1"
    . "$root/labautomation/localbox-startup-watch.ps1"
    . "$root/labautomation/localbox-automation.ps1"
    $id = '10000000-0000-0000-0000-000000000001'
    $subscription = '20000000-0000-0000-0000-000000000001'
    function Update-MhhToken {}
    function Get-ScheduledTask { param($TaskName) }
    function Get-ScheduledTaskInfo { param([Parameter(ValueFromPipeline)]$InputObject) }
    $imageScript = @'
Write-Host 'before'
# Download LocalBox VHDs
#azcopy cp 'https://ignored.example/old.vhdx' "$($LocalBoxConfig.Paths.VHDDir)\AzL-node.vhdx"
azcopy cp 'https://azlocalvhds.blob.core.windows.net/images/AzLocal2608.vhdx' "$($LocalBoxConfig.Paths.VHDDir)\AzL-node.vhdx" --recursive=true
azcopy cp 'https://azlocalvhds.blob.core.windows.net/images/AzLocal2608.sha256' "$($LocalBoxConfig.Paths.VHDDir)\AzL-node.sha256" --recursive=true
azcopy cp https://jumpstartprodsg.blob.core.windows.net/hcibox23h2/WinServerApril2024.vhdx "$($LocalBoxConfig.Paths.VHDDir)\GUI.vhdx" --recursive=true
azcopy cp https://jumpstartprodsg.blob.core.windows.net/hcibox23h2/WinServerApril2024.sha256 "$($LocalBoxConfig.Paths.VHDDir)\GUI.sha256" --recursive=true
# Set credentials
Write-Host 'after'
'@
}

Describe 'Future-only bootstrap installation' {
    BeforeEach {
        $hostPath = "$TestDrive/host.bicep"
        @'
resource vm 'Microsoft.Compute/virtualMachines@2024-07-01' = {
  properties: {
    osProfile: {
      computerName: 'LocalBox-Client'
    }
  }
}
var command = {
  commandToExecute: 'powershell.exe -ExecutionPolicy Bypass -File Bootstrap.ps1 -adminPassword opaque'
}
'@ | Set-Content $hostPath
    }
    It 'embeds bounded custom data only for a new VM and preserves protected arguments' {
        Set-LocalBoxStartupTemplate $hostPath "$root/labautomation/localbox-startup.ps1" $id -NewVm
        $text = Get-Content $hostPath -Raw
        $text | Should -Match "customData: base64\(loadTextContent\('localbox-startup.ps1'\)\)"
        $text | Should -Match '&& powershell.exe.*-Install && powershell.exe.*-adminPassword opaque'
        Get-Content "$TestDrive/localbox-startup.ps1" -Raw | Should -Match $id
        Get-Content "$TestDrive/localbox-startup.ps1" -Raw | Should -Not -Match '__LOCALBOX_BOOTSTRAP_ID__'
        $embeddedAst = [Management.Automation.Language.Parser]::ParseFile("$TestDrive/localbox-startup.ps1", [ref]$null, [ref]$null)
        $embeddedFormatter = $embeddedAst.Find({
            param($node)
            $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'ConvertTo-LocalBoxDiagnosticText'
        }, $true)
        $embeddedFormatter.Body.Extent.Text | Should -Be ('{' + (Get-Command ConvertTo-LocalBoxDiagnosticText).Definition + '}')
    }
    It 'does not replace immutable custom data for an already guarded VM' {
        Set-LocalBoxStartupTemplate $hostPath "$root/labautomation/localbox-startup.ps1" $id
        Get-Content $hostPath -Raw | Should -Not -Match 'customData:'
    }
    It 'rejects an incompatible upstream template without silently removing protection' {
        Add-Content $hostPath 'customData: other'
        { Set-LocalBoxStartupTemplate $hostPath "$root/labautomation/localbox-startup.ps1" $id -NewVm } | Should -Throw '*Unsupported*'
    }
    It 'rejects custom data larger than the API limit' {
        ('x' * 65536) | Set-Content "$TestDrive/oversized.ps1"
        { Set-LocalBoxStartupTemplate $hostPath "$TestDrive/oversized.ps1" $id -NewVm } | Should -Throw '*custom-data limit*'
    }
    It 'wraps the existing startup task and protects the destination directory ACL' {
        '$Action = New-ScheduledTaskAction -Execute $ScheduledTaskExecutable -Argument $LocalBoxPath\LocalBoxLogonScript.ps1' |
            Set-Content "$TestDrive/Bootstrap.ps1"
        Install-LocalBoxStartupGuard "$TestDrive/Bootstrap.ps1"
        $text = Get-Content "$TestDrive/Bootstrap.ps1" -Raw
        $text | Should -Match 'Set-Acl'
        $text | Should -Match '\$guardRoot\\startup.ps1'
        $text | Should -Match 'Set-LocalBoxBgInfoGuard'
        { Install-LocalBoxStartupGuard "$TestDrive/Bootstrap.ps1" } | Should -Throw '*Unsupported*'
    }
}

Describe 'Upstream image download patch' {
    BeforeEach { $imageScript | Set-Content "$TestDrive/cluster.ps1" }
    It 'captures only active trusted sources and inserts a terminating image gate' {
        Set-LocalBoxBaseImageGuard "$TestDrive/cluster.ps1" "$TestDrive/images.json" $id
        $plan = Get-Content "$TestDrive/images.json" -Raw | ConvertFrom-Json -AsHashtable
        $plan.Artifacts.Count | Should -Be 4
        $plan.Artifacts['AzL-node.vhdx'] | Should -Be 'https://azlocalvhds.blob.core.windows.net/images/AzLocal2608.vhdx'
        $text = Get-Content "$TestDrive/cluster.ps1" -Raw
        $text | Should -Match '-DownloadImages'
        $text | Should -Match 'if \(-not \$\?\) \{ throw'
        $text | Should -Match "Write-Host 'after'"
        $text | Should -Not -Match '(?m)^azcopy'
    }
    It 'rejects untrusted or incomplete upstream sources' {
        $imageScript.Replace('azlocalvhds.blob.core.windows.net', 'untrusted.example') | Set-Content "$TestDrive/cluster.ps1"
        { Set-LocalBoxBaseImageGuard "$TestDrive/cluster.ps1" "$TestDrive/images.json" $id } | Should -Throw '*Unrecognized*'
        $imageScript.Replace('AzL-node.sha256', 'unexpected.sha256') | Set-Content "$TestDrive/cluster.ps1"
        { Set-LocalBoxBaseImageGuard "$TestDrive/cluster.ps1" "$TestDrive/images.json" $id } | Should -Throw
    }
}

Describe 'Bounded verified base-image staging' {
    BeforeEach {
        $directory = Join-Path $TestDrive ([guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $directory | Out-Null
        $statusPath = "$directory/status.json"
        $status = @{ BootstrapId = $id; State = 'Running'; Phase = 'Startup' }
        $artifacts = @{}
        foreach ($name in @('AzL-node', 'GUI')) {
            $artifacts["$name.vhdx"] = "https://azlocalvhds.blob.core.windows.net/images/$name.vhdx"
            $artifacts["$name.sha256"] = "https://azlocalvhds.blob.core.windows.net/images/$name.sha256"
        }
        Set-Content "$directory/fixture" 'fixture-image'
        $digest = (Get-FileHash "$directory/fixture").Hash
        Mock Start-Sleep {}
        Mock Invoke-LocalBoxBaseImageTransfer {
            if ($Destination.EndsWith('.sha256')) { Set-Content $Destination $digest }
            else { Set-Content $Destination 'fixture-image' }
        }
        $arguments = @{ Artifacts = $artifacts; Directory = $directory; Status = $status; StatusPath = $statusPath; RetryDelaySeconds = 0 }
    }
    It 'never considers two absent files a valid checksum' {
        Test-LocalBoxBaseImage "$directory/missing.vhdx" "$directory/missing.sha256" | Should -BeFalse
    }
    It 'rejects an empty checksum without skipping download recovery' {
        Set-Content "$directory/AzL-node.vhdx" 'fixture-image'
        Set-Content "$directory/AzL-node.sha256" ''
        Test-LocalBoxBaseImage "$directory/AzL-node.vhdx" "$directory/AzL-node.sha256" | Should -BeFalse
        Sync-LocalBoxBaseImages @arguments
        Should -Invoke Invoke-LocalBoxBaseImageTransfer -Times 4 -Exactly
    }
    It 'rejects a corrupt source plan before making any network request' {
        $artifacts['GUI.vhdx'] = 'https://untrusted.example/image'
        { Sync-LocalBoxBaseImages @arguments } | Should -Throw '*Invalid base-image download plan*'
        Should -Invoke Invoke-LocalBoxBaseImageTransfer -Times 0
    }
    It 'downloads and verifies both images before reporting nested deployment may proceed' {
        Sync-LocalBoxBaseImages @arguments
        Should -Invoke Invoke-LocalBoxBaseImageTransfer -Times 4 -Exactly -ParameterFilter { $TimeoutSeconds -gt 0 -and $TimeoutSeconds -le 1800 }
        Test-LocalBoxBaseImage "$directory/AzL-node.vhdx" "$directory/AzL-node.sha256" | Should -BeTrue
        $status.Phase | Should -Be 'NestedDeployment'
        @(Get-ChildItem $directory -Directory -Force).Count | Should -Be 0
    }
    It 'reuses valid cached images without transferring or changing them' {
        foreach ($name in @('AzL-node', 'GUI')) {
            Set-Content "$directory/$name.vhdx" 'fixture-image'
            Set-Content "$directory/$name.sha256" $digest
        }
        Sync-LocalBoxBaseImages @arguments
        Should -Invoke Invoke-LocalBoxBaseImageTransfer -Times 0
    }
    It 'retries a transient 401 within the fixed attempt count' {
        $transferCounter = @{ Count = 0 }
        Mock Invoke-LocalBoxBaseImageTransfer {
            $transferCounter.Count++
            if ($transferCounter.Count -eq 1) { throw 'AzCopy failed with exit code 1. HTTP 401.' }
            if ($Destination.EndsWith('.sha256')) { Set-Content $Destination $digest }
            else { Set-Content $Destination 'fixture-image' }
        }
        Sync-LocalBoxBaseImages @arguments
        Should -Invoke Invoke-LocalBoxBaseImageTransfer -Times 5 -Exactly
        Should -Invoke Start-Sleep -Times 1 -Exactly
    }
    It 'fails after three denied downloads, preserving existing cache and an actionable report' {
        Set-Content "$directory/AzL-node.vhdx" 'old-incomplete-image'
        Mock Invoke-LocalBoxBaseImageTransfer { throw 'AzCopy failed with exit code 1. HTTP 401.' }
        { Sync-LocalBoxBaseImages @arguments } | Should -Throw '*attempt 3/3*HTTP 401*'
        Should -Invoke Invoke-LocalBoxBaseImageTransfer -Times 3 -Exactly
        Should -Invoke Start-Sleep -Times 2 -Exactly
        Get-Content "$directory/AzL-node.vhdx" | Should -Be 'old-incomplete-image'
        $report = Get-Content $statusPath -Raw | ConvertFrom-Json
        $report.State | Should -Be 'Failed'
        $report.Code | Should -Be 'BaseImageDownloadFailed'
        @(Get-ChildItem $directory -Directory -Force).Count | Should -Be 0
    }
    It 'rejects malformed checksums even when transfers report success' {
        Mock Invoke-LocalBoxBaseImageTransfer { Set-Content $Destination 'not-a-checksum' }
        { Sync-LocalBoxBaseImages @arguments } | Should -Throw '*malformed*'
        Test-Path "$directory/AzL-node.vhdx" | Should -BeFalse
        $status.State | Should -Be 'Failed'
    }
    It 'does not promote a hash-mismatched image' {
        Mock Invoke-LocalBoxBaseImageTransfer {
            if ($Destination.EndsWith('.sha256')) { Set-Content $Destination ('0' * 64) }
            else { Set-Content $Destination 'fixture-image' }
        }
        { Sync-LocalBoxBaseImages @arguments } | Should -Throw '*does not match*'
        Should -Invoke Invoke-LocalBoxBaseImageTransfer -Times 6 -Exactly
        Test-Path "$directory/AzL-node.vhdx" | Should -BeFalse
    }
    It 'does not create another attempt when the remaining budget cannot cover the retry delay' {
        $arguments.TimeoutSeconds = 30
        $arguments.RetryDelaySeconds = 60
        Mock Invoke-LocalBoxBaseImageTransfer { throw 'Download failed' }
        { Sync-LocalBoxBaseImages @arguments } | Should -Throw
        Should -Invoke Start-Sleep -Times 0
        Should -Invoke Invoke-LocalBoxBaseImageTransfer -Times 1 -Exactly
    }

}

Describe 'Guarded startup replay protection' {
        BeforeEach {
            $startupRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString())
            New-Item -ItemType Directory -Path "$startupRoot/SovereignStartup" -Force | Out-Null
            $stateFile = "$startupRoot/SovereignStartup/state.json"
            Mock Set-LocalBoxBaseImageGuard {}
            Mock Wait-LocalBoxStartupPrerequisites {}
        }
        It 'does not repeat completed initialization' {
            @{ BootstrapId = $id; State = 'Succeeded' } | ConvertTo-Json | Set-Content $stateFile
            Invoke-LocalBoxGuardedStartup $id $startupRoot
            Should -Invoke Set-LocalBoxBaseImageGuard -Times 0
        }
        It 'blocks incomplete or failed initialization without rerunning storage' -TestCases @(
            @{ PreviousState = 'Running' }, @{ PreviousState = 'Failed' }
        ) {
            param($PreviousState)
            @{ BootstrapId = $id; State = $PreviousState } | ConvertTo-Json | Set-Content $stateFile
            { Invoke-LocalBoxGuardedStartup $id $startupRoot } | Should -Throw '*Automatic replay*disabled*'
            Should -Invoke Set-LocalBoxBaseImageGuard -Times 0
        }
        It 'fails closed on corrupt previous state' {
            Set-Content $stateFile 'not json'
            { Invoke-LocalBoxGuardedStartup $id $startupRoot } | Should -Throw
            Should -Invoke Set-LocalBoxBaseImageGuard -Times 0
        }
        It 'preserves the primary error if recording its report also fails' {
            Mock Save-LocalBoxStartupStatus { throw 'fixture-state-write-denied' }
            { Invoke-LocalBoxGuardedStartup $id $startupRoot } | Should -Throw '*fixture-state-write-denied*'
            Should -Invoke Set-LocalBoxBaseImageGuard -Times 0
        }
        It 'records an upstream failure and prevents a second invocation' {
            Set-Content "$startupRoot/LocalBoxLogonScript.ps1" 'throw "fixture-upstream-failed"'
            { Invoke-LocalBoxGuardedStartup $id $startupRoot } | Should -Throw '*fixture-upstream-failed*'
            (Get-Content $stateFile -Raw | ConvertFrom-Json).Code | Should -Be 'StartupFailed'
            (Get-Content $stateFile -Raw | ConvertFrom-Json).Message | Should -Match 'fixture-upstream-failed'
            { Invoke-LocalBoxGuardedStartup $id $startupRoot } | Should -Throw '*Automatic replay*disabled*'
            Should -Invoke Set-LocalBoxBaseImageGuard -Times 1 -Exactly
        }
        It 'does not enter storage initialization when prerequisites fail' {
            Mock Wait-LocalBoxStartupPrerequisites {
                $Status.Phase = 'Prerequisites'
                Save-LocalBoxStartupStatus $Status $StatusPath
                throw 'fixture-prerequisites-incomplete'
            }
            { Invoke-LocalBoxGuardedStartup $id $startupRoot } | Should -Throw '*fixture-prerequisites-incomplete*'
            (Get-Content $stateFile -Raw | ConvertFrom-Json).Code | Should -Be 'StartupPrerequisitesFailed'
            Should -Invoke Set-LocalBoxBaseImageGuard -Times 0
        }
        It 'records successful script completion without claiming infrastructure readiness' {
            Set-Content "$startupRoot/LocalBoxLogonScript.ps1" 'Write-Output "fixture-script-completed"'
            Invoke-LocalBoxGuardedStartup $id $startupRoot | Out-Null
            $saved = Get-Content $stateFile -Raw | ConvertFrom-Json
            $saved.State | Should -Be 'Succeeded'
            $saved.Message | Should -Match 'Full health gates are still required'
        }
        It 'preserves a non-terminating upstream lookup error and still runs its next readiness gate' {
            @'
Write-Error "No MSFT_ScheduledTask objects found for ImageCustomizationScheduledTask"
Set-Content "$PSScriptRoot/readiness-checked" 'yes'
'@ | Set-Content "$startupRoot/LocalBoxLogonScript.ps1"
            $result = @(Invoke-LocalBoxGuardedStartup $id $startupRoot 2>&1)
            ($result | Out-String) | Should -Match 'ImageCustomizationScheduledTask'
            Get-Content "$startupRoot/readiness-checked" | Should -Be 'yes'
            (Get-Content $stateFile -Raw | ConvertFrom-Json).State | Should -Be 'Succeeded'
        }
        It 'still fails when upstream readiness throws after a non-terminating lookup' {
            @'
Write-Error "ImageCustomizationScheduledTask is absent"
throw 'Timeout waiting for required bootstrap paths'
'@ | Set-Content "$startupRoot/LocalBoxLogonScript.ps1"
            { Invoke-LocalBoxGuardedStartup $id $startupRoot 2>$null } | Should -Throw '*required bootstrap paths*'
            (Get-Content $stateFile -Raw | ConvertFrom-Json).State | Should -Be 'Failed'
        }
        It 'keeps an explicit upstream ErrorAction Stop terminating' {
            Set-Content "$startupRoot/LocalBoxLogonScript.ps1" 'Write-Error "fixture-required-operation-failed" -ErrorAction Stop'
            { Invoke-LocalBoxGuardedStartup $id $startupRoot } | Should -Throw '*fixture-required-operation-failed*'
            (Get-Content $stateFile -Raw | ConvertFrom-Json).State | Should -Be 'Failed'
        }
        It 'preserves module error semantics and restores global preference for <Outcome>' -TestCases @(
            @{ Outcome = 'Continue'; Ending = 'Set-Content "$PSScriptRoot/module-readiness-checked" yes' }
            @{ Outcome = 'Throw'; Ending = 'throw "fixture-module-readiness-failed"' }
            @{ Outcome = 'ExplicitStop'; Ending = 'Write-Error "fixture-module-required-operation-failed" -ErrorAction Stop' }
        ) {
            param($Outcome, $Ending)
            $moduleName = 'FixtureLocalBoxBootstrap'
            @'
function Invoke-FixtureBootstrap {
    Write-Error 'ImageCustomizationScheduledTask is absent'
    __ENDING__
}
'@.Replace('__ENDING__', $Ending) | Set-Content "$startupRoot/$moduleName.psm1"
            @'
Import-Module "$PSScriptRoot/FixtureLocalBoxBootstrap.psm1" -Force
Invoke-FixtureBootstrap
'@ | Set-Content "$startupRoot/LocalBoxLogonScript.ps1"
            $previousGlobalPreference = $global:ErrorActionPreference
            try {
                $global:ErrorActionPreference = 'Stop'
                if ($Outcome -eq 'Continue') {
                    $result = @(Invoke-LocalBoxGuardedStartup $id $startupRoot 2>&1)
                    ($result | Out-String) | Should -Match 'ImageCustomizationScheduledTask'
                    Get-Content "$startupRoot/module-readiness-checked" | Should -Be 'yes'
                    (Get-Content $stateFile -Raw | ConvertFrom-Json).State | Should -Be 'Succeeded'
                }
                else {
                    { Invoke-LocalBoxGuardedStartup $id $startupRoot 2>$null } | Should -Throw '*fixture-module-*'
                    (Get-Content $stateFile -Raw | ConvertFrom-Json).State | Should -Be 'Failed'
                }
                $global:ErrorActionPreference | Should -Be 'Stop'
            }
            finally {
                $global:ErrorActionPreference = $previousGlobalPreference
                Remove-Module $moduleName -ErrorAction Stop
            }
        }
        It 'records a bounded redacted error rather than only a generic failure' {
            Set-Content "$startupRoot/LocalBoxLogonScript.ps1" 'throw (''Missing task; password=fixture-sensitive token=fixture-token '' + (''x'' * 1000))'
            { Invoke-LocalBoxGuardedStartup $id $startupRoot } | Should -Throw
            $saved = Get-Content $stateFile -Raw | ConvertFrom-Json
            $saved.Message | Should -Match 'Missing task'
            $saved.Message | Should -Not -Match 'fixture-sensitive|fixture-token'
            $saved.Message.Length | Should -BeLessOrEqual 1000
        }
    }

    Describe 'Native transfer outcome checks' {
        BeforeEach {
            $processState = @{ Finished = $true; Exit = 0; Killed = $false; Disposed = $false }
            $fakeProcess = [pscustomobject]@{ HasExited = $true; ExitCode = 0 }
            $fakeProcess | Add-Member ScriptMethod WaitForExit { param($milliseconds) return $processState.Finished }
            $fakeProcess | Add-Member ScriptMethod Kill { param($tree) $processState.Killed = $true; $this.HasExited = $true }
            $fakeProcess | Add-Member ScriptMethod Dispose { $processState.Disposed = $true }
            Mock Get-Command { @{ Path = 'fixture-azcopy' } } -ParameterFilter { $Name -eq 'azcopy' }
            Mock Start-Process { $fakeProcess }
            $transferPath = Join-Path $TestDrive ([guid]::NewGuid().ToString())
            New-Item -ItemType Directory -Path $transferPath | Out-Null
            $transferArgs = @{ Uri = 'https://azlocalvhds.blob.core.windows.net/image'; Destination = "$transferPath/image"; LogDirectory = $transferPath; TimeoutSeconds = 1 }
            $originalLogs = $env:AZCOPY_LOG_LOCATION
            $originalPlans = $env:AZCOPY_JOB_PLAN_LOCATION
        }
        AfterEach {
            $env:AZCOPY_LOG_LOCATION | Should -Be $originalLogs
            $env:AZCOPY_JOB_PLAN_LOCATION | Should -Be $originalPlans
        }
        It 'rejects a zero exit without an output file' {
            { Invoke-LocalBoxBaseImageTransfer @transferArgs } | Should -Throw '*success without creating*'
            $processState.Disposed | Should -BeTrue
        }
        It 'extracts only HTTP status codes instead of raw native error output' {
            $fakeProcess.ExitCode = 1
            Set-Content "$transferPath/error.log" 'RESPONSE 401 secret-response-fixture'
            { Invoke-LocalBoxBaseImageTransfer @transferArgs } | Should -Throw '*exit code 1. HTTP 401.*'
            try { Invoke-LocalBoxBaseImageTransfer @transferArgs } catch { $_.Exception.Message | Should -Not -Match 'secret-response-fixture' }
        }
        It 'terminates only its own timed-out process and restores the environment' {
            $processState.Finished = $false
            $fakeProcess.HasExited = $false
            { Invoke-LocalBoxBaseImageTransfer @transferArgs } | Should -Throw
            $processState.Killed | Should -BeTrue
            $processState.Disposed | Should -BeTrue
        }
        It 'restores the environment even when process termination fails' {
            $processState.Finished = $false
            $fakeProcess.HasExited = $false
            $fakeProcess | Add-Member ScriptMethod Kill { param($tree) throw 'fixture-kill-denied' } -Force
            { Invoke-LocalBoxBaseImageTransfer @transferArgs } | Should -Throw '*fixture-kill-denied*'
            $processState.Disposed | Should -BeTrue
        }
    }

    Describe 'Console startup correlation' {
        BeforeEach {
            $tracking = @{ Checked = $false; Id = $null }
            $monitorState = @{ Vm = @{ tags = @{ 'microhack-startup-version' = '1'; 'microhack-startup-id' = $id }; location = 'spaincentral' } }
            $report = @{ BootstrapId = $id; SubscriptionId = $subscription; ResourceGroupName = 'group'; State = 'Failed'; Phase = 'BaseImages'; Code = 'BaseImageDownloadFailed'; Message = 'AzCopy HTTP 401' }
            $monitorState.Command = @{ properties = @{
                provisioningState = 'Succeeded'
                parameters = @(
                    @{ name = 'BootstrapId'; value = $id }
                    @{ name = 'SubscriptionId'; value = $subscription }
                    @{ name = 'ResourceGroupName'; value = 'group' }
                    @{ name = 'StartedAfter'; value = '2026-11-05T00:00:00Z' }
                )
                instanceView = @{ startTime = '2026-11-05T00:00:01Z'; executionState = 'Failed'; exitCode = 1; output = 'LOCALBOX_STARTUP_REPORT:' + ($report | ConvertTo-Json -Compress) }
            } }
            Mock Invoke-LocalBoxAutomationRequest {
                if ($Path -notmatch '/runCommands/') { return $monitorState.Vm }
                return $monitorState.Command
            }
        }
        It 'does not create a startup monitor for a legacy VM' {
            $monitorState.Vm.tags = @{}
            $monitorState.Command = $null
            Get-LocalBoxStartupProgress $tracking $subscription group 100
            Should -Invoke Invoke-LocalBoxAutomationRequest -Times 0 -ParameterFilter { $Method -eq 'PUT' }
        }
        It 'fails explicitly if startup identity was lost after a monitor was created' {
            $monitorState.Vm.tags = @{}
            { Get-LocalBoxStartupProgress $tracking $subscription group 100 } | Should -Throw '*identity tags are missing*'
            Should -Invoke Invoke-LocalBoxAutomationRequest -Times 0 -ParameterFilter { $Method -eq 'PUT' }
        }
        It 'surfaces the correlated download failure immediately' {
            { Get-LocalBoxStartupProgress $tracking $subscription group 100 } | Should -Throw '*BaseImages*BaseImageDownloadFailed*HTTP 401*'
        }
        It 'never overwrites a foreign command' {
            $monitorState.Command.properties.parameters[0].value = 'foreign'
            { Get-LocalBoxStartupProgress $tracking $subscription group 100 } | Should -Throw '*not replaced*'
            Should -Invoke Invoke-LocalBoxAutomationRequest -Times 0 -ParameterFilter { $Method -eq 'PUT' }
        }
        It 'does not accept stale execution output' {
            $monitorState.Command.properties.instanceView.startTime = '2026-11-04T00:00:01Z'
            Get-LocalBoxStartupProgress $tracking $subscription group 100
        }
        It 'rejects terminal output without a verified report' {
            $monitorState.Command.properties.instanceView.output = 'untrusted raw stdout'
            { Get-LocalBoxStartupProgress $tracking $subscription group 100 } | Should -Throw '*without a verified report*'
        }
        It 'starts one asynchronous scoped monitor when none exists' {
            $monitorState.Command.properties.instanceView.executionState = 'Running'
            Mock Invoke-LocalBoxAutomationRequest { return $null } -ParameterFilter { $AllowNotFound }
            Get-LocalBoxStartupProgress $tracking $subscription group 100
            Get-LocalBoxStartupProgress $tracking $subscription group 90
            Should -Invoke Invoke-LocalBoxAutomationRequest -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'PUT' -and $Body.properties.asyncExecution -and $Body.properties.timeoutInSeconds -eq 100 -and
                ($Body.properties.parameters | Where-Object name -eq BootstrapId).value -eq $id
            }
        }
    }
Describe 'Startup report validation' {
    It 'accepts the prerequisite phase while WinGet is still installing' {
        $path = "$TestDrive/state.json"
        @{ BootstrapId = $id; SubscriptionId = $subscription; ResourceGroupName = 'group'; State = 'Running'; Phase = 'Prerequisites'; Code = ''; Message = 'Waiting for WinGet' } |
            ConvertTo-Json | Set-Content $path
        (Get-LocalBoxStartupReport $path $id $subscription group).Phase | Should -Be 'Prerequisites'
    }
    It 'rejects reports for another bootstrap or subscription' {
        $path = "$TestDrive/state.json"
        @{ BootstrapId = 'foreign'; SubscriptionId = $subscription; ResourceGroupName = 'group'; State = 'Failed'; Phase = 'BaseImages' } |
            ConvertTo-Json | Set-Content $path
        { Get-LocalBoxStartupReport $path $id $subscription group } | Should -Throw '*does not match*'
    }

    Describe 'WinGet startup prerequisite ordering' {
        BeforeEach {
            $prerequisiteClock = @{ Now = [datetime]'2026-11-06T00:00:00Z'; Sleeps = 0 }
            $originalPath = $env:PATH
            $prerequisiteStatus = @{ BootstrapId = $id; State = 'Running'; Phase = 'Startup' }
            $prerequisitePath = "$TestDrive/prerequisites.json"
            Mock Get-Date { $prerequisiteClock.Now }
            Mock Get-ScheduledTask { @() }
            Mock Get-ScheduledTaskInfo { @{ LastRunTime = [datetime]'1999-01-01'; LastTaskResult = 267011 } }
            Mock Start-Sleep {
                $prerequisiteClock.Sleeps++
                $prerequisiteClock.Now = $prerequisiteClock.Now.AddSeconds(15)
            }
            Mock Resolve-LocalBoxAzCopy { 'fixture-azcopy.exe' }
            Mock Resolve-LocalBoxBgInfo { 'fixture-bginfo.exe' }
        }
        AfterEach { $env:PATH = $originalPath }
        It 'waits for installer completion before resolving tools or initializing storage' {
            Mock Get-ScheduledTask {
                if ($prerequisiteClock.Sleeps -lt 2) { @{ TaskName = 'WinGetLogonScript'; TaskPath = '\'; State = 'Running' } }
            }
            Mock Resolve-LocalBoxAzCopy {
                $prerequisiteClock.Sleeps | Should -Be 2
                'fixture-azcopy.exe'
            }
            Wait-LocalBoxStartupPrerequisites $prerequisiteStatus $prerequisitePath
            Should -Invoke Start-Sleep -Times 2 -Exactly
            Should -Invoke Resolve-LocalBoxAzCopy -Times 1 -Exactly
            Should -Invoke Resolve-LocalBoxBgInfo -Times 1 -Exactly
            $prerequisiteStatus.Phase | Should -Be 'Startup'
        }
        It 'also waits for a registered task that has not started yet' {
            Mock Get-ScheduledTask {
                if ($prerequisiteClock.Sleeps -eq 0) { @{ TaskName = 'WinGetLogonScript'; TaskPath = '\'; State = 'Ready' } }
            }
            Wait-LocalBoxStartupPrerequisites $prerequisiteStatus $prerequisitePath
            Should -Invoke Start-Sleep -Times 1 -Exactly
        }
        It 'stops at the one-hour installation budget without attempting a download' {
            Mock Get-ScheduledTask { @{ TaskName = 'WinGetLogonScript'; TaskPath = '\'; State = 'Running' } }
            Mock Start-Sleep { $prerequisiteClock.Now = $prerequisiteClock.Now.AddHours(1) }
            { Wait-LocalBoxStartupPrerequisites $prerequisiteStatus $prerequisitePath } | Should -Throw '*one-hour prerequisite budget*'
            ($prerequisiteClock.Now - [datetime]'2026-11-06T00:00:00Z').TotalSeconds | Should -Be 3600
            Should -Invoke Resolve-LocalBoxAzCopy -Times 0
        }
        It 'does not treat an installation/discovery failure as ready' {
            Mock Resolve-LocalBoxAzCopy { throw 'fixture-missing-azcopy' }
            { Wait-LocalBoxStartupPrerequisites $prerequisiteStatus $prerequisitePath } | Should -Throw '*fixture-missing-azcopy*'
            $prerequisiteStatus.Phase | Should -Be 'Prerequisites'
        }
        It 'requires BGInfo before storage initialization even when AzCopy is available' {
            Mock Resolve-LocalBoxBgInfo { throw 'fixture-missing-bginfo' }
            { Wait-LocalBoxStartupPrerequisites $prerequisiteStatus $prerequisitePath } | Should -Throw '*fixture-missing-bginfo*'
            $prerequisiteStatus.Phase | Should -Be 'Prerequisites'
        }
        It 'surfaces task query errors rather than assuming WinGet completed' {
            Mock Get-ScheduledTask { throw 'fixture-scheduler-unavailable' }
            { Wait-LocalBoxStartupPrerequisites $prerequisiteStatus $prerequisitePath } | Should -Throw '*fixture-scheduler-unavailable*'
            Should -Invoke Resolve-LocalBoxAzCopy -Times 0
        }
        It 'fails promptly when WinGet exited unsuccessfully instead of waiting an hour' {
            Mock Get-ScheduledTask { @{ TaskName = 'WinGetLogonScript'; TaskPath = '\'; State = 'Ready' } }
            Mock Get-ScheduledTaskInfo { @{ LastRunTime = [datetime]'2026-11-06T00:00:00Z'; LastTaskResult = 1 } }
            { Wait-LocalBoxStartupPrerequisites $prerequisiteStatus $prerequisitePath } | Should -Throw '*task result 1*'
            Should -Invoke Start-Sleep -Times 0
            Should -Invoke Resolve-LocalBoxAzCopy -Times 0
        }
    }

    Describe 'AzCopy resolution with a stale process PATH' {
        BeforeEach {
            Mock Get-Command { @() } -ParameterFilter { $Name -eq 'azcopy' }
            $localData = Join-Path $TestDrive ([guid]::NewGuid().ToString())
            $programRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString())
            $resolveArguments = @{ LocalAppData = $localData; ProgramFiles = $programRoot }
        }
        It 'preserves an existing native PATH resolution' {
            Mock Get-Command { @{ Path = 'native-azcopy.exe' } } -ParameterFilter { $Name -eq 'azcopy' }
            Resolve-LocalBoxAzCopy @resolveArguments | Should -Be 'native-azcopy.exe'
        }
        It 'finds the current startup user WinGet link without searching other profiles' {
            $directory = Join-Path $localData 'Microsoft/WinGet/Links'
            New-Item -ItemType Directory -Path $directory -Force | Out-Null
            Set-Content "$directory/azcopy.exe" 'fixture'
            Resolve-LocalBoxAzCopy @resolveArguments | Should -Be "$directory/azcopy.exe"
        }
        It 'finds the exact installed package when its WinGet link is absent' {
            $directory = Join-Path $localData 'Microsoft/WinGet/Packages/Microsoft.Azure.AZCopy.10_fixture/azcopy_windows_amd64_10.34.1'
            New-Item -ItemType Directory -Path $directory -Force | Out-Null
            Set-Content "$directory/azcopy.exe" 'fixture'
            Resolve-LocalBoxAzCopy @resolveArguments | Should -Be "$directory/azcopy.exe"
        }
        It 'fails explicitly instead of choosing between multiple unlinked versions' {
            foreach ($version in @('10.34.0','10.34.1')) {
                $directory = Join-Path $localData "Microsoft/WinGet/Packages/Microsoft.Azure.AZCopy.10_fixture/azcopy_windows_amd64_$version"
                New-Item -ItemType Directory -Path $directory -Force | Out-Null
                Set-Content "$directory/azcopy.exe" 'fixture'
            }
            { Resolve-LocalBoxAzCopy @resolveArguments } | Should -Throw '*Multiple unlinked AzCopy*'
        }
        It 'reports an actionable error when installation did not provide AzCopy' {
            { Resolve-LocalBoxAzCopy @resolveArguments } | Should -Throw '*Inspect the WinGet provisioning log*'
        }
    }
    It 'rejects corrupt JSON and invalid states' {
        $path = "$TestDrive/state.json"
        Set-Content $path 'not-json'
        { Get-LocalBoxStartupReport $path $id $subscription group } | Should -Throw '*read or parsed*'
        @{ BootstrapId = $id; SubscriptionId = $subscription; ResourceGroupName = 'group'; State = 'Unknown'; Phase = 'BaseImages' } |
            ConvertTo-Json | Set-Content $path
        { Get-LocalBoxStartupReport $path $id $subscription group } | Should -Throw '*invalid state metadata*'
    }
}

Describe 'Startup report monitor thresholds' {
    BeforeEach {
        $clock = @{ Now = [datetime]'2026-11-05T00:00:00Z' }
        Mock Get-Date { $clock.Now }
        Mock Start-Sleep { $clock.Now = $clock.Now.AddHours(1) }
        Mock Get-LocalBoxStartupReport { $null }
        Mock Get-ScheduledTask { @{ State = 'Ready' } }
        Mock Test-LocalBoxStartupActive { $false }
    }
    It 'fails at the one-hour missing-report threshold instead of waiting eight hours' {
        $report = Wait-LocalBoxStartupReport $id $subscription group 28800
        $report.Code | Should -Be 'StartupNotStarted'
        Should -Invoke Start-Sleep -Times 1 -Exactly
        ($clock.Now - [datetime]'2026-11-05T00:00:00Z').TotalSeconds | Should -Be 3600
    }
    It 'detects an exited guarded process only after the two-minute startup grace' {
        Mock Get-LocalBoxStartupReport { @{ State = 'Running' } }
        Mock Start-Sleep { $clock.Now = $clock.Now.AddSeconds(120) }
        (Wait-LocalBoxStartupReport $id $subscription group 28800).Code | Should -Be 'StartupExited'
        Should -Invoke Test-LocalBoxStartupActive -Times 1 -Exactly
        Should -Invoke Get-ScheduledTask -Times 0
        ($clock.Now - [datetime]'2026-11-05T00:00:00Z').TotalSeconds | Should -Be 120
    }
    It 'returns reported failure immediately without waiting or inspecting tasks' {
        Mock Get-LocalBoxStartupReport { @{ State = 'Failed'; Code = 'BaseImageDownloadFailed' } }
        (Wait-LocalBoxStartupReport $id $subscription group 28800).Code | Should -Be 'BaseImageDownloadFailed'
        Should -Invoke Start-Sleep -Times 0
        Should -Invoke Get-ScheduledTask -Times 0
        Should -Invoke Test-LocalBoxStartupActive -Times 0
    }
    It 'does not treat a monitoring exception as startup success' {
        Mock Get-LocalBoxStartupReport { throw 'Invalid metadata' }
        $report = Wait-LocalBoxStartupReport $id $subscription group 28800
        $report.State | Should -Be 'Failed'
        $report.Message | Should -Match 'Invalid metadata'
    }
    It 'continues observing a live startup after it unregisters its scheduled task' {
        Mock Get-ScheduledTask { throw 'No scheduled task exists' }
        Mock Start-Sleep { $clock.Now = $clock.Now.AddSeconds(120) }
        Mock Test-LocalBoxStartupActive { $true }
        Mock Get-LocalBoxStartupReport {
            if ($clock.Now -ge [datetime]'2026-11-05T00:04:00Z') { return @{ State = 'Succeeded'; Phase = 'Complete' } }
            @{ State = 'Running'; Phase = 'NestedDeployment' }
        }
        (Wait-LocalBoxStartupReport $id $subscription group 28800).State | Should -Be 'Succeeded'
        Should -Invoke Test-LocalBoxStartupActive -Times 1 -Exactly
        Should -Invoke Get-ScheduledTask -Times 0
    }
    It 'rereads the terminal report when the process releases its lock between observations' {
        $reads = @{ Count = 0 }
        Mock Start-Sleep { $clock.Now = $clock.Now.AddSeconds(120) }
        Mock Get-LocalBoxStartupReport {
            $reads.Count++
            if ($reads.Count -eq 3) { return @{ State = 'Succeeded'; Phase = 'Complete' } }
            @{ State = 'Running' }
        }
        (Wait-LocalBoxStartupReport $id $subscription group 28800).State | Should -Be 'Succeeded'
        $reads.Count | Should -Be 3
    }
    It 'does not treat a held lock as success when the report remains incomplete' {
        Mock Get-LocalBoxStartupReport { @{ State = 'Running' } }
        Mock Test-LocalBoxStartupActive { $true }
        $report = Wait-LocalBoxStartupReport $id $subscription group 3600
        $report.State | Should -Be 'Failed'
        $report.Code | Should -Be 'StartupTimedOut'
    }
    It 'preserves bounded redacted lock-inspection errors without hiding the failure' {
        Mock Get-LocalBoxStartupReport { @{ State = 'Running' } }
        Mock Test-LocalBoxStartupActive { throw ('Mutex access denied; password=fixture-password token=fixture-token ' + ('x' * 1000)) }
        $report = Wait-LocalBoxStartupReport $id $subscription group 28800
        $report.Code | Should -Be 'StartupMonitorFailed'
        $report.State | Should -Be 'Failed'
        $report.Message | Should -Match 'Mutex access denied'
        $report.Message | Should -Not -Match 'fixture-password|fixture-token'
        $report.Message.Length | Should -BeLessOrEqual 800
    }
}

Describe 'BGInfo resolution and persistent test-runner protection' {
    BeforeEach {
        Mock Get-Command { @() } -ParameterFilter { $Name -eq 'bginfo64.exe' }
        $localData = Join-Path $TestDrive ([guid]::NewGuid().ToString())
        $programRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString())
        $resolveArguments = @{ LocalAppData = $localData; ProgramFiles = $programRoot }
        $runner = "$TestDrive/Invoke-Test.ps1"
        $bginfoLine = 'bginfo64.exe $Env:LocalBoxTestsDir\localbox-bginfo.bgi /timer:0 /NOLICPROMPT'
    }
    It 'preserves a native command already available on PATH' {
        Mock Get-Command { @{ Path = 'native-bginfo.exe' } } -ParameterFilter { $Name -eq 'bginfo64.exe' }
        Resolve-LocalBoxBgInfo @resolveArguments | Should -Be 'native-bginfo.exe'
    }
    It 'resolves a WinGet link or exact package without relying on process PATH: <Location>' -TestCases @(
        @{ Location = 'UserLink'; Relative = 'Microsoft/WinGet/Links' }
        @{ Location = 'MachineLink'; Relative = 'WinGet/Links' }
        @{ Location = 'UserPackage'; Relative = 'Microsoft/WinGet/Packages/Microsoft.Sysinternals.BGInfo_fixture' }
        @{ Location = 'MachinePackage'; Relative = 'WinGet/Packages/Microsoft.Sysinternals.BGInfo_fixture' }
    ) {
        param($Location, $Relative)
        $base = if ($Location -like 'User*') { $localData } else { $programRoot }
        $directory = Join-Path $base $Relative
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
        Set-Content "$directory/Bginfo64.exe" fixture
        Resolve-LocalBoxBgInfo @resolveArguments | Should -Be "$directory/Bginfo64.exe"
    }
    It 'rejects ambiguous unlinked packages instead of choosing a version' {
        foreach ($version in @('one', 'two')) {
            $directory = Join-Path $localData "Microsoft/WinGet/Packages/Microsoft.Sysinternals.BGInfo_$version"
            New-Item -ItemType Directory -Path $directory -Force | Out-Null
            Set-Content "$directory/Bginfo64.exe" fixture
        }
        { Resolve-LocalBoxBgInfo @resolveArguments } | Should -Throw '*Multiple unlinked BGInfo*'
    }
    It 'reports a missing installation rather than falling back to another user profile' {
        { Resolve-LocalBoxBgInfo @resolveArguments } | Should -Throw '*BGInfo is unavailable*'
    }
    It 'patches the retained runner for startup and future logons: <Newline>' -TestCases @(
        @{ Newline = "`n" }; @{ Newline = "`r`n" }
    ) {
        param($Newline)
        "Write-Output before${Newline}$bginfoLine${Newline}Write-Output after" | Set-Content $runner
        Set-LocalBoxBgInfoGuard $runner
        $text = Get-Content $runner -Raw
        $text | Should -Match '\. "\$Env:LocalBoxDir\\SovereignStartup\\startup.ps1"'
        $text | Should -Match 'Invoke-LocalBoxBgInfo -ConfigurationPath "\$Env:LocalBoxTestsDir\\localbox-bginfo.bgi"'
        $text | Should -Match 'Write-Output before'
        $text | Should -Match 'Write-Output after'
        $text | Should -Not -Match '(?m)^bginfo64.exe'
    }
    It 'rejects missing or duplicate upstream commands without modifying the runner' -TestCases @(
        @{ Count = 0 }; @{ Count = 2 }
    ) {
        param($Count)
        (@($bginfoLine) * $Count -join "`n") | Set-Content $runner
        $before = Get-Content $runner -Raw
        { Set-LocalBoxBgInfoGuard $runner } | Should -Throw '*Unsupported upstream BGInfo*'
        Get-Content $runner -Raw | Should -Be $before
    }
}

Describe 'Checked BGInfo invocation' {
    BeforeEach {
        $configuration = "$TestDrive/configuration with spaces.bgi"
        Set-Content $configuration fixture
        $executable = "$TestDrive/bginfo fixture.ps1"
        Mock Resolve-LocalBoxBgInfo { $executable }
        $previousExitCode = $global:LASTEXITCODE
    }
    AfterEach { $global:LASTEXITCODE = $previousExitCode }
    It 'passes the exact configuration and noninteractive flags to the resolved executable' {
        @'
$args | ConvertTo-Json | Set-Content "$PSScriptRoot/bginfo-arguments.json"
$global:LASTEXITCODE = 0
'@ | Set-Content $executable
        Invoke-LocalBoxBgInfo $configuration
        $arguments = Get-Content "$TestDrive/bginfo-arguments.json" -Raw | ConvertFrom-Json
        $arguments.Count | Should -Be 3
        $arguments[0] | Should -Be $configuration
        $arguments[1] | Should -Be '/timer:0'
        $arguments[2] | Should -Be '/NOLICPROMPT'
    }
    It 'fails on a nonzero exit code' {
        '$global:LASTEXITCODE = 5' | Set-Content $executable
        { Invoke-LocalBoxBgInfo $configuration } | Should -Throw '*BGInfo failed with exit code 5*'
    }
    It 'does not launch BGInfo without its configuration' {
        { Invoke-LocalBoxBgInfo "$TestDrive/missing.bgi" } | Should -Throw '*configuration is missing*'
        Should -Invoke Resolve-LocalBoxBgInfo -Times 0
    }
}

Describe 'Startup lock and standalone monitor packaging' {
    It 'reports a nonexistent or unowned lock as inactive and releases acquired handles' {
        $name = "MicroHackTest-$([guid]::NewGuid())"
        Test-LocalBoxStartupActive $name | Should -BeFalse
        $mutex = [Threading.Mutex]::new($false, $name)
        try {
            Test-LocalBoxStartupActive $name | Should -BeFalse
            $mutex.WaitOne(0) | Should -BeTrue
            $mutex.ReleaseMutex()
        }
        finally { $mutex.Dispose() }
    }
    It 'observes a lock held by another process without acquiring or releasing its ownership' {
        $name = "MicroHackTest-$([guid]::NewGuid())"
        $job = Start-Job -ArgumentList $name -ScriptBlock {
            param($Name)
            $mutex = [Threading.Mutex]::new($false, $Name)
            if (-not $mutex.WaitOne(0)) { throw 'Fixture could not acquire its startup lock.' }
            try { Write-Output 'held'; Start-Sleep -Seconds 30 }
            finally { $mutex.ReleaseMutex(); $mutex.Dispose() }
        }
        try {
            $deadline = [datetime]::UtcNow.AddSeconds(15)
            while (-not $job.ChildJobs[0].Output.Count -and [datetime]::UtcNow -lt $deadline) { Start-Sleep -Milliseconds 50 }
            Receive-Job $job -Keep -ErrorAction Stop | Should -Be 'held'
            Test-LocalBoxStartupActive $name | Should -BeTrue
            Test-LocalBoxStartupActive $name | Should -BeTrue
        }
        finally { Stop-Job $job; Remove-Job $job -Force }
    }
    It 'embeds the shared diagnostic formatter in the submitted standalone monitor' {
        $source = New-LocalBoxStartupWatchScript
        $errors = $null
        $ast = [Management.Automation.Language.Parser]::ParseInput($source, [ref]$null, [ref]$errors)
        $errors.Count | Should -Be 0
        $formatter = $ast.FindAll({
            param($node)
            $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'ConvertTo-LocalBoxDiagnosticText'
        }, $true)
        $formatter.Count | Should -Be 1
        $formatter[0].Body.Extent.Text | Should -Be ('{' + "`n" + (Get-Command ConvertTo-LocalBoxDiagnosticText).Definition + "`n}")
        $ast.ParamBlock.Parameters.Name.VariablePath.UserPath | Should -Contain 'BootstrapId'
    }
}
