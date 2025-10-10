#Requires -Version 5.1
<#
.SYNOPSIS
    Management script for ODAA MH environments deployed on Azure

.DESCRIPTION
    This script provides management capabilities for ODAA MH environments including:
    - List all deployed environments
    - Check status of environments
    - Cleanup/delete environments
    - Get external IPs and connection information

.PARAMETER Action
    Action to perform: List, Status, Cleanup, GetInfo

.PARAMETER ResourceGroupPattern
    Pattern to match resource group names (supports wildcards)

.PARAMETER ResourceGroupNames
    Specific resource group names to operate on

.PARAMETER SubscriptionName
    Azure subscription name

.PARAMETER Confirm
    Skip confirmation prompts for destructive operations

.EXAMPLE
    .\Manage-Environments.ps1 -Action List

.EXAMPLE
    .\Manage-Environments.ps1 -Action Status -ResourceGroupNames @("odaa-team1", "odaa-team2")

.EXAMPLE
    .\Manage-Environments.ps1 -Action Cleanup -ResourceGroupPattern "odaa-team*" -Confirm

.NOTES
    Author: Generated for ODAA MH Workshop
    This script helps manage multiple ODAA MH environments
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("List", "Status", "Cleanup", "GetInfo")]
    [string]$Action,
    
    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupPattern,
    
    [Parameter(Mandatory = $false)]
    [string[]]$ResourceGroupNames,
    
    [Parameter(Mandatory = $false)]
    [string]$SubscriptionName = "sub-cptdx-01",
    
    [Parameter(Mandatory = $false)]
    [switch]$Confirm
)

# Function to write colored output
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

# Function to get resource groups
function Get-TargetResourceGroups {
    try {
        if ($ResourceGroupNames) {
            $resourceGroups = @()
            foreach ($rgName in $ResourceGroupNames) {
                $rg = az group show --name $rgName --query "name" -o tsv 2>$null
                if ($rg) {
                    $resourceGroups += $rg
                }
                else {
                    Write-ColorOutput "Resource group not found: $rgName" "Yellow"
                }
            }
            return $resourceGroups
        }
        elseif ($ResourceGroupPattern) {
            $allRgs = az group list --query "[].name" -o tsv
            $matchingRgs = $allRgs | Where-Object { $_ -like $ResourceGroupPattern }
            return $matchingRgs
        }
        else {
            # List all resource groups
            return az group list --query "[].name" -o tsv
        }
    }
    catch {
        Write-ColorOutput "Failed to get resource groups: $_" "Red"
        return @()
    }
}

# Function to list environments
function Invoke-ListEnvironments {
    Write-ColorOutput "Listing ODAA MH Environments..." "Yellow"
    
    $resourceGroups = Get-TargetResourceGroups
    
    if ($resourceGroups.Count -eq 0) {
        Write-ColorOutput "No matching resource groups found" "Yellow"
        return
    }
    
    $environments = @()
    
    foreach ($rgName in $resourceGroups) {
        try {
            # Get AKS clusters in the resource group
            $aksClusters = az aks list --resource-group $rgName --query "[].{Name:name, Status:powerState.code, Version:kubernetesVersion, Location:location}" -o json | ConvertFrom-Json
            
            if ($aksClusters) {
                foreach ($cluster in $aksClusters) {
                    $environments += [PSCustomObject]@{
                        ResourceGroup = $rgName
                        AKSCluster = $cluster.Name
                        Status = $cluster.Status
                        K8sVersion = $cluster.Version
                        Location = $cluster.Location
                    }
                }
            }
            else {
                # Check if resource group has any resources
                $resources = az resource list --resource-group $rgName --query "length(@)" -o tsv
                if ($resources -gt 0) {
                    $environments += [PSCustomObject]@{
                        ResourceGroup = $rgName
                        AKSCluster = "No AKS cluster"
                        Status = "Unknown"
                        K8sVersion = "N/A"
                        Location = "N/A"
                    }
                }
            }
        }
        catch {
            Write-ColorOutput "Failed to get info for $rgName: $_" "Red"
        }
    }
    
    if ($environments.Count -gt 0) {
        Write-ColorOutput "`nFound $($environments.Count) environments:" "Green"
        $environments | Format-Table -AutoSize
    }
    else {
        Write-ColorOutput "No ODAA MH environments found" "Yellow"
    }
}

