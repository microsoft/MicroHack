targetScope = 'subscription'

@description('Object ID of the current user (az ad signed-in-user show --query id)')
param currentUserObjectId string

@description('Prefix for multiple deployments per subscription')
param prefix string = 'mh'

@description('The Number of deployments per subscription. This parameter is to be used it the deployment gets precreated for the users.')
param deploymentCount int = 1

@description('Azure region for the deployment. Defaulting to the Location of the Deployment.')
param location string = deployment().location

@description('User Name for the Tags')
param userName string 

@description('Tags to identify user resources')
var tags = {
  User: userName
}

@description('Source Resouce Groups.')
resource sourceRg 'Microsoft.Resources/resourceGroups@2021-01-01' = [for i in range(0, deploymentCount): {
  //name: '${prefix}${(i+1)}-${suffix}-source-rg'
  name: '${prefix}${(i+1)}-${userName}-source-rg'
  location: location
  tags: tags
}]

@description('Source Module to deploy initial demo resources for migration')
module source 'source.bicep' = [for i in range(0, deploymentCount):  {
  name: '${prefix}${(i+1)}-sourceModule'
  scope: sourceRg[i]
  params: {
    location: location
    currentUserObjectId: currentUserObjectId
    prefix: prefix
    deployment: (i+1)
    userName: userName
    adminPassword: '${toUpper(uniqueString(subscription().id, deployment().name))}${deployment().name}'
  }
}]

@description('Destination Resouce Groups.')
resource destinationRg 'Microsoft.Resources/resourceGroups@2021-01-01' = [for i in range(0, deploymentCount): {
  //name: '${prefix}${(i+1)}-${suffix}-destination-rg'
  name: '${prefix}${(i+1)}-${userName}-destination-rg'
  location: location
  tags: tags
}]

@description('Destination Module to deploy the destination resources')
module destination 'destination.bicep' = [for i in range(0, deploymentCount): {
  name: '${prefix}${(i+1)}-destinationModule'
  scope: destinationRg[i]
  params: {
    location: location
    prefix: prefix
    deployment: (i+1)
    userName: userName
  }
}]


output identifier string = userName

