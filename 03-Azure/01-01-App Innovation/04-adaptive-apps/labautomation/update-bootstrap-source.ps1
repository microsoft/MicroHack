<#
.SYNOPSIS
Pin published workshop sources, or check that local sources still match the pin.
#>
param(
    [string]$Commit,
    [switch]$Check,
    [string]$SourceRoot = (Split-Path $PSScriptRoot -Parent)
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'console-helpers.ps1')
$manifestPath = Join-Path $PSScriptRoot 'bootstrap-source.json'
Assert-AdaptivePackage -LabRoot $SourceRoot

if ($Check) {
    $manifest = Read-AdaptiveSourceManifest -Path $manifestPath
    foreach ($path in Get-AdaptiveBootstrapFiles) {
        $hash = (Get-FileHash -LiteralPath (Join-Path $SourceRoot $path) -Algorithm SHA256).Hash
        if ($hash -ne $manifest.files[$path]) {
            throw "Bootstrap source pin is stale for '$path'. Publish the source changes, then run update-bootstrap-source.ps1 -Commit <published-commit-sha>."
        }
    }
    Write-Host 'Local bootstrap sources match the pinned manifest.'
    return
}
if ($Commit -cnotmatch '^[0-9a-f]{40}$') {
    throw 'Specify -Commit with a full, lowercase commit SHA published in microsoft/MicroHack, or use -Check.'
}

$scratch = Join-Path ([IO.Path]::GetTempPath()) "adaptive-source-pin-$([guid]::NewGuid().ToString('N'))"
try {
    $files = [ordered]@{}
    foreach ($path in Get-AdaptiveBootstrapFiles) {
        $download = Join-Path $scratch $path
        Save-AdaptiveSourceFile -Commit $Commit -RelativePath $path -Destination $download
        $hash = (Get-FileHash -LiteralPath $download -Algorithm SHA256).Hash
        $localHash = (Get-FileHash -LiteralPath (Join-Path $SourceRoot $path) -Algorithm SHA256).Hash
        if ($hash -ne $localHash) {
            throw "Published commit '$Commit' does not match local '$path'. The existing source pin was not changed."
        }
        $files[$path] = $hash.ToLowerInvariant()
    }
    [ordered]@{ commit = $Commit; files = $files } | ConvertTo-Json -Depth 3 |
        Set-Content -LiteralPath $manifestPath -Encoding utf8NoBOM
    Write-Host "Pinned $($files.Count) verified source files to microsoft/MicroHack commit $Commit."
} finally {
    if (Test-Path -LiteralPath $scratch) { Remove-Item -LiteralPath $scratch -Recurse -Force }
}
