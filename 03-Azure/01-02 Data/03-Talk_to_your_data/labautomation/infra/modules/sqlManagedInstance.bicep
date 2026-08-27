// SQL Managed Instance. Faithful Bicep port of infra/modules/sql_managed_instance.
// NOTE: the Entra "Directory Readers" grant on the MI identity and the AD admin
// assignment are NOT ARM operations and are handled by orchestration (Phase 2),
// so they are intentionally omitted here. The inbound 3342 NSG rule now lives in
// the vnet module.

@description('Azure region.')
param location string

@description('Lab/environment name (used for tagging).')
param envName string

@description('SQL Managed Instance name.')
param instanceName string

@description('Resource ID of the delegated ManagedInstance subnet.')
param subnetId string

@description('SQL administrator login.')
param administratorLogin string

@description('SQL administrator login password.')
@secure()
param administratorLoginPassword string

@description('Tags to apply to all resources.')
param tags object = {}

var mergedTags = union(tags, {
  environment: envName
})

resource managedInstance 'Microsoft.Sql/managedInstances@2023-08-01-preview' = {
  name: instanceName
  location: location
  tags: mergedTags
  sku: {
    name: 'GP_Gen5'
    tier: 'GeneralPurpose'
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    administratorLogin: administratorLogin
    administratorLoginPassword: administratorLoginPassword
    subnetId: subnetId
    licenseType: 'LicenseIncluded'
    vCores: 4
    storageSizeInGB: 96
    requestedBackupStorageRedundancy: 'Local'
    proxyOverride: 'Default'
    publicDataEndpointEnabled: true
    databaseFormat: 'AlwaysUpToDate'
  }
}

output id string = managedInstance.id
output name string = managedInstance.name
output fqdn string = managedInstance.properties.fullyQualifiedDomainName
output identityPrincipalId string = managedInstance.identity.principalId
