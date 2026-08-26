// Phase 1: subscription-scoped entry point. Creates the resource group and deploys
// the ARM infrastructure previously described by the Terraform root module.
// The non-ARM pieces (Entra users, SQL MI Directory-Readers grant + AD admin,
// Fabric gateway/workspaces/role-assignments, blob uploads, data loading) are
// deliberately out of scope here and handled by deployment orchestration.

targetScope = 'subscription'

@description('Azure region for all resources.')
param location string

@description('Lab/environment name.')
param envName string

@description('SQL Managed Instance SQL admin login.')
param sqlAdminLogin string

@description('SQL Managed Instance administrator password.')
@secure()
param sqlPassword string

@description('Entra admin login used as the Fabric capacity administrator.')
param sqlMiEntraAdminLogin string

@description('Number of user containers/workspaces to size the environment for.')
@minValue(1)
param userCount int = 5

@description('Base database the webshop App Service connects to.')
param appServiceSqlDatabase string = 'TailspinToys_Demo_Final'

var commonTags = {
  SecurityControl: 'Ignore'
}

resource resourceGroup 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: 'rg-sqlhack-${envName}'
  location: location
  tags: commonTags
}

module vnet 'modules/vnet.bicep' = {
  scope: resourceGroup
  name: 'vnet'
  params: {
    location: location
    envName: envName
    tags: commonTags
  }
}

module sqlManagedInstance 'modules/sqlManagedInstance.bicep' = {
  scope: resourceGroup
  name: 'sqlManagedInstance'
  params: {
    location: location
    envName: envName
    instanceName: 'sqlhackmi-${envName}'
    subnetId: vnet.outputs.managedInstanceSubnetId
    administratorLogin: sqlAdminLogin
    administratorLoginPassword: sqlPassword
    tags: commonTags
  }
}

module appService 'modules/appService.bicep' = {
  scope: resourceGroup
  name: 'appService'
  params: {
    location: location
    envName: envName
    subnetId: vnet.outputs.appServiceSubnetId
    sqlDatabase: appServiceSqlDatabase
    sqlServerFqdn: sqlManagedInstance.outputs.fqdn
    sqlAdminLogin: sqlAdminLogin
    sqlPassword: sqlPassword
    tags: commonTags
  }
}

module storageBackups 'modules/storageBackups.bicep' = {
  scope: resourceGroup
  name: 'storageBackups'
  params: {
    location: location
    envName: envName
    containerName: 'build'
    tags: commonTags
  }
}

module userDataStorage 'modules/userDataStorage.bicep' = {
  scope: resourceGroup
  name: 'userDataStorage'
  params: {
    location: location
    envName: envName
    userCount: userCount
    containerNamePrefix: 'container'
    tags: commonTags
  }
}

module fabricCapacity 'modules/fabricCapacity.bicep' = {
  scope: resourceGroup
  name: 'fabricCapacity'
  params: {
    location: location
    envName: envName
    skuName: 'F2'
    administrationMembers: [
      sqlMiEntraAdminLogin
    ]
    tags: commonTags
  }
}

output resourceGroupName string = resourceGroup.name
output vnetName string = vnet.outputs.vnetName
output sqlManagedInstanceName string = sqlManagedInstance.outputs.name
output sqlManagedInstanceFqdn string = sqlManagedInstance.outputs.fqdn
output AZURE_APP_SERVICE_WEB_APP_NAME string = appService.outputs.webAppName
output appServiceDefaultHostname string = appService.outputs.defaultHostname
output backupStorageAccountName string = storageBackups.outputs.storageAccountName
output userDataStorageAccountName string = userDataStorage.outputs.storageAccountName
output fabricCapacityName string = fabricCapacity.outputs.capacityName
