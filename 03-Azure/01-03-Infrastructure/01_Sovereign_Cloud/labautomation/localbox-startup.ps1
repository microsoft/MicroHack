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
        $diagnosticsPath = Join-Path $PSScriptRoot 'localbox-automation.ps1'
        $parseErrors = $null
        $diagnostics = [Management.Automation.Language.Parser]::ParseFile($diagnosticsPath, [ref]$null, [ref]$parseErrors)
        if ($parseErrors.Count) { throw 'Cannot parse the shared LocalBox diagnostic formatter for startup packaging.' }
        $formatter = $diagnostics.FindAll({
            param($node)
            $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'ConvertTo-LocalBoxDiagnosticText'
        }, $true)
        $sourceAst = [Management.Automation.Language.Parser]::ParseInput($source, [ref]$null, [ref]$parseErrors)
        if ($parseErrors.Count -or $formatter.Count -ne 1 -or -not $sourceAst.ParamBlock) {
            throw 'Cannot embed the shared diagnostic formatter in the startup payload.'
        }
        $source = $source.Insert($sourceAst.ParamBlock.Extent.EndOffset, "`n`n" + $formatter[0].Extent.Text)
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
. "$guardRoot\startup.ps1"
Set-LocalBoxWinGetGuard -Path "$LocalBoxPath\WinGet.ps1"
Set-LocalBoxPackageConfiguration -Path "$LocalBoxPath\DSC\packages.dsc.yml"
Set-LocalBoxBgInfoGuard -Path "$($LocalBoxConfig.Paths.TestsDir)\Invoke-Test.ps1"
$Action = New-ScheduledTaskAction -Execute $ScheduledTaskExecutable -Argument "$guardRoot\startup.ps1"
'@
    Set-Content -LiteralPath $Path -Value $text.Replace($action, $replacement) -Encoding utf8 -ErrorAction Stop
}

function Set-LocalBoxWinGetGuard {
    param([string]$Path)
    $text = Get-Content -LiteralPath $Path -Raw -ErrorAction Stop
    $preference = '$ErrorActionPreference = $env:ErrorActionPreference'
    $repair = 'Repair-WinGetPackageManager -AllUsers -Force -Latest -Verbose'
    $packageCommand = '& $winget configure --file "$($Env:LocalBoxDir)\DSC\packages.dsc.yml" --accept-configuration-agreements --disable-interactivity'
    $hostCommand = '& $winget configure --file "$($Env:LocalBoxDir)\DSC\hyper-v.dsc.yml" --accept-configuration-agreements --disable-interactivity'
    foreach ($line in @($preference, $packageCommand, $hostCommand)) {
        if ([regex]::Matches($text, [regex]::Escape($line)).Count -ne 1) { throw 'Unsupported upstream WinGet script; prerequisite protection was not installed.' }
    }
    if ([regex]::Matches($text, [regex]::Escape($repair)).Count -ne 2) { throw 'Unsupported upstream WinGet repair sequence.' }
    $text = $text.Replace($preference, '$ErrorActionPreference = ''Stop''')
    $first = $text.IndexOf($repair)
    $text = $text.Remove($first, $repair.Length).Insert($first, '. "$Env:LocalBoxDir\SovereignStartup\startup.ps1"' + "`n" + 'Initialize-LocalBoxWinGet')
    $text = $text.Replace($repair, '')
    $text = $text.Replace($packageCommand, 'Invoke-LocalBoxWinGetConfiguration -Path "$Env:LocalBoxDir\DSC\packages.dsc.yml"')
    $text = $text.Replace($hostCommand, 'Invoke-LocalBoxWinGetConfiguration -Path "$Env:LocalBoxDir\DSC\hyper-v.dsc.yml"')
    Set-Content -LiteralPath $Path -Value $text -Encoding utf8 -ErrorAction Stop
}

