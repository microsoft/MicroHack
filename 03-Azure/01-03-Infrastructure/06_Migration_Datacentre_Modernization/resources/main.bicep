targetScope = 'subscription'

@description('Object ID of the current user')
param currentUserObjectId string

// Locals
param location string = 'westeurope'

/*
* Source Module
*/
resource sourceRg 'Microsoft.Resources/resourceGroups@2021-01-01' = {
  name: 'source-rg'
  location: location
}

module source 'source.bicep' = {
  name: 'sourceModule'
  scope: sourceRg
  params: {
    location: location
    currentUserObjectId: currentUserObjectId
  }
}

/*
* Destination Module
*/
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
