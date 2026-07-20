param (
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$SourceRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$SourceRoot = $SourceRoot.Trim().TrimEnd('/')
$sourceUri = $null
if (
    -not [Uri]::TryCreate($SourceRoot, [UriKind]::Absolute, [ref]$sourceUri) -or
    $sourceUri.Scheme -ne [Uri]::UriSchemeHttps
) {
    throw 'SourceRoot must be an absolute HTTPS URL.'
}

$webRoot = 'C:\inetpub\wwwroot'
$assets = @('index.html', 'stylesheet.css', 'GitHub_Logo.png', 'MSLogo.png', 'MSicon.png')
$stagingRoot = Join-Path $env:TEMP "microhack-demopage-$([guid]::NewGuid())"

New-Item -Path $stagingRoot -ItemType Directory -Force | Out-Null

try {
    foreach ($asset in $assets) {
        $destination = Join-Path $stagingRoot $asset
        Invoke-WebRequest -Uri "$SourceRoot/$asset" -OutFile $destination -UseBasicParsing
        if ((Get-Item -LiteralPath $destination).Length -eq 0) {
            throw "Downloaded asset is empty: $asset"
        }
    }

    $indexPath = Join-Path $stagingRoot 'index.html'
    $html = Get-Content -LiteralPath $indexPath -Raw
    $values = [ordered]@{
        '<HOSTNAME>' = [Environment]::MachineName
        '<PLATFORM>' = 'Windows Server 2022'
        '<WEB_SERVER>' = 'IIS'
    }

    foreach ($token in $values.Keys) {
        $html = $html.Replace($token, $values[$token])
    }

    if ($html -match '<(?:HOSTNAME|PLATFORM|WEB_SERVER)>') {
        throw 'One or more template tokens remain in index.html.'
    }

    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($indexPath, $html, $utf8NoBom)

    New-Item -Path $webRoot -ItemType Directory -Force | Out-Null
    Get-ChildItem -LiteralPath $webRoot -Force | Remove-Item -Recurse -Force
    Copy-Item -Path (Join-Path $stagingRoot '*') -Destination $webRoot -Force

    $deployedAssets = @(Get-ChildItem -LiteralPath $webRoot -File | Select-Object -ExpandProperty Name)
    if ($deployedAssets.Count -ne $assets.Count -or (Compare-Object $assets $deployedAssets)) {
        throw 'The IIS web root does not contain exactly the expected static assets.'
    }

    Set-Service -Name W3SVC -StartupType Automatic
    Start-Service -Name W3SVC
    $response = Invoke-WebRequest -Uri 'http://localhost/' -UseBasicParsing -TimeoutSec 15
    if ($response.StatusCode -ne 200) {
        throw "Local IIS validation returned HTTP $($response.StatusCode)."
    }
}
finally {
    Remove-Item -LiteralPath $stagingRoot -Recurse -Force -ErrorAction SilentlyContinue
}
