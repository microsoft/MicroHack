#Requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$Install,
    [switch]$DownloadImages,
    [string]$BootstrapId = '__LOCALBOX_BOOTSTRAP_ID__'
)

function Set-LocalBoxStartupTemplate {
    param([string]$HostTemplate, [string]$StartupSource, [guid]$Id, [switch]$NewVm)
    $text = Get-Content -LiteralPath $HostTemplate -Raw -ErrorAction Stop
    $pattern = '(?m)^([ \t]*)commandToExecute: ''(powershell\.exe -ExecutionPolicy Bypass -File Bootstrap\.ps1 [^''\r\n]+)''[ \t]*\r?$'
    $matches = [regex]::Matches($text, $pattern)
    if ($matches.Count -ne 1 -or $text -match 'customData:') {
        throw 'Unsupported upstream LocalBox host template; startup protection cannot be installed safely.'
    }
    $command = 'cmd.exe /d /c "copy /y C:\\AzureData\\CustomData.bin SovereignStartup.ps1 >nul && powershell.exe -NoProfile -ExecutionPolicy Bypass -File SovereignStartup.ps1 -Install && ' +
        $matches[0].Groups[2].Value + '"'
    $text = $text.Replace($matches[0].Value, $matches[0].Groups[1].Value + "commandToExecute: '$command'")
    if ($NewVm) {
        if ([regex]::Matches($text, 'osProfile: \{').Count -ne 1) { throw 'Cannot uniquely locate the upstream VM osProfile.' }
        $source = (Get-Content -LiteralPath $StartupSource -Raw -ErrorAction Stop).Replace('__LOCALBOX_BOOTSTRAP_ID__', $Id.ToString())
        if ([Text.Encoding]::UTF8.GetByteCount($source) -gt 65535) { throw 'LocalBox startup protection exceeds the VM custom-data limit.' }
        $destination = Join-Path (Split-Path -Parent $HostTemplate) 'localbox-startup.ps1'
        Set-Content -LiteralPath $destination -Value $source -Encoding utf8NoBOM -NoNewline -ErrorAction Stop
        $text = $text.Replace('osProfile: {', "osProfile: {`n      customData: base64(loadTextContent('localbox-startup.ps1'))")
    }
    Set-Content -LiteralPath $HostTemplate -Value $text -Encoding utf8 -ErrorAction Stop
}

function Install-LocalBoxStartupGuard {
    param([string]$Path = '.\Bootstrap.ps1')
    $text = Get-Content -LiteralPath $Path -Raw -ErrorAction Stop
    $action = '$Action = New-ScheduledTaskAction -Execute $ScheduledTaskExecutable -Argument $LocalBoxPath\LocalBoxLogonScript.ps1'
    if ([regex]::Matches($text, [regex]::Escape($action)).Count -ne 1) {
        throw 'Unsupported upstream Bootstrap task action; refusing to start an unguarded deployment.'
    }
    $replacement = @'
$guardRoot = Join-Path $LocalBoxPath 'SovereignStartup'
New-Item -ItemType Directory -Path $guardRoot -Force -ErrorAction Stop | Out-Null
Set-Acl -LiteralPath $guardRoot -AclObject (Get-Acl -LiteralPath 'C:\AzureData' -ErrorAction Stop) -ErrorAction Stop
Copy-Item -LiteralPath 'C:\AzureData\CustomData.bin' -Destination "$guardRoot\startup.ps1" -Force -ErrorAction Stop
$Action = New-ScheduledTaskAction -Execute $ScheduledTaskExecutable -Argument "$guardRoot\startup.ps1"
'@
    Set-Content -LiteralPath $Path -Value $text.Replace($action, $replacement) -Encoding utf8 -ErrorAction Stop
}

function Save-LocalBoxStartupStatus {
    param([hashtable]$Status, [string]$Path)
    $Status.UpdatedAt = [datetime]::UtcNow.ToString('o')
    $temporary = "$Path.$PID.tmp"
    try {
        $Status | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $temporary -Encoding utf8 -ErrorAction Stop
        Move-Item -LiteralPath $temporary -Destination $Path -Force -ErrorAction Stop
    }
    finally {
        if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary -Force -ErrorAction Stop }
    }
}

