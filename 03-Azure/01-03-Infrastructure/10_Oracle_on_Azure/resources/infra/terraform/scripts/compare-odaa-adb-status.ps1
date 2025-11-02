<#
.SYNOPSIS
    Compares ODAA Autonomous Databases between Azure and OCI to identify discrepancies.

.DESCRIPTION
    This script retrieves all Oracle Autonomous Databases from Azure subscription sub-mhodaa,
    queries corresponding resources in OCI, and provides a detailed comparison report showing:
    - Databases present in Azure but not in OCI
    - Databases present in OCI but not in Azure
    - Databases with mismatched states or configurations
    - Complete status overview of all databases

.PARAMETER SubscriptionName
    Azure subscription name containing ODAA resources (default: "sub-mhodaa")

.PARAMETER CompartmentId
    OCI compartment OCID to query for Autonomous Databases.
    If not provided, attempts to derive from first Azure database's OCI ID.

.PARAMETER ResourceGroupName
    Azure resource group name containing ODAA databases (default: "odaa-shared")

.PARAMETER OutputFormat
    Output format: Table, JSON, or CSV (default: Table)

.PARAMETER ExportPath
    Optional file path to export results (CSV or JSON based on OutputFormat)

.EXAMPLE
    .\compare-odaa-adb-status.ps1

.EXAMPLE
    .\compare-odaa-adb-status.ps1 -CompartmentId "ocid1.compartment.oc1..aaaaaa..." -OutputFormat JSON

.EXAMPLE
    .\compare-odaa-adb-status.ps1 -ExportPath ".\odaa-comparison-report.csv" -OutputFormat CSV
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$SubscriptionName = "sub-mhodaa",

    [Parameter(Mandatory=$false)]
    [string]$CompartmentId,

    [Parameter(Mandatory=$false)]
    [string]$ResourceGroupName = "odaa-shared",

    [Parameter(Mandatory=$false)]
    [ValidateSet("Table", "JSON", "CSV")]
    [string]$OutputFormat = "Table",

    [Parameter(Mandatory=$false)]
    [string]$ExportPath
)

# Color output helpers
function Write-ColorOutput {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        
        [Parameter(Mandatory=$false)]
        [ConsoleColor]$ForegroundColor = [ConsoleColor]::White
    )
    Write-Host $Message -ForegroundColor $ForegroundColor
}

function Write-Section {
    param([string]$Title)
    Write-Host "`n$('=' * 80)" -ForegroundColor Cyan
    Write-Host $Title -ForegroundColor Cyan
    Write-Host $('=' * 80) -ForegroundColor Cyan
}

# Error handling
$ErrorActionPreference = "Stop"

