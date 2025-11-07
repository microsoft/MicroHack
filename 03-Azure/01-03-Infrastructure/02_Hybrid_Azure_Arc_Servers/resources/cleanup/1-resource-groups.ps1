<#
.SYNOPSIS
    Bulk delete resource groups matching a specific pattern across multiple Azure subscriptions.

.DESCRIPTION
    This script identifies and deletes resource groups that match a specified naming pattern
    across all available Azure subscriptions. It's designed for cleanup after MicroHack labs
    where multiple user resource groups need to be removed.

    The script will:
    - Prompt for Azure authentication if not already logged in
    - List all matching resource groups across all subscriptions
    - Ask for confirmation before deletion
    - Delete resource groups in parallel using background jobs

.PARAMETER ResourceGroupPattern
    The wildcard pattern to match resource group names (default: "LabUser*")

.EXAMPLE
    .\1-resource-groups.ps1
    Deletes all resource groups starting with "LabUser" across all subscriptions

.EXAMPLE
    .\1-resource-groups.ps1 -ResourceGroupPattern "MicroHack*"
    Deletes all resource groups starting with "MicroHack" across all subscriptions

.NOTES
    Author: MicroHack Team
    Date: November 2025

    WARNING: This script will permanently delete resource groups and all their contents.
    Make sure you have backups of any important data before running.

.LINK
    https://learn.microsoft.com/powershell/module/az.resources/remove-azresourcegroup
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupPattern = "LabUser*"
)

# Ensure Az.Accounts and Az.Resources modules are available
$requiredModules = @('Az.Accounts', 'Az.Resources')
foreach ($module in $requiredModules) {
    if (-not (Get-Module -ListAvailable -Name $module)) {
        Write-Error "$module module is not installed. Please run: Install-Module -Name $module"
        exit 1
    }
}

# Import required modules
Import-Module Az.Accounts, Az.Resources -ErrorAction Stop

# Check if user is logged in
try {
    $context = Get-AzContext
    if (-not $context) {
        Write-Host "`nNo Azure context found. Please login..." -ForegroundColor Yellow
        Connect-AzAccount
        $context = Get-AzContext
    } else {
        Write-Host "`nUsing Azure account: $($context.Account.Id)" -ForegroundColor Green
    }
} catch {
    Write-Error "Failed to get Azure context. Please run Connect-AzAccount first."
    exit 1
}

Write-Host "`n=== Resource Group Cleanup Utility ===" -ForegroundColor Cyan
Write-Host "Pattern to match: $ResourceGroupPattern" -ForegroundColor Yellow
Write-Host ""

# Get all subscriptions
$subscriptions = Get-AzSubscription

if ($subscriptions.Count -eq 0) {
    Write-Error "No subscriptions found. Please ensure you have access to at least one subscription."
    exit 1
}

Write-Host "Found $($subscriptions.Count) subscription(s)" -ForegroundColor Green

# Collect all matching resource groups across all subscriptions
$allMatchingResourceGroups = @()

foreach ($sub in $subscriptions) {
    Write-Host "`nScanning subscription: $($sub.Name)" -ForegroundColor Cyan
    Set-AzContext -SubscriptionId $sub.Id | Out-Null

    $filteredResourceGroups = Get-AzResourceGroup | Where-Object { $_.ResourceGroupName -like $ResourceGroupPattern }

    if ($filteredResourceGroups.Count -gt 0) {
        Write-Host "  Found $($filteredResourceGroups.Count) matching resource group(s):" -ForegroundColor Yellow
        foreach ($rg in $filteredResourceGroups) {
            Write-Host "    - $($rg.ResourceGroupName)" -ForegroundColor Gray

            # Store resource group with subscription info
            $allMatchingResourceGroups += [PSCustomObject]@{
                ResourceGroupName = $rg.ResourceGroupName
                SubscriptionName  = $sub.Name
                SubscriptionId    = $sub.Id
                Location          = $rg.Location
            }
        }
    } else {
        Write-Host "  No matching resource groups found" -ForegroundColor Gray
    }
}

# Display summary
Write-Host "`n" + ("=" * 80) -ForegroundColor Cyan
Write-Host "SUMMARY" -ForegroundColor Cyan
Write-Host ("=" * 80) -ForegroundColor Cyan
Write-Host "Total resource groups matching pattern '$ResourceGroupPattern': $($allMatchingResourceGroups.Count)" -ForegroundColor Yellow

