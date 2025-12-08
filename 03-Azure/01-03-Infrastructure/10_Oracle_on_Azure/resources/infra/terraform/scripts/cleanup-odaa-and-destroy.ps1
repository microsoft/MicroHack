<#
.SYNOPSIS
    Cleanup Oracle Database @ Azure (ODAA) resources with optional exclusions.

.DESCRIPTION
    This script deletes Oracle Autonomous Databases in Azure and their associated
    OCI resources (subnets, NSGs, VCNs). You can exclude specific ADBs from deletion
    by providing their Azure resource IDs or names.

.PARAMETER ExcludeAdbIds
    Array of Azure ADB resource IDs to exclude from deletion.
    Example: "/subscriptions/.../providers/Oracle.Database/autonomousDatabases/adb-user00"

.PARAMETER ExcludeAdbNames
    Array of ADB names to exclude from deletion.
    Example: @("adb-user00", "adb-user01")

.PARAMETER WhatIf
    Preview mode - shows what would be deleted without actually deleting.

.PARAMETER SkipOciCleanup
    Skip OCI resource cleanup (subnets, NSGs, VCNs). Only delete Azure ADBs.

.EXAMPLE
    # Delete all ADBs and OCI resources
    .\cleanup-odaa-and-destroy.ps1

.EXAMPLE
    # Preview what would be deleted
    .\cleanup-odaa-and-destroy.ps1 -WhatIf

.EXAMPLE
    # Exclude specific ADBs by name
    .\cleanup-odaa-and-destroy.ps1 -ExcludeAdbNames @("adb-user00", "adb-user01")

.EXAMPLE
    # Exclude by Azure resource ID
    .\cleanup-odaa-and-destroy.ps1 -ExcludeAdbIds @("/subscriptions/xxx/resourceGroups/rg-odaa-user00/providers/Oracle.Database/autonomousDatabases/adb-user00")

.EXAMPLE
    # Exclude and preview
    .\cleanup-odaa-and-destroy.ps1 -ExcludeAdbNames @("adb-user00") -WhatIf
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter()]
    [string[]]$ExcludeAdbIds = @(),

    [Parameter()]
    [string[]]$ExcludeAdbNames = @(),

    [Parameter()]
    [switch]$SkipOciCleanup
)

$ErrorActionPreference = "Continue"
$compartmentId = "ocid1.compartment.oc1..aaaaaaaayehuog6myqxudqejx3ddy6bzkr2f3dnjuuygs424taimn4av4wbq"

# ===============================================================================
# Helper Functions
# ===============================================================================

