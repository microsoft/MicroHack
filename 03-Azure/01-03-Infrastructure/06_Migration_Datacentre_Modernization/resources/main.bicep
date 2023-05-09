targetScope = 'subscription'

@description('Location for all resources')
param location string

@description('Admin username for all VMs')
param adminUsername string

@secure()
@description('Admin password for all VMs')
param adminPassword string

// Source module

resource sourceRg 'Microsoft.Resources/resourceGroups@2021-01-01' = {
  name: 'source-rg'
  location: location
}

module source 'source.bicep' = {
  name: 'sourceModule'
  scope: sourceRg
  params: {
    location: location
    adminUsername: adminUsername
    adminPassword: adminPassword
  }
}

// Destination module

resource destinationRg 'Microsoft.Resources/resourceGroups@2021-01-01' = {
  name: 'destination-rg'
  location: location
}

module destination 'destination.bicep' = {
  name: 'destinationModule'
  scope: destinationRg
  params: {
    location: location
  }
}