# Function to check environment status
function Invoke-StatusCheck {
    Write-ColorOutput "Checking environment status..." "Yellow"
    
    $resourceGroups = Get-TargetResourceGroups
    
    if ($resourceGroups.Count -eq 0) {
        Write-ColorOutput "No matching resource groups found" "Yellow"
        return
    }
    
    foreach ($rgName in $resourceGroups) {
        Write-ColorOutput "`n" + "="*60 "Cyan"
        Write-ColorOutput "Resource Group: $rgName" "Cyan"
        Write-ColorOutput "="*60 "Cyan"
        
        try {
            # Get AKS cluster info
            $aksClusters = az aks list --resource-group $rgName --query "[].name" -o tsv
            
            if ($aksClusters) {
                foreach ($aksName in $aksClusters) {
                    Write-ColorOutput "`nAKS Cluster: $aksName" "White"
                    
                    # Get credentials and check cluster
                    try {
                        az aks get-credentials --resource-group $rgName --name $aksName --overwrite-existing --only-show-errors
                        
                        # Check cluster nodes
                        Write-ColorOutput "Cluster Nodes:" "Yellow"
                        kubectl get nodes --no-headers 2>$null | Format-Table
                        
                        # Check namespaces
                        Write-ColorOutput "Namespaces:" "Yellow"
                        kubectl get namespaces --no-headers 2>$null | Format-Table
                        
                        # Check NGINX ingress controller
                        Write-ColorOutput "NGINX Ingress Controller:" "Yellow"
                        $nginxService = kubectl get service -n ingress-nginx --no-headers 2>$null
                        
                        if ($nginxService) {
                            $nginxService | Format-Table
                            
                            # Get external IP
                            $externalIP = kubectl get service -n ingress-nginx -o jsonpath='{range .items[*]} {.status.loadBalancer.ingress[*].ip} {"\n"} {end}' 2>$null
                            if ($externalIP -and $externalIP.Trim()) {
                                Write-ColorOutput "External IP: $($externalIP.Trim())" "Green"
                            }
                            else {
                                Write-ColorOutput "External IP: Not assigned yet" "Yellow"
                            }
                        }
                        else {
                            Write-ColorOutput "NGINX Ingress Controller not found" "Red"
                        }
                    }
                    catch {
                        Write-ColorOutput "Failed to check AKS cluster: $_" "Red"
                    }
                }
            }
            else {
                Write-ColorOutput "No AKS clusters found in this resource group" "Yellow"
                
                # List other resources
                Write-ColorOutput "Other resources:" "Yellow"
                az resource list --resource-group $rgName --query "[].{Name:name, Type:type}" -o table
            }
        }
        catch {
            Write-ColorOutput "Failed to get status for $rgName: $_" "Red"
        }
    }
}

# Function to get environment information
function Invoke-GetInfo {
    Write-ColorOutput "Getting environment connection information..." "Yellow"
    
    $resourceGroups = Get-TargetResourceGroups
    
    if ($resourceGroups.Count -eq 0) {
        Write-ColorOutput "No matching resource groups found" "Yellow"
        return
    }
    
    $connectionInfo = @()
    
    foreach ($rgName in $resourceGroups) {
        try {
            $aksClusters = az aks list --resource-group $rgName --query "[].name" -o tsv
            
            foreach ($aksName in $aksClusters) {
                # Get credentials
                az aks get-credentials --resource-group $rgName --name $aksName --overwrite-existing --only-show-errors
                
                # Get external IP
                $externalIP = kubectl get service -n ingress-nginx -o jsonpath='{range .items[*]} {.status.loadBalancer.ingress[*].ip} {"\n"} {end}' 2>$null
                
                # Get cluster info
                $clusterInfo = az aks show --resource-group $rgName --name $aksName --query "{fqdn:fqdn, version:kubernetesVersion}" -o json | ConvertFrom-Json
                
                $connectionInfo += [PSCustomObject]@{
                    ResourceGroup = $rgName
                    AKSCluster = $aksName
                    ClusterFQDN = $clusterInfo.fqdn
                    K8sVersion = $clusterInfo.version
                    ExternalIP = if ($externalIP -and $externalIP.Trim()) { $externalIP.Trim() } else { "Not assigned" }
                    KubectlContext = kubectl config current-context 2>$null
                }
            }
        }
        catch {
            Write-ColorOutput "Failed to get info for $rgName/$aksName: $_" "Red"
        }
    }
    
    if ($connectionInfo.Count -gt 0) {
        Write-ColorOutput "`nConnection Information:" "Green"
        $connectionInfo | Format-Table -AutoSize -Wrap
        
        Write-ColorOutput "`nConnection Commands:" "Yellow"
        foreach ($info in $connectionInfo) {
            Write-ColorOutput "# Connect to $($info.AKSCluster):" "Cyan"
            Write-ColorOutput "az aks get-credentials --resource-group $($info.ResourceGroup) --name $($info.AKSCluster)" "White"
            Write-ColorOutput ""
        }
    }
    else {
        Write-ColorOutput "No connection information found" "Yellow"
    }
}