function Set-LocalBoxBaseImageGuard {
    param([string]$Path, [string]$PlanPath, [string]$Id)
    $text = Get-Content -LiteralPath $Path -Raw -ErrorAction Stop
    $start = '# Download LocalBox VHDs'
    $end = '# Set credentials'
    if ([regex]::Matches($text, [regex]::Escape($start)).Count -ne 1 -or
        [regex]::Matches($text, [regex]::Escape($end)).Count -ne 1 -or $text.IndexOf($end) -le $text.IndexOf($start)) {
        throw 'Unsupported upstream base-image download block; no cluster startup was attempted.'
    }
    $block = $text.Substring($text.IndexOf($start), $text.IndexOf($end) - $text.IndexOf($start))
    $pattern = '(?m)^[ \t]*azcopy cp (?:''(?<url>https://[^'']+)''|"(?<url>https://[^"]+)"|(?<url>https://\S+)) "\$\(\$LocalBoxConfig\.Paths\.VHDDir\)\\(?<name>[^"]+)"[^\r\n]*'
    $artifacts = @{}
    foreach ($match in [regex]::Matches($block, $pattern)) {
        $name = $match.Groups['name'].Value
        $uri = [uri]$match.Groups['url'].Value
        if ($name -notin @('AzL-node.vhdx', 'AzL-node.sha256', 'GUI.vhdx', 'GUI.sha256') -or $artifacts.ContainsKey($name) -or
            $uri.Host -notin @('azlocalvhds.blob.core.windows.net', 'jumpstartprodsg.blob.core.windows.net') -or
            $uri.Query -or $uri.Fragment -or $uri.UserInfo) {
            throw 'Unrecognized or duplicate upstream base-image source; organizer review is required.'
        }
        $artifacts[$name] = $uri.AbsoluteUri
    }
    if ($artifacts.Count -ne 4) { throw 'Expected exactly four upstream VHD/checksum sources; refusing a partial download plan.' }
    @{ BootstrapId = $Id; Artifacts = $artifacts } | ConvertTo-Json |
        Set-Content -LiteralPath $PlanPath -Encoding utf8 -ErrorAction Stop
    $replacement = @'
# Sovereign guarded base-image downloads
& "$Env:LocalBoxDir\SovereignStartup\startup.ps1" -DownloadImages
if (-not $?) { throw 'Base-image staging failed; nested deployment was not started.' }

'@
    Set-Content -LiteralPath $Path -Value $text.Replace($block, $replacement) -Encoding utf8 -ErrorAction Stop
}

function Test-LocalBoxBaseImage {
    param([string]$Image, [string]$Checksum)
    if (-not (Test-Path -LiteralPath $Image -PathType Leaf) -or -not (Test-Path -LiteralPath $Checksum -PathType Leaf)) { return $false }
    if ((Get-Item -LiteralPath $Checksum -ErrorAction Stop).Length -gt 256) { return $false }
    $expected = ([string](Get-Content -LiteralPath $Checksum -Raw -ErrorAction Stop)).Trim()
    if ($expected -notmatch '^[a-fA-F0-9]{64}$' -or (Get-Item -LiteralPath $Image -ErrorAction Stop).Length -le 0) { return $false }
    return (Get-FileHash -LiteralPath $Image -Algorithm SHA256 -ErrorAction Stop).Hash -eq $expected
}

