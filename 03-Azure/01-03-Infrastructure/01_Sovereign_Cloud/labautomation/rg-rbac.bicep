// Sovereign Cloud MicroHack - per-participant resource-group-scoped RBAC
//
// Deployed as a module (scope = the participant's resource group) from main.bicep.
// Adds the resource-group-scoped roles (per participant).
// Owner on the resource group is already granted by the platform (deploymentType =
// resourcegroup), so only the two additional roles are assigned here:
//   - Key Vault Administrator
//   - Storage Account Contributor

targetScope = 'resourceGroup'

@description('Entra object ID of the lab participant to grant the resource-group-scoped RBAC roles to.')
param userObjectId string

// Built-in role definition IDs (stable across all Azure subscriptions)
var keyVaultAdministratorRoleId = '00482a5a-887f-4fb3-b363-3b7fe8e74483'
var storageAccountContributorRoleId = '17d1049b-9a84-46fb-8f53-869881c3d3ab'

resource keyVaultAdministratorAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, userObjectId, keyVaultAdministratorRoleId)
  properties: {
    principalId: userObjectId
    principalType: 'User'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', keyVaultAdministratorRoleId)
  }
}

resource storageAccountContributorAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, userObjectId, storageAccountContributorRoleId)
  properties: {
    principalId: userObjectId
    principalType: 'User'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageAccountContributorRoleId)
  }
}
