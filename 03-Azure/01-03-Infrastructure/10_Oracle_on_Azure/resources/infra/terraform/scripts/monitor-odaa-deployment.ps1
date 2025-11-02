<#
.SYNOPSIS
    Simple script to retrieve ODAA deployment logs from Azure and OCI.

.PARAMETER ResourceGroupName
    Azure resource group containing the database.

.PARAMETER DatabaseName
    Name of the Autonomous Database.

.PARAMETER CompartmentId
    OCI compartment OCID.

.PARAMETER StartTime
    Start time in ISO 8601 format (e.g., "2025-11-02T08:00:00Z").

.PARAMETER EndTime
    End time in ISO 8601 format (e.g., "2025-11-02T10:00:00Z").

.PARAMETER SubscriptionId
    Azure subscription ID. If not provided, uses current subscription.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory=$true)]
    [string]$DatabaseName,

    [Parameter(Mandatory=$true)]
    [string]$CompartmentId,

    [Parameter(Mandatory=$false)]
    [string]$StartTime,

    [Parameter(Mandatory=$false)]
    [string]$EndTime,

    [Parameter(Mandatory=$false)]
    [string]$SubscriptionId
)

# Set default time range if not provided
if (-not $StartTime) {
    $StartTime = (Get-Date).AddHours(-2).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
}
if (-not $EndTime) {
    $EndTime = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
}

# Get current subscription if not provided
if (-not $SubscriptionId) {
    $currentSubJson = az account show --output json
    $currentSub = $currentSubJson | ConvertFrom-Json
    $SubscriptionId = $currentSub.id
}

Write-Host "`n=== ODAA Deployment Monitor ===" -ForegroundColor Cyan
Write-Host "Resource Group: $ResourceGroupName"
Write-Host "Database: $DatabaseName"
Write-Host "Subscription: $SubscriptionId"
Write-Host "Time Range: $StartTime to $EndTime`n"

# Retrieve Azure Activity Log
Write-Host "=== Azure Activity Log ===" -ForegroundColor Yellow
$azureLogsJson = az monitor activity-log list `
    --subscription $SubscriptionId `
    --resource-group $ResourceGroupName `
    --start-time $StartTime `
    --end-time $EndTime `
    --output json

if ($LASTEXITCODE -eq 0) {
    $azureLogs = $azureLogsJson | ConvertFrom-Json | Where-Object { $_.resourceId -like "*$DatabaseName*" } | Sort-Object eventTimestamp
    
    if ($azureLogs.Count -eq 0) {
        Write-Host "No Azure Activity Log entries found for database '$DatabaseName'" -ForegroundColor Yellow
    } else {
        Write-Host "Found $($azureLogs.Count) Azure Activity Log entries:`n" -ForegroundColor Green
        $azureLogs | Format-Table @{Label="Time";Expression={$_.eventTimestamp}}, @{Label="Operation";Expression={$_.operationName.localizedValue}}, @{Label="Status";Expression={$_.status.localizedValue}} -AutoSize
    }
} else {
    Write-Host "Failed to retrieve Azure Activity Log" -ForegroundColor Red
}

# Retrieve OCI Resource Timeline
Write-Host "`n=== OCI Resource Timeline ===" -ForegroundColor Yellow
$ociQuery = "query all resources where compartmentId = '$CompartmentId' && timeCreated >= '$StartTime' && timeCreated <= '$EndTime'"
oci search resource structured-search --query-text $ociQuery --query "data.items[*].{Time:\`"time-created\`",ResourceType:\`"resource-type\`",DisplayName:\`"display-name\`"}" --output table

if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to retrieve OCI resource timeline" -ForegroundColor Red
}

Write-Host "`nDone!" -ForegroundColor Cyan
