#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Pre-flight validation script for Oracle on Azure Microhack Terraform deployment.

.DESCRIPTION
    This script performs comprehensive pre-flight checks to validate that all prerequisites
    are met before running terraform apply. It checks:
    - Required tools and versions
    - Azure authentication and permissions
    - Management group existence
    - Oracle service principal configuration
    - Azure subscription access and quotas
    - VM family quotas across all target subscriptions
    - Required resource provider registrations
    
.PARAMETER ConfigFile
    Path to terraform.tfvars file. Defaults to ../terraform.tfvars

.PARAMETER SkipQuotaCheck
    Skip VM quota validation (faster but less thorough)

.EXAMPLE
    .\preflight-check.ps1
    
.EXAMPLE
    .\preflight-check.ps1 -ConfigFile ".\my-config.tfvars" -SkipQuotaCheck

.NOTES
    Author: Oracle on Azure Microhack Team
    Version: 1.0.0
    Last Updated: November 1, 2025
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ConfigFile = "..\terraform.tfvars",
    
    [Parameter(Mandatory = $false)]
    [switch]$SkipQuotaCheck
)

# Script configuration
$ErrorActionPreference = "Continue"
$WarningPreference = "Continue"

# Color coding for output
function Write-Success { param([string]$Message) Write-Host "✓ $Message" -ForegroundColor Green }
function Write-Failure { param([string]$Message) Write-Host "✗ $Message" -ForegroundColor Red }
function Write-Info { param([string]$Message) Write-Host "ℹ $Message" -ForegroundColor Cyan }
function Write-Warning { param([string]$Message) Write-Host "⚠ $Message" -ForegroundColor Yellow }

# Counters for summary
$script:ChecksPassed = 0
$script:ChecksFailed = 0
$script:ChecksWarning = 0

Write-Host "`n================================================" -ForegroundColor Cyan
Write-Host "Oracle on Azure Microhack - Pre-flight Checks" -ForegroundColor Cyan
Write-Host "================================================`n" -ForegroundColor Cyan

# ============================================================================
# 1. Tool Version Checks
# ============================================================================
Write-Info "Checking required tools..."

function Test-Command {
    param([string]$CommandName, [string]$MinVersion = $null)
    
    try {
        $command = Get-Command $CommandName -ErrorAction Stop
        Write-Success "$CommandName is installed at: $($command.Source)"
        
        if ($MinVersion) {
            $installedVersion = & $CommandName --version 2>&1 | Select-Object -First 1
            Write-Host "  Version: $installedVersion" -ForegroundColor Gray
        }
        $script:ChecksPassed++
        return $true
    }
    catch {
        Write-Failure "$CommandName is not installed or not in PATH"
        Write-Host "  Install with: winget install <package-name>" -ForegroundColor Gray
        $script:ChecksFailed++
        return $false
    }
}

# Check required tools
$terraformInstalled = Test-Command "terraform"
$azInstalled = Test-Command "az"
$kubectlInstalled = Test-Command "kubectl"
$helmInstalled = Test-Command "helm"

if (-not ($terraformInstalled -and $azInstalled)) {
    Write-Failure "Critical tools missing. Cannot continue."
    exit 1
}

# ============================================================================
# 2. Azure Authentication Check
# ============================================================================
Write-Host "`n" -NoNewline
Write-Info "Checking Azure authentication..."

try {
    $account = az account show 2>&1 | ConvertFrom-Json
    if ($account) {
        Write-Success "Authenticated as: $($account.user.name)"
        Write-Host "  Current subscription: $($account.name) ($($account.id))" -ForegroundColor Gray
        $script:ChecksPassed++
    }
}
catch {
    Write-Failure "Not authenticated to Azure"
    Write-Host "  Run: az login" -ForegroundColor Gray
    $script:ChecksFailed++
    exit 1
}

# ============================================================================
# 3. Parse Terraform Configuration
# ============================================================================
Write-Host "`n" -NoNewline
Write-Info "Parsing Terraform configuration..."

if (-not (Test-Path $ConfigFile)) {
    Write-Failure "Configuration file not found: $ConfigFile"
    $script:ChecksFailed++
    exit 1
}

# Parse terraform.tfvars (simple key-value extraction)
$tfvarsContent = Get-Content $ConfigFile -Raw
$config = @{}

