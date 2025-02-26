param namePrefix string
var location = resourceGroup().location
var unique = uniqueString(resourceGroup().id)
var subName = '${namePrefix}${location}${unique}'
var Name = length(subName) >= 24 ? substring(subName, 0, 24) : subName // Storage account name must be between 3 and 24 characters in length and use numbers and lower-case letters only
var logSettings = [
  {
    category: 'StorageRead'
    enabled: true
  }
  {
    category: 'StorageWrite'
    enabled: true
  }
  {
    category: 'StorageDelete'
    enabled: true
  }
]

// Resources
@description('Storage account')
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: toLower(Name) // Storage account names must be lowercase
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    allowSharedKeyAccess: true
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2021-06-01' = {
  parent: storageAccount
  name: 'default'
  properties: {}
}

resource fileService 'Microsoft.Storage/storageAccounts/fileServices@2021-06-01' = {
  parent: storageAccount
  name: 'default'
  properties: {}
}

resource queueService 'Microsoft.Storage/storageAccounts/queueServices@2021-06-01' = {
  parent: storageAccount
  name: 'default'
  properties: {}
}

resource tableService 'Microsoft.Storage/storageAccounts/tableServices@2021-06-01' = {
  parent: storageAccount
  name: 'default'
  properties: {}
}

// Output
@description('Output the storage account ID')
output storageAccountId string = storageAccount.id
output storageAccountName string = storageAccount.name
