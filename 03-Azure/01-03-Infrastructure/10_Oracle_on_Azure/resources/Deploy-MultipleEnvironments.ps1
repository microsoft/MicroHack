#Requires -Version 5.1
<#
.SYNOPSIS
    Batch deployment script for multiple ODAA MH environments

.DESCRIPTION
    This script allows you to deploy multiple ODAA MH environments at once.
    It reads configuration from a CSV file or uses predefined configurations.

.PARAMETER ConfigFile
    Path to CSV configuration file with columns: ResourceGroupName, Prefix, Postfix, Location

.PARAMETER PredefinedTeams
    Number of predefined team environments to create (1-10)

.PARAMETER BaseResourceGroupName
    Base name for resource groups when using predefined teams

.PARAMETER BasePrefix
    Base prefix for resources when using predefined teams

.PARAMETER Location
    Azure region for all deployments

.PARAMETER SubscriptionName
    Azure subscription name

.PARAMETER MaxParallelJobs
    Maximum number of parallel deployments (default: 3)

.EXAMPLE
    .\Deploy-MultipleEnvironments.ps1 -PredefinedTeams 3 -BaseResourceGroupName "odaa" -BasePrefix "ODAA" -Location "germanywestcentral"

.EXAMPLE
    .\Deploy-MultipleEnvironments.ps1 -ConfigFile ".\team-configs.csv"

.NOTES
    Author: Generated for ODAA MH Workshop
    This script creates multiple environments for workshop teams
#>

[CmdletBinding(DefaultParameterSetName = "Predefined")]
param(
    [Parameter(ParameterSetName = "ConfigFile", Mandatory = $true)]
    [string]$ConfigFile,
    
    [Parameter(ParameterSetName = "Predefined", Mandatory = $true)]
    [ValidateRange(1, 10)]
    [int]$PredefinedTeams,
    
    [Parameter(ParameterSetName = "Predefined", Mandatory = $true)]
    [string]$BaseResourceGroupName,
    
    [Parameter(ParameterSetName = "Predefined", Mandatory = $true)]
    [string]$BasePrefix,
    
    [Parameter(Mandatory = $false)]
    [string]$Location = "germanywestcentral",
    
    [Parameter(Mandatory = $false)]
    [string]$SubscriptionName = "sub-cptdx-01",
    
    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 5)]
    [int]$MaxParallelJobs = 3
)

# Function to write colored output
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

# Function to create sample configuration file
function New-SampleConfigFile {
    $sampleFile = ".\sample-team-configs.csv"
    
    $sampleContent = @"
ResourceGroupName,Prefix,Postfix,Location
odaa-team1,ODAA,team1,germanywestcentral
odaa-team2,ODAA,team2,germanywestcentral
odaa-team3,ODAA,team3,germanywestcentral
odaa-team4,ODAA,team4,westeurope
odaa-team5,ODAA,team5,westeurope
"@
    
    $sampleContent | Out-File -FilePath $sampleFile -Encoding UTF8
    Write-ColorOutput "Sample configuration file created: $sampleFile" "Green"
    Write-ColorOutput "Edit this file with your desired configurations and use -ConfigFile parameter" "Yellow"
}

# Function to get configurations
function Get-DeploymentConfigurations {
    if ($PSCmdlet.ParameterSetName -eq "ConfigFile") {
        if (-not (Test-Path $ConfigFile)) {
            Write-ColorOutput "Configuration file not found: $ConfigFile" "Red"
            Write-ColorOutput "Creating a sample configuration file..." "Yellow"
            New-SampleConfigFile
            exit 1
        }
        
        try {
            $configs = Import-Csv $ConfigFile
            Write-ColorOutput "Loaded $($configs.Count) configurations from $ConfigFile" "Green"
            return $configs
        }
        catch {
            Write-ColorOutput "Failed to read configuration file: $_" "Red"
            exit 1
        }
    }
    else {
        # Generate predefined team configurations
        $configs = @()
        
        for ($i = 1; $i -le $PredefinedTeams; $i++) {
            $configs += [PSCustomObject]@{
                ResourceGroupName = "$BaseResourceGroupName-team$i"
                Prefix = $BasePrefix
                Postfix = "team$i"
                Location = $Location
            }
        }
        
        Write-ColorOutput "Generated $($configs.Count) predefined team configurations" "Green"
        return $configs
    }
}

