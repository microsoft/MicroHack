<#
.SYNOPSIS
    Create a custom "Deployment Validator" RBAC role and assign it to a group along with Security Reader role.

.DESCRIPTION
    This script is intended for MicroHack coaches who are preparing pre-provisioned Azure subscriptions
    for lab participants. It automates the setup of appropriate RBAC permissions for lab users.

    The script creates a custom Azure RBAC role that allows users to validate ARM/Bicep deployments
    without granting full deployment permissions. It then assigns both this custom role and the
    built-in Security Reader role to a specified Entra ID group.

    The custom "Deployment Validator" role includes permissions to:
    - Validate ARM/Bicep deployments
    - Read deployment information
    - Read resource group information

    The Security Reader role provides read-only access to security-related resources and settings.

    This setup ensures lab participants have the necessary permissions to complete MicroHack exercises
    while maintaining appropriate security boundaries in pre-provisioned subscriptions.

.PARAMETER GroupName
    The display name of the Entra ID group to assign the roles to (default: "LabUsers")

.PARAMETER SubscriptionId
    The Azure subscription ID where the role should be created and assigned.
    If not provided, you will be prompted to select from available subscriptions.

.EXAMPLE
    .\3-rbac.ps1
    Prompts for subscription selection and uses the default group name "LabUsers"

.EXAMPLE
    .\3-rbac.ps1 -GroupName "MicroHackUsers"
    Prompts for subscription selection and uses the specified group name

.EXAMPLE
    .\3-rbac.ps1 -GroupName "LabUsers" -SubscriptionId "12345678-1234-1234-1234-123456789012"
    Uses the specified subscription and group name without prompting

.NOTES
    Author: MicroHack Team
    Date: November 2025

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
Write-Host "This script will create a custom 'Deployment Validator' role and assign RBAC permissions." -ForegroundColor Gray
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

        # Get all available subscriptions
        $subscriptions = Get-AzSubscription | Sort-Object Name

        if ($subscriptions.Count -eq 0) {
            Write-Error "No subscriptions found. Please ensure you have access to at least one subscription."
            exit 1
        }

        # Display subscriptions
        Write-Host "`nAvailable Subscriptions:" -ForegroundColor Yellow
        for ($i = 0; $i -lt $subscriptions.Count; $i++) {
            $sub = $subscriptions[$i]
            $current = if ($sub.Id -eq (Get-AzContext).Subscription.Id) { " (current)" } else { "" }
            Write-Host ("  {0,2}. {1} ({2}){3}" -f ($i + 1), $sub.Name, $sub.Id, $current) -ForegroundColor Gray
        }

        Write-Host "`nOptions:" -ForegroundColor Cyan
        Write-Host "  - Enter a number to select a subscription"
        Write-Host "  - Press Enter to use the current subscription"

        $selection = Read-Host "`nYour selection"

        if ([string]::IsNullOrWhiteSpace($selection)) {
            # Use current subscription
            $selectedSub = $subscriptions | Where-Object { $_.Id -eq (Get-AzContext).Subscription.Id }
            if (-not $selectedSub) {
                $selectedSub = $subscriptions[0]
            }
        } else {
            # Parse selection
            if ($selection -match '^\d+$') {
                $idx = [int]$selection - 1
                if ($idx -ge 0 -and $idx -lt $subscriptions.Count) {
                    $selectedSub = $subscriptions[$idx]
                } else {
                    Write-Error "Invalid selection: $selection (out of range)"
                    exit 1
                }
            } else {
                Write-Error "Invalid selection: $selection (not a number)"
                exit 1
            }
        }

        Write-Host "`nSelected Subscription: $($selectedSub.Name) ($($selectedSub.Id))" -ForegroundColor Green
        return $selectedSub.Id
    } else {
        # Validate provided subscription ID
        $sub = Get-AzSubscription -SubscriptionId $SubId -ErrorAction SilentlyContinue
        if (-not $sub) {
            Write-Error "Subscription ID '$SubId' not found or you don't have access to it."
            exit 1
        }
        Write-Host "`nUsing Subscription: $($sub.Name) ($($sub.Id))" -ForegroundColor Green
        return $SubId
    }
}

# Select subscription
$subId = Select-AzureSubscription -SubId $SubscriptionId

# Set context to selected subscription
Set-AzContext -SubscriptionId $subId | Out-Null

# Get group object ID
Write-Host "`nLooking up Entra ID group: '$GroupName'..." -ForegroundColor Cyan