if ($allMatchingResourceGroups.Count -eq 0) {
    Write-Host "`nNo resource groups found matching the pattern. Exiting." -ForegroundColor Green
    exit 0
}

# Show detailed list
Write-Host "`nResource groups to be deleted:" -ForegroundColor Red
$allMatchingResourceGroups | Format-Table -Property ResourceGroupName, SubscriptionName, Location -AutoSize

# Ask for confirmation
Write-Host "`nWARNING: This will permanently delete all listed resource groups and their contents!" -ForegroundColor Red
Write-Host "This action cannot be undone." -ForegroundColor Red
$confirmation = Read-Host "`nAre you sure you want to proceed? Type 'YES' to confirm"

if ($confirmation -ne 'YES') {
    Write-Host "`nDeletion cancelled. No changes were made." -ForegroundColor Yellow
    exit 0
}

# Proceed with deletion
Write-Host "`nProceeding with deletion..." -ForegroundColor Yellow
$jobs = @()

foreach ($rgInfo in $allMatchingResourceGroups) {
    Write-Host "Submitting deletion job for: $($rgInfo.ResourceGroupName) in subscription: $($rgInfo.SubscriptionName)" -ForegroundColor Cyan

    # Set context to the correct subscription
    Set-AzContext -SubscriptionId $rgInfo.SubscriptionId | Out-Null

    # Start deletion as background job
    $job = Remove-AzResourceGroup -Name $rgInfo.ResourceGroupName -Force -AsJob
    $jobs += [PSCustomObject]@{
        Job               = $job
        ResourceGroupName = $rgInfo.ResourceGroupName
        SubscriptionName  = $rgInfo.SubscriptionName
    }
}

Write-Host "`n$($jobs.Count) deletion job(s) submitted" -ForegroundColor Green
Write-Host "Jobs are running in the background. You can monitor their progress below." -ForegroundColor Gray
Write-Host ""

# Monitor jobs
Write-Host "Monitoring job progress (Ctrl+C to exit monitoring, jobs will continue)..." -ForegroundColor Cyan
Write-Host ""

$completedJobs = 0
$failedJobs = 0

while ($jobs | Where-Object { $_.Job.State -eq 'Running' }) {
    foreach ($jobInfo in $jobs) {
        $job = $jobInfo.Job

        if ($job.State -eq 'Completed' -and $job.Tag -ne 'Reported') {
            $completedJobs++
            Write-Host "[COMPLETED] $($jobInfo.ResourceGroupName) - $($jobInfo.SubscriptionName)" -ForegroundColor Green
            $job.Tag = 'Reported'
        }
        elseif ($job.State -eq 'Failed' -and $job.Tag -ne 'Reported') {
            $failedJobs++
            Write-Host "[FAILED] $($jobInfo.ResourceGroupName) - $($jobInfo.SubscriptionName)" -ForegroundColor Red
            $job.Tag = 'Reported'
        }
    }

    Start-Sleep -Seconds 5
}

# Final status check for any remaining jobs
foreach ($jobInfo in $jobs | Where-Object { $_.Job.Tag -ne 'Reported' }) {
    if ($jobInfo.Job.State -eq 'Completed') {
        $completedJobs++
        Write-Host "[COMPLETED] $($jobInfo.ResourceGroupName) - $($jobInfo.SubscriptionName)" -ForegroundColor Green
    }
    elseif ($jobInfo.Job.State -eq 'Failed') {
        $failedJobs++
        Write-Host "[FAILED] $($jobInfo.ResourceGroupName) - $($jobInfo.SubscriptionName)" -ForegroundColor Red
    }
}

# Display final summary
Write-Host "`n" + ("=" * 80) -ForegroundColor Cyan
Write-Host "DELETION SUMMARY" -ForegroundColor Cyan
Write-Host ("=" * 80) -ForegroundColor Cyan
Write-Host "Total jobs submitted: $($jobs.Count)" -ForegroundColor Gray
Write-Host "Completed successfully: $completedJobs" -ForegroundColor Green
Write-Host "Failed: $failedJobs" -ForegroundColor $(if ($failedJobs -gt 0) { "Red" } else { "Gray" })

if ($failedJobs -gt 0) {
    Write-Host "`nSome deletions failed. You can check job details with:" -ForegroundColor Yellow
    Write-Host "Get-Job | Where-Object { `$_.State -eq 'Failed' } | Receive-Job -Keep" -ForegroundColor Gray
}

Write-Host "`nCleanup complete!" -ForegroundColor Green