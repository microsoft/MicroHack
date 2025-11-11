
# Set error action preference for better error handling
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# Initialize logging
$LogFile = "cleanup-odaa-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogMessage = "[$Timestamp] [$Level] $Message"
    Write-Host $LogMessage
    Add-Content -Path $LogFile -Value $LogMessage
}


function Get-OdaaAdbInstances {
    Write-Log "Searching for Oracle Database@Azure Autonomous Database instances..."
    
    try {
        # Use the specific Oracle Database@Azure CLI command to list autonomous databases
        $adbInstances = az oracle-database autonomous-database list --query "[].{name:name, resourceGroup:resourceGroup, id:id, provisioningState:properties.provisioningState, lifecycleState:properties.lifecycleState}" -o json | ConvertFrom-Json
        
        if (-not $adbInstances -or $adbInstances.Count -eq 0) {
            Write-Log "No Oracle Database@Azure Autonomous Database instances found"
            return @()
        }
        
        Write-Log "Found $($adbInstances.Count) Oracle Database@Azure Autonomous Database instance(s):"
        foreach ($instance in $adbInstances) {
            Write-Log "  - Name: $($instance.name), Resource Group: $($instance.resourceGroup), Provisioning State: $($instance.provisioningState), Lifecycle State: $($instance.lifecycleState)"
        }
        
        return $adbInstances
    }
    catch {
        Write-Log "Failed to list Oracle Database@Azure Autonomous Database instances: $($_.Exception.Message)" "ERROR"
        # Fallback to generic resource listing if the specific command fails
        try {
            Write-Log "Attempting fallback search for Oracle Database@Azure resources..."
            $oracleResources = az resource list --resource-type "Oracle.Database/autonomousDatabases" --query "[].{name:name, resourceGroup:resourceGroup, type:type, id:id}" -o json | ConvertFrom-Json
            
            if ($oracleResources -and $oracleResources.Count -gt 0) {
                Write-Log "Found $($oracleResources.Count) Oracle Database@Azure resource(s) via fallback method:"
                foreach ($resource in $oracleResources) {
                    Write-Log "  - Name: $($resource.name), Type: $($resource.type), Resource Group: $($resource.resourceGroup)"
                }
            }
            
            return $oracleResources
        }
        catch {
            Write-Log "Failed to find any Oracle Database@Azure resources: $($_.Exception.Message)" "ERROR"
            throw
        }
    }
}

function Remove-OdaaAdbInstance {
    param(
        [Parameter(Mandatory = $true)]
        [PSObject]$Instance
    )
    
    Write-Log "Deleting ADB instance: $($Instance.name) (this may take several minutes)..."
    
    try {
        # Use the specific Oracle Database@Azure CLI command to delete autonomous database
        Write-Log "Running: az oracle-database autonomous-database delete --name $($Instance.name) --resource-group $($Instance.resourceGroup) --yes"
        $deleteResult = az oracle-database autonomous-database delete --name $Instance.name --resource-group $Instance.resourceGroup --yes --verbose 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-Log "Successfully deleted: $($Instance.name)"
            return $true
        } else {
            Write-Log "Failed to delete $($Instance.name). Exit code: $LASTEXITCODE" "ERROR"
            Write-Log "Error details: $deleteResult" "ERROR"
            
            # Fallback to generic resource delete if specific command fails
            Write-Log "Attempting fallback deletion using generic resource delete..." "WARNING"
            $fallbackResult = az resource delete --id $Instance.id --verbose 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                Write-Log "Successfully deleted $($Instance.name) using fallback method"
                return $true
            } else {
                Write-Log "Fallback deletion also failed. Exit code: $LASTEXITCODE" "ERROR"
                Write-Log "Fallback error details: $fallbackResult" "ERROR"
                return $false
            }
        }
    }
    catch {
        Write-Log "Exception during deletion of $($Instance.name): $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Invoke-TerraformDestroy {
    Write-Log "Starting Terraform destroy..."
    
    try {
        # Run terraform destroy with auto-approve
        Write-Log "Running terraform destroy -auto-approve..."
        terraform destroy -auto-approve
        
        if ($LASTEXITCODE -eq 0) {
            Write-Log "Terraform destroy completed successfully"
            return $true
        } else {
            Write-Log "Terraform destroy failed with exit code: $LASTEXITCODE" "ERROR"
            return $false
        }
    }
    catch {
        Write-Log "Terraform destroy failed: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

# Main execution
try {
    Write-Log "=== Starting ODAA Cleanup and Terraform Destroy Script ==="
    Write-Log "Parameters: Subscription=$SubscriptionName"
    
    
    # Get all ODAA ADB instances
    $adbInstances = Get-OdaaAdbInstances
    
    if ($adbInstances.Count -eq 0) {
        Write-Log "No Oracle Database@Azure instances found. Proceeding directly to Terraform destroy."
    } else {
        Write-Log "Found $($adbInstances.Count) Oracle Database@Azure instance(s). Starting deletion process..."
        
        # Delete all instances synchronously
        $failedDeletions = @()
        
        foreach ($instance in $adbInstances) {
            if (-not (Remove-OdaaAdbInstance -Instance $instance)) {
                $failedDeletions += $instance.name
            }
        }
        
        if ($failedDeletions.Count -gt 0) {
            Write-Log "Failed to delete the following instances: $($failedDeletions -join ', ')" "ERROR"
            Write-Log "Continuing with terraform destroy despite deletion failures..." "WARNING"
        } else {
            Write-Log "All Oracle Database@Azure instances deleted successfully"
        }
    }
    
    # Run terraform destroy
    $terraformSuccess = Invoke-TerraformDestroy
    
    if ($terraformSuccess) {
        Write-Log "=== Script completed successfully ==="
    } else {
        Write-Log "=== Script completed with errors during terraform destroy ===" "WARNING"
        exit 1
    }
}
catch {
    Write-Log "Script failed with error: $($_.Exception.Message)" "ERROR"
    Write-Log "Stack trace: $($_.ScriptStackTrace)" "ERROR"
    exit 1
}
finally {
    Write-Log "Log file saved to: $LogFile"
}