function Invoke-LocalBoxBaseImageTransfer {
    param([string]$Uri, [string]$Destination, [string]$LogDirectory, [int]$TimeoutSeconds)
    $client = Get-Command azcopy -CommandType Application -ErrorAction Stop
    $stdout = Join-Path $LogDirectory 'stdout.log'
    $stderr = Join-Path $LogDirectory 'stderr.log'
    $oldLogs = $env:AZCOPY_LOG_LOCATION
    $oldPlans = $env:AZCOPY_JOB_PLAN_LOCATION
    $process = $null
    try {
        $env:AZCOPY_LOG_LOCATION = $LogDirectory
        $env:AZCOPY_JOB_PLAN_LOCATION = $LogDirectory
        $process = Start-Process -FilePath $client.Path -ArgumentList @('copy', "`"$Uri`"", "`"$Destination`"",
            '--recursive=true', '--check-length=false', '--log-level=ERROR') -PassThru -NoNewWindow `
            -RedirectStandardOutput $stdout -RedirectStandardError $stderr -ErrorAction Stop
        if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
            throw "AzCopy transfer timed out after $TimeoutSeconds seconds."
        }
        $process.WaitForExit()
        if ($process.ExitCode -ne 0) {
            $http = @(
                foreach ($file in Get-ChildItem -LiteralPath $LogDirectory -Filter '*.log' -File) {
                    foreach ($line in Get-Content -LiteralPath $file.FullName -Tail 80) {
                        if ($line -match '(?:RESPONSE(?: Status:)?|StatusCode[:=])\s*(4\d\d|5\d\d)') { $Matches[1] }
                    }
                }
            ) | Select-Object -Unique
            $detail = if ($http) { " HTTP $($http -join ', ')." } else { '' }
            throw "AzCopy failed with exit code $($process.ExitCode).$detail Verify source availability and access; no authentication bypass is attempted."
        }
        if (-not (Test-Path -LiteralPath $Destination -PathType Leaf)) { throw 'AzCopy reported success without creating the requested file.' }
    }
    finally {
        try {
            if ($process) {
                try {
                    if (-not $process.HasExited) {
                        $process.Kill($true)
                        if (-not $process.WaitForExit(10000)) { throw 'The timed-out AzCopy process did not stop.' }
                    }
                }
                finally { $process.Dispose() }
            }
        }
        finally {
            $env:AZCOPY_LOG_LOCATION = $oldLogs
            $env:AZCOPY_JOB_PLAN_LOCATION = $oldPlans
        }
    }
}

function Sync-LocalBoxBaseImages {
    param(
        [hashtable]$Artifacts, [string]$Directory, [hashtable]$Status, [string]$StatusPath,
        [ValidateRange(1, 3)][int]$Attempts = 3, [ValidateRange(0, 120)][int]$RetryDelaySeconds = 60,
        [ValidateRange(1, 7200)][int]$TimeoutSeconds = 7200
    )
    $ErrorActionPreference = 'Stop'
    $expectedNames = @('AzL-node.vhdx', 'AzL-node.sha256', 'GUI.vhdx', 'GUI.sha256')
    if ($Artifacts.Count -ne 4) { throw 'Invalid base-image download plan: exactly four artifacts are required.' }
    foreach ($name in $expectedNames) {
        $uri = $null
        if (-not [uri]::TryCreate([string]$Artifacts[$name], [UriKind]::Absolute, [ref]$uri) -or
            $uri.Scheme -ne 'https' -or $uri.Host -notin @('azlocalvhds.blob.core.windows.net', 'jumpstartprodsg.blob.core.windows.net') -or
            $uri.Query -or $uri.Fragment -or $uri.UserInfo -or -not $uri.IsDefaultPort) {
            throw 'Invalid base-image download plan: an artifact source is not recognized.'
        }
    }
    $deadline = [datetime]::UtcNow.AddSeconds($TimeoutSeconds)
    $Status.Phase = 'BaseImages'
    Save-LocalBoxStartupStatus $Status $StatusPath
    New-Item -ItemType Directory -Path $Directory -Force -ErrorAction Stop | Out-Null
    foreach ($name in @('AzL-node', 'GUI')) {
        $image = Join-Path $Directory "$name.vhdx"
        $checksum = Join-Path $Directory "$name.sha256"
        if (Test-LocalBoxBaseImage $image $checksum) {
            Write-Host "Reusing SHA256-verified base image $name."
            continue
        }
        for ($attempt = 1; $attempt -le $Attempts; $attempt++) {
            $temporary = Join-Path $Directory ".download-$name-$([guid]::NewGuid())"
            New-Item -ItemType Directory -Path $temporary -ErrorAction Stop | Out-Null
            try {
                $Status.Message = "Downloading base image $name; attempt $attempt/$Attempts."
                Save-LocalBoxStartupStatus $Status $StatusPath
                Write-Host $Status.Message
                foreach ($extension in @('sha256', 'vhdx')) {
                    $remaining = [int][math]::Floor(($deadline - [datetime]::UtcNow).TotalSeconds)
                    if ($remaining -le 0) { throw 'The two-hour base-image download budget is exhausted.' }
                    if (-not $Artifacts["$name.$extension"]) { throw "Missing source for $name.$extension." }
                    Invoke-LocalBoxBaseImageTransfer -Uri $Artifacts["$name.$extension"] -Destination "$temporary/$name.$extension" `
                        -LogDirectory $temporary -TimeoutSeconds ([math]::Min(1800, $remaining))
                }
                if (-not (Test-LocalBoxBaseImage "$temporary/$name.vhdx" "$temporary/$name.sha256")) {
                    throw "The downloaded $name image or SHA256 file is missing, empty, malformed or does not match."
                }
                if ([datetime]::UtcNow -ge $deadline) { throw 'The base-image verification exceeded its download budget.' }
                Move-Item -LiteralPath "$temporary/$name.vhdx" -Destination $image -Force -ErrorAction Stop
                Move-Item -LiteralPath "$temporary/$name.sha256" -Destination $checksum -Force -ErrorAction Stop
                break
            }
            catch {
                $message = "Base image $name failed on attempt $attempt/$Attempts. $($_.Exception.Message)"
                Write-Warning $message
                if ($attempt -eq $Attempts -or [datetime]::UtcNow.AddSeconds($RetryDelaySeconds) -ge $deadline) {
                    $Status.State = 'Failed'
                    $Status.Code = 'BaseImageDownloadFailed'
                    $Status.Message = $message
                    Save-LocalBoxStartupStatus $Status $StatusPath
                    throw $message
                }
                Start-Sleep -Seconds $RetryDelaySeconds
            }
            finally {
                Remove-Item -LiteralPath $temporary -Recurse -Force -ErrorAction Stop
            }
        }
    }
    $Status.Phase = 'NestedDeployment'
    $Status.Message = 'Both base images have verified SHA256 checksums; upstream cluster construction may proceed.'
    Save-LocalBoxStartupStatus $Status $StatusPath
}

