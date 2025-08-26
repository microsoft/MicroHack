// Storage Account deployment (resource group scope)
// Implements requirements from req.txt:
//  - Parameters: storage account name, region, allow/deny public blob access
//  - Deploys a StorageV2 account with secure defaults

targetScope = 'resourceGroup'

@description('Globally unique storage account name (3-24 lowercase alphanumeric).')
@minLength(3)
@maxLength(24)
param storageAccountName string

@description('Azure region for the storage account. Defaults to the resource group location.')
param location string = resourceGroup().location

@description('Allow public network access to the storage account (controls publicNetworkAccess and anonymous blob access).')
param allowPublicAccess bool = false

// Re-use for allowBlobPublicAccess property
var allowBlobPublicAccess = allowPublicAccess
// Value to use in the resource: set properties.publicNetworkAccess to this variable
var publicNetworkAccessSetting = allowPublicAccess ? 'Enabled' : 'Disabled'

@description('Replication SKU for the storage account.')
@allowed([
  'Standard_LRS'
  'Standard_GRS'
  'Standard_ZRS'
  'Standard_RAGRS'
  'Standard_GZRS'
  'Standard_RAGZRS'
  'Premium_LRS'
])
param skuName string = 'Standard_LRS'

@description('Optional tags to apply to the storage account.')
param tags object = {}

// Basic validation / normalization note (Bicep cannot enforce regex here)
// Ensure provided name already meets naming rules.

resource storageAcct 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: skuName
  }
  kind: 'StorageV2'
  tags: tags
  properties: {
    allowBlobPublicAccess: allowBlobPublicAccess
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    encryption: {
      services: {
        blob: { enabled: true }
        file: { enabled: true }
      }
      keySource: 'Microsoft.Storage'
    }
    publicNetworkAccess: publicNetworkAccessSetting
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
    }
  }
}

output storageAccountId string = storageAcct.id
output primaryEndpoints object = storageAcct.properties.primaryEndpoints
output allowBlobPublicAccessEffective bool = storageAcct.properties.allowBlobPublicAccess
