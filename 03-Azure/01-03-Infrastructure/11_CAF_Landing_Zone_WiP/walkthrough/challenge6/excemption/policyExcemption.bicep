// Bicep module to create a single policy exemption at the module deployment scope.
// Suitable when the policy assignment ID is already known and a static declaration is desired.
// For dynamic discovery of assignments, prefer the accompanying bash script.

@description('Name of the policy exemption resource (must be unique within the scope).')
param exemptionName string

@description('Display name for the exemption.')
param displayName string

@description('Policy Assignment (full resource ID) this exemption applies to.')
param policyAssignmentId string

@description('Exemption category: Waiver or Mitigated.')
@allowed(['Waiver', 'Mitigated'])
param exemptionCategory string = 'Waiver'

@description('Optional ISO8601 UTC date/time when the exemption expires. Leave empty for no expiry.')
param expiresOn string = ''

@description('Optional description / justification.')
param exemptionDescription string = 'Policy exemption created via policyExemption.bicep module.'

@description('Optional metadata object (e.g., owner, ticketId).')
param metadata object = {}

// Optional: list of policy definition reference IDs if applying exemption only to part of a policy set
@description('Optional list of policy definition reference IDs (for policy set assignments). Leave empty to exempt entire assignment.')
param policyDefinitionReferenceIds array = []

resource exemption 'Microsoft.Authorization/policyExemptions@2022-07-01-preview' = {
  name: exemptionName
  properties: {
    displayName: displayName
    description: exemptionDescription
    exemptionCategory: exemptionCategory
    policyAssignmentId: policyAssignmentId
    metadata: metadata
    // Only include expiresOn if provided (non-empty string)
    ...(length(expiresOn) == 0 ? {} : { expiresOn: expiresOn })
    ...(length(policyDefinitionReferenceIds) == 0 ? {} : { policyDefinitionReferenceIds: policyDefinitionReferenceIds })
  }
}

@description('Exemption name output for reference.')
output name string = exemption.name
