targetScope = 'subscription'

@description('Object ID of the current user (az ad signed-in-user show --query id)')
param currentUserObjectId string

@description('The Number of deployments per subscription')
param deploymentCount int = 1

@description('Azure region for the deployment')
@allowed([
  'West Europe'
  'North Europe'
  'East US'
  'East US 2'
  'Southeast Asia'
  'East Asia'
  'Germany West Central'
])
param location string

@description('Source Resouce Groups.')
resource sourceRg 'Microsoft.Resources/resourceGroups@2021-01-01' = [for i in range(0, deploymentCount): {
  name: 'source-rg-${(i+1)}'
  location: location
}]

@description('Source Module to deploy initial demo resources for migration')
module source 'source.bicep' = [for i in range(0, deploymentCount):  {
  name: 'sourceModule${(i+1)}'
  scope: sourceRg[i]
  params: {
    location: location
    currentUserObjectId: currentUserObjectId
    vm1Name: 'frontend-${(i+1)}-1'
    vm2Name: 'frontend-${(i+1)}-2'
    adminUsername: 'microhackadmin${(i+1)}'
    deployment: (i+1)
  }
}]

@description('Destination Resouce Groups.')
resource destinationRg 'Microsoft.Resources/resourceGroups@2021-01-01' = [for i in range(0, deploymentCount): {
  name: 'destination-rg-${(i+1)}'
  location: location
}]

@description('Destination Module to deploy the destination resources')
module destination 'destination.bicep' = [for i in range(0, deploymentCount): {
  name: 'destinationModule${(i+1)}'
  scope: destinationRg[i]
  params: {
    location: location
    deployment: (i+1)
  }
}]
