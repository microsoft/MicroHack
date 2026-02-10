<#
.SYNOPSIS
    Create a custom "Deployment Validator" RBAC role and assign permissions for MicroHack participants.

.DESCRIPTION
    This script is intended for MicroHack coaches who are preparing Azure subscriptions
    for lab participants. It automates the setup of appropriate RBAC permissions.

    The script creates a custom Azure RBAC role that allows users to validate ARM/Bicep
    deployments without granting full deployment permissions. It then assigns both this
    custom role and the built-in Security Reader role to a specified Entra ID group.

    The custom "Deployment Validator" role includes permissions to:
    - Validate ARM/Bicep deployments
    - Read deployment information
    - Read resource group information

    This setup ensures lab participants have the necessary permissions to complete
    MicroHack exercises while maintaining appropriate security boundaries.

.PARAMETER GroupName
    The display name of the Entra ID group to assign the roles to (default: "LabUsers")

.PARAMETER SubscriptionId
    The Azure subscription ID where the role should be created and assigned.
    If not provided, you will be prompted to select from available subscriptions.

.EXAMPLE
    .\3-rbac.ps1
    Prompts for subscription selection and uses the default group name "LabUsers"

.EXAMPLE
    .\3-rbac.ps1 -GroupName "SovereignCloudLabUsers"
    Prompts for subscription selection and uses the specified group name

.EXAMPLE
    .\3-rbac.ps1 -GroupName "LabUsers" -SubscriptionId "12345678-1234-1234-1234-123456789012"
    Uses the specified subscription and group name without prompting

.NOTES
    Author: MicroHack Team
    Date: January 2026

    Prerequisites:
    - Az.Accounts module
    - Az.Resources module
    - Microsoft.Graph.Groups module (for querying Entra ID groups)
    - Appropriate permissions to create custom roles and assign RBAC roles

.LINK
    https://learn.microsoft.com/azure/role-based-access-control/custom-roles
.LINK
    https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#security-reader
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$GroupName = "LabUsers",

    [Parameter(Mandatory = $false)]
    [string]$SubscriptionId
)

# Ensure required modules are available
$requiredModules = @('Az.Accounts', 'Az.Resources', 'Microsoft.Graph.Groups')
foreach ($module in $requiredModules) {
    if (-not (Get-Module -ListAvailable -Name $module)) {
        Write-Error "$module module is not installed. Please run: Install-Module -Name $module"
        exit 1
    }
}

# Import required modules
Import-Module Az.Accounts, Az.Resources, Microsoft.Graph.Groups -ErrorAction Stop

Write-Host "`n=== RBAC Role Assignment Utility ===" -ForegroundColor Cyan
Write-Host "This script will create a custom 'Deployment Validator' role and assign RBAC permissions."
Write-Host ""

# Check if user is logged in to Azure
try {
    $context = Get-AzContext
    if (-not $context) {
        Write-Host "No Azure context found. Please login..." -ForegroundColor Yellow
        Connect-AzAccount
        $context = Get-AzContext
    } else {
        Write-Host "Using Azure account: $($context.Account.Id)" -ForegroundColor Green
    }
} catch {
    Write-Error "Failed to get Azure context. Please run Connect-AzAccount first."
    exit 1
}

