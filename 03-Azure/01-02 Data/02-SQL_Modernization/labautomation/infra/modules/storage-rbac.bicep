param storageAccountName string
param vmPrincipalId string
param sqlmiPrincipalId string

var storageBlobDataContributorRoleId = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
)

/*
var storageBlobDataReaderRoleId = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1'
)
*/

resource storageAccount 'Microsoft.Storage/storageAccounts@2025-01-01' existing = {
  name: storageAccountName
}

resource vmBlobContributorRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(
    storageAccount.id,
    vmPrincipalId,
    storageBlobDataContributorRoleId
  )

  scope: storageAccount

  properties: {
    roleDefinitionId: storageBlobDataContributorRoleId
    principalId: vmPrincipalId
    principalType: 'ServicePrincipal'
  }
}

/* resource sqlmiBlobDataReaderRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(
    storageAccount.id,
    sqlmiPrincipalId,
    storageBlobDataReaderRoleId
  )

  scope: storageAccount

  properties: {
    roleDefinitionId: storageBlobDataReaderRoleId
    principalId: sqlmiPrincipalId
    principalType: 'ServicePrincipal'
  }
}
 */

resource sqlmiBlobContributorRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(
    storageAccount.id,
    sqlmiPrincipalId,
    storageBlobDataContributorRoleId
  )

  scope: storageAccount

  properties: {
    roleDefinitionId: storageBlobDataContributorRoleId
    principalId: sqlmiPrincipalId
    principalType: 'ServicePrincipal'
  }
}
