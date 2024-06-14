targetScope = 'subscription'

@description('Object ID of the current user (az ad signed-in-user show --query id)')
param currentUserObjectId string

@description('Prefix for multiple deployments per subscription')
param prefix string = 'mh'

@description('The Number of deployments per subscription. This parameter is to be used if the deployment gets precreated for the users.')
param deploymentCount int = 1

@description('Azure region for the deployment')
param location string
@description('Azure region for the destination deployment. In case you want to deploy to a different region than the source.')
param destinationLocation string = location

@secure()
@description('Admin password variable')
param adminPassword string

param suffix string = substring(uniqueString(currentUserObjectId), 0, 4)

param imageReference object = {
  publisher: 'RedHat'
  offer: 'RHEL'
  // sku: '81-ci-gen2' https://github.com/MicrosoftDocs/azure-docs/issues/84430
  // sku: '8-gen2'
  sku: '7_9'
  version: 'latest'
}

@description('Admin user variable')
param adminUsername string = 'microhackadmin'

@description('Source Resouce Groups.')
resource sourceRg 'Microsoft.Resources/resourceGroups@2021-01-01' = [for i in range(0, deploymentCount): {
  name: '${prefix}${(i+1)}-${suffix}-source-rg'
  location: location
}]

@description('Source Module to deploy initial demo resources for migration')
module source 'source.bicep' = [for i in range(0, deploymentCount):  {
  name: '${prefix}${(i+1)}-sourceModule'
  scope: sourceRg[i]
  params: {
    location: location
    currentUserObjectId: currentUserObjectId
    prefix: prefix
    suffix: suffix
    deployment: (i+1)
    adminUsername: adminUsername
    adminPassword: adminPassword
    imageReference: imageReference
    customData: loadTextContent('vmnodejs.yaml')
  }
}]

@description('Destination Resouce Groups.')
resource destinationRg 'Microsoft.Resources/resourceGroups@2021-01-01' = [for i in range(0, deploymentCount): {
  name: '${prefix}${(i+1)}-${suffix}-destination-rg'
  location: destinationLocation
}]

@description('Destination Module to deploy the destination resources')
module destination 'destination.bicep' = [for i in range(0, deploymentCount): {
  name: '${prefix}${(i+1)}-destinationModule'
  scope: destinationRg[i]
  params: {
    location: destinationLocation
    prefix: prefix
    suffix: suffix
    deployment: (i+1)
  }
}]

output identifier string = suffix


