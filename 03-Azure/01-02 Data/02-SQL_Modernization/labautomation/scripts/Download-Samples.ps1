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

Stop-Transcript