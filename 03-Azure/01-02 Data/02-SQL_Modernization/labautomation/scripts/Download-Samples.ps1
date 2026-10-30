[CmdletBinding()]
param
(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $SamplesBaseUri,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string] $DownloadDirectory = "C:\Samples",

    [Parameter(Mandatory = $false)]
    [switch] $ForceDownload
)

$ErrorActionPreference = 'Stop'

$logPath = 'C:\Windows\Temp\Download-Samples.log'
Start-Transcript -Path $logPath -Append

<# OLD LOGIC (disabled): listed the folder via the GitHub REST API (60 requests/hour per IP without auth)
$BaseURL = ($SamplesBaseUri -split "//")[1]

$company = ($BaseURL -split "/")[1]
$repo = ($BaseURL -split "/")[2]
$branch = ($BaseURL -split "/")[3]
#$folder = ($BaseURL -split "/")[4]
$folder = $BaseURL -replace "raw.githubusercontent.com/$company/$repo/$branch/", ""

if (-not (Test-Path -LiteralPath $DownloadDirectory))
{
    New-Item `
        -ItemType Directory `
        -Path $DownloadDirectory `
        -Force |
        Out-Null
}

$apiUrl = "https://api.github.com/repos/$company/$repo/contents/$($folder)?ref=$branch"

$items = Invoke-RestMethod -Uri $apiUrl

foreach ($item in $items) {
    if ($item.type -eq "file") {
        $destination = Join-Path $DownloadDirectory $item.name
        Write-Host "Downloading $($item.path)"
        if ((Test-Path $destination) -and (-not $ForceDownload.IsPresent)) {
            Write-Host "File $($item.name) already exists. Skipping download."
        } else {
            Remove-Item -LiteralPath $destination -ErrorAction SilentlyContinue -Force
            $lastProgressPreference = $ProgressPreference
            $ProgressPreference = 'SilentlyContinue'
            Invoke-WebRequest -Uri $item.download_url -OutFile $destination 
            $ProgressPreference = $lastProgressPreference
        }
    }
}

#>

# NEW LOGIC: downloads the files listed in <SamplesBaseUri>/manifest.txt directly via raw URLs (no GitHub REST API)
[Net.ServicePointManager]::SecurityProtocol =
    [Net.ServicePointManager]::SecurityProtocol -bor
    [Net.SecurityProtocolType]::Tls12

function Invoke-DownloadWithRetry
{
    param
    (
        [Parameter(Mandatory = $true)]
        [string] $Uri,

        [Parameter(Mandatory = $true)]
        [string] $OutFile,

        [int] $MaxAttempts = 5
    )

    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++)
    {
        $lastProgressPreference = $ProgressPreference
        $ProgressPreference = 'SilentlyContinue'

        try
        {
            Invoke-WebRequest -Uri $Uri -OutFile $OutFile -UseBasicParsing -ErrorAction Stop
            return
        }
        catch
        {
            $statusCode = $null
            if ($_.Exception.Response)
            {
                $statusCode = [int] $_.Exception.Response.StatusCode
            }

            # Retry network errors, throttling (429) and server errors (5xx); fail fast on 404 etc.
            $isRetryable = (-not $statusCode) -or ($statusCode -eq 429) -or ($statusCode -ge 500)

            if ((-not $isRetryable) -or ($attempt -eq $MaxAttempts))
            {
                throw
            }

            $delaySeconds = [math]::Min(60, [math]::Pow(2, $attempt) * 2)
            Write-Warning "Download failed (attempt $attempt of $MaxAttempts): $Uri - $($_.Exception.Message). Retrying in $delaySeconds s."
            Start-Sleep -Seconds $delaySeconds
        }
        finally
        {
            $ProgressPreference = $lastProgressPreference
        }
    }
}

try
{
    $baseUri      = $SamplesBaseUri.TrimEnd('/')
    $manifestUri  = "$baseUri/manifest.txt"
    $manifestFile = Join-Path ([System.IO.Path]::GetTempPath()) "samples-manifest-$([guid]::NewGuid()).txt"

    Write-Host "Manifest : $manifestUri"
    Write-Host "Target   : $DownloadDirectory"

    try
    {
        Invoke-DownloadWithRetry -Uri $manifestUri -OutFile $manifestFile

        $entries = @(
            Get-Content -LiteralPath $manifestFile -Encoding UTF8 |
                ForEach-Object { $_.TrimStart([char]0xFEFF).Trim() } |
                Where-Object { $_ -and -not $_.StartsWith('#') }
        )
    }
    finally
    {
        Remove-Item -LiteralPath $manifestFile -Force -ErrorAction SilentlyContinue
    }

    if ($entries.Count -eq 0)
    {
        throw "The manifest '$manifestUri' does not contain any files."
    }

    if (-not (Test-Path -LiteralPath $DownloadDirectory))
    {
        New-Item -ItemType Directory -Path $DownloadDirectory -Force | Out-Null
    }

    $failed = @()

    foreach ($entry in $entries)
    {
        try
        {
            $segments = @(($entry -replace '\\', '/') -split '/' | Where-Object { $_ })

            if ($segments | Where-Object { $_ -eq '..' -or $_ -match '[:*?"<>|]' })
            {
                throw "Invalid manifest entry '$entry'."
            }

            $downloadUri          = "$baseUri/" + (($segments | ForEach-Object { [uri]::EscapeDataString($_) }) -join '/')
            $destination          = Join-Path $DownloadDirectory ($segments -join '\')
            $destinationDirectory = Split-Path -Parent $destination

            if ((Test-Path -LiteralPath $destination) -and (-not $ForceDownload.IsPresent))
            {
                Write-Host "File $entry already exists. Skipping download."
                continue
            }

            if (-not (Test-Path -LiteralPath $destinationDirectory))
            {
                New-Item -ItemType Directory -Path $destinationDirectory -Force | Out-Null
            }

            Write-Host "Downloading $entry"

            $temporaryFile = "$destination.download"

            try
            {
                Invoke-DownloadWithRetry -Uri $downloadUri -OutFile $temporaryFile
                Move-Item -LiteralPath $temporaryFile -Destination $destination -Force
            }
            finally
            {
                Remove-Item -LiteralPath $temporaryFile -Force -ErrorAction SilentlyContinue
            }
        }
        catch
        {
            Write-Warning "Failed to download '$entry': $($_.Exception.Message)"
            $failed += $entry
        }
    }

    if ($failed.Count -gt 0)
    {
        throw "$($failed.Count) file(s) could not be downloaded: $($failed -join ', ')"
    }
}
finally
{
    Stop-Transcript
}