# Function to select subscription
function Select-AzureSubscription {
    param([string]$SubId)

    if ([string]::IsNullOrWhiteSpace($SubId)) {
        Write-Host "`n=== Select Azure Subscription ===" -ForegroundColor Cyan

        $subscriptions = Get-AzSubscription | Sort-Object Name

        if ($subscriptions.Count -eq 0) {
            Write-Error "No subscriptions found."
            exit 1
        }

        Write-Host "`nAvailable Subscriptions:" -ForegroundColor Yellow
        for ($i = 0; $i -lt $subscriptions.Count; $i++) {
            $sub = $subscriptions[$i]
            $current = if ($sub.Id -eq (Get-AzContext).Subscription.Id) { " (current)" } else { "" }
            Write-Host ("  {0,2}. {1} ({2}){3}" -f ($i + 1), $sub.Name, $sub.Id, $current) -ForegroundColor Gray
        }

        $selection = Read-Host "`nEnter selection (or press Enter for current)"

        if ([string]::IsNullOrWhiteSpace($selection)) {
            $selectedSub = $subscriptions | Where-Object { $_.Id -eq (Get-AzContext).Subscription.Id }
            if (-not $selectedSub) { $selectedSub = $subscriptions[0] }
        } else {
            $idx = [int]$selection - 1
            if ($idx -ge 0 -and $idx -lt $subscriptions.Count) {
                $selectedSub = $subscriptions[$idx]
            } else {
                Write-Error "Invalid selection"
                exit 1
            }
        }

        Write-Host "`nSelected Subscription: $($selectedSub.Name)" -ForegroundColor Green
        return $selectedSub.Id
    } else {
        $sub = Get-AzSubscription -SubscriptionId $SubId -ErrorAction SilentlyContinue
        if (-not $sub) {
            Write-Error "Subscription ID '$SubId' not found."
            exit 1
        }
        Write-Host "`nUsing Subscription: $($sub.Name)" -ForegroundColor Green
        return $SubId
    }
}

# Select subscription
$subId = Select-AzureSubscription -SubId $SubscriptionId
Set-AzContext -SubscriptionId $subId | Out-Null

# Get group object ID
Write-Host "`nLooking up Entra ID group: '$GroupName'..." -ForegroundColor Cyan

try {
    $mgContext = Get-MgContext -ErrorAction SilentlyContinue
    if (-not $mgContext) {
        Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Yellow
        Connect-MgGraph -Scopes "Group.Read.All" -NoWelcome
    }

    $group = Get-MgGroup -Filter "DisplayName eq '$GroupName'" -ErrorAction Stop

    if (-not $group) {
        Write-Error "Group '$GroupName' not found in Entra ID. Please verify the group name."
        exit 1
    }

    if ($group -is [array] -and $group.Count -gt 1) {
        Write-Warning "Multiple groups found with name '$GroupName'. Using the first one."
        $group = $group[0]
    }

    $objectId = $group.Id
    Write-Host "Found group: $($group.DisplayName) (Object ID: $objectId)" -ForegroundColor Green

} catch {
    Write-Error "Failed to query Entra ID group: $($_.Exception.Message)"
    exit 1
}

# Define the custom role
Write-Host "`nCreating custom 'Deployment Validator' role definition..." -ForegroundColor Cyan

$role = [pscustomobject]@{
    Name             = "Deployment Validator"
    IsCustom         = $true
    Description      = "Can validate ARM/Bicep deployments without full deployment permissions."
    Actions          = @(
        "Microsoft.Resources/deployments/validate/action",
        "Microsoft.Resources/deployments/read",
        "Microsoft.Resources/subscriptions/resourceGroups/read"
    )
    NotActions       = @()
    DataActions      = @()
    NotDataActions   = @()
    AssignableScopes = @("/subscriptions/$subId")
}

$tmp = Join-Path $env:TEMP "deployment-validator-role.json"
$role | ConvertTo-Json -Depth 10 | Set-Content -Path $tmp -Encoding UTF8

# Check if role already exists
$existingRole = Get-AzRoleDefinition -Name "Deployment Validator" -ErrorAction SilentlyContinue -WarningAction SilentlyContinue

