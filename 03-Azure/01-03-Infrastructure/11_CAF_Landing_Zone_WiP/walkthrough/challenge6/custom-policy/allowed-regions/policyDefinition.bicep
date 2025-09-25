// Custom Policy Definition: Allowed Regions
// Deploy at subscription scope. Defines a custom policy that denies resource deployments
// whose location is not in the provided allowedLocations list.
// Parameters:
//  - policyDefinitionName (string)
//  - displayName (string)
//  - description (string)
//  - allowedLocations (array)

targetScope = 'subscription'

// Parameters kept simple for broad Bicep version compatibility (decorators removed)
param policyDefinitionName string = 'custom-allowed-regions'
param displayName string = 'Allowed regions (custom)'
param policyDescription string = 'Restricts resource deployment to the specified list of regions.'

// NOTE: Policy definitions only define parameter schema; values are supplied at assignment time.
resource policyDef 'Microsoft.Authorization/policyDefinitions@2025-03-01' = {
  name: policyDefinitionName
  properties: {
    policyType: 'Custom'
    mode: 'All'
    displayName: displayName
  description: policyDescription
    metadata: {
      category: 'General'
      version: '1.0.0'
    }
    parameters: {
      allowedLocations: {
        type: 'Array'
        metadata: {
          displayName: 'Allowed locations'
          description: 'The list of allowed locations for resources.'
        }
      }
    }
    // Policy rule embedded as raw JSON to allow Azure Policy expression syntax.
    policyRule: policyRule
  }
}

// Raw JSON policy rule (uses Azure Policy expression for parameters). Kept after resource for readability.
var policyRule = json('''
{
  "if": {
    "allOf": [
      {
        "field": "type",
        "notEquals": "Microsoft.Resources/subscriptions"
      },
      {
        "field": "location",
        "notIn": "[parameters('allowedLocations')]"
      },
      {
        "field": "location",
        "notEquals": "global"
      }
    ]
  },
  "then": {
    "effect": "Deny"
  }
}
''')

output policyDefinitionId string = policyDef.id