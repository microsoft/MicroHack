// Resource-group scope module that creates the policy assignment (no parameters required by policy)
targetScope = 'resourceGroup'

param assignmentName string
param displayName string
param assignmentDescription string
param policyDefinitionId string
@allowed(['Default', 'DoNotEnforce'])
param enforcementMode string = 'Default'

resource assignment 'Microsoft.Authorization/policyAssignments@2025-03-01' = {
  name: assignmentName
  properties: {
    displayName: displayName
    description: assignmentDescription
    policyDefinitionId: policyDefinitionId
    enforcementMode: enforcementMode
  }
}

output policyAssignmentId string = assignment.id