# Extract key configuration values
if ($tfvarsContent -match 'user_count\s*=\s*(\d+)') { $config.user_count = [int]$Matches[1] }
if ($tfvarsContent -match 'microhack_event_name\s*=\s*"([^"]+)"') { $config.event_name = $Matches[1] }
if ($tfvarsContent -match 'create_oracle_database\s*=\s*(true|false)') { $config.create_oracle_db = $Matches[1] -eq 'true' }
if ($tfvarsContent -match 'entra_user_principal_domain\s*=\s*"([^"]+)"') { $config.entra_domain = $Matches[1] }

Write-Success "Configuration loaded"
Write-Host "  Event name: $($config.event_name)" -ForegroundColor Gray
Write-Host "  User count: $($config.user_count)" -ForegroundColor Gray
Write-Host "  Create Oracle DB: $($config.create_oracle_db)" -ForegroundColor Gray
Write-Host "  Entra domain: $($config.entra_domain)" -ForegroundColor Gray
$script:ChecksPassed++

# Validate required configuration
if (-not $config.entra_domain) {
    Write-Warning "entra_user_principal_domain is not set in terraform.tfvars"
    Write-Host "  This variable is required for user creation" -ForegroundColor Gray
    $script:ChecksWarning++
}

# ============================================================================
# 4. Check Subscription Access
# ============================================================================
Write-Host "`n" -NoNewline
Write-Info "Validating subscription access..."

# Get subscriptions from variables.tf default values
$subscriptionIds = @(
    "556f9b63-ebc9-4c7e-8437-9a05aa8cdb25",  # Slot 0
    "a0844269-41ae-442c-8277-415f1283d422",  # Slot 1
    "b1658f1f-33e5-4e48-9401-f66ba5e64cce",  # Slot 2
    "9aa72379-2067-4948-b51c-de59f4005d04",  # Slot 3
    "98525264-1eb4-493f-983d-16a330caa7f6"   # Slot 4
)

$odaaSubscriptionId = "4aecf0e8-2fe2-4187-bc93-0356bd2676f5"

# Test access to all subscriptions
$accessibleSubs = @()
foreach ($subId in $subscriptionIds) {
    try {
        $sub = az account show --subscription $subId 2>&1 | ConvertFrom-Json
        if ($sub) {
            Write-Success "Access to subscription: $($sub.name) ($subId)"
            $accessibleSubs += $subId
            $script:ChecksPassed++
        }
    }
    catch {
        Write-Failure "Cannot access subscription: $subId"
        Write-Host "  Run: az account set --subscription $subId" -ForegroundColor Gray
        $script:ChecksFailed++
    }
}

# Check ODAA subscription
try {
    $odaaSub = az account show --subscription $odaaSubscriptionId 2>&1 | ConvertFrom-Json
    if ($odaaSub) {
        Write-Success "Access to ODAA subscription: $($odaaSub.name)"
        $script:ChecksPassed++
    }
}
catch {
    Write-Failure "Cannot access ODAA subscription: $odaaSubscriptionId"
    $script:ChecksFailed++
}

# ============================================================================
# 5. Check Management Group
# ============================================================================
Write-Host "`n" -NoNewline
Write-Info "Checking management group access..."

try {
    $mg = az account management-group show --name "mhteams" 2>&1 | ConvertFrom-Json
    if ($mg) {
        Write-Success "Management group 'mhteams' exists and is accessible"
        Write-Host "  Display name: $($mg.displayName)" -ForegroundColor Gray
        $script:ChecksPassed++
    }
}
catch {
    Write-Failure "Cannot access management group 'mhteams'"
    Write-Host "  Ensure the management group exists and you have read permissions" -ForegroundColor Gray
    $script:ChecksFailed++
}

# ============================================================================
# 6. Check Oracle Service Principal
# ============================================================================
Write-Host "`n" -NoNewline
Write-Info "Checking Oracle Cloud service principal..."

$oracleSPObjectId = "6240ab05-e243-48b2-9619-c3e3f53c6dca"

try {
    $sp = az ad sp show --id $oracleSPObjectId 2>&1 | ConvertFrom-Json
    if ($sp) {
        Write-Success "Oracle Cloud service principal found"
        Write-Host "  Display name: $($sp.displayName)" -ForegroundColor Gray
        Write-Host "  App ID: $($sp.appId)" -ForegroundColor Gray
        
        # Check for app roles
        if ($sp.appRoles -and $sp.appRoles.Count -gt 0) {
            Write-Success "Service principal has $($sp.appRoles.Count) app role(s) available"
            foreach ($role in $sp.appRoles) {
                if ($role.isEnabled) {
                    Write-Host "    - $($role.displayName) (enabled)" -ForegroundColor Gray
                }
            }
            $script:ChecksPassed++
        }
        else {
            Write-Warning "Service principal has no app roles defined"
            $script:ChecksWarning++
        }
        $script:ChecksPassed++
    }
}
catch {
    Write-Failure "Cannot access Oracle Cloud service principal: $oracleSPObjectId"
    Write-Host "  Ensure the enterprise application is registered in your tenant" -ForegroundColor Gray
    $script:ChecksFailed++
}

