<#
.SYNOPSIS
Aggressively removes Entra ID security groups created for AKS teams (mhteam-*).

.DESCRIPTION
Discovers every Entra security group whose display name starts with "mhteam-".
For each group, the script removes all members and then deletes the group itself.
No input parameters are exposed to avoid accidental customization. Use PowerShell's
built-in -WhatIf / -Confirm flags if a dry run is required.

.NOTES
Requires Azure CLI (az) with delegated Microsoft Graph permissions. Run az login first.
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param()

$ErrorActionPreference = "Stop"

function Invoke-AzCliJson {
    param(
        [Parameter(Mandatory = $true)][string[]]$CommandParts,
        [Parameter()][hashtable]$Arguments
    )

    $argumentsList = @()
    $argumentsList += $CommandParts
    foreach ($key in $Arguments.Keys) {
        $value = $Arguments[$key]
        if ($null -ne $value -and $value -ne "") {
            $argumentsList += $key
            if ($value -isnot [switch]) {
                $argumentsList += $value
            }
        }
    }

    $raw = az @argumentsList 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Azure CLI command failed: $raw"
    }
    if ([string]::IsNullOrWhiteSpace($raw)) {
        return $null
    }
    return $raw | ConvertFrom-Json
}

function Invoke-AzCli {
    param(
        [Parameter(Mandatory = $true)][string[]]$CommandParts,
        [Parameter()][hashtable]$Arguments
    )

    $argumentsList = @()
    $argumentsList += $CommandParts
    foreach ($key in $Arguments.Keys) {
        $value = $Arguments[$key]
        if ($null -ne $value -and $value -ne "") {
            $argumentsList += $key
            if ($value -isnot [switch]) {
                $argumentsList += $value
            }
        }
    }

    az @argumentsList 2>&1 | ForEach-Object { $_ }
    if ($LASTEXITCODE -ne 0) {
        throw "Azure CLI command failed with exit code $LASTEXITCODE"
    }
}

if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    throw "Azure CLI (az) not found on PATH. Install the CLI and run az login before executing this script."
}

$prefix = "mhteam-"
$query = "[?starts_with(displayName, 'mhteam-')]"
$groups = Invoke-AzCliJson -CommandParts @("ad","group","list","--query",$query)
$groups = @($groups) | Where-Object { $_ }

if ($groups.Count -eq 0) {
    Write-Host "No Entra ID groups found with prefix '$prefix'." -ForegroundColor Yellow
    return
}

foreach ($group in $groups) {
    $groupName = $group.displayName
    $groupId = $group.id

    Write-Host "Processing group '$groupName' ($groupId)..."

    try {
        $members = Invoke-AzCliJson -CommandParts @("ad","group","member","list") -Arguments @{ "--group" = $groupId }
        $members = @($members) | Where-Object { $_ }
    }
    catch {
        Write-Warning "Failed to retrieve members for '$groupName': $_"
        $members = @()
    }

    if ($members.Count -gt 0) {
        foreach ($member in $members) {
            $memberId = $member.id
            $memberDisplayName = $member.displayName
            if (-not $memberDisplayName -and $member.userPrincipalName) {
                $memberDisplayName = $member.userPrincipalName
            }
            $memberDescription = if ($memberDisplayName) { $memberDisplayName } else { $memberId }

            if ($PSCmdlet.ShouldProcess("Member $memberDescription", "Remove from $groupName")) {
                try {
                    Invoke-AzCli -CommandParts @("ad","group","member","remove") -Arguments @{ "--group" = $groupId; "--member-id" = $memberId }
                    Write-Verbose "Removed member '$memberDescription' from '$groupName'."
                }
                catch {
                    Write-Warning "Failed to remove member '$memberDescription' from '$groupName': $_"
                }
            }
        }
    }

    if ($PSCmdlet.ShouldProcess($groupName, "Delete Entra ID group")) {
        try {
            Invoke-AzCli -CommandParts @("ad","group","delete") -Arguments @{ "--group" = $groupId }
            Write-Host "Deleted group '$groupName'." -ForegroundColor Green
        }
        catch {
            Write-Warning "Failed to delete group '$groupName': $_"
        }
    }
}
