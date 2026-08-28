// Shared infrastructure for one subscription, deployed once by shared-deploy-lab.ps1
// into the dedicated rg-shared resource group. Reuses the Phase 1 modules under
// infra/modules.
//
// Non-ARM follow-up performed by shared-deploy-lab.ps1 after this template:
//   - SQL MI Directory-Readers grant + Entra admin
//   - demo database restores, stored proc, product, Agent job
//   - Fabric VNet gateway + gateway role assignments
// Per-attendee resources (user databases, Fabric workspaces) are created by
// deploy-lab.ps1.

@description('Azure region for the shared resources.')
param location string

@description('Naming/tag suffix for the shared resources. Kept unique per subscription.')
param envName string = 'sh${uniqueString(subscription().subscriptionId)}'

@description('SQL Managed Instance SQL admin login.')
param sqlAdminLogin string

@description('SQL Managed Instance administrator password.')
@secure()
param sqlPassword string

@description('Entra admin display name for the SQL MI (label only).')
param sqlAadAdminLogin string

@description('Entra admin object ID (sid) for the SQL MI.')
param sqlAadAdminSid string

@description('Entra admin tenant ID for the SQL MI.')
param sqlAadAdminTenantId string

@description('Fabric capacity SKU name.')
param fabricSkuName string = 'F32'

@description('Fabric capacity administrator identities (object IDs / UPNs). Must include the deploying principal.')
param fabricAdminMembers array

@description('Base database the shared webshop connects to.')
param webshopSqlDatabase string = 'TailspinToys_Demo_Final'

@description('When true, the SQL MI subnet NSG and route table already exist and are referenced instead of redeployed (avoids ConflictWithNetworkIntentPolicy on shared hook re-runs).')
param sqlMiNetworkingExists bool = false

var commonTags = {
  SecurityControl: 'Ignore'
}

module vnet 'infra/modules/vnet.bicep' = {
  name: 'shared-vnet'
  params: {
    location: location
    envName: envName
    tags: commonTags
    sqlMiNetworkingExists: sqlMiNetworkingExists
  }
}

module sqlManagedInstance 'infra/modules/sqlManagedInstance.bicep' = {
  name: 'shared-sqlmi'
  params: {
    location: location
    envName: envName
    instanceName: 'sqlhackmi-${envName}'
    subnetId: vnet.outputs.managedInstanceSubnetId
    administratorLogin: sqlAdminLogin
    administratorLoginPassword: sqlPassword
    aadAdminLogin: sqlAadAdminLogin
    aadAdminSid: sqlAadAdminSid
    aadAdminTenantId: sqlAadAdminTenantId
    tags: commonTags
  }
}

module appService 'infra/modules/appService.bicep' = {
  name: 'shared-webshop'
  params: {
    location: location
    envName: envName
    subnetId: vnet.outputs.appServiceSubnetId
    sqlDatabase: webshopSqlDatabase
    sqlServerFqdn: sqlManagedInstance.outputs.fqdn
    sqlAdminLogin: sqlAdminLogin
    sqlPassword: sqlPassword
    tags: commonTags
  }
}

module storageBackups 'infra/modules/storageBackups.bicep' = {
  name: 'shared-backups'
  params: {
    location: location
    envName: envName
    containerName: 'build'
    tags: commonTags
  }
}

module fabricCapacity 'infra/modules/fabricCapacity.bicep' = {
  name: 'shared-fabric'
  params: {
    location: location
    envName: envName
    skuName: fabricSkuName
    administrationMembers: fabricAdminMembers
    tags: commonTags
  }
}

output sqlManagedInstanceName string = sqlManagedInstance.outputs.name
output sqlManagedInstanceFqdn string = sqlManagedInstance.outputs.fqdn
output sqlManagedInstanceIdentityPrincipalId string = sqlManagedInstance.outputs.identityPrincipalId
output vnetName string = vnet.outputs.vnetName
output fabricSubnetName string = vnet.outputs.fabricSubnetName
output fabricCapacityName string = fabricCapacity.outputs.capacityName
output backupStorageAccountName string = storageBackups.outputs.storageAccountName
output backupContainerName string = storageBackups.outputs.containerName
output webshopName string = appService.outputs.webAppName
output webshopDefaultHostname string = appService.outputs.defaultHostname