function Set-LocalBoxPackageConfiguration {
    param([string]$Path)
    $text = (Get-Content -LiteralPath $Path -Raw -ErrorAction Stop).Replace("`r`n", "`n")
    $block = @'
    - resource: Microsoft.WinGet.DSC/WinGetPackage
      id: Microsoft.AzureDataStudio
      directives:
        description: Install Microsoft Azure Data Studio
      settings:
        id: Microsoft.AzureDataStudio
        source: winget
'@
    $pattern = '(?m)^' + [regex]::Escape($block) + '[ \t]*(?:\n|$)'
    $matches = [regex]::Matches($text, $pattern)
    if ($matches.Count -eq 0 -and $text -notmatch 'AzureDataStudio') { return }
    if ($matches.Count -ne 1 -or [regex]::Replace($text, $pattern, '') -match 'AzureDataStudio') {
        throw 'Unrecognized retired Azure Data Studio package configuration; no package entries were changed.'
    }
    Write-Host 'Removing the retired Azure Data Studio package from LocalBox prerequisites; all remaining package results must still succeed.'
    Set-Content -LiteralPath $Path -Value ([regex]::Replace($text, $pattern, '')) -Encoding utf8 -ErrorAction Stop
}

function Initialize-LocalBoxWinGet {
    param([ValidateRange(1, 3)][int]$Attempts = 3)
    $ErrorActionPreference = 'Stop'
    $module = Get-Module -ListAvailable Microsoft.WinGet.Client | Sort-Object Version -Descending | Select-Object -First 1
    if (-not $module) { throw 'Microsoft.WinGet.Client is not installed; package configuration was not started.' }
    $version = $module.Version.ToString()
    Import-Module Microsoft.WinGet.Client -RequiredVersion $version -ErrorAction Stop
    for ($attempt = 1; $attempt -le $Attempts; $attempt++) {
        try {
            Repair-WinGetPackageManager -Version $version -AllUsers -Force -ErrorAction Stop
            $actual = [string](Get-WinGetVersion -ErrorAction Stop)
            if ($actual.TrimStart('v') -ne $version) { throw "WinGet CLI '$actual' does not match installed client module '$version'." }
            $null = @(Get-WinGetPackage -ErrorAction Stop)
            Write-Host "WinGet CLI/client $version compatibility and package enumeration verified."
            return
        }
        catch {
            if ($attempt -eq $Attempts) { throw }
            Write-Warning "WinGet manager repair attempt $attempt/$Attempts failed: $(ConvertTo-LocalBoxDiagnosticText $_.Exception.Message 400). Retrying in 30 seconds."
            Start-Sleep -Seconds 30
        }
    }
}

