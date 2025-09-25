// Custom Policy Assignment: Allowed Regions
// Deploy at subscription scope. Assigns an existing custom allowed regions policy
// to a specified resource group.
// Parameters:
//  - assignmentName (string)
//  - displayName (string)
//  - description (string)
//  - policyDefinitionName (string) (must already exist or be deployed separately)
//  - targetResourceGroupName (string)
//  - allowedLocations (array) (passed to policy definition parameters)
//  - enforcementMode (string) (Default | DoNotEnforce)

// This file remains subscription scoped and uses a module deployed to the RG scope.
// If you prefer a purely RG-scoped template, create a separate file with targetScope='resourceGroup'.
targetScope = 'subscription'

param assignmentName string = 'custom-allowed-regions-assignment'
param displayName string = 'Enforce allowed regions'
param assignmentDescription string = 'Ensures only approved regions are used in the target resource group.'
param policyDefinitionName string
param targetResourceGroupName string
param allowedLocations array
@allowed(['Default','DoNotEnforce'])
param enforcementMode string = 'Default'

resource policyDef 'Microsoft.Authorization/policyDefinitions@2025-03-01' existing = {
  name: policyDefinitionName
}

// Module that performs the assignment at the resource group scope
module rgAssignment './rgPolicyAssignmentModule.bicep' = {
  name: '${assignmentName}-module'
  scope: resourceGroup(targetResourceGroupName)
  params: {
    assignmentName: assignmentName
    displayName: displayName
    assignmentDescription: assignmentDescription
    policyDefinitionId: policyDef.id
    allowedLocations: allowedLocations
    enforcementMode: enforcementMode
  }
}

output policyAssignmentId string = rgAssignment.outputs.policyAssignmentId