param([Parameter(Mandatory)][string]$ConfigurationBase64, [string]$RunId = '')

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Add-Type -AssemblyName System.IO.Compression.FileSystem

function Get-VerifiedAsset {
    param($Asset, [string]$Destination)
    $uri = [uri]$Asset.uri
    if ($uri.Scheme -ne 'https' -or $uri.Query -or $uri.UserInfo -or $uri.Fragment -or $Asset.sha256 -notmatch '^[a-fA-F0-9]{64}$') {
        throw 'Invalid checksum-pinned public asset.'
    }
    # Official release/Marketplace downloads redirect to their CDNs; bytes remain hash-pinned.
    for ($attempt = 0; $attempt -lt 3; $attempt++) {
        try {
            Invoke-WebRequest -Uri $uri -OutFile $Destination -UseBasicParsing -MaximumRedirection 5 -TimeoutSec 300 -ErrorAction Stop | Out-Null
            break
        } catch {
            if ($attempt -eq 2) { throw 'Asset download failed after three bounded attempts.' }
            Start-Sleep -Seconds (2 * ($attempt + 1))
        }
    }
    if ((Get-FileHash -LiteralPath $Destination -Algorithm SHA256).Hash -ne $Asset.sha256) { throw 'Asset checksum mismatch.' }
}

