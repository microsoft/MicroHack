// Storage account for database backup (.bak) files. Faithful Bicep port of
// infra/modules/storage_account_backups. NOTE: uploading the .bak blobs is not an
// ARM operation and is handled by orchestration (Phase 2); only the account and
// container are created here.

@description('Azure region.')
param location string

@description('Lab/environment name (used for tagging and the generated account name).')
param envName string

@description('Blob container name for backups.')
param containerName string = 'build'

@description('Optional explicit storage account name. Defaults to stsqlhack<normalizedEnv>.')
param storageAccountName string = ''

@description('Tags to apply to all resources.')
param tags object = {}

var normalizedEnv = toLower(replace(envName, '-', ''))
var generatedName = substring('stsqlhack${normalizedEnv}', 0, min(length('stsqlhack${normalizedEnv}'), 24))
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
    minimumTlsVersion: 'TLS1_2'
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  parent: storageAccount
  name: 'default'
}

resource container 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: blobService
  name: containerName
  properties: {
    publicAccess: 'None'
  }
}

output storageAccountName string = storageAccount.name
output containerName string = container.name
