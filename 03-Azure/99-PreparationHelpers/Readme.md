# Prepare the MH environments

The [Create Admin Users.ps1](../99-PreparationHelpers/Create%20Admin%20Users.ps1) and [Create MH Users.ps1](../99-PreparationHelpers/Create%20Admin%20Users.ps1) PowerShell scripts can be used to prepare a Multi-MicroHack environment.

# Create Admin Users.ps1

This script will perform the following actions:

- Create 10 EntraID user accounts that will be used as dedicated Admin accounts for seperate MicroHacks
- Create 6 EntraID groups that can be used to assign RBAC roles on the Azure Subscriptions

You need to update line 7, 12 and 17 with your environment parameters.

# Create MH Users.ps1

This script will perform the following actions:

- Create 60 EntraID user accounts that will be used as dedicated MicroHack user accounts for seperate MicroHacks
- Assignes always 10 user accounts to the previously created groups

You need to update line 8, 13 and 19 with your environment parameters.

# Downloads

Download from here:

- [Create Admin Users.ps1](../99-PreparationHelpers/Create%20Admin%20Users.ps1)
- [Create MH Users.ps1](../99-PreparationHelpers/Create%20Admin%20Users.ps1) 