# Function to deploy single environment
function Deploy-SingleEnvironment {
    param(
        [PSCustomObject]$Config,
        [string]$SubscriptionName,
        [int]$JobNumber
    )
    
    $jobName = "Deploy-Team-$($Config.Postfix)"
    Write-ColorOutput "[$jobName] Starting deployment..." "Cyan"
    
    $scriptPath = ".\Deploy-ODAAMHEnv.ps1"
    
    if (-not (Test-Path $scriptPath)) {
        Write-ColorOutput "[$jobName] Main deployment script not found: $scriptPath" "Red"
        return $false
    }
    
    try {
        $params = @{
            ResourceGroupName = $Config.ResourceGroupName
            Prefix = $Config.Prefix
            Postfix = $Config.Postfix
            Location = $Config.Location
            SubscriptionName = $SubscriptionName
            SkipLogin = $true
            SkipPrerequisites = $true
        }
        
        # Execute deployment script
        & $scriptPath @params
        
        Write-ColorOutput "[$jobName] Deployment completed successfully!" "Green"
        return $true
    }
    catch {
        Write-ColorOutput "[$jobName] Deployment failed: $_" "Red"
        return $false
    }
}

# Function to display final summary
function Show-FinalSummary {
    param(
        [array]$Results,
        [array]$Configs
    )
    
    Write-ColorOutput "`n" + "="*80 "Green"
    Write-ColorOutput "BATCH DEPLOYMENT SUMMARY" "Green"
    Write-ColorOutput "="*80 "Green"
    
    $successful = $Results | Where-Object { $_.Success -eq $true }
    $failed = $Results | Where-Object { $_.Success -eq $false }
    
    Write-ColorOutput "Total Deployments: $($Results.Count)" "White"
    Write-ColorOutput "Successful: $($successful.Count)" "Green"
    Write-ColorOutput "Failed: $($failed.Count)" "Red"
    
    if ($successful.Count -gt 0) {
        Write-ColorOutput "`nSuccessful Deployments:" "Green"
        foreach ($result in $successful) {
            Write-ColorOutput "  ✓ $($result.Config.ResourceGroupName) ($($result.Config.Postfix))" "Green"
        }
    }
    
    if ($failed.Count -gt 0) {
        Write-ColorOutput "`nFailed Deployments:" "Red"
        foreach ($result in $failed) {
            Write-ColorOutput "  ✗ $($result.Config.ResourceGroupName) ($($result.Config.Postfix))" "Red"
        }
    }
    
    Write-ColorOutput "`nNext Steps:" "Yellow"
    Write-ColorOutput "1. Verify all AKS clusters are accessible" "White"
    Write-ColorOutput "2. Check NGINX ingress controller external IPs" "White"
    Write-ColorOutput "3. Add VNet CIDRs to Oracle NSG" "White"
    Write-ColorOutput "4. Distribute access credentials to teams" "White"
    
    Write-ColorOutput "="*80 "Green"
}

