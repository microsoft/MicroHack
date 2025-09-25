// Subscription-scope template that assigns a built-in policy denying public blob access on storage accounts
// to a specified resource group. Uses a module for RG scope assignment.
//
// The script provided resolves the built-in policy definition name dynamically by displayName to avoid
// hard-coding GUIDs. You can also supply policyDefinitionName directly.

targetScope = 'subscription'

@description('Name of the policy assignment.')
param assignmentName string = 'enforce-storage-no-public-blob'

@description('Display name for the policy assignment.')
param displayName string = 'Deny storage public network access'

@description('Description for the policy assignment.')
param assignmentDescription string = 'Ensures storage accounts in this resource group do not permit public blob access.'

@description('Target resource group name for the policy assignment scope.')
param targetResourceGroupName string

@description('Name (GUID) of the built-in policy definition that disallows public blob access. If empty, provide via script.')
param policyDefinitionName string = ''

@description('Enforcement mode: Default (enforced) or DoNotEnforce.')
@allowed([
  'Default'
  'DoNotEnforce'
])
param enforcementMode string = 'Default'

// Optionally allow passing the full policyDefinitionId instead of name (takes precedence if provided)
@description('Optional full resource ID of the policy definition. If provided, overrides policyDefinitionName.')
param policyDefinitionId string = ''

// Determine effective policy definition id
var effectivePolicyDefinitionId = empty(policyDefinitionId)
  ? subscriptionResourceId('Microsoft.Authorization/policyDefinitions', policyDefinitionName)
  : policyDefinitionId

module rgAssignment './storagePolicyRgModule.bicep' = {
  name: '${assignmentName}-module'
  scope: resourceGroup(targetResourceGroupName)
  params: {
    assignmentName: assignmentName
    displayName: displayName
    assignmentDescription: assignmentDescription
    policyDefinitionId: effectivePolicyDefinitionId
    enforcementMode: enforcementMode
  }
}

output policyAssignmentId string = rgAssignment.outputs.policyAssignmentId
