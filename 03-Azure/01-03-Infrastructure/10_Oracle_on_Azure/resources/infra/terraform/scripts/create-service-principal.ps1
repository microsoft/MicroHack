#!/usr/bin/env pwsh
<#
.SYNOPSIS
Creates a Service Principal with the necessary permissions to deploy the Oracle on Azure Microhack infrastructure.

.DESCRIPTION
This script automates the creation of an Azure Service Principal and grants it the required roles
across all necessary subscriptions and the Entra ID tenant.

The script assigns the following roles:
- Contributor: On all AKS and ODAA subscriptions to create and manage resources.
- User Access Administrator: On all AKS and ODAA subscriptions to manage role assignments.
- User Administrator (Entra ID): To create and manage the user accounts for the microhack.
- Application Administrator (Entra ID): To assign the Oracle Cloud enterprise app role.

.EXAMPLE
./create-service-principal.ps1 -OutputPath ./mhodaa-sp-credentials.json
#>

[CmdletBinding()]
param(
    [string]$ServicePrincipalName = "mhodaa-sp",
    [string]$OutputPath = "./mhodaa-sp-credentials.json"
)

$ErrorActionPreference = "Stop"

# ===============================================================================
# Helper Functions
# ===============================================================================

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "[ OK ] $Message" -ForegroundColor Green
}

function Write-WarningMessage {
    param([string]$Message)
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Write-Error-Message {
    param([string]$Message)
    Write-Host "[FAIL] $Message" -ForegroundColor Red
}

function Invoke-AzCommand {
    param(
        [string[]]$Arguments,
        [switch]$AllowFailure
    )
    $commandString = "az $($Arguments -join ' ')"
    Write-Info "Executing: $commandString"
    $output = az @Arguments 2>&1

    if ($LASTEXITCODE -ne 0) {
        $errorMessage = "Command '$commandString' failed: $output"
        if ($AllowFailure) {
            Write-WarningMessage $errorMessage
            return $null
        }
        else {
            throw $errorMessage
        }
    }
    return $output
}

function Get-ServicePrincipal {
    param(
        [string]$Identifier,
        [int]$RetryCount = 6,
        [int]$DelaySeconds = 5
    )

    for ($attempt = 1; $attempt -le $RetryCount; $attempt++) {
        $spJson = Invoke-AzCommand -Arguments @(
            "ad", "sp", "show",
            "--id", $Identifier,
            "--only-show-errors",
            "-o", "json"
        ) -AllowFailure

        if ($spJson) {
            return $spJson | ConvertFrom-Json
        }

        if ($attempt -lt $RetryCount) {
            Write-Info "Awaiting service principal propagation ($attempt/$RetryCount)..."
            Start-Sleep -Seconds $DelaySeconds
        }
    }

    return $null
}

# ===============================================================================
# Pre-flight Checks
# ===============================================================================

if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    Write-Error-Message "Azure CLI not found. Please install it and ensure it's in your PATH."
    exit 1
}

try {
    $currentUser = Invoke-AzCommand -Arguments @("account", "show", "-o", "json") | ConvertFrom-Json
    Write-Info "Logged in as '$($currentUser.user.name)'."
}
catch {
    Write-WarningMessage "You are not logged into Azure. Please run 'az login' and try again."
    exit 1
}

# ===============================================================================
# Main Logic
# ===============================================================================

# 1. Define Management Groups
$managementGroups = @("mhodaa", "mhteams")
Write-Info "Targeting management groups: $($managementGroups -join ', ')"

# 2. Create or Reuse the Service Principal
$spName = $ServicePrincipalName
$spIdentifier = if ($spName -like "http://*") { $spName } else { "http://$spName" }

$existingSp = Get-ServicePrincipal -Identifier $spIdentifier -RetryCount 1

