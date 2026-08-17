// Sovereign Cloud MicroHack - per-participant lab RBAC
//
// deploymentType = resourcegroup: the platform pre-creates one resource group
// per participant in the shared subscription and grants the participant Owner on
// that resource group plus Reader on the subscription. This template adds the
// same subscription-scoped permissions that resources/subscription-preparations/3-rbac.ps1
// previously assigned to the LabUsers group:
//   - Security Reader              (view Defender for Cloud secure score / recommendations)
//   - Resource Policy Contributor  (author and assign Azure Policy at subscription scope)
//
// The role assignments are subscription-scoped, so this deployment must target the
// subscription (see deploy-lab.ps1, which invokes it with New-AzSubscriptionDeployment).

targetScope = 'subscription'

@description('Entra object ID of the lab participant to grant the lab-specific subscription-scoped RBAC roles to.')
param userObjectId string

@description('Name of the participant resource group (created by the platform) to grant resource-group-scoped RBAC roles in.')
param resourceGroupName string

// Built-in role definition IDs (stable across all Azure subscriptions)
var securityReaderRoleId = '39bc4728-0917-49c7-9d2c-d95423bc2eb4'
var resourcePolicyContributorRoleId = '36243c78-bf99-498c-9df9-86d9f8d28608'

resource securityReaderAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, userObjectId, securityReaderRoleId)
  properties: {
    principalId: userObjectId
    principalType: 'User'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', securityReaderRoleId)
  }
}

resource resourcePolicyContributorAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, userObjectId, resourcePolicyContributorRoleId)
  properties: {
    principalId: userObjectId
    principalType: 'User'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', resourcePolicyContributorRoleId)
  }
}

// Resource-group-scoped roles for the participant's dedicated resource group
// (Owner is already granted by the platform).
module resourceGroupRbac 'rg-rbac.bicep' = {
  name: 'lab-rg-rbac'
  scope: resourceGroup(resourceGroupName)
  params: {
    userObjectId: userObjectId
  }
}

