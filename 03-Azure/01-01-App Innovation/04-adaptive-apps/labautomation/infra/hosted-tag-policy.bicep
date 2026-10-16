// Portable copy of Sovereign_Cloud/labautomation/infra/hosted-tag-policy.bicep
// at d3e446889384325605e5db7e4e61ab1ed8af2cfd. Names retained to reuse the proven initiative.
targetScope = 'subscription'

var resourceTagPolicyId = tenantResourceId('Microsoft.Authorization/policyDefinitions', '5ffd78d9-436d-4b41-a421-5baa819e3008')
var resourceGroupTagPolicyId = tenantResourceId('Microsoft.Authorization/policyDefinitions', 'd157c373-a6c4-483d-aaad-570756956268')
var policies = [
  {
    referenceId: 'security-control-resources'
    definitionId: resourceTagPolicyId
    tagName: 'SecurityControl'
  }
  {
    referenceId: 'cost-control-resources'
    definitionId: resourceTagPolicyId
    tagName: 'CostControl'
  }
  {
    referenceId: 'security-control-resource-groups'
    definitionId: resourceGroupTagPolicyId
    tagName: 'SecurityControl'
  }
  {
    referenceId: 'cost-control-resource-groups'
    definitionId: resourceGroupTagPolicyId
    tagName: 'CostControl'
  }
]

resource initiative 'Microsoft.Authorization/policySetDefinitions@2026-06-01' = {
  name: 'sovereign-hosted-control-tags'
  properties: {
    displayName: 'Sovereign MicroHack - hosted MCAPS control tags'
    description: 'For dedicated Microsoft-hosted lab subscriptions only. Apply SecurityControl=Ignore and CostControl=Ignore to taggable resources and resource groups on creation or update.'
    policyType: 'Custom'
    metadata: {
      category: 'Tags'
      version: '1.0.0'
    }
    policyDefinitions: [for policy in policies: {
      policyDefinitionReferenceId: policy.referenceId
      policyDefinitionId: policy.definitionId
      parameters: {
        tagName: {
          value: policy.tagName
        }
        tagValue: {
          value: 'Ignore'
        }
      }
    }]
  }
}

// Azure requires an identity for Modify assignments, even without remediation tasks.
resource assignment 'Microsoft.Authorization/policyAssignments@2026-06-01' = {
  name: 'sov-hosted-control-tags'
  location: deployment().location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    displayName: 'Sovereign MicroHack - hosted MCAPS control tags'
    description: 'Organizer-owned assignment for new hosted environments; not for bring-your-own subscriptions.'
    policyDefinitionId: initiative.id
    enforcementMode: 'Default'
  }
}