# ============================================================================
# 7. Check Resource Provider Registration
# ============================================================================
Write-Host "`n" -NoNewline
Write-Info "Checking resource provider registrations..."

$requiredProviders = @(
    "Microsoft.ContainerService",
    "Microsoft.Network",
    "Microsoft.Compute",
    "Microsoft.OperationalInsights",
    "Oracle.Database",
    "Microsoft.Baremetal"
)

foreach ($subId in $accessibleSubs + $odaaSubscriptionId | Select-Object -Unique) {
    Write-Host "`n  Subscription: $subId" -ForegroundColor Gray
    
    foreach ($provider in $requiredProviders) {
        try {
            $registration = az provider show --namespace $provider --subscription $subId 2>&1 | ConvertFrom-Json
            
            if ($registration.registrationState -eq "Registered") {
                Write-Host "    ✓ $provider" -ForegroundColor Green
            }
            else {
                Write-Warning "$provider is '$($registration.registrationState)' in subscription $subId"
                Write-Host "      Run: az provider register --namespace $provider --subscription $subId" -ForegroundColor Gray
                $script:ChecksWarning++
            }
        }
        catch {
            Write-Warning "Could not check $provider in subscription $subId"
            $script:ChecksWarning++
        }
    }
}

# ============================================================================
# 8. Check Oracle SDN Feature Registration
# ============================================================================
Write-Host "`n" -NoNewline
Write-Info "Checking Oracle SDN feature registration..."

$oracleFeatures = @(
    @{ Namespace = "Microsoft.Baremetal"; Feature = "EnableRotterdamSdnApplianceForOracle" },
    @{ Namespace = "Microsoft.Network"; Feature = "EnableRotterdamSdnApplianceForOracle" }
)

