// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.
/*
SUMMARY: Module to create a Storage Account
DESCRIPTION: This module will create a deployment which will create a Storage Account
AUTHOR/S: David Smith (CSA FSI)
*/

param namePrefix string
var location = resourceGroup().location
var unique = uniqueString(resourceGroup().id)
var subName = '${namePrefix}${location}${unique}'
var Name = length(subName) >= 24 ? substring(subName, 0, 24) : subName // Storage account name must be between 3 and 24 characters in length and use numbers and lower-case letters only
// param logAnalyticsWorkspaceId string
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

// resource diagnosticSetting 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
//   name: '${storageAccount.name}-diagnostic'
//   scope: storageAccount
//   properties: {
//     workspaceId: logAnalyticsWorkspaceId
//     storageAccountId: storageAccount.id
//     metrics: [
//       {
//         category: 'Transaction'
//         enabled: true
//       }
//     ]
//   }
// }

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2021-06-01' = {
  parent: storageAccount
  name: 'default'
  properties: {}
}

// resource diagnosticSettingsBlob 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
//   name: '${storageAccount.name}-blob-diag'
//   scope: blobService
//   properties: {
//     workspaceId: logAnalyticsWorkspaceId
//     logs: logSettings
//   }
// }

resource fileService 'Microsoft.Storage/storageAccounts/fileServices@2021-06-01' = {
  parent: storageAccount
  name: 'default'
  properties: {}
}

// resource diagnosticsFile 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
//   scope: fileService
//   name: '${storageAccount.name}-file-diag'
//   properties: {
//     workspaceId: logAnalyticsWorkspaceId
//     logs: logSettings
//   }
// }

resource queueService 'Microsoft.Storage/storageAccounts/queueServices@2021-06-01' = {
  parent: storageAccount
  name: 'default'
  properties: {}
}

// resource diagnosticsQueue 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
//   scope: queueService
//   name: '${storageAccount.name}-queue-diag'
//   properties: {
//     workspaceId: logAnalyticsWorkspaceId
//     logs: logSettings
//   }
// }

resource tableService 'Microsoft.Storage/storageAccounts/tableServices@2021-06-01' = {
  parent: storageAccount
  name: 'default'
  properties: {}
}

// resource diagnosticsTable 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
//   scope: tableService
//   name: '${storageAccount.name}-table-diag'
//   properties: {
//     workspaceId: logAnalyticsWorkspaceId
//     logs: logSettings
//   }
// }

// Output
@description('Output the storage account ID')
output storageAccountId string = storageAccount.id
output storageAccountName string = storageAccount.name
