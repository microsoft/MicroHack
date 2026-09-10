// Storage account with per-user containers for employee CSV data. Faithful Bicep
// port of infra/modules/user_data_storage. NOTE: uploading the CSV blobs and the
// user/group RBAC role assignments depend on Entra principals and blob content,
// neither of which is created here; those are handled by orchestration (Phase 2).

@description('Azure region.')
param location string

@description('Lab/environment name (used for tagging and the generated account name).')
param envName string

@description('Explicit per-user container names, e.g. container0001 for lab users or containerx001 for local test users.')
@minLength(1)
param containerNames array

@description('Optional explicit storage account name. Defaults to employeedata<unique>.')
param storageAccountName string = ''

@description('Tags to apply to all resources.')
param tags object = {}

var normalizedEnv = toLower(replace(envName, '-', ''))
var generatedNameBase = 'employeedata${uniqueString(subscription().subscriptionId, resourceGroup().id, normalizedEnv)}'
var generatedName = substring(generatedNameBase, 0, min(length(generatedNameBase), 24))
var effectiveName = empty(storageAccountName) ? generatedName : storageAccountName

var mergedTags = union(tags, {
  environment: envName
})

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: effectiveName
  location: location
  tags: mergedTags
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false
    minimumTlsVersion: 'TLS1_2'
    isHnsEnabled: true
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  parent: storageAccount
  name: 'default'
}

resource containers 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = [
  for name in containerNames: {
    parent: blobService
    name: name
    properties: {
      publicAccess: 'None'
    }
  }
]

output storageAccountName string = storageAccount.name
output storageAccountDfsEndpoint string = storageAccount.properties.primaryEndpoints.dfs
output containerNames array = containerNames