if ($existingSp) {
    Write-WarningMessage "Service Principal '$spName' already exists. Resetting credentials..."
    $spCredentialJson = Invoke-AzCommand -Arguments @(
        "ad", "sp", "credential", "reset",
        "--id", $spIdentifier,
        "--only-show-errors",
        "-o", "json"
    )
    $spCredential = $spCredentialJson | ConvertFrom-Json
    Write-Success "Credentials reset for Service Principal '$spName'."
    $spDetails = $existingSp
}
else {
    Write-Info "Creating Service Principal named '$spName'..."
    $spCredentialJson = Invoke-AzCommand -Arguments @(
        "ad", "sp", "create-for-rbac",
        "--name", $spIdentifier,
        "--skip-assignment",
        "--only-show-errors",
        "-o", "json"
    )
    $spCredential = $spCredentialJson | ConvertFrom-Json
    Write-Success "Service Principal created with App ID $($spCredential.appId)."

    # Query by appId instead of display name to avoid propagation issues
    $spDetails = Get-ServicePrincipal -Identifier $spCredential.appId -RetryCount 8 -DelaySeconds 5
    if (-not $spDetails) {
        throw "Service Principal '$spName' was created but is not yet available. Please rerun the script in a few moments."
    }
}

if (-not $spDetails) {
    $spDetails = Get-ServicePrincipal -Identifier $spIdentifier -RetryCount 3 -DelaySeconds 5
}

if (-not $spCredential.password) {
    throw "Failed to retrieve a client secret for Service Principal '$spName'."
}

$sp = [PSCustomObject]@{
    displayName = $spDetails.displayName
    appId       = $spDetails.appId
    objectId    = $spDetails.id
    password    = $spCredential.password
    tenant      = $spCredential.tenant
}

# 3. Assign Roles on Management Groups
Write-Info "Assigning 'Contributor' and 'User Access Administrator' roles on target management groups..."
foreach ($mg in $managementGroups) {
    Write-Info "Processing Management Group: $mg"
    
    $mgId = (Invoke-AzCommand -Arguments @("account", "management-group", "show", "-n", $mg, "--query", "id", "-o", "tsv"))
    if (-not $mgId) {
        Write-WarningMessage "Could not find management group '$mg'. Skipping role assignments."
        continue
    }

    # Assign Contributor
    Invoke-AzCommand -Arguments @(
        "role", "assignment", "create",
        "--assignee", $sp.appId,
        "--role", "Contributor",
        "--scope", $mgId
    ) -AllowFailure | Out-Null

    # Assign User Access Administrator
    Invoke-AzCommand -Arguments @(
        "role", "assignment", "create",
        "--assignee", $sp.appId,
        "--role", "User Access Administrator",
        "--scope", $mgId
    ) -AllowFailure | Out-Null

    Write-Success "Roles assigned for management group $mg."
}

# 4. Grant Entra ID (Graph API) permissions
Write-Info "Granting Microsoft Entra ID permissions..."

$tempDir = [System.IO.Path]::GetTempPath()

# User Administrator role assignment
$userAdminPayload = @{
    "@odata.type"      = "#microsoft.graph.unifiedRoleAssignment"
    roleDefinitionId    = "fe930be7-5e62-47db-91af-98c3a49a38b1"
    principalId         = $sp.objectId
    directoryScopeId    = "/"
}
$userAdminFile = Join-Path $tempDir "user-admin-payload.json"
$userAdminPayload | ConvertTo-Json -Depth 10 | Set-Content -Path $userAdminFile -Encoding UTF8

Invoke-AzCommand -Arguments @(
    "rest",
    "--method", "POST",
    "--uri", "https://graph.microsoft.com/v1.0/roleManagement/directory/roleAssignments",
    "--body", "@$userAdminFile"
) -AllowFailure | Out-Null
Remove-Item -Path $userAdminFile -Force -ErrorAction SilentlyContinue
Write-Success "Granted 'User Administrator' role."

# Application Administrator role assignment
$appAdminPayload = @{
    "@odata.type"      = "#microsoft.graph.unifiedRoleAssignment"
    roleDefinitionId    = "9b895d92-2cd3-44c7-9d02-a6ac2d5ea5c3"
    principalId         = $sp.objectId
    directoryScopeId    = "/"
}
$appAdminFile = Join-Path $tempDir "app-admin-payload.json"
$appAdminPayload | ConvertTo-Json -Depth 10 | Set-Content -Path $appAdminFile -Encoding UTF8

Invoke-AzCommand -Arguments @(
    "rest",
    "--method", "POST",
    "--uri", "https://graph.microsoft.com/v1.0/roleManagement/directory/roleAssignments",
    "--body", "@$appAdminFile"
) -AllowFailure | Out-Null
Remove-Item -Path $appAdminFile -Force -ErrorAction SilentlyContinue
Write-Success "Granted 'Application Administrator' role."

# Grant Microsoft Graph API Application Permissions
Write-Info "Granting Microsoft Graph API application permissions..."