function Invoke-LocalBoxWinGetConfiguration {
    param([string]$Path, [string]$LogDirectory = 'C:\LocalBox\SovereignStartup',
        [ValidateRange(1, 3)][int]$Attempts = 3, [ValidateRange(1, 900)][int]$AttemptTimeoutSeconds = 900)
    $ErrorActionPreference = 'Stop'
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw 'The WinGet configuration file is missing.' }
    $winget = Join-Path $env:LOCALAPPDATA 'Microsoft/WindowsApps/winget.exe'
    if (-not (Test-Path -LiteralPath $winget -PathType Leaf)) { throw 'WinGet is unavailable in the startup user profile.' }
    for ($attempt = 1; $attempt -le $Attempts; $attempt++) {
        $process = $null
        $log = Join-Path $LogDirectory ("winget-{0}-{1}-{2}" -f [IO.Path]::GetFileNameWithoutExtension($Path), $PID, $attempt)
        try {
            $process = Start-Process -FilePath $winget -ArgumentList @('configure', '--file', "`"$Path`"",
                '--accept-configuration-agreements', '--disable-interactivity') -NoNewWindow -PassThru `
                -RedirectStandardOutput "$log.stdout.log" -RedirectStandardError "$log.stderr.log" -ErrorAction Stop
            if (-not $process.WaitForExit($AttemptTimeoutSeconds * 1000)) { throw "WinGet configuration exceeded its $AttemptTimeoutSeconds-second attempt budget." }
            $process.WaitForExit()
            if ($null -eq $process.ExitCode -or $process.ExitCode -ne 0) {
                throw "WinGet configuration failed with exit code '$($process.ExitCode)'. Inspect the private $log logs."
            }
            return
        }
        catch {
            if ($attempt -eq $Attempts) { throw }
            Write-Warning "WinGet configuration attempt $attempt/$Attempts failed: $(ConvertTo-LocalBoxDiagnosticText $_.Exception.Message 400). Retrying in 30 seconds."
        }
        finally {
            if ($process) {
                try {
                    if (-not $process.HasExited) {
                        $process.Kill($true)
                        if (-not $process.WaitForExit(10000)) { throw 'WinGet process did not stop after its timeout.' }
                    }
                }
                finally { $process.Dispose() }
            }
        }
        Start-Sleep -Seconds 30
    }
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

function Set-LocalBoxBgInfoGuard {
    param([string]$Path)
    $text = Get-Content -LiteralPath $Path -Raw -ErrorAction Stop
    $command = 'bginfo64.exe $Env:LocalBoxTestsDir\localbox-bginfo.bgi /timer:0 /NOLICPROMPT'
    $pattern = '(?m)^' + [regex]::Escape($command) + '\r?$'
    if ([regex]::Matches($text, $pattern).Count -ne 1) {
        throw 'Unsupported upstream BGInfo invocation; test-runner protection was not installed.'
    }
    $replacement = @'
. "$Env:LocalBoxDir\SovereignStartup\startup.ps1"
Invoke-LocalBoxBgInfo -ConfigurationPath "$Env:LocalBoxTestsDir\localbox-bginfo.bgi"
'@
    Set-Content -LiteralPath $Path -Value $text.Replace($command, $replacement) -Encoding utf8 -ErrorAction Stop
}

function Resolve-LocalBoxStartupTool {
    param(
        [ValidateSet('AzCopy', 'BGInfo')][string]$Tool,
        [string]$LocalAppData, [string]$ProgramFiles
    )
    $command = if ($Tool -eq 'AzCopy') { 'azcopy' } else { 'bginfo64.exe' }
    $executable = if ($Tool -eq 'AzCopy') { 'azcopy.exe' } else { 'Bginfo64.exe' }
    $client = @(Get-Command $command -CommandType Application -ErrorAction SilentlyContinue)
    if ($client.Count) { return $client[0].Path }
    $links = @(
        if ($LocalAppData) { Join-Path $LocalAppData "Microsoft/WinGet/Links/$executable" }
        if ($ProgramFiles) {
            Join-Path $ProgramFiles "WinGet/Links/$executable"
            if ($Tool -eq 'AzCopy') { Join-Path $ProgramFiles 'AzCopy/azcopy.exe' }
        }
    )
    foreach ($path in $links) {
        if (Test-Path -LiteralPath $path -PathType Leaf -ErrorAction Stop) { return $path }
    }
    $patterns = @(
        if ($LocalAppData) {
            if ($Tool -eq 'AzCopy') {
                Join-Path $LocalAppData 'Microsoft/WinGet/Packages/Microsoft.Azure.AZCopy.10_*/azcopy_windows_*/azcopy.exe'
            }
            else { Join-Path $LocalAppData 'Microsoft/WinGet/Packages/Microsoft.Sysinternals.BGInfo_*/Bginfo64.exe' }
        }
        if ($Tool -eq 'BGInfo' -and $ProgramFiles) {
            Join-Path $ProgramFiles 'WinGet/Packages/Microsoft.Sysinternals.BGInfo_*/Bginfo64.exe'
        }
    )
    $candidates = @(foreach ($pattern in $patterns) {
        if (Test-Path -Path $pattern -PathType Leaf -ErrorAction Stop) {
            Get-ChildItem -Path $pattern -File -ErrorAction Stop
        }
    })
    if ($candidates.Count -gt 1) { throw "Multiple unlinked $Tool installations exist; repair the WinGet link before retrying." }
    if ($candidates.Count -eq 1) { return $candidates[0].FullName }
    throw "$Tool is unavailable after prerequisite installation. Inspect the WinGet provisioning log and the startup user WinGet installation."
}

function Resolve-LocalBoxAzCopy {
    param([string]$LocalAppData = $env:LOCALAPPDATA, [string]$ProgramFiles = $env:ProgramFiles)
    Resolve-LocalBoxStartupTool -Tool AzCopy -LocalAppData $LocalAppData -ProgramFiles $ProgramFiles
}

function Resolve-LocalBoxBgInfo {
    param([string]$LocalAppData = $env:LOCALAPPDATA, [string]$ProgramFiles = $env:ProgramFiles)
    Resolve-LocalBoxStartupTool -Tool BGInfo -LocalAppData $LocalAppData -ProgramFiles $ProgramFiles
}

function Invoke-LocalBoxBgInfo {
    param([string]$ConfigurationPath, [ValidateRange(1, 120)][int]$TimeoutSeconds = 60)
    $ErrorActionPreference = 'Stop'
    if (-not (Test-Path -LiteralPath $ConfigurationPath -PathType Leaf)) {
        throw 'The LocalBox BGInfo configuration is missing.'
    }
    $client = Resolve-LocalBoxBgInfo
    $log = Join-Path ([IO.Path]::GetTempPath()) "localbox-bginfo-$([guid]::NewGuid()).log"
    $process = $null
    try {
        # GUI applications can leave LASTEXITCODE unchanged; inspect the actual process.
        $process = Start-Process -FilePath $client -ArgumentList @("`"$ConfigurationPath`"",
            '/timer:0', '/NOLICPROMPT', '/silent', "/log:`"$log`"") -PassThru -ErrorAction Stop
        if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
            throw "BGInfo exceeded its $TimeoutSeconds-second budget. Inspect $log if present."
        }
        $process.WaitForExit()
        if ($null -eq $process.ExitCode -or $process.ExitCode -ne 0) {
            throw "BGInfo failed with exit code '$($process.ExitCode)'. Inspect $log if present."
        }
        if (Test-Path -LiteralPath $log -PathType Leaf) {
            $message = ([string](Get-Content -LiteralPath $log -Raw -ErrorAction Stop)).Trim()
            if ($message) {
                throw "BGInfo reported an error: $(ConvertTo-LocalBoxDiagnosticText $message 400). Inspect $log."
            }
            Remove-Item -LiteralPath $log -ErrorAction Stop
        }
    }
    finally {
        if ($process) {
            try {
                if (-not $process.HasExited) {
                    $process.Kill()
                    if (-not $process.WaitForExit(10000)) { throw 'BGInfo process did not stop after its timeout.' }
                }
            }
            finally { $process.Dispose() }
        }
    }
}

function Wait-LocalBoxStartupPrerequisites {
    param([hashtable]$Status, [string]$StatusPath, [ValidateRange(1, 3600)][int]$TimeoutSeconds = 3600)
    $ErrorActionPreference = 'Stop'
    $deadline = (Get-Date).ToUniversalTime().AddSeconds($TimeoutSeconds)
    $Status.Phase = 'Prerequisites'
    $Status.Message = 'Waiting for WinGetLogonScript to finish before initializing storage or downloading images.'
    Save-LocalBoxStartupStatus $Status $StatusPath
    Write-Host $Status.Message
    do {
        $tasks = @(Get-ScheduledTask -ErrorAction Stop | Where-Object { $_.TaskName -eq 'WinGetLogonScript' -and $_.TaskPath -eq '\' })
        if ($tasks.Count -gt 1) { throw 'Ambiguous WinGet prerequisite task state.' }
        if (-not $tasks.Count) { break }
        if ($tasks[0].State -eq 'Disabled') { throw 'WinGetLogonScript is disabled; prerequisite installation cannot be verified.' }
        if ($tasks[0].State -eq 'Ready') {
            $info = $tasks[0] | Get-ScheduledTaskInfo -ErrorAction Stop
            if ($info.LastRunTime -gt [datetime]'2000-01-01' -and $info.LastTaskResult -ne 0) {
                throw "WinGetLogonScript stopped with task result $($info.LastTaskResult). Inspect its provisioning and private WinGet logs; storage initialization was not started."
            }
        }
        if ((Get-Date).ToUniversalTime() -ge $deadline) {
            throw 'WinGetLogonScript did not complete within the one-hour prerequisite budget. Inspect its provisioning log; storage initialization was not started.'
        }
        Start-Sleep -Seconds 15
    } while ($true)
    $env:PATH = (@($env:PATH, [Environment]::GetEnvironmentVariable('PATH', 'Machine'),
        [Environment]::GetEnvironmentVariable('PATH', 'User')) | Where-Object { $_ } | Select-Object -Unique) -join [IO.Path]::PathSeparator
    $null = Resolve-LocalBoxAzCopy
    $null = Resolve-LocalBoxBgInfo
    $Status.Phase = 'Startup'
    $Status.Message = 'WinGet prerequisites completed; AzCopy and BGInfo resolved. Upstream initialization may proceed.'
    Save-LocalBoxStartupStatus $Status $StatusPath
}

function Invoke-LocalBoxBaseImageTransfer {
    param([string]$Uri, [string]$Destination, [string]$LogDirectory, [int]$TimeoutSeconds)
    $client = Resolve-LocalBoxAzCopy
    $stdout = Join-Path $LogDirectory 'stdout.log'
    $stderr = Join-Path $LogDirectory 'stderr.log'
    $oldLogs = $env:AZCOPY_LOG_LOCATION
    $oldPlans = $env:AZCOPY_JOB_PLAN_LOCATION
    $process = $null
    try {
        $env:AZCOPY_LOG_LOCATION = $LogDirectory
        $env:AZCOPY_JOB_PLAN_LOCATION = $LogDirectory
        $process = Start-Process -FilePath $client -ArgumentList @('copy', "`"$Uri`"", "`"$Destination`"",
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

function Invoke-LocalBoxUpstreamStartup {
    param([string]$Path)
    # Modules resolve preferences through global scope, not the calling function.
    $ErrorActionPreference = 'Continue'
    $previousGlobalPreference = $global:ErrorActionPreference
    try {
        $global:ErrorActionPreference = 'Continue'
        & $Path
        if (-not $?) { throw 'Upstream LocalBox startup returned unsuccessfully.' }
    }
    finally { $global:ErrorActionPreference = $previousGlobalPreference }
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
        Wait-LocalBoxStartupPrerequisites -Status $status -StatusPath $statusPath
        Set-LocalBoxBaseImageGuard -Path "$Root/New-LocalBoxCluster.ps1" -PlanPath "$Root/SovereignStartup/images.json" -Id $Id
        Invoke-LocalBoxUpstreamStartup -Path "$Root/LocalBoxLogonScript.ps1"
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
                    if ($latest.Phase -eq 'Prerequisites') {
                        $latest.Code = 'StartupPrerequisitesFailed'
                        $latest.Message = 'WinGet prerequisite readiness or AzCopy/BGInfo discovery failed before storage initialization. Inspect WinGet-provisioning logs and WinGetLogonScript task state.'
                    }
                    else {
                        $latest.Code = 'StartupFailed'
                        $latest.Message = 'Upstream LocalBox startup failed. Inspect LocalBoxLogonScript.log and New-LocalBoxCluster.log; do not blindly rerun storage initialization.'
                    }
                    $latest.Message = "$(ConvertTo-LocalBoxDiagnosticText $failure.Exception.Message 600) $($latest.Message)"
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