try {
    # Ensure we're connected to Microsoft Graph
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

# Create the role definition from JSON
$tmp = Join-Path $env:TEMP "deployment-validator-role.json"
$role | ConvertTo-Json -Depth 10 | Set-Content -Path $tmp -Encoding UTF8

# Check if role already exists (suppress warnings about delays)
Write-Verbose "Checking if role 'Deployment Validator' already exists..."

# Try to get all role definitions with this name (may exist in different scopes)
$allRolesWithName = Get-AzRoleDefinition -Name "Deployment Validator" -ErrorAction SilentlyContinue -WarningAction SilentlyContinue

if ($allRolesWithName) {
    # Role exists - check if it includes this subscription in assignable scopes
    Write-Host "Custom role 'Deployment Validator' already exists." -ForegroundColor Yellow
    Write-Verbose "Role ID: $($allRolesWithName.Id)"
    Write-Verbose "Assignable Scopes: $($allRolesWithName.AssignableScopes -join ', ')"

    # Check if this subscription is in the assignable scopes
    if ($allRolesWithName.AssignableScopes -notcontains "/subscriptions/$subId") {
        Write-Warning "The existing role does not include this subscription in its assignable scopes."
        Write-Host "Current assignable scopes: $($allRolesWithName.AssignableScopes -join ', ')" -ForegroundColor Yellow
        Write-Host "Attempting to update the role to include this subscription..." -ForegroundColor Cyan

        try {
            # Add this subscription to assignable scopes
            $updatedScopes = $allRolesWithName.AssignableScopes + @("/subscriptions/$subId")
            $allRolesWithName.AssignableScopes = $updatedScopes

            Set-AzRoleDefinition -Role $allRolesWithName | Out-Null
            Write-Host "Successfully updated role to include this subscription." -ForegroundColor Green

            # Re-query to get updated role
            Start-Sleep -Seconds 5
            $existingRole = Get-AzRoleDefinition -Name "Deployment Validator" -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
        } catch {
            Write-Warning "Failed to update role definition: $($_.Exception.Message)"
            Write-Host "You may need to manually update the role or delete and recreate it." -ForegroundColor Yellow
            $existingRole = $allRolesWithName
        }
    } else {
        Write-Host "Role is already configured for this subscription." -ForegroundColor Green
        $existingRole = $allRolesWithName
    }
} else {
    try {
        Write-Host "Creating new custom role..." -ForegroundColor Gray
        $newRole = New-AzRoleDefinition -InputFile $tmp -ErrorAction Stop

        # Only show success if we actually created it
        Write-Host "Custom role 'Deployment Validator' created successfully." -ForegroundColor Green
        Write-Verbose "Role ID: $($newRole.Id)"

        # Wait a moment for role to propagate
        Write-Host "Waiting for role to propagate..." -ForegroundColor Gray
        Start-Sleep -Seconds 10

        # Update the existingRole variable for later use
        $existingRole = $newRole
    } catch {
        # Check if it's a conflict error (role already exists)
        if ($_.Exception.Message -like "*Conflict*" -or $_.Exception.Message -like "*RoleDefinitionAlreadyExists*") {
            Write-Host "Custom role 'Deployment Validator' already exists (detected during creation)." -ForegroundColor Yellow

            # Retry getting the existing role with multiple attempts (Azure replication delay)
            Write-Host "Retrieving existing role definition and updating assignable scopes..." -ForegroundColor Gray
            $maxRetries = 5
            $retryCount = 0

            while (-not $existingRole -and $retryCount -lt $maxRetries) {
                Start-Sleep -Seconds 3
                $retryCount++
                Write-Verbose "Attempt $retryCount of $maxRetries to retrieve role..."

                # Try method 1: Direct query by name
                $existingRole = Get-AzRoleDefinition -Name "Deployment Validator" -ErrorAction SilentlyContinue -WarningAction SilentlyContinue

                if (-not $existingRole) {
                    # Try method 2: Search in all accessible subscriptions
                    Write-Verbose "Searching across all accessible subscriptions..."
                    $allSubscriptions = Get-AzSubscription -ErrorAction SilentlyContinue

                    foreach ($sub in $allSubscriptions) {
                        if ($existingRole) { break }

                        try {
                            $tempContext = Set-AzContext -SubscriptionId $sub.Id -ErrorAction SilentlyContinue
                            $roleInSub = Get-AzRoleDefinition -Name "Deployment Validator" -ErrorAction SilentlyContinue -WarningAction SilentlyContinue

                            if ($roleInSub) {
                                $existingRole = $roleInSub
                                Write-Host "Found role in subscription: $($sub.Name)" -ForegroundColor Yellow
                                Write-Host "Role ID: $($existingRole.Id)" -ForegroundColor Gray
                                Write-Host "Current scopes: $($existingRole.AssignableScopes -join ', ')" -ForegroundColor Gray
                                break
                            }
                        } catch {
                            Write-Verbose "Could not check subscription $($sub.Name): $($_.Exception.Message)"
                        }
                    }

                    # Switch back to target subscription
                    Set-AzContext -SubscriptionId $subId -ErrorAction SilentlyContinue | Out-Null
                }
            }

            if ($existingRole) {
                # Check if this subscription is in assignable scopes
                if ($existingRole.AssignableScopes -notcontains "/subscriptions/$subId") {
                    Write-Host "Updating role to include this subscription in assignable scopes..." -ForegroundColor Cyan

                    try {
                        # Add this subscription to assignable scopes
                        if ($existingRole.AssignableScopes -is [System.Collections.Generic.List[string]]) {
                            $existingRole.AssignableScopes.Add("/subscriptions/$subId")
                        } else {
                            $existingRole.AssignableScopes = @($existingRole.AssignableScopes) + @("/subscriptions/$subId")
                        }

                        Write-Verbose "New assignable scopes: $($existingRole.AssignableScopes -join ', ')"

                        Set-AzRoleDefinition -Role $existingRole -ErrorAction Stop | Out-Null
                        Write-Host "Successfully updated role to include this subscription." -ForegroundColor Green
                        Write-Host "Waiting for updates to propagate..." -ForegroundColor Gray
                        Start-Sleep -Seconds 15

                        # Re-query to confirm the update
                        $existingRole = Get-AzRoleDefinition -Name "Deployment Validator" -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
                        if ($existingRole) {
                            Write-Host "Role successfully retrieved after update." -ForegroundColor Green
                            Write-Verbose "Updated scopes: $($existingRole.AssignableScopes -join ', ')"
                        }
                    } catch {
                        Write-Warning "Could not update role: $($_.Exception.Message)"
                        Write-Host "You may need to manually add '/subscriptions/$subId' to the role's assignable scopes." -ForegroundColor Yellow
                    }
                } else {
                    Write-Host "Successfully retrieved existing role definition." -ForegroundColor Green
                    Write-Verbose "Role ID: $($existingRole.Id)"
                    Write-Verbose "Assignable Scopes: $($existingRole.AssignableScopes -join ', ')"
                }
            } else {
                Write-Warning "Could not retrieve the existing role definition after $maxRetries attempts."
                Write-Host "Attempting to proceed with role assignment anyway..." -ForegroundColor Yellow
            }
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
    $assignmentSuccess = $false
    $maxAssignmentRetries = 5
    $assignmentRetryCount = 0

    while (-not $assignmentSuccess -and $assignmentRetryCount -lt $maxAssignmentRetries) {
        try {
            $assignmentRetryCount++
            if ($assignmentRetryCount -gt 1) {
                Write-Host "Retry attempt $assignmentRetryCount of $maxAssignmentRetries..." -ForegroundColor Gray
                Start-Sleep -Seconds 5
            }

            # Try to assign by name first
            if ($existingRole -and $existingRole.Id) {
                # If we have the role object, use the ID for more reliable assignment
                Write-Verbose "Assigning role using ID: $($existingRole.Id)"
                New-AzRoleAssignment `
                    -ObjectId $objectId `
                    -RoleDefinitionId $existingRole.Id `
                    -Scope "/subscriptions/$subId" `
                    -ErrorAction Stop | Out-Null
            } else {
                # Fall back to name-based assignment
                Write-Verbose "Assigning role using name: Deployment Validator"
                New-AzRoleAssignment `
                    -ObjectId $objectId `
                    -RoleDefinitionName "Deployment Validator" `
                    -Scope "/subscriptions/$subId" `
                    -ErrorAction Stop | Out-Null
            }

            Write-Host "'Deployment Validator' role assigned successfully." -ForegroundColor Green
            $assignmentSuccess = $true
        } catch {
            if ($_.Exception.Message -like "*Cannot find role definition*" -or $_.Exception.Message -like "*does not exist*") {
                if ($assignmentRetryCount -lt $maxAssignmentRetries) {
                    Write-Host "Role definition not yet available, waiting..." -ForegroundColor Yellow

                    # Try to find the role using alternative methods
                    if (-not $existingRole) {
                        Write-Verbose "Attempting to locate role definition..."
                        $allCustomRoles = Get-AzRoleDefinition -Custom -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
                        $existingRole = $allCustomRoles | Where-Object { $_.Name -eq "Deployment Validator" } | Select-Object -First 1

                        if ($existingRole) {
                            Write-Host "Found role definition, will retry with role ID." -ForegroundColor Green
                            Write-Verbose "Role ID: $($existingRole.Id)"
                        }
                    }
                } else {
                    Write-Error "Failed to assign 'Deployment Validator' role after $maxAssignmentRetries attempts: Role definition not found."
                    Write-Host "This may be due to the role existing in a different subscription's scope." -ForegroundColor Yellow
                    Write-Host "Try manually checking the role's assignable scopes in the Azure Portal under 'Access Control (IAM) > Roles'." -ForegroundColor Yellow
                }
            } else {
                Write-Error "Failed to assign 'Deployment Validator' role: $($_.Exception.Message)"
                break
            }
        }
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
