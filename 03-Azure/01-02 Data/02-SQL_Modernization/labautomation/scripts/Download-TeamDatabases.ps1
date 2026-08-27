<#
.SYNOPSIS
Downloads four SQL Server backup files.

.DESCRIPTION
For each team, the script restores:

    TEAMxx_LocalMasterDataDB
    TEAMxx_SharedMasterDataDB
    TEAMxx_TenantDataDB
    TEAMxx_GlobalDataDB

The physical database files are relocated to the SQL Server instance's
default data and log directories. Every restored database receives unique
physical file names, including backups containing multiple data or log files.

The script is designed for the local default SQL Server instance.

.REQUIREMENTS
- Windows PowerShell 5.1 or PowerShell 7
- SqlServer PowerShell module
- Local SQL Server default instance
- Permission to create and restore databases
- SQL Server service account must be able to read the download directory

.EXAMPLE
.\Restore-TeamDatabases.ps1 `
    -TeamCount 4 `
    -BackupBaseUri "https://raw.githubusercontent.com/organisation/repository/main/backups"

.EXAMPLE
.\Restore-TeamDatabases.ps1 `
    -TeamCount 4 `
    -BackupBaseUri "https://storageaccount.blob.core.windows.net/backups?<SAS-token>"

.NOTES
When the base URI contains a query string, such as a SAS token, the script
inserts the backup file name before the query string.
#>

[CmdletBinding()]
param
(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $BackupBaseUri,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string] $DownloadDirectory = "C:\SQLBackups\TeamDatabases",

    [Parameter(Mandatory = $false)]
    [switch] $ForceDownload
)

$ErrorActionPreference = 'Stop'

$logPath = 'C:\Windows\Temp\Dwonload-TeamDatabases.log'
Start-Transcript -Path $logPath -Append

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Windows PowerShell 5.1 can otherwise negotiate an older TLS version.
[Net.ServicePointManager]::SecurityProtocol =
    [Net.ServicePointManager]::SecurityProtocol -bor
    [Net.SecurityProtocolType]::Tls12

$backupNames = @(
    "LocalMasterDataDB",
    "SharedMasterDataDB",
    "TenantDataDB",
    "GlobalDataDB"
)

function Get-BackupDownloadUri
{
    param
    (
        [Parameter(Mandatory = $true)]
        [string] $BaseUri,

        [Parameter(Mandatory = $true)]
        [string] $FileName
    )

    # Handles normal URLs:
    # https://server/backups + Database.bak
    #
    # Also handles URLs containing a query string:
    # https://server/container?sv=... becomes
    # https://server/container/Database.bak?sv=...

    $questionMarkPosition = $BaseUri.IndexOf("?")

    if ($questionMarkPosition -ge 0)
    {
        $uriPath  = $BaseUri.Substring(0, $questionMarkPosition).TrimEnd("/")
        $uriQuery = $BaseUri.Substring($questionMarkPosition)

        return "$uriPath/$FileName$uriQuery"
    }

    return "$($BaseUri.TrimEnd('/'))/$FileName"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

if (-not (Test-Path -LiteralPath $DownloadDirectory))
{
    New-Item `
        -ItemType Directory `
        -Path $DownloadDirectory `
        -Force |
        Out-Null
}

$downloadedBackups = @{}

foreach ($backupName in $backupNames)
{
    $fileName       = "$backupName.bak"
    $destination    = Join-Path $DownloadDirectory $fileName
    $downloadUri    = Get-BackupDownloadUri `
        -BaseUri $BackupBaseUri `
        -FileName $fileName

    if ((Test-Path -LiteralPath $destination) -and
        -not $ForceDownload.IsPresent)
    {
        Write-Host "Using existing backup: $destination"
    }
    else
    {
        Write-Host "Downloading [$fileName] from $downloadUri ..."

        $temporaryFile = "$destination.download"

        Remove-Item `
            -LiteralPath $temporaryFile `
            -Force `
            -ErrorAction SilentlyContinue

        try
        {
            $invokeWebRequestParameters = @{
                Uri         = $downloadUri
                OutFile     = $temporaryFile
                ErrorAction = "Stop"
            }

            # UseBasicParsing exists in Windows PowerShell 5.1 but not in
            # newer editions in the same form.
            if ($PSVersionTable.PSEdition -eq "Desktop")
            {
                $invokeWebRequestParameters.UseBasicParsing = $true
            }

            $lastProgressPreference = $ProgressPreference
            $ProgressPreference = 'SilentlyContinue'
            Invoke-WebRequest @invokeWebRequestParameters
            $ProgressPreference = $lastProgressPreference

            if (-not (Test-Path -LiteralPath $temporaryFile))
            {
                throw "The downloaded file was not created."
            }

            if ((Get-Item -LiteralPath $temporaryFile).Length -eq 0)
            {
                throw "The downloaded file is empty."
            }

            Move-Item `
                -LiteralPath $temporaryFile `
                -Destination $destination `
                -Force
        }
        catch
        {
            Remove-Item `
                -LiteralPath $temporaryFile `
                -Force `
                -ErrorAction SilentlyContinue

            throw "Download of [$fileName] failed: $($_.Exception.Message)"
        }

        Write-Host "Downloaded [$fileName] to [$destination]." `
            -ForegroundColor Green
    }

    $downloadedBackups[$backupName] = $destination
}

Stop-Transcript