// Storage account with per-user containers for employee CSV data. Faithful Bicep
// port of infra/modules/user_data_storage. NOTE: uploading the CSV blobs and the
// user/group RBAC role assignments depend on Entra principals and blob content,
// neither of which is created here; those are handled by orchestration (Phase 2).

@description('Azure region.')
param location string

@description('Lab/environment name (used for tagging and the generated account name).')
param envName string

@description('Number of per-user containers to create.')
@minValue(1)
param userCount int

@description('Prefix for generated container names (e.g. container001).')
param containerNamePrefix string = 'container'

@description('Optional explicit storage account name. Defaults to stuserdata<normalizedEnv>.')
param storageAccountName string = ''

@description('Tags to apply to all resources.')
param tags object = {}

var normalizedEnv = toLower(replace(envName, '-', ''))
var generatedName = substring('stuserdata${normalizedEnv}', 0, min(length('stuserdata${normalizedEnv}'), 24))
var effectiveName = empty(storageAccountName) ? generatedName : storageAccountName

var mergedTags = union(tags, {
  environment: envName
})

var containerNames = [for i in range(0, userCount): '${containerNamePrefix}${padLeft(string(i + 1), 3, '0')}']

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
output containerNames array = containerNames