# Get Microsoft Graph Service Principal ID
$graphSpId = "5d31879b-d3a0-4d61-b4c1-a43c76e8acb4"  # Well-known Graph SP ID, but verify it exists
$graphSp = Invoke-AzCommand -Arguments @(
    "ad", "sp", "show",
    "--id", "00000003-0000-0000-c000-000000000000",
    "--query", "id",
    "-o", "tsv",
    "--only-show-errors"
) -AllowFailure

if ($graphSp) {
    $graphSpId = $graphSp.Trim()
}

# User.ReadWrite.All permission
$userReadWritePayload = @{
    principalId = $sp.objectId
    resourceId  = $graphSpId
    appRoleId   = "741f803b-c850-494e-b5df-cde7c675a1ca"  # User.ReadWrite.All
}
$userReadWriteFile = Join-Path $tempDir "user-readwrite-payload.json"
$userReadWritePayload | ConvertTo-Json -Depth 10 | Set-Content -Path $userReadWriteFile -Encoding UTF8

Invoke-AzCommand -Arguments @(
    "rest",
    "--method", "POST",
    "--uri", "https://graph.microsoft.com/v1.0/servicePrincipals/$($sp.objectId)/appRoleAssignments",
    "--body", "@$userReadWriteFile",
    "--headers", "Content-Type=application/json"
) -AllowFailure | Out-Null
Remove-Item -Path $userReadWriteFile -Force -ErrorAction SilentlyContinue
Write-Success "Granted 'User.ReadWrite.All' Graph API permission."

# AppRoleAssignment.ReadWrite.All permission
$appRoleAssignmentPayload = @{
    principalId = $sp.objectId
    resourceId  = $graphSpId
    appRoleId   = "06b708a9-e830-4db3-a914-8e69da51d44f"  # AppRoleAssignment.ReadWrite.All
}
$appRoleAssignmentFile = Join-Path $tempDir "approleassignment-readwrite-payload.json"
$appRoleAssignmentPayload | ConvertTo-Json -Depth 10 | Set-Content -Path $appRoleAssignmentFile -Encoding UTF8

Invoke-AzCommand -Arguments @(
    "rest",
    "--method", "POST",
    "--uri", "https://graph.microsoft.com/v1.0/servicePrincipals/$($sp.objectId)/appRoleAssignments",
    "--body", "@$appRoleAssignmentFile",
    "--headers", "Content-Type=application/json"
) -AllowFailure | Out-Null
Remove-Item -Path $appRoleAssignmentFile -Force -ErrorAction SilentlyContinue
Write-Success "Granted 'AppRoleAssignment.ReadWrite.All' Graph API permission."

# 5. Persist the credentials to disk
$outputDirectory = Split-Path -Path $OutputPath -Parent
if ($outputDirectory -and -not (Test-Path -Path $outputDirectory)) {
    Write-Info "Creating output directory '$outputDirectory'."
    New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
}

$credentialOutput = @{
    clientId     = $sp.appId
    clientSecret = $sp.password
    tenantId     = $sp.tenant
    createdAtUtc = (Get-Date).ToUniversalTime().ToString("o")
    servicePrincipal = $sp.displayName
}

$credentialJson = $credentialOutput | ConvertTo-Json -Compress
Set-Content -Path $OutputPath -Value $credentialJson -Encoding UTF8NoBOM
Write-Success "Credential details written to '$OutputPath'."

# 6. Verify Role Assignments
Write-Info "Verifying role assignments..."

# Verify Azure RBAC roles
$azureRoles = @()
foreach ($mg in $managementGroups) {
    $mgScope = "/providers/Microsoft.Management/managementGroups/$mg"
    $assignments = Invoke-AzCommand -Arguments @(
        "role", "assignment", "list",
        "--assignee", $sp.appId,
        "--scope", $mgScope,
        "--only-show-errors",
        "-o", "json"
    ) -AllowFailure
    
    if ($assignments) {
        $roleList = $assignments | ConvertFrom-Json
        foreach ($role in $roleList) {
            $azureRoles += [PSCustomObject]@{
                Role = $role.roleDefinitionName
                Scope = $mg
            }
        }
    }
}

# Verify Entra ID directory roles
$entraRoles = @()
$roleAssignmentsJson = Invoke-AzCommand -Arguments @(
    "rest",
    "--method", "GET",
    "--uri", "https://graph.microsoft.com/v1.0/roleManagement/directory/roleAssignments?`$filter=principalId eq '$($sp.objectId)'",
    "--only-show-errors"
) -AllowFailure