# Main execution
function Main {
    $startTime = Get-Date
    
    Write-ColorOutput "Starting Batch ODAA MH Environment Deployment" "Green"
    Write-ColorOutput "Subscription: $SubscriptionName" "White"
    Write-ColorOutput "Max Parallel Jobs: $MaxParallelJobs" "White"
    Write-ColorOutput ""
    
    # Get deployment configurations
    $configs = Get-DeploymentConfigurations
    
    if ($configs.Count -eq 0) {
        Write-ColorOutput "No configurations found to deploy" "Red"
        exit 1
    }
    
    # Login to Azure once
    Write-ColorOutput "Logging into Azure..." "Yellow"
    try {
        az login --use-device-code
        az account set -s $SubscriptionName
        Write-ColorOutput "Successfully logged into Azure!" "Green"
    }
    catch {
        Write-ColorOutput "Failed to login to Azure: $_" "Red"
        exit 1
    }
    
    # Display configurations to be deployed
    Write-ColorOutput "`nConfigurations to deploy:" "Cyan"
    $configs | Format-Table -AutoSize
    
    $confirmation = Read-Host "Do you want to proceed with these deployments? (y/N)"
    if ($confirmation -notmatch "^[Yy]") {
        Write-ColorOutput "Deployment cancelled by user" "Yellow"
        exit 0
    }
    
    # Execute deployments
    $results = @()
    $jobs = @()
    $jobIndex = 0
    
    foreach ($config in $configs) {
        # Wait if we have reached max parallel jobs
        while ($jobs.Count -ge $MaxParallelJobs) {
            $completedJobs = $jobs | Where-Object { $_.State -eq "Completed" -or $_.State -eq "Failed" -or $_.State -eq "Stopped" }
            
            if ($completedJobs.Count -gt 0) {
                foreach ($job in $completedJobs) {
                    $jobResult = Receive-Job $job -Wait
                    $success = $job.State -eq "Completed"
                    
                    $results += [PSCustomObject]@{
                        Config = $job.Config
                        Success = $success
                        JobName = $job.Name
                    }
                    
                    Remove-Job $job
                    $jobs = $jobs | Where-Object { $_.Id -ne $job.Id }
                }
            }
            else {
                Start-Sleep 10
            }
        }
        
        # Start new job
        $jobIndex++
        $jobName = "DeployJob-$jobIndex-$($config.Postfix)"
        
        $job = Start-Job -Name $jobName -ScriptBlock {
            param($Config, $SubscriptionName, $JobNumber, $ScriptPath)
            
            try {
                $params = @{
                    ResourceGroupName = $Config.ResourceGroupName
                    Prefix = $Config.Prefix
                    Postfix = $Config.Postfix
                    Location = $Config.Location
                    SubscriptionName = $SubscriptionName
                    SkipLogin = $true
                    SkipPrerequisites = $true
                }
                
                & $ScriptPath @params
                return $true
            }
            catch {
                Write-Error "Deployment failed: $_"
                return $false
            }
        } -ArgumentList $config, $SubscriptionName, $jobIndex, ".\Deploy-ODAAMHEnv.ps1"
        
        # Add config reference to job for later use
        $job | Add-Member -MemberType NoteProperty -Name "Config" -Value $config
        $jobs += $job
        
        Write-ColorOutput "Started job: $jobName for $($config.ResourceGroupName)" "Cyan"
    }
    
    # Wait for remaining jobs to complete
    Write-ColorOutput "Waiting for remaining deployments to complete..." "Yellow"
    
    while ($jobs.Count -gt 0) {
        $completedJobs = $jobs | Where-Object { $_.State -eq "Completed" -or $_.State -eq "Failed" -or $_.State -eq "Stopped" }
        
        if ($completedJobs.Count -gt 0) {
            foreach ($job in $completedJobs) {
                $jobResult = Receive-Job $job -Wait
                $success = $job.State -eq "Completed"
                
                $results += [PSCustomObject]@{
                    Config = $job.Config
                    Success = $success
                    JobName = $job.Name
                }
                
                Remove-Job $job
                $jobs = $jobs | Where-Object { $_.Id -ne $job.Id }
            }
        }
        else {
            Start-Sleep 10
        }
    }
    
    # Show final summary
    $endTime = Get-Date
    $duration = $endTime - $startTime
    
    Show-FinalSummary -Results $results -Configs $configs
    Write-ColorOutput "`nBatch deployment completed in $($duration.ToString('hh\:mm\:ss'))" "Green"
}

# Execute main function
try {
    Main
}
catch {
    Write-ColorOutput "Batch deployment failed: $_" "Red"
    Write-ColorOutput "Stack trace: $($_.ScriptStackTrace)" "Red"
    exit 1
}