function Get-AdbOciVcnId {
    <#
    .SYNOPSIS
        Extract the OCI VCN ID associated with an Azure ADB by querying its details.
    #>
    param([string]$AdbName, [string]$ResourceGroup)
    
    try {
        $adbDetails = az oracle-database autonomous-database show `
            --name $AdbName `
            --resource-group $ResourceGroup `
            --query "properties" -o json 2>$null | ConvertFrom-Json
        
        # The subnetId in Azure maps to an OCI subnet, which belongs to a VCN
        # We'll extract info from the OCI URL or naming convention
        if ($adbDetails.ociUrl) {
            return $adbDetails.ociUrl
        }
        return $null
    } catch {
        return $null
    }
}

# ===============================================================================
# Main Script
# ===============================================================================

Write-Host ""
Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "         ODAA CLEANUP - Oracle Database @ Azure Destroyer            " -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host ""

if ($WhatIfPreference -or $PSBoundParameters.ContainsKey('WhatIf')) {
    Write-Host "  [PREVIEW MODE] No resources will be deleted" -ForegroundColor Yellow
    Write-Host ""
}

# Set subscription
Write-Host "Setting subscription to sub-mhodaa..." -ForegroundColor Gray
az account set -s sub-mhodaa

# ===============================================================================
# Step 1: List and Filter ADB Instances
# ===============================================================================

Write-Host "`n[Step 1] Discovering Azure ADB instances..." -ForegroundColor Cyan
$adbQuery = '[].{name:name, resourceGroup:resourceGroup, id:id, provisioningState:properties.provisioningState, lifecycleState:properties.lifecycleState}'
$adbJson = az oracle-database autonomous-database list --query $adbQuery -o json 2>$null
$adbInstances = @()
if ($adbJson) {
    $adbInstances = $adbJson | ConvertFrom-Json
}

if (-not $adbInstances -or $adbInstances.Count -eq 0) {
    Write-Host "  No ADB instances found." -ForegroundColor Yellow
} else {
    Write-Host "  Found $($adbInstances.Count) ADB instance(s)" -ForegroundColor White
}

# Separate into delete and exclude lists
$adbsToDelete = @()
$adbsToKeep = @()
$excludedVcnPatterns = @()

foreach ($Instance in $adbInstances) {
    $shouldExclude = $false
    $excludeReason = ""

    # Check exclusion by ID
    if ($ExcludeAdbIds -contains $Instance.id) {
        $shouldExclude = $true
        $excludeReason = "ID in exclusion list"
    }
    
    # Check exclusion by name
    if ($ExcludeAdbNames -contains $Instance.name) {
        $shouldExclude = $true
        $excludeReason = "Name in exclusion list"
    }

    if ($shouldExclude) {
        $adbsToKeep += $Instance
        $excludedVcnPatterns += $Instance.name  # Use ADB name to match OCI resources
        Write-Host "  [EXCLUDE] $($Instance.name) - $excludeReason" -ForegroundColor Yellow
    } else {
        $adbsToDelete += $Instance
        Write-Host "  [DELETE]  $($Instance.name) ($($Instance.lifecycleState))" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "  Summary: $($adbsToDelete.Count) to delete, $($adbsToKeep.Count) excluded" -ForegroundColor White

# ===============================================================================
# Step 2: Delete ADB Instances (excluding protected ones)
# ===============================================================================

Write-Host "`n[Step 2] Deleting Azure ADB instances..." -ForegroundColor Cyan

foreach ($Instance in $adbsToDelete) {
    if ($WhatIfPreference -or $PSBoundParameters.ContainsKey('WhatIf')) {
        Write-Host "  [WOULD DELETE] $($Instance.name) in $($Instance.resourceGroup)" -ForegroundColor Magenta
    } else {
        Write-Host "  Deleting: $($Instance.name) (this may take several minutes)..." -ForegroundColor White
        Write-Host "    Command: az oracle-database autonomous-database delete --name $($Instance.name) --resource-group $($Instance.resourceGroup) --yes" -ForegroundColor Gray
        
        $deleteResult = az oracle-database autonomous-database delete `
            --name $Instance.name `
            --resource-group $Instance.resourceGroup `
            --yes --verbose 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "    [OK] Successfully deleted $($Instance.name)" -ForegroundColor Green
        } else {
            Write-Host "    [FAIL] Failed to delete $($Instance.name): $deleteResult" -ForegroundColor Red
        }
    }
}

# ===============================================================================
# Step 3: OCI Resource Cleanup (with exclusions)
# ===============================================================================

if ($SkipOciCleanup) {
    Write-Host "`n[Step 3] Skipping OCI cleanup (--SkipOciCleanup specified)" -ForegroundColor Yellow
} else {
    Write-Host "`n[Step 3] Cleaning up OCI resources..." -ForegroundColor Cyan
    
    if ($excludedVcnPatterns.Count -gt 0) {
        Write-Host "  Protected patterns (will skip): $($excludedVcnPatterns -join ', ')" -ForegroundColor Yellow
    }

    # -------------------------------------------------------------------------
    # 3a: Delete Subnets (excluding those matching protected ADBs)
    # -------------------------------------------------------------------------
    Write-Host "`n  [3a] Processing OCI Subnets..." -ForegroundColor Cyan
    $subnetQuery = 'data[].{id:id, displayName:"display-name", vcnId:"vcn-id"}'
    $subnetJson = oci network subnet list --compartment-id $compartmentId --all --query $subnetQuery 2>$null
    $subnets = @()
    if ($subnetJson) {
        $subnets = $subnetJson | ConvertFrom-Json
    }

    foreach ($subnet in $subnets) {
        $subnetName = $subnet.displayName
        $shouldSkip = $false
        
        # Check if subnet name contains any excluded ADB pattern
        foreach ($pattern in $excludedVcnPatterns) {
            if ($subnetName -like "*$pattern*") {
                $shouldSkip = $true
                break
            }
        }
        
        if ($shouldSkip) {
            Write-Host "    [SKIP] Subnet: $subnetName (protected)" -ForegroundColor Yellow
        } elseif ($WhatIfPreference -or $PSBoundParameters.ContainsKey('WhatIf')) {
            Write-Host "    [WOULD DELETE] Subnet: $subnetName" -ForegroundColor Magenta
        } else {
            Write-Host "    Deleting Subnet: $subnetName" -ForegroundColor White
            oci network subnet delete --subnet-id $subnet.id --force --wait-for-state TERMINATED 2>$null
            if ($LASTEXITCODE -eq 0) {
                Write-Host "      [OK] Deleted" -ForegroundColor Green
            } else {
                Write-Host "      [WARN] Failed (may be in use)" -ForegroundColor Yellow
            }
        }
    }

    # -------------------------------------------------------------------------
    # 3b: Delete NSGs (excluding those matching protected ADBs)
    # -------------------------------------------------------------------------
    Write-Host "`n  [3b] Processing OCI Network Security Groups..." -ForegroundColor Cyan
    $nsgQuery = 'data[].{id:id, displayName:"display-name", vcnId:"vcn-id"}'
    $nsgJson = oci network nsg list --compartment-id $compartmentId --all --query $nsgQuery 2>$null
    $nsgs = @()
    if ($nsgJson) {
        $nsgs = $nsgJson | ConvertFrom-Json
    }

    foreach ($nsg in $nsgs) {
        $nsgName = $nsg.displayName
        $shouldSkip = $false
        
        foreach ($pattern in $excludedVcnPatterns) {
            if ($nsgName -like "*$pattern*") {
                $shouldSkip = $true
                break
            }
        }
        
        if ($shouldSkip) {
            Write-Host "    [SKIP] NSG: $nsgName (protected)" -ForegroundColor Yellow
        } elseif ($WhatIfPreference -or $PSBoundParameters.ContainsKey('WhatIf')) {
            Write-Host "    [WOULD DELETE] NSG: $nsgName" -ForegroundColor Magenta
        } else {
            Write-Host "    Deleting NSG: $nsgName" -ForegroundColor White
            oci network nsg delete --nsg-id $nsg.id --force --wait-for-state TERMINATED 2>$null
            if ($LASTEXITCODE -eq 0) {
                Write-Host "      [OK] Deleted" -ForegroundColor Green
            } else {
                Write-Host "      [WARN] Failed (may have VNICs attached)" -ForegroundColor Yellow
            }
        }
    }

    # -------------------------------------------------------------------------
    # 3c: Delete VCNs (excluding those matching protected ADBs)
    # -------------------------------------------------------------------------
    Write-Host "`n  [3c] Processing OCI VCNs..." -ForegroundColor Cyan
    $vcnQuery = 'data[].{id:id, displayName:"display-name"}'
    $vcnJson = oci network vcn list --compartment-id $compartmentId --all --query $vcnQuery 2>$null
    $vcns = @()
    if ($vcnJson) {
        $vcns = $vcnJson | ConvertFrom-Json
    }

    foreach ($vcn in $vcns) {
        $vcnName = $vcn.displayName
        $shouldSkip = $false
        
        foreach ($pattern in $excludedVcnPatterns) {
            if ($vcnName -like "*$pattern*") {
                $shouldSkip = $true
                break
            }
        }
        
        if ($shouldSkip) {
            Write-Host "    [SKIP] VCN: $vcnName (protected)" -ForegroundColor Yellow
        } elseif ($WhatIfPreference -or $PSBoundParameters.ContainsKey('WhatIf')) {
            Write-Host "    [WOULD DELETE] VCN: $vcnName" -ForegroundColor Magenta
        } else {
            Write-Host "    Deleting VCN: $vcnName" -ForegroundColor White
            oci network vcn delete --vcn-id $vcn.id --force --wait-for-state TERMINATED 2>$null
            if ($LASTEXITCODE -eq 0) {
                Write-Host "      [OK] Deleted" -ForegroundColor Green
            } else {
                Write-Host "      [WARN] Failed (may have dependencies)" -ForegroundColor Yellow
            }
        }
    }
}

# ===============================================================================
# Summary
# ===============================================================================

Write-Host ""
Write-Host "======================================================================" -ForegroundColor Green
Write-Host "                        CLEANUP COMPLETE                              " -ForegroundColor Green
Write-Host "======================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  ADBs deleted:  $($adbsToDelete.Count)" -ForegroundColor White
Write-Host "  ADBs excluded: $($adbsToKeep.Count)" -ForegroundColor Yellow

if ($adbsToKeep.Count -gt 0) {
    Write-Host "`n  Preserved ADBs:" -ForegroundColor Yellow
    foreach ($kept in $adbsToKeep) {
        Write-Host "    - $($kept.name) ($($kept.resourceGroup))" -ForegroundColor Yellow
    }
}

Write-Host ""