if ($roleAssignmentsJson) {
    $roleAssignments = ($roleAssignmentsJson | ConvertFrom-Json).value
    foreach ($assignment in $roleAssignments) {
        $roleName = switch ($assignment.roleDefinitionId) {
            "fe930be7-5e62-47db-91af-98c3a49a38b1" { "User Administrator" }
            "9b895d92-2cd3-44c7-9d02-a6ac2d5ea5c3" { "Application Administrator" }
            default { $assignment.roleDefinitionId }
        }
        $entraRoles += $roleName
    }
}

# Verify Microsoft Graph API app role assignments
$graphApiPermissions = @()
$appRoleAssignmentsJson = Invoke-AzCommand -Arguments @(
    "rest",
    "--method", "GET",
    "--uri", "https://graph.microsoft.com/v1.0/servicePrincipals/$($sp.objectId)/appRoleAssignments",
    "--only-show-errors"
) -AllowFailure

if ($appRoleAssignmentsJson) {
    $appRoleAssignments = ($appRoleAssignmentsJson | ConvertFrom-Json).value
    foreach ($assignment in $appRoleAssignments) {
        $permissionName = switch ($assignment.appRoleId) {
            "741f803b-c850-494e-b5df-cde7c675a1ca" { "User.ReadWrite.All" }
            "06b708a9-e830-4db3-a914-8e69da51d44f" { "AppRoleAssignment.ReadWrite.All" }
            default { $assignment.appRoleId }
        }
        $graphApiPermissions += $permissionName
    }
}

# 7. Output the results
Write-Host "
===============================================================================
Service Principal Created Successfully
===============================================================================
" -ForegroundColor Green

Write-Host "Service Principal Details:" -ForegroundColor Cyan
Write-Host "  Name:      $($sp.displayName)"
Write-Host "  Client ID: $($sp.appId)"
Write-Host "  Tenant ID: $($sp.tenant)"
Write-Host ""

Write-Host "Azure RBAC Roles:" -ForegroundColor Cyan
if ($azureRoles.Count -gt 0) {
    foreach ($role in $azureRoles) {
        Write-Host "  ✓ $($role.Role) ($($role.Scope) management group)" -ForegroundColor Green
    }
} else {
    Write-Host "  ⚠ No Azure RBAC roles verified" -ForegroundColor Yellow
}
Write-Host ""

Write-Host "Entra ID Directory Roles:" -ForegroundColor Cyan
if ($entraRoles.Count -gt 0) {
    foreach ($role in $entraRoles) {
        Write-Host "  ✓ $role" -ForegroundColor Green
    }
} else {
    Write-Host "  ⚠ No Entra ID directory roles verified" -ForegroundColor Yellow
}
Write-Host ""

Write-Host "Microsoft Graph API Permissions:" -ForegroundColor Cyan
if ($graphApiPermissions.Count -gt 0) {
    foreach ($permission in $graphApiPermissions) {
        Write-Host "  ✓ $permission" -ForegroundColor Green
    }
} else {
    Write-Host "  ⚠ No Microsoft Graph API permissions verified" -ForegroundColor Yellow
    Write-Host "  ⚠ Graph API permissions are REQUIRED for Terraform to manage Entra ID users" -ForegroundColor Yellow
}
Write-Host ""

Write-Host "Credentials File:" -ForegroundColor Cyan
Write-Host "  $OutputPath" -ForegroundColor Yellow
Write-Host ""

Write-Host "You can now use these credentials to authenticate Terraform.

Option 1: Set as environment variables (Recommended):
"
Write-Host -NoNewline "PowerShell:" -ForegroundColor Magenta
Write-Host "
`$env:TF_VAR_client_id = `"$($sp.appId)`"
`$env:TF_VAR_client_secret = `"$($sp.password)`"
"

Write-Host -NoNewline "Bash/Zsh:" -ForegroundColor Magenta
Write-Host "
export TF_VAR_client_id=`"$($sp.appId)`"
export TF_VAR_client_secret=`"$($sp.password)`"
"
Write-Host "
Option 2: Store the credentials securely in your secrets manager of choice (for example Azure Key Vault) and reference them from your CI/CD pipeline.
"
Write-Host "===============================================================================" -ForegroundColor Green