try {
    Write-Section "ODAA Autonomous Database Comparison Report"
    Write-Host "Subscription: $SubscriptionName"
    Write-Host "Resource Group: $ResourceGroupName"
    Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss UTC')`n"

    # Step 1: Set Azure subscription
    Write-ColorOutput "Setting Azure subscription..." -ForegroundColor Yellow
    $currentSubJson = az account show --output json 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Not logged into Azure. Run 'az login' first."
    }

    $setSubResult = az account set --subscription $SubscriptionName 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to set subscription '$SubscriptionName'. Error: $setSubResult"
    }
    Write-ColorOutput "Success - Subscription set to: $SubscriptionName" -ForegroundColor Green

    # Step 2: Retrieve Azure ODAA databases using REST API
    Write-Section "Step 1: Retrieving Azure ODAA Autonomous Databases"
    
    # Get subscription ID
    $subInfo = az account show --output json | ConvertFrom-Json
    $subscriptionId = $subInfo.id
    
    # Use Azure REST API to list Oracle Autonomous Databases
    $apiVersion = "2023-09-01"
    $resourceGroupUrl = "/subscriptions/$subscriptionId/resourceGroups/$ResourceGroupName/providers/Oracle.Database/autonomousDatabases?api-version=$apiVersion"
    
    $azureDbsJson = az rest --method GET --url $resourceGroupUrl --output json 2>&1

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to retrieve Azure databases. Error: $azureDbsJson"
    }

    $azureResult = $azureDbsJson | ConvertFrom-Json
    $azureDbs = $azureResult.value

    if ($azureDbs.Count -eq 0) {
        Write-ColorOutput "Warning - No ODAA databases found in Azure resource group: $ResourceGroupName" -ForegroundColor Yellow
        exit 0
    }

    Write-ColorOutput "Success - Found $($azureDbs.Count) databases in Azure" -ForegroundColor Green

    # Display Azure databases
    $azureDbs | ForEach-Object {
        [PSCustomObject]@{
            Name = $_.name
            DisplayName = $_.properties.displayName
            State = $_.properties.lifecycleState
            Compute = "$($_.properties.computeCount) eCPU"
            Storage = "$($_.properties.dataStorageSizeInTbs) TB"
            OCID = $_.properties.ocid
        }
    } | Format-Table -AutoSize

    # Step 3: Extract OCI compartment if not provided
    if (-not $CompartmentId -and $azureDbs.Count -gt 0) {
        Write-ColorOutput "`nExtracting OCI compartment ID from Azure database metadata..." -ForegroundColor Yellow
        
        $firstDb = $azureDbs[0]
        if ($firstDb.properties.compartmentId) {
            $CompartmentId = $firstDb.properties.compartmentId
            Write-ColorOutput "Success - Extracted compartment ID: $CompartmentId" -ForegroundColor Green
        } elseif ($firstDb.properties.ocid) {
            $ociId = $firstDb.properties.ocid
            Write-ColorOutput "Database OCI ID found: $ociId" -ForegroundColor Gray
            Write-ColorOutput "Warning - CompartmentId not found in database properties" -ForegroundColor Yellow
        }
    }

    if (-not $CompartmentId) {
        Write-ColorOutput "Warning - No OCI compartment ID provided or found. Provide -CompartmentId parameter." -ForegroundColor Yellow
        Write-ColorOutput "  Example: ocid1.compartment.oc1..aaaaaaaayehuog6myqxudqejx3ddy6bzkr2f3dnjuuygs424taimn4av4wbq" -ForegroundColor Gray
        
        Write-Section "Azure Database Summary (OCI comparison skipped)"
        $summary = @{
            AzureDatabases = $azureDbs.Count
            OCIDatabases = "N/A (no compartment ID)"
            Status = "Partial - Azure only"
        }
        $summary | Format-Table -AutoSize
        exit 0
    }

    # Step 4: Retrieve OCI Autonomous Databases using native filtering
    Write-Section "Step 2: Retrieving OCI Autonomous Databases"
    Write-ColorOutput "Querying OCI compartment: $CompartmentId" -ForegroundColor Yellow

    # Test OCI CLI connectivity
    $ociTestResult = oci iam region list --output json 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "OCI CLI not configured. Run 'oci setup config' first. Error: $ociTestResult"
    }

    # Query OCI for Autonomous Databases using structured search with native --query filtering
    $ociQuery = "query AutonomousDatabase resources where compartmentId = '$CompartmentId'"
    $ociDbsJson = oci search resource structured-search `
        --query-text $ociQuery `
        --query "data.items[*].{DisplayName:\`"display-name\`",OCID:\`"identifier\`",LifecycleState:\`"lifecycle-state\`",TimeCreated:\`"time-created\`",CompartmentId:\`"compartment-id\`"}" `
        --output json 2>&1

    if ($LASTEXITCODE -ne 0) {
        Write-ColorOutput "Warning - Failed to query OCI. Error: $ociDbsJson" -ForegroundColor Red
        $ociDbs = @()
    } else {
        $ociDbs = $ociDbsJson | ConvertFrom-Json
        Write-ColorOutput "Success - Found $($ociDbs.Count) databases in OCI compartment" -ForegroundColor Green
    }

    # Display OCI databases if found
    if ($ociDbs.Count -gt 0) {
        $ociDbs | Format-Table -AutoSize
    }

    # Step 5: Compare databases
    Write-Section "Step 3: Comparison Analysis"

    # Create lookup dictionaries
    $azureDbDict = @{}
    foreach ($db in $azureDbs) {
        $key = $db.properties.displayName.ToLower()
        $azureDbDict[$key] = $db
    }

    $ociDbDict = @{}
    foreach ($db in $ociDbs) {
        $key = $db.DisplayName.ToLower()
        $ociDbDict[$key] = $db
    }

    # Find discrepancies
    $onlyInAzure = @()
    $onlyInOCI = @()
    $inBoth = @()
    $stateMismatches = @()

    # Check Azure databases
    foreach ($azureDb in $azureDbs) {
        $displayName = $azureDb.properties.displayName.ToLower()
        
        if ($ociDbDict.ContainsKey($displayName)) {
            $ociDb = $ociDbDict[$displayName]
            
            $comparison = [PSCustomObject]@{
                DisplayName = $azureDb.properties.displayName
                AzureName = $azureDb.name
                AzureState = $azureDb.properties.lifecycleState
                OCIState = $ociDb.LifecycleState
                OCIID = $ociDb.OCID
                AzureCompute = "$($azureDb.properties.computeCount) eCPU"
                AzureStorage = "$($azureDb.properties.dataStorageSizeInTbs) TB"
                Match = $azureDb.properties.lifecycleState -eq $ociDb.LifecycleState
            }
            
            $inBoth += $comparison
            
            if (-not $comparison.Match) {
                $stateMismatches += $comparison
            }
        } else {
            $onlyInAzure += [PSCustomObject]@{
                DisplayName = $azureDb.properties.displayName
                AzureName = $azureDb.name
                State = $azureDb.properties.lifecycleState
                Compute = "$($azureDb.properties.computeCount) eCPU"
                Storage = "$($azureDb.properties.dataStorageSizeInTbs) TB"
                ResourceId = $azureDb.id
            }
        }
    }

    # Check OCI databases
    foreach ($ociDb in $ociDbs) {
        $displayName = $ociDb.DisplayName.ToLower()
        
        if (-not $azureDbDict.ContainsKey($displayName)) {
            $onlyInOCI += [PSCustomObject]@{
                DisplayName = $ociDb.DisplayName
                OCID = $ociDb.OCID
                State = $ociDb.LifecycleState
                TimeCreated = $ociDb.TimeCreated
            }
        }
    }

    # Display results
    Write-ColorOutput "`nComparison Summary:" -ForegroundColor Cyan
    Write-Host "  Databases in both Azure and OCI: $($inBoth.Count)" -ForegroundColor Green
    Write-Host "  Databases only in Azure: $($onlyInAzure.Count)" -ForegroundColor $(if ($onlyInAzure.Count -gt 0) { "Yellow" } else { "Green" })
    Write-Host "  Databases only in OCI: $($onlyInOCI.Count)" -ForegroundColor $(if ($onlyInOCI.Count -gt 0) { "Yellow" } else { "Green" })
    Write-Host "  State mismatches: $($stateMismatches.Count)" -ForegroundColor $(if ($stateMismatches.Count -gt 0) { "Red" } else { "Green" })

    # Detailed reports
    if ($inBoth.Count -gt 0) {
        Write-Section "Databases in Both Platforms"
        $inBoth | Format-Table DisplayName, AzureState, OCIState, Match, AzureCompute, AzureStorage -AutoSize
    }

    if ($stateMismatches.Count -gt 0) {
        Write-Section "State Mismatches"
        $stateMismatches | Format-Table DisplayName, AzureState, OCIState, OCIID -AutoSize
    }

    if ($onlyInAzure.Count -gt 0) {
        Write-Section "Databases Only in Azure (Missing in OCI)"
        $onlyInAzure | Format-Table DisplayName, AzureName, State, Compute, Storage -AutoSize
    }

    if ($onlyInOCI.Count -gt 0) {
        Write-Section "Databases Only in OCI (Missing in Azure)"
        $onlyInOCI | Format-Table DisplayName, OCID, State, TimeCreated -AutoSize
    }

    # Generate final report object
    $report = [PSCustomObject]@{
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss UTC"
        AzureSubscription = $SubscriptionName
        AzureResourceGroup = $ResourceGroupName
        OCICompartmentId = $CompartmentId
        TotalAzureDatabases = $azureDbs.Count
        TotalOCIDatabases = $ociDbs.Count
        DatabasesInBoth = $inBoth.Count
        OnlyInAzure = $onlyInAzure.Count
        OnlyInOCI = $onlyInOCI.Count
        StateMismatches = $stateMismatches.Count
        Details = @{
            InBoth = $inBoth
            OnlyInAzure = $onlyInAzure
            OnlyInOCI = $onlyInOCI
            Mismatches = $stateMismatches
        }
    }

    # Export results if requested
    if ($ExportPath) {
        Write-Section "Exporting Results"
        
        if ($OutputFormat -eq "JSON") {
            $report | ConvertTo-Json -Depth 10 | Out-File -FilePath $ExportPath -Encoding UTF8
            Write-ColorOutput "Success - Results exported to: $ExportPath (JSON)" -ForegroundColor Green
        }
        elseif ($OutputFormat -eq "CSV") {
            # Flatten for CSV export
            $csvData = @()
            foreach ($db in $inBoth) {
                $csvData += [PSCustomObject]@{
                    DisplayName = $db.DisplayName
                    AzureName = $db.AzureName
                    Location = "Both"
                    AzureState = $db.AzureState
                    OCIState = $db.OCIState
                    Match = $db.Match
                    OCIID = $db.OCIID
                }
            }
            foreach ($db in $onlyInAzure) {
                $csvData += [PSCustomObject]@{
                    DisplayName = $db.DisplayName
                    AzureName = $db.AzureName
                    Location = "Azure Only"
                    AzureState = $db.State
                    OCIState = "N/A"
                    Match = $false
                    OCIID = "N/A"
                }
            }
            foreach ($db in $onlyInOCI) {
                $csvData += [PSCustomObject]@{
                    DisplayName = $db.DisplayName
                    AzureName = "N/A"
                    Location = "OCI Only"
                    AzureState = "N/A"
                    OCIState = $db.State
                    Match = $false
                    OCIID = $db.OCID
                }
            }
            
            $csvData | Export-Csv -Path $ExportPath -NoTypeInformation -Encoding UTF8
            Write-ColorOutput "Success - Results exported to: $ExportPath (CSV)" -ForegroundColor Green
        }
    }

    # Final summary
    Write-Section "Status Summary"
    
    if ($stateMismatches.Count -eq 0 -and $onlyInAzure.Count -eq 0 -and $onlyInOCI.Count -eq 0) {
        Write-ColorOutput "Success - All databases are synchronized between Azure and OCI" -ForegroundColor Green
    } else {
        Write-ColorOutput "Warning - Discrepancies found - review details above" -ForegroundColor Yellow
        
        if ($stateMismatches.Count -gt 0) {
            Write-ColorOutput "  Action required: Investigate state mismatches" -ForegroundColor Red
        }
        if ($onlyInAzure.Count -gt 0) {
            Write-ColorOutput "  Action required: Check databases missing in OCI" -ForegroundColor Yellow
        }
        if ($onlyInOCI.Count -gt 0) {
            Write-ColorOutput "  Action required: Check databases missing in Azure" -ForegroundColor Yellow
        }
    }

    Write-Host "`nComparison complete!" -ForegroundColor Cyan

} catch {
    Write-ColorOutput "`nError: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Gray
    exit 1
}