function Expand-VerifiedZip {
    param([string]$Archive, [string]$Destination, [string[]]$AllowedRelativePaths = @())
    $zip = [IO.Compression.ZipFile]::OpenRead($Archive)
    try {
        $total = 0L
        $seen = @{}
        if ($zip.Entries.Count -gt 30000) { throw 'Archive entry limit exceeded.' }
        foreach ($entry in $zip.Entries) {
            $name = $entry.FullName.Replace('/', '\')
            if ($name -match '(^[\\]|:|(^|\\)\.\.?(\\|$))' -or
                $name -match '(?i)(^|\\)(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(\.|\\|$)' -or
                $name.TrimEnd('\') -match '[. ](\\|$)' -or
                (($entry.ExternalAttributes -shr 16) -band 0xF000) -eq 0xA000) { throw 'Unsafe ZIP path or symbolic link.' }
            $key = $name.TrimEnd('\').ToLowerInvariant()
            if ($seen.ContainsKey($key)) { throw 'Duplicate archive entry.' }
            $seen[$key] = $true
            $total += $entry.Length
            if ($total -gt 3GB) { throw 'Archive expanded-size limit exceeded.' }
        }
        foreach ($entry in $zip.Entries) {
            $name = $entry.FullName.Replace('/', '\')
            $selected = $AllowedRelativePaths.Count -eq 0
            foreach ($allowed in $AllowedRelativePaths) {
                if ($name -eq $allowed -or $name.StartsWith($allowed.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) { $selected = $true }
            }
            if (-not $selected) { continue }
            if ($AllowedRelativePaths.Count -gt 0 -and $name -match '(?i)(^|\\)(coach|solutions?|walkthrough)(\\|$)') {
                throw 'Selected archive path contains coach content.'
            }
            $target = [IO.Path]::GetFullPath((Join-Path $Destination $name))
            if (-not $target.StartsWith([IO.Path]::GetFullPath($Destination).TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Archive path escaped destination.' }
            if ($name.EndsWith('\')) { [IO.Directory]::CreateDirectory($target) | Out-Null }
            else {
                [IO.Directory]::CreateDirectory((Split-Path -Parent $target)) | Out-Null
                [IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $target, $false)
            }
        }
    } finally { $zip.Dispose() }
}

function Get-SafeSourcePath {
    param([string]$Root, [string]$Relative)
    if (-not $Relative -or $Relative -match '(^[\\/]|:|(^|[\\/])\.\.?([\\/]|$))' -or
        $Relative -match '(?i)(^|[\\/])(coach|solutions?|walkthrough)([\\/]|$)') { throw 'Unsafe student source path.' }
    $full = [IO.Path]::GetFullPath((Join-Path $Root $Relative))
    if (-not $full.StartsWith([IO.Path]::GetFullPath($Root).TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Source path escaped archive root.' }
    if (-not (Test-Path -LiteralPath $full)) { throw 'Required student source missing from pinned archive.' }
    return $full
}

function Copy-StudentTree {
    param([string]$Source, [string]$Destination)
    if (-not (Test-Path -LiteralPath $Source -PathType Container)) { throw 'Required student source directory is missing.' }
    foreach ($item in Get-ChildItem -LiteralPath $Source -Recurse -Force) {
        if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint -or
            $item.FullName -match '(?i)[\\/](coach|solutions?|walkthrough)([\\/]|$)') { throw 'Coach content or reparse point in student staging tree.' }
    }
    New-Item -ItemType Directory -Path $Destination -Force | Out-Null
    Get-ChildItem -LiteralPath $Source -Force |
        Copy-Item -Destination $Destination -Recurse -Force -ErrorAction Stop
}

function Assert-CsvManifest {
    param([string]$StudentRoot)
    $manifest = Get-Content -LiteralPath (Join-Path $StudentRoot 'datasets\manifest.json') -Raw | ConvertFrom-Json
    foreach ($scenario in 'banking', 'insurance') {
        $tables = $manifest.scenarios.$scenario.tables.PSObject.Properties
        if (@($tables).Count -lt 1) { throw 'Scenario manifest has no tables.' }
        foreach ($table in $tables) {
            $entry = $table.Value
            if ($entry.file.Replace('\', '/') -notlike "$scenario/*.csv") { throw 'Manifest references an unexpected scenario path.' }
            $path = Get-SafeSourcePath (Join-Path $StudentRoot 'datasets') $entry.file
            if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ne $entry.sha256 -or
                (Get-Item -LiteralPath $path).Length -ne $entry.bytes) { throw 'Staged CSV manifest checksum/size mismatch.' }
        }
    }
}

function Copy-LabStudentFiles {
    param($Source, [string]$StudentRoot)
    if ($Source.ref -notmatch '^[a-f0-9]{40}$') { throw 'Student source requires an immutable commit.' }
    foreach ($file in $Source.files) {
        $relative = $file.target.Replace('/', '\')
        $path = $file.path.Replace('/', '\')
        if ($relative -notmatch '^(datasets|briefs)\\' -or
            $path -notmatch '^(datasets|resources)\\' -or
            "$relative\$path" -match '(^|\\)\.\.?($|\\)|:|(?i)(^|\\)(coach|solutions?|walkthrough)(\\|$)') { throw 'Unsafe student target or source.' }
        $target = [IO.Path]::GetFullPath((Join-Path $StudentRoot $relative))
        [IO.Directory]::CreateDirectory((Split-Path -Parent $target)) | Out-Null
        $segments = $file.path.Replace('\', '/') -split '/' | ForEach-Object { [uri]::EscapeDataString($_) }
        $uri = "https://raw.githubusercontent.com/microsoft/MicroHack/$($Source.ref)/03-Azure/01-02%20Data/04-Agentic_PBIReport_Development/" + ($segments -join '/')
        Get-VerifiedAsset @{uri=$uri; sha256=$file.sha256} $target
    }
}

function Invoke-LabBootstrap {
    param([string]$EncodedConfiguration)
    $config = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($EncodedConfiguration)) | ConvertFrom-Json
    $root = 'C:\MicroHack'
    $marker = Join-Path $root 'bootstrap-complete.sha256'
    $hasher = [Security.Cryptography.SHA256]::Create()
    try { $fingerprint = ([BitConverter]::ToString($hasher.ComputeHash([Text.Encoding]::UTF8.GetBytes($EncodedConfiguration)))).Replace('-', '').ToLowerInvariant() }
    finally { $hasher.Dispose() }
    if (Test-Path -LiteralPath $marker) {
        if ((Get-Content -LiteralPath $marker -Raw).Trim() -ne $fingerprint) { throw 'Bootstrap configuration changed; preserve participant work and rebuild an approved empty VM.' }
        Assert-CsvManifest (Join-Path $root 'student')
        foreach ($tool in $config.tools) {
            if (-not (Test-Path -LiteralPath (Get-LabToolPath $tool))) { throw 'Completed bootstrap is missing a tool executable.' }
        }
        if (-not (Test-Path -LiteralPath "$root\tools\report\node_modules\.bin\powerbi-report-author.cmd")) { throw 'Completed bootstrap is missing report authoring.' }
        return
    }
    # A failed run owns only staging, never student work. A clean successful run is immutable.
    $staging = Join-Path $root 'staging'
    if (Test-Path -LiteralPath "$root\student") { throw 'Unmarked student tree exists; recover privately before bootstrap retry.' }
    New-Item -ItemType Directory -Path $root -Force | Out-Null
    if (Test-Path -LiteralPath $staging) { Remove-Item -LiteralPath $staging -Recurse -Force }
    New-Item -ItemType Directory -Path $staging -Force | Out-Null
    $student = "$staging\student"
    Copy-LabStudentFiles $config.source $student
    Assert-CsvManifest $student
    @'
# Your Agentic Power BI exercise VM

Connect through Azure Bastion; this VM has no public IP. Run
`C:\MicroHack\initialize-user.ps1` after first login if setup did not run.
It prepares your own CLI skills and VS Code extensions. Sign in interactively,
open this student folder and verify the host and model with your coach.
Use `python datasets\generate-data.py --validate` before Challenge 1.
Business/design briefs are under `briefs`; the dictionary is under `datasets`.
The pinned Fabric skills are spark-cli, semantic-model-authoring and powerbi-report-cli.
These hosts use CLI/REST authoring; a modeling MCP is optional, not preconfigured.

Follow the published lessons and the organizer's retention instructions.
Only the organizer removes shared resources after every participant is finished.
In addition to F16, shared Bastion, NAT and public IPs incur charges until removed;
deleting participant VMs or pausing F16 does not remove these shared resources.
'@ | Set-Content -LiteralPath "$student\README.md" -Encoding UTF8
    $skillsZip = "$staging\skills.zip"
    Get-VerifiedAsset $config.skills $skillsZip
    $skillPaths = @("$($config.skills.root)\common") + @($config.skills.names | ForEach-Object { "$($config.skills.root)\skills\$_" })
    Expand-VerifiedZip $skillsZip "$staging\skills" -AllowedRelativePaths $skillPaths
    $skillRoot = Get-SafeSourcePath "$staging\skills" $config.skills.root
    New-Item -ItemType Directory -Path "$student\.github\skills", "$student\.vscode", "$root\host\skills", "$root\host\extensions" -Force | Out-Null
    foreach ($name in $config.skills.names) {
        Copy-StudentTree "$skillRoot\skills\$name" "$student\.github\skills\$name"
        Copy-StudentTree "$skillRoot\skills\$name" "$root\host\skills\$name"
    }
    Copy-StudentTree "$skillRoot\common" "$student\.github\common"
    if (-not (Test-Path -LiteralPath "$root\host\common")) { Copy-StudentTree "$skillRoot\common" "$root\host\common" }
    @{'chat.useAgentSkills'=$true; 'extensions.autoUpdate'=$false; 'update.mode'='none'} |
        ConvertTo-Json | Set-Content -LiteralPath "$student\.vscode\settings.json" -Encoding UTF8
    foreach ($extension in $config.extensions) {
        Get-VerifiedAsset $extension "$root\host\extensions\$($extension.id).vsix"
    }
    $config.extensions | ConvertTo-Json | Set-Content -LiteralPath "$root\host\extensions.json" -Encoding UTF8
    New-Item -ItemType Directory -Path "$root\tools" -Force | Out-Null
    $pathEntries = @()
    foreach ($tool in $config.tools) {
        $download = "$staging\$($tool.name).$($tool.format)"
        Get-VerifiedAsset $tool $download
        if ($tool.format -eq 'zip') {
            $destination = "$staging\tool-$($tool.name)"
            Expand-VerifiedZip $download $destination
            if (Test-Path -LiteralPath "$root\tools\$($tool.name)") { Remove-Item -LiteralPath "$root\tools\$($tool.name)" -Recurse -Force }
            Move-Item -LiteralPath $destination -Destination "$root\tools\$($tool.name)"
        } elseif ($tool.format -eq 'msi' -and $tool.name -eq 'azure-cli') {
            $process = Start-Process -FilePath 'msiexec.exe' -ArgumentList @('/i', "`"$download`"", '/qn', '/norestart') -Wait -PassThru
            if ($process.ExitCode -notin 0, 3010) { throw 'Azure CLI MSI installation failed.' }
        } elseif ($tool.format -eq 'python' -and $tool.name -eq 'python') {
            $installer = "$staging\python.exe"
            Move-Item -LiteralPath $download -Destination $installer -Force
            $process = Start-Process -FilePath $installer -ArgumentList @('/quiet','InstallAllUsers=1','PrependPath=0','Include_test=0',"TargetDir=$root\tools\python") -Wait -PassThru
            if ($process.ExitCode -notin 0, 3010) { throw 'Python installation failed.' }
        } else { throw 'Unsupported tool package.' }
        $executable = Get-LabToolPath $tool
        $versionOutput = & $executable --version 2>&1 | Out-String
        if ($LASTEXITCODE -ne 0 -or $versionOutput -notmatch [regex]::Escape($tool.version)) {
            throw "Pinned tool failed its exact version check: $($tool.name)"
        }
        $pathEntries += Split-Path -Parent $executable
    }
    $reportRoot = "$root\tools\report"
    New-Item -ItemType Directory -Path $reportRoot -Force | Out-Null
    [IO.File]::WriteAllText("$reportRoot\package.json", $config.npm.package, [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText("$reportRoot\package-lock.json", $config.npm.lock, [Text.UTF8Encoding]::new($false))
    $env:Path = ($pathEntries -join ';') + ';' + $env:Path
    $node = Get-LabToolPath ($config.tools | Where-Object name -EQ 'node')
    $npm = Join-Path (Split-Path -Parent $node) 'npm.cmd'
    & $npm ci --prefix $reportRoot --ignore-scripts --no-audit --no-fund --registry=https://registry.npmjs.org | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Locked report runtime installation failed.' }
    & "$reportRoot\node_modules\.bin\powerbi-report-author.cmd" --version | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Report authoring CLI startup failed.' }
    $pathEntries += "$reportRoot\node_modules\.bin"
    $machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $segments = @($pathEntries) + @($machinePath.Split(';') | Where-Object { $_ -and $_ -notlike "$root\tools\*" })
    [Environment]::SetEnvironmentVariable('Path', ($segments -join ';'), 'Machine')
    # Prepare each interactive user's profile, not Run Command's SYSTEM profile.
    $profileSetup = @'
$ErrorActionPreference = 'Stop'
$target = Join-Path $env:USERPROFILE '.copilot'
if (-not (Test-Path -LiteralPath (Join-Path $target 'microhack-configured'))) {
    $initializing = Join-Path $target 'microhack-initializing'
    if (-not (Test-Path -LiteralPath $initializing) -and
        ((Test-Path -LiteralPath (Join-Path $target 'skills')) -or (Test-Path -LiteralPath (Join-Path $target 'common')))) {
        throw 'Existing Copilot configuration: merge manually; MicroHack will not overwrite it.'
    }
    New-Item -ItemType Directory -Path $target -Force | Out-Null
    New-Item -ItemType File -Path $initializing -Force | Out-Null
    foreach ($folder in 'skills','common') {
        New-Item -ItemType Directory -Path (Join-Path $target $folder) -Force | Out-Null
        Get-ChildItem -LiteralPath "C:\MicroHack\host\$folder" -Force | Copy-Item -Destination (Join-Path $target $folder) -Recurse -Force
    }
    $code = 'C:\MicroHack\tools\vscode\bin\code.cmd'
    foreach ($extension in @(Get-Content 'C:\MicroHack\host\extensions.json' -Raw | ConvertFrom-Json)) {
        & $code --install-extension "C:\MicroHack\host\extensions\$($extension.id).vsix" --force | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "VS Code extension installation failed: $($extension.id)" }
    }
    $installed = & $code --list-extensions --show-versions
    if ($LASTEXITCODE -ne 0) { throw 'Could not verify VS Code extensions.' }
    foreach ($extension in @(Get-Content 'C:\MicroHack\host\extensions.json' -Raw | ConvertFrom-Json)) {
        if ("$($extension.id)@$($extension.version)" -notin $installed) { throw 'Pinned VS Code extension missing.' }
    }
    New-Item -ItemType File -Path (Join-Path $target 'microhack-configured') | Out-Null
    Remove-Item -LiteralPath $initializing -Force
}
'@
    Set-Content -LiteralPath "$root\initialize-user.ps1" -Value $profileSetup -Encoding UTF8
    New-Item -Path 'HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\MicroHackAgenticPBI' -Force | Out-Null
    Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\MicroHackAgenticPBI' -Name 'StubPath' `
        -Value 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\MicroHack\initialize-user.ps1'
    Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\MicroHackAgenticPBI' -Name 'Version' -Value '2,0,0,0'
    Move-Item -LiteralPath $student -Destination "$root\student"
    Set-Content -LiteralPath $marker -Value $fingerprint -Encoding ASCII
    Remove-Item -LiteralPath $staging -Recurse -Force
}

function Get-LabToolPath {
    param($Tool)
    if ($Tool.format -eq 'zip') { return Join-Path "C:\MicroHack\tools\$($Tool.name)" $Tool.executable }
    return $Tool.executable
}

# Dot-sourcing permits offline helper tests without modifying the host.
if ($MyInvocation.InvocationName -ne '.') {
    try { Invoke-LabBootstrap $ConfigurationBase64 }
    catch {
        [IO.Directory]::CreateDirectory('C:\MicroHack') | Out-Null
        [IO.File]::WriteAllText('C:\MicroHack\bootstrap-error.txt',
            [DateTimeOffset]::UtcNow.ToString('o') + "`r`n" + $_.Exception.Message)
        throw 'MicroHack bootstrap failed. Inspect C:\MicroHack\bootstrap-error.txt privately on the VM; no configuration body is emitted.'
    }
}