function Invoke-LocalBoxGuardedStartup {
    param([string]$Id, [string]$Root = 'C:\LocalBox')
    $ErrorActionPreference = 'Stop'
    $statusPath = Join-Path $Root 'SovereignStartup/state.json'
    $lock = [Threading.Mutex]::new($false, 'Global\MicroHackLocalBoxStartup')
    $locked = $false
    $status = $null
    try {
        $locked = $lock.WaitOne(0)
        if (-not $locked) { throw 'Another LocalBox startup is active; storage initialization will not be repeated.' }
        if (Test-Path -LiteralPath $statusPath) {
            $previous = Get-Content -LiteralPath $statusPath -Raw | ConvertFrom-Json -AsHashtable -ErrorAction Stop
            if ($previous.BootstrapId -eq $Id -and $previous.State -eq 'Succeeded') {
                Write-Host 'This LocalBox startup already completed; not repeating initialization.'
                return
            }
            throw 'An earlier LocalBox startup is incomplete or failed. Automatic replay of storage initialization is disabled; organizer review is required.'
        }
        New-Item -ItemType Directory -Path (Split-Path -Parent $statusPath) -Force | Out-Null
        $status = @{
            BootstrapId = $Id; SubscriptionId = $env:subscriptionId; ResourceGroupName = $env:resourceGroup
            State = 'Running'; Phase = 'Startup'; Code = ''; Message = 'Upstream LocalBox startup is beginning.'
            StartedAt = [datetime]::UtcNow.ToString('o')
        }
        Save-LocalBoxStartupStatus $status $statusPath
        Set-LocalBoxBaseImageGuard -Path "$Root/New-LocalBoxCluster.ps1" -PlanPath "$Root/SovereignStartup/images.json" -Id $Id
        & "$Root/LocalBoxLogonScript.ps1"
        if (-not $?) { throw 'Upstream LocalBox startup returned unsuccessfully.' }
        $status = Get-Content -LiteralPath $statusPath -Raw | ConvertFrom-Json -AsHashtable -ErrorAction Stop
        if ($status.State -eq 'Failed') { throw 'Upstream startup returned after a reported base-image failure.' }
        $status.State = 'Succeeded'
        $status.Phase = 'Complete'
        $status.Message = 'Upstream startup returned; Azure deployment and Full health gates are still required.'
        Save-LocalBoxStartupStatus $status $statusPath
    }
    catch {
        $failure = $_
        if ($status) {
            try {
                $latest = Get-Content -LiteralPath $statusPath -Raw | ConvertFrom-Json -AsHashtable -ErrorAction Stop
                if ($latest.State -ne 'Failed') {
                    $latest.State = 'Failed'
                    $latest.Code = 'StartupFailed'
                    $latest.Message = 'Upstream LocalBox startup failed. Inspect LocalBoxLogonScript.log and New-LocalBoxCluster.log; do not blindly rerun storage initialization.'
                    Save-LocalBoxStartupStatus $latest $statusPath
                }
            }
            catch { Write-Warning 'Could not persist the startup failure report. The original failure is preserved; inspect local startup logs.' }
        }
        throw $failure
    }
    finally {
        if ($locked) { $lock.ReleaseMutex() }
        $lock.Dispose()
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    $ErrorActionPreference = 'Stop'
    if ($Install) {
        Install-LocalBoxStartupGuard
    }
    else {
        if ($PSVersionTable.PSVersion.Major -lt 7) { throw 'Guarded LocalBox startup requires PowerShell 7.' }
        if ($BootstrapId -notmatch '^[a-fA-F0-9-]{36}$') { throw 'Missing deployment-specific LocalBox startup identity.' }
        if ($DownloadImages) {
            $statusPath = 'C:\LocalBox\SovereignStartup\state.json'
            $status = Get-Content -LiteralPath $statusPath -Raw | ConvertFrom-Json -AsHashtable -ErrorAction Stop
            $plan = Get-Content 'C:\LocalBox\SovereignStartup\images.json' -Raw | ConvertFrom-Json -AsHashtable -ErrorAction Stop
            if ($status.BootstrapId -ne $BootstrapId -or $plan.BootstrapId -ne $BootstrapId) { throw 'Base-image download metadata does not match this startup.' }
            $config = Import-PowerShellDataFile -LiteralPath $env:LocalBoxConfigFile
            Sync-LocalBoxBaseImages -Artifacts $plan.Artifacts -Directory $config.Paths.VHDDir -Status $status -StatusPath $statusPath
        }
        else { Invoke-LocalBoxGuardedStartup -Id $BootstrapId }
    }
}
