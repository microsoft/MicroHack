param([Parameter(Mandatory)][string]$ConfigurationBase64)

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
    # Redirects are rejected, not followed to unreviewed download hosts.
    for ($attempt = 0; $attempt -lt 3; $attempt++) {
        try {
            Invoke-WebRequest -Uri $uri -OutFile $Destination -UseBasicParsing -MaximumRedirection 0 -TimeoutSec 300 -ErrorAction Stop | Out-Null
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
    foreach ($item in Get-ChildItem -LiteralPath $Source -Recurse -Force) {
        if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint -or
            $item.FullName -match '(?i)[\\/](coach|solutions?|walkthrough)([\\/]|$)') { throw 'Coach content or reparse point in student staging tree.' }
    }
    Copy-Item -LiteralPath $Source -Destination $Destination -Recurse -Force -ErrorAction Stop
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

function Get-LabSourceArchiveAllowlist {
    param($Config)
    return @(
        $Config.source.banking, $Config.source.insurance, $Config.source.briefs, $Config.source.manifest,
        $Config.source.dictionary, $Config.source.generator, $Config.source.generatorCli,
        $Config.hosts.cliSkills, $Config.hosts.cliMcp, $Config.hosts.vscodeSkills, $Config.hosts.vscodeMcp
    ) | ForEach-Object { (Join-Path $Config.source.root $_).Replace('/', '\') }
}

function Copy-LabStudentSource {
    param([string]$SourceRoot, [string]$StudentRoot, $Source)
    New-Item -ItemType Directory -Path "$StudentRoot\datasets" -Force | Out-Null
    foreach ($scenario in 'banking', 'insurance') {
        Copy-StudentTree (Get-SafeSourcePath $SourceRoot $Source.$scenario) "$StudentRoot\datasets\$scenario"
    }
    foreach ($file in @(
        @{ path = $Source.manifest; name = 'manifest.json' },
        @{ path = $Source.dictionary; name = 'dictionary.md' },
        @{ path = $Source.generator; name = 'generate_data.py' },
        @{ path = $Source.generatorCli; name = 'generate-data.py' }
    )) {
        Copy-Item -LiteralPath (Get-SafeSourcePath $SourceRoot $file.path) -Destination (Join-Path "$StudentRoot\datasets" $file.name)
    }
    Copy-StudentTree (Get-SafeSourcePath $SourceRoot $Source.briefs) "$StudentRoot\briefs"
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
            if (-not (Test-Path -LiteralPath (Join-Path "$root\tools\$($tool.name)" $tool.executable))) { throw 'Completed bootstrap is missing a tool executable.' }
        }
        return
    }
    # A failed run owns only staging, never student work. A clean successful run is immutable.
    $staging = Join-Path $root 'staging'
    if (Test-Path -LiteralPath "$root\student") { throw 'Unmarked student tree exists; recover privately before bootstrap retry.' }
    New-Item -ItemType Directory -Path $root -Force | Out-Null
    if (Test-Path -LiteralPath $staging) { Remove-Item -LiteralPath $staging -Recurse -Force }
    New-Item -ItemType Directory -Path $staging -Force | Out-Null
    $allowlist = Get-LabSourceArchiveAllowlist $config
    try {
        Get-VerifiedAsset $config.source "$staging\source.zip"
        Expand-VerifiedZip "$staging\source.zip" "$staging\source" -AllowedRelativePaths $allowlist
    } finally {
        if (Test-Path -LiteralPath "$staging\source.zip") { Remove-Item -LiteralPath "$staging\source.zip" -Force }
    }
    $sourceRoot = Get-SafeSourcePath "$staging\source" $config.source.root
    $student = "$staging\student"
    Copy-LabStudentSource -SourceRoot $sourceRoot -StudentRoot $student -Source $config.source
    New-Item -ItemType Directory -Path "$student\.github", "$student\.vscode", "$student\cli-host" -Force | Out-Null
    Copy-StudentTree (Get-SafeSourcePath $sourceRoot $config.hosts.cliSkills) "$student\cli-host\skills"
    Copy-StudentTree (Get-SafeSourcePath $sourceRoot $config.hosts.vscodeSkills) "$student\.github\skills"
    foreach ($hostConfig in @(
        @{ source = $config.hosts.cliMcp; target = "$student\cli-host\mcp-config.json"; rootKey = 'mcpServers' },
        @{ source = $config.hosts.vscodeMcp; target = "$student\.vscode\mcp.json"; rootKey = 'servers' }
    )) {
        $hostPath = Get-SafeSourcePath $sourceRoot $hostConfig.source
        $hostJson = Get-Content -LiteralPath $hostPath -Raw | ConvertFrom-Json
        if ($hostConfig.rootKey -notin $hostJson.PSObject.Properties.Name) { throw 'Host-specific MCP configuration missing its expected root.' }
        if ((Get-Content -LiteralPath $hostPath -Raw) -match '(?i)(bearer\s|gh[pousr]_|eyJ[a-zA-Z0-9_-]{12}|client_secret|access_token)') {
            throw 'Potential embedded credential in host configuration.'
        }
        Copy-Item -LiteralPath $hostPath -Destination $hostConfig.target
    }
    Assert-CsvManifest $student
    New-Item -ItemType Directory -Path "$root\tools" -Force | Out-Null
    $pathEntries = @()
    foreach ($tool in $config.tools) {
        if ($tool.name -notin @('git', 'node', 'vscode', 'copilot', 'azure-cli', 'python') -or $tool.format -ne 'zip') { throw 'Unsupported tool package.' }
        $zip = "$staging\$($tool.name).zip"
        Get-VerifiedAsset $tool $zip
        $destination = "$staging\tool-$($tool.name)"
        Expand-VerifiedZip $zip $destination
        $executable = Get-SafeSourcePath $destination $tool.executable
        $versionOutput = & $executable --version 2>&1 | Out-String
        if ($LASTEXITCODE -ne 0 -or $versionOutput -notmatch [regex]::Escape($tool.version)) {
            throw 'Pinned tool failed its approved version check.'
        }
        # Portable packages are approved/tested as a unit (including all dependencies).
        if (Test-Path -LiteralPath "$root\tools\$($tool.name)") { Remove-Item -LiteralPath "$root\tools\$($tool.name)" -Recurse -Force }
        Move-Item -LiteralPath $destination -Destination "$root\tools\$($tool.name)"
        $pathEntries += Split-Path -Parent (Join-Path "$root\tools\$($tool.name)" $tool.executable)
    }
    $machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $segments = @($pathEntries) + @($machinePath.Split(';') | Where-Object { $_ -and $_ -notlike "$root\tools\*" })
    [Environment]::SetEnvironmentVariable('Path', ($segments -join ';'), 'Machine')
    # Prepare each interactive user's profile on first logon, not the extension's SYSTEM profile.
    $profileSetup = @'
$ErrorActionPreference = 'Stop'
$target = Join-Path $env:USERPROFILE '.copilot'
if (-not (Test-Path -LiteralPath (Join-Path $target 'microhack-configured'))) {
    if ((Test-Path -LiteralPath (Join-Path $target 'skills')) -or (Test-Path -LiteralPath (Join-Path $target 'mcp-config.json'))) {
        throw 'Existing Copilot configuration: merge manually; MicroHack will not overwrite it.'
    }
    New-Item -ItemType Directory -Path $target -Force | Out-Null
    Copy-Item -LiteralPath 'C:\MicroHack\student\cli-host\skills' -Destination (Join-Path $target 'skills') -Recurse
    Copy-Item -LiteralPath 'C:\MicroHack\student\cli-host\mcp-config.json' -Destination (Join-Path $target 'mcp-config.json')
    New-Item -ItemType File -Path (Join-Path $target 'microhack-configured') | Out-Null
}
'@
    Set-Content -LiteralPath "$root\initialize-user.ps1" -Value $profileSetup -Encoding UTF8
    New-Item -Path 'HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\MicroHackAgenticPBI' -Force | Out-Null
    Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\MicroHackAgenticPBI' -Name 'StubPath' `
        -Value 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\MicroHack\initialize-user.ps1'
    Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\MicroHackAgenticPBI' -Name 'Version' -Value '1,0,0,0'
    Move-Item -LiteralPath $student -Destination "$root\student"
    Set-Content -LiteralPath $marker -Value $fingerprint -Encoding ASCII
    Remove-Item -LiteralPath $staging -Recurse -Force
}

# Dot-sourcing permits offline helper tests without modifying the host.
if ($MyInvocation.InvocationName -ne '.') {
    try { Invoke-LabBootstrap $ConfigurationBase64 }
    catch { throw 'MicroHack bootstrap failed. Inspect the VM privately; no provider/configuration body is emitted.' }
}