if ($existingRole) {
    Write-Host "Custom role 'Deployment Validator' already exists." -ForegroundColor Yellow

    if ($existingRole.AssignableScopes -notcontains "/subscriptions/$subId") {
        Write-Host "Updating role to include this subscription..." -ForegroundColor Cyan
        try {
            $existingRole.AssignableScopes = @($existingRole.AssignableScopes) + @("/subscriptions/$subId")
            Set-AzRoleDefinition -Role $existingRole | Out-Null
            Write-Host "Role updated successfully." -ForegroundColor Green
            Start-Sleep -Seconds 10
        } catch {
            Write-Warning "Could not update role: $($_.Exception.Message)"
        }
    }
} else {
    try {
        Write-Host "Creating new custom role..." -ForegroundColor Gray
        $newRole = New-AzRoleDefinition -InputFile $tmp -ErrorAction Stop
        Write-Host "Custom role 'Deployment Validator' created successfully." -ForegroundColor Green
        Start-Sleep -Seconds 10
        $existingRole = $newRole
    } catch {
        if ($_.Exception.Message -like "*Conflict*" -or $_.Exception.Message -like "*RoleDefinitionAlreadyExists*") {
            Write-Host "Role already exists (detected during creation)." -ForegroundColor Yellow
            Start-Sleep -Seconds 5
            $existingRole = Get-AzRoleDefinition -Name "Deployment Validator" -ErrorAction SilentlyContinue
        } else {
            Write-Error "Failed to create custom role: $($_.Exception.Message)"
            exit 1
        }
    }
}

# Assign the custom role
Write-Host "`nAssigning 'Deployment Validator' role to group '$GroupName'..." -ForegroundColor Cyan

$existingAssignment = Get-AzRoleAssignment -ObjectId $objectId -RoleDefinitionName "Deployment Validator" -Scope "/subscriptions/$subId" -ErrorAction SilentlyContinue

if ($existingAssignment) {
    Write-Host "Group already has 'Deployment Validator' role assigned." -ForegroundColor Yellow
} else {
    try {
        New-AzRoleAssignment `
            -ObjectId $objectId `
            -RoleDefinitionName "Deployment Validator" `
            -Scope "/subscriptions/$subId" | Out-Null
        Write-Host "'Deployment Validator' role assigned successfully." -ForegroundColor Green
    } catch {
        Write-Error "Failed to assign 'Deployment Validator' role: $($_.Exception.Message)"
    }
}

# Assign the Security Reader role
Write-Host "`nAssigning 'Security Reader' role to group '$GroupName'..." -ForegroundColor Cyan

$existingSecurityReaderAssignment = Get-AzRoleAssignment -ObjectId $objectId -RoleDefinitionName "Security Reader" -Scope "/subscriptions/$subId" -ErrorAction SilentlyContinue

if ($existingSecurityReaderAssignment) {
    Write-Host "Group already has 'Security Reader' role assigned." -ForegroundColor Yellow
} else {
    try {
        New-AzRoleAssignment `
            -ObjectId $objectId `
            -RoleDefinitionName "Security Reader" `
            -Scope "/subscriptions/$subId" | Out-Null
        Write-Host "'Security Reader' role assigned successfully." -ForegroundColor Green
    } catch {
        Write-Error "Failed to assign 'Security Reader' role: $($_.Exception.Message)"
    }
}

# Display summary
Write-Host "`n" + ("=" * 80) -ForegroundColor Cyan
Write-Host "SUMMARY" -ForegroundColor Cyan
Write-Host ("=" * 80) -ForegroundColor Cyan
Write-Host "Subscription       : $((Get-AzSubscription -SubscriptionId $subId).Name)" -ForegroundColor Gray
Write-Host "Subscription ID    : $subId" -ForegroundColor Gray
Write-Host "Group Name         : $GroupName" -ForegroundColor Gray
Write-Host "Group Object ID    : $objectId" -ForegroundColor Gray
Write-Host ""
Write-Host "Roles Assigned:" -ForegroundColor Yellow
Write-Host "  1. Deployment Validator (Custom)" -ForegroundColor Green
Write-Host "  2. Security Reader (Built-in)" -ForegroundColor Green
Write-Host ""
Write-Host "Configuration complete!" -ForegroundColor Green
