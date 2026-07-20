// Challenge 00: Azure Copilot Basics
// Deploys: Storage Account, Virtual Network (2 subnets), Network Security Group

@description('Azure region for all resources')
param location string

@description('Random suffix for globally unique resource names')
param suffix string

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: 'stcopilotworkshop${suffix}'
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  tags: {
    CostControl: 'Ignore'
    SecurityControl: 'Ignore'
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2024-01-01' = {
  name: 'vnet-copilot-workshop'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'snet-frontend'
        properties: {
          addressPrefix: '10.0.1.0/24'
        }
      }
      {
        name: 'snet-backend'
        properties: {
          addressPrefix: '10.0.2.0/24'
        }
      }
    ]
  }
}

// NSG for exploration — deliberately NOT associated with any subnet
resource nsg 'Microsoft.Network/networkSecurityGroups@2024-01-01' = {
  name: 'nsg-copilot-workshop'
  location: location
  tags: {
    CostControl: 'Ignore'
    SecurityControl: 'Ignore'
  }
}
