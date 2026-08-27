[CmdletBinding()]
param
(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $LabsBaseUri,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string] $DownloadDirectory = "C:\MicroHack\Labs",

    [Parameter(Mandatory = $false)]
    [switch] $ForceDownload
)

$ErrorActionPreference = 'Stop'

$logPath = 'C:\Windows\Temp\Download-Labs.log'
Start-Transcript -Path $logPath -Append

try
{
    #
    # Parse GitHub URL
    #
    $BaseURL = ($LabsBaseUri -split "//")[1]
    Write-Host "Base URL: $BaseURL"

    $company = ($BaseURL -split "/")[1]
    $repo    = ($BaseURL -split "/")[2]
    $branch  = ($BaseURL -split "/")[3]

    $folder = $BaseURL -replace "raw.githubusercontent.com/$company/$repo/$branch/", ""

    Write-Host "Company : $company"
    Write-Host "Repo    : $repo"
    Write-Host "Branch  : $branch"
    Write-Host "Folder  : $folder"
    Write-Host "Target  : $DownloadDirectory"

    #
    # Create target directory if required
    #
    if (-not (Test-Path -LiteralPath $DownloadDirectory))
    {
        New-Item `
            -ItemType Directory `
            -Path $DownloadDirectory `
            -Force | Out-Null
    }

    function Get-GitHubFolderContent
    {
        param (
            [AllowEmptyString()]
            [string] $RepoFolder,

            [Parameter(Mandatory)]
            [string] $LocalFolder
        )

        $apiUrl = "https://api.github.com/repos/$company/$repo/contents/$($RepoFolder)?ref=$branch"

        Write-Host ""
        Write-Host "Reading folder: $RepoFolder"
	Write-Host $apiUrl

        try
        {
            $items = Invoke-RestMethod -Uri $apiUrl
        }
        catch
        {
            Write-Warning "Failed to enumerate folder: $RepoFolder"
            Write-Warning $_.Exception.Message
            return
        }

        foreach ($item in $items)
        {
            switch ($item.type)
            {
                "file"
                {
                    $destination = Join-Path $LocalFolder $item.name

                    Write-Host "Downloading $($item.path)"

                    if ((Test-Path $destination) -and (-not $ForceDownload))
                    {
                        Write-Host "File exists. Skipping."
                        continue
                    }

                    Remove-Item `
                        -LiteralPath $destination `
                        -Force `
                        -ErrorAction SilentlyContinue

                    $oldProgress = $ProgressPreference
                    $ProgressPreference = 'SilentlyContinue'

                    try
                    {
                        Invoke-WebRequest `
                            -Uri $item.download_url `
                            -OutFile $destination
                    }
                    finally
                    {
                        $ProgressPreference = $oldProgress
                    }
                }

                "dir"
                {
                    $subFolder = Join-Path $LocalFolder $item.name

                    if (-not (Test-Path $subFolder))
                    {
                        New-Item `
                            -ItemType Directory `
                            -Path $subFolder `
                            -Force | Out-Null
                    }

                    Get-GitHubFolderContent `
                        -RepoFolder $item.path `
                        -LocalFolder $subFolder
                }

                default
                {
                    Write-Host "Skipping unsupported item type '$($item.type)' : $($item.path)"
                }
            }
        }
    }

    #
    # Start recursive download
    #
    Get-GitHubFolderContent `
        -RepoFolder $folder `
        -LocalFolder $DownloadDirectory
}
finally
{
    Stop-Transcript
}