# Function to cleanup environments
function Invoke-Cleanup {
    Write-ColorOutput "Preparing to cleanup environments..." "Yellow"
    
    $resourceGroups = Get-TargetResourceGroups
    
    if ($resourceGroups.Count -eq 0) {
        Write-ColorOutput "No matching resource groups found" "Yellow"
        return
    }
    
    Write-ColorOutput "`nResource groups to be deleted:" "Red"
    foreach ($rgName in $resourceGroups) {
        Write-ColorOutput "- $rgName" "Red"
    }
    
    if (-not $Confirm) {
        Write-ColorOutput "`nWARNING: This will permanently delete all resources in the above resource groups!" "Red"
        $confirmation = Read-Host "Type 'DELETE' to confirm deletion"
        
        if ($confirmation -ne "DELETE") {
            Write-ColorOutput "Cleanup cancelled" "Yellow"
            return
        }
    }
    
    Write-ColorOutput "`nStarting cleanup..." "Yellow"
    $failed = @()
    
    foreach ($rgName in $resourceGroups) {
        try {
            Write-ColorOutput "Deleting resource group: $rgName" "Yellow"
            az group delete --name $rgName --yes --no-wait
            Write-ColorOutput "✓ Deletion initiated for: $rgName" "Green"
        }
        catch {
            Write-ColorOutput "✗ Failed to delete: $rgName - $_" "Red"
            $failed += $rgName
        }
    }
    
    if ($failed.Count -eq 0) {
        Write-ColorOutput "`nAll resource group deletions initiated successfully!" "Green"
        Write-ColorOutput "Note: Actual deletion may take several minutes to complete." "Yellow"
    }
    else {
        Write-ColorOutput "`nSome deletions failed:" "Red"
        foreach ($failedRg in $failed) {
            Write-ColorOutput "- $failedRg" "Red"
        }
    }
}

# Main execution
function Main {
    Write-ColorOutput "ODAA MH Environment Management" "Green"
    Write-ColorOutput "Action: $Action" "White"
    Write-ColorOutput "Subscription: $SubscriptionName" "White"
    Write-ColorOutput ""
    
    # Check Azure CLI authentication
    try {
        $currentAccount = az account show --query "name" -o tsv 2>$null
        if (-not $currentAccount) {
            Write-ColorOutput "Not authenticated with Azure CLI. Please run: az login" "Red"
            exit 1
        }
        
        # Set subscription
        az account set -s $SubscriptionName
        Write-ColorOutput "Using subscription: $SubscriptionName" "Green"
    }
    catch {
        Write-ColorOutput "Failed to set Azure subscription: $_" "Red"
        exit 1
    }
    
    # Execute action
    switch ($Action) {
        "List" { Invoke-ListEnvironments }
        "Status" { Invoke-StatusCheck }
        "GetInfo" { Invoke-GetInfo }
        "Cleanup" { Invoke-Cleanup }
        default { 
            Write-ColorOutput "Unknown action: $Action" "Red"
            exit 1
        }
    }
}

# Execute main function
try {
    Main
}
catch {
    Write-ColorOutput "Management operation failed: $_" "Red"
    Write-ColorOutput "Stack trace: $($_.ScriptStackTrace)" "Red"
    exit 1
}
