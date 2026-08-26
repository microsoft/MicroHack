// Per-attendee ARM resources, deployed by deploy-lab.ps1 into the attendee's own
// resource group. The attendee's two databases and Fabric workspace are not ARM
// resources and are created by deploy-lab.ps1 against the shared MI/capacity.
// The employee CSV blob is uploaded by deploy-lab.ps1 (not an ARM operation).

@description('Azure region.')
param location string

@description('Entra object ID of the attendee, granted data access to the CSV storage.')
param attendeeObjectId string

@description('Blob container name for the attendee employee CSV.')
param containerName string = 'container'

@description('Optional explicit storage account name. Defaults to a unique per-RG name.')
param storageAccountName string = 'stusr${uniqueString(resourceGroup().id)}'

var commonTags = {
  SecurityControl: 'Ignore'
}

// Storage Blob Data Owner
var blobDataOwnerRoleId = 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b'

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName
  location: location
  tags: commonTags
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

resource container 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: blobService
  name: containerName
  properties: {
    publicAccess: 'None'
  }
}

resource blobOwner 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount.id, attendeeObjectId, blobDataOwnerRoleId)
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', blobDataOwnerRoleId)
    principalId: attendeeObjectId
    principalType: 'User'
  }
}

output storageAccountName string = storageAccount.name
output containerName string = container.name
