// Module deployed at resource group scope to create the policy assignment.
targetScope = 'resourceGroup'

param assignmentName string
param displayName string
param assignmentDescription string
param policyDefinitionId string
param allowedLocations array
@allowed(['Default','DoNotEnforce'])
param enforcementMode string = 'Default'

resource assignment 'Microsoft.Authorization/policyAssignments@2025-03-01' = {
  name: assignmentName
  properties: {
    displayName: displayName
    description: assignmentDescription
    policyDefinitionId: policyDefinitionId
    enforcementMode: enforcementMode
    parameters: {
      allowedLocations: {
        value: allowedLocations
      }
    }
  }
}

output policyAssignmentId string = assignment.id