foreach ($subId in $accessibleSubs + $odaaSubscriptionId | Select-Object -Unique) {
    Write-Host "`n  Subscription: $subId" -ForegroundColor Gray
    
    foreach ($featureInfo in $oracleFeatures) {
        try {
            $feature = az feature show `
                --namespace $featureInfo.Namespace `
                --name $featureInfo.Feature `
                --subscription $subId 2>&1 | ConvertFrom-Json
            
            if ($feature.properties.state -eq "Registered") {
                Write-Host "    ✓ $($featureInfo.Namespace)/$($featureInfo.Feature)" -ForegroundColor Green
            }
            else {
                Write-Warning "$($featureInfo.Namespace)/$($featureInfo.Feature) is '$($feature.properties.state)'"
                Write-Host "      Run: az feature register --namespace $($featureInfo.Namespace) --name $($featureInfo.Feature) --subscription $subId" -ForegroundColor Gray
                $script:ChecksWarning++
            }
        }
        catch {
            Write-Warning "Could not check feature $($featureInfo.Feature) in subscription $subId"
            $script:ChecksWarning++
        }
    }
}

# ============================================================================
# 9. Check VM Quota (Optional)
# ============================================================================
if (-not $SkipQuotaCheck) {
    Write-Host "`n" -NoNewline
    Write-Info "Checking VM quota availability..."
    
    $vmFamily = "standardDASv5Family"
    $location = "francecentral"
    $vCPUsPerCluster = 8  # 2 nodes * 4 vCPUs (Standard_D4as_v5)
    
    foreach ($subId in $accessibleSubs) {
        try {
            $quotas = az vm list-usage --location $location --subscription $subId 2>&1 | ConvertFrom-Json
            $quota = $quotas | Where-Object { $_.name.value -eq $vmFamily }
            
            if ($quota) {
                $available = $quota.limit - $quota.currentValue
                $required = $vCPUsPerCluster * [Math]::Ceiling($config.user_count / $accessibleSubs.Count)
                
                Write-Host "`n  Subscription: $subId" -ForegroundColor Gray
                Write-Host "    Current: $($quota.currentValue) / Limit: $($quota.limit) / Available: $available vCPUs" -ForegroundColor Gray
                Write-Host "    Required: ~$required vCPUs (for estimated user allocation)" -ForegroundColor Gray
                
                if ($available -ge $required) {
                    Write-Success "Sufficient quota in subscription $subId"
                    $script:ChecksPassed++
                }
                else {
                    Write-Warning "Potential quota shortage in subscription $subId"
                    Write-Host "      Consider requesting a quota increase" -ForegroundColor Gray
                    $script:ChecksWarning++
                }
            }
            else {
                Write-Warning "Could not retrieve quota for $vmFamily in $location"
                $script:ChecksWarning++
            }
        }
        catch {
            Write-Warning "Failed to check quota in subscription $subId"
            $script:ChecksWarning++
        }
    }
}
else {
    Write-Info "VM quota check skipped (use without -SkipQuotaCheck to enable)"
}

# ============================================================================
# 10. Check users.json File
# ============================================================================
Write-Host "`n" -NoNewline
Write-Info "Validating users.json file..."

$usersJsonPath = "..\users.json"
if (Test-Path $usersJsonPath) {
    try {
        $usersData = Get-Content $usersJsonPath -Raw | ConvertFrom-Json
        $userCount = $usersData.Count
        
        Write-Success "users.json found with $userCount user entries"
        
        # Validate that we have enough users
        if ($userCount -ge $config.user_count) {
            Write-Success "Sufficient user entries ($userCount) for deployment ($($config.user_count) required)"
            $script:ChecksPassed++
        }
        else {
            Write-Failure "Not enough user entries in users.json"
            Write-Host "  Found: $userCount, Required: $($config.user_count)" -ForegroundColor Gray
            $script:ChecksFailed++
        }
        
        # Validate required fields
        $missingFields = @()
        foreach ($user in $usersData) {
            if (-not $user.identifier) { $missingFields += "identifier" }
            if (-not $user.given_name) { $missingFields += "given_name" }
            if (-not $user.surname) { $missingFields += "surname" }
        }
        
        if ($missingFields.Count -eq 0) {
            Write-Success "All user entries have required fields"
            $script:ChecksPassed++
        }
        else {
            Write-Warning "Some user entries missing required fields: $($missingFields -join ', ')"
            $script:ChecksWarning++
        }
    }
    catch {
        Write-Failure "Failed to parse users.json: $($_.Exception.Message)"
        $script:ChecksFailed++
    }
}
else {
    Write-Failure "users.json file not found at $usersJsonPath"
    $script:ChecksFailed++
}

# ============================================================================
# 11. Check Terraform Initialization
# ============================================================================
Write-Host "`n" -NoNewline
Write-Info "Checking Terraform initialization..."

Push-Location ..
try {
    if (Test-Path ".terraform") {
        Write-Success "Terraform is initialized"
        $script:ChecksPassed++
    }
    else {
        Write-Warning "Terraform not initialized"
        Write-Host "  Run: terraform init" -ForegroundColor Gray
        $script:ChecksWarning++
    }
    
    # Try terraform validate
    $validateOutput = terraform validate 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Terraform configuration is valid"
        $script:ChecksPassed++
    }
    else {
        Write-Failure "Terraform validation failed"
        Write-Host "  $validateOutput" -ForegroundColor Gray
        $script:ChecksFailed++
    }
}
finally {
    Pop-Location
}

# ============================================================================
# Summary
# ============================================================================
Write-Host "`n================================================" -ForegroundColor Cyan
Write-Host "Pre-flight Check Summary" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan

Write-Host "`nResults:" -ForegroundColor White
Write-Success "Passed: $script:ChecksPassed"
if ($script:ChecksWarning -gt 0) {
    Write-Warning "Warnings: $script:ChecksWarning"
}
if ($script:ChecksFailed -gt 0) {
    Write-Failure "Failed: $script:ChecksFailed"
}

Write-Host "`n" -NoNewline
if ($script:ChecksFailed -eq 0 -and $script:ChecksWarning -eq 0) {
    Write-Success "All pre-flight checks passed! Ready to deploy."
    Write-Host "`nNext steps:" -ForegroundColor Cyan
    Write-Host "  1. Review your terraform.tfvars configuration" -ForegroundColor Gray
    Write-Host "  2. Run: terraform plan -out tfplan" -ForegroundColor Gray
    Write-Host "  3. Review the plan carefully" -ForegroundColor Gray
    Write-Host "  4. Run: terraform apply tfplan" -ForegroundColor Gray
    exit 0
}
elseif ($script:ChecksFailed -eq 0) {
    Write-Warning "Pre-flight checks completed with warnings."
    Write-Host "`nYou may proceed with caution. Review warnings above." -ForegroundColor Yellow
    exit 0
}
else {
    Write-Failure "Pre-flight checks failed."
    Write-Host "`nPlease address the failures above before proceeding." -ForegroundColor Red
    exit 1
}
