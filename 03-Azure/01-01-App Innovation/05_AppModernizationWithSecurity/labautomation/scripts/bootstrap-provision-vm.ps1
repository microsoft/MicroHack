<#
.SYNOPSIS
Splits the VM custom-data bundle and launches the facilitator provisioner.

.DESCRIPTION
Custom data carries a base64 secret payload and the provisioner script, separated by marker
lines. This writes both to disk and then runs the provisioner from that file.

This script is inlined as plain text into the Custom Script Extension command. It must not
decompress and then evaluate a script it assembled in memory: Microsoft Defender classifies
base64 + GZipStream + ScriptBlock::Create inside powershell.exe -EncodedCommand as
Behavior:Win32/PShellCobStager.A, terminates the process, and the extension still reports
success. Keep this file small enough to inline, and keep every launch file-based.
#>

function Invoke-ProvisioningBootstrap {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('dotnet', 'java')]
        [string]$Stack,

        [Parameter(Mandatory)]
        [ValidatePattern('^[0-9a-f]{40}$')]
        [string]$SourceCommit,

        [Parameter(Mandatory)]
        [ValidatePattern('^[0-9a-f]{64}$')]
        [string]$SourceArchiveSha256
    )

    $DataPath = 'C:\AzureData\CustomData.bin'
    $ScriptPath = 'C:\AzureData\provision-vm.ps1'
    $PayloadPath = 'C:\MicroHack\secrets\provisioning.json'
    $Header = "MICROHACK_CUSTOM_DATA_V2`n"
    $Marker = "`nMICROHACK_PROVISIONER_START`n"

    New-Item -ItemType Directory -Path (Split-Path $PayloadPath) -Force | Out-Null

    $Bundle = [IO.File]::ReadAllText($DataPath)
    if (-not $Bundle.StartsWith($Header, [StringComparison]::Ordinal)) {
        throw 'VM custom data does not contain the expected bundle header.'
    }
    $Index = $Bundle.IndexOf($Marker, $Header.Length, [StringComparison]::Ordinal)
    if ($Index -lt 0) {
        throw 'VM custom data does not contain the provisioner boundary.'
    }

    $Payload = $Bundle.Substring($Header.Length, $Index - $Header.Length)
    $Body = $Bundle.Substring($Index + $Marker.Length)
    if ($Payload.Length -eq 0 -or [string]::IsNullOrWhiteSpace($Body)) {
        throw 'VM custom data contains an empty payload or provisioner.'
    }

    [IO.File]::WriteAllBytes($PayloadPath, [Convert]::FromBase64String($Payload))
    [IO.File]::WriteAllText($ScriptPath, $Body, (New-Object Text.UTF8Encoding($false)))

    & powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass `
        -File $ScriptPath `
        -Stack $Stack `
        -SourceCommit $SourceCommit `
        -SourceArchiveUrl "https://github.com/CZSK-MicroHacks/MicroHack-AppInnovation/archive/$SourceCommit.zip" `
        -SourceArchiveSha256 $SourceArchiveSha256
    if ($LASTEXITCODE -ne 0) {
        throw "The facilitator provisioner exited with code $LASTEXITCODE."
    }
}
