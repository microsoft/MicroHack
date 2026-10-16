targetScope = 'resourceGroup'

@description('Use the existing resource group location.')
param location string = resourceGroup().location

@description('Walkthrough stage: 2 database, 4 registry, 5 Azure firewall, 6 Container Apps and Files.')
@allowed([2, 4, 5, 6])
param deploymentStage int = 2

@description('Enable only after building the image, uploading the files and checking AcrPull.')
param deployApplication bool = false

@description('PostgreSQL administrator login for this workshop.')
param postgresAdministratorLogin string = 'catalogadmin'

@description('PostgreSQL administrator password supplied outside source control.')
@secure()
param postgresAdministratorPassword string

@description('Public IPv4 address of the workstation or Codespace running the local application.')
param clientIpAddress string

@description('Catalog database name.')
param databaseName string = 'catalog'

@description('Managed PostgreSQL major version; the walkthrough permits 16 or later.')
@allowed(['16', '17', '18'])
param postgresVersion string = '16'

@description('Registry SKU. Basic is sufficient for the workshop.')
@allowed(['Basic', 'Standard', 'Premium'])
param containerRegistrySku string = 'Basic'

@description('Image built in the Java registry, including repository and tag.')
param containerImageName string = 'lego-catalog/app:latest'

@description('Secret protecting the performance endpoint.')
@secure()
param performanceApiKey string

@description('Version identity for the upgraded application.')
param serviceVersion string

// Java-specific names prevent overwriting the .NET path in the same participant group.
var suffix = uniqueString(resourceGroup().id)

module database './modules/database.bicep' = {
  name: 'ch01-java-database'
  params: {
    location: location
    serverName: 'pg-legocatalog-java-${suffix}'
    databaseName: databaseName
    postgresVersion: postgresVersion
    administratorLogin: postgresAdministratorLogin
    administratorPassword: postgresAdministratorPassword
    clientIpAddress: clientIpAddress
    allowAzureServices: deploymentStage >= 5
  }
}

module registry './modules/registry.bicep' = if (deploymentStage >= 4) {
  name: 'ch01-java-registry'
  params: {
    location: location
    registryName: 'acrlegojava${suffix}'
    identityName: 'id-legocatalog-java-${suffix}'
    sku: containerRegistrySku
  }
}

module environment './modules/environment.bicep' = if (deploymentStage >= 6) {
  name: 'ch01-java-environment'
  params: {
    location: location
    environmentName: 'cae-legocatalog-java-${suffix}'
    workspaceName: 'log-legocatalog-java-${suffix}'
    storageAccountName: 'stlegoj${suffix}'
  }
}

module app './modules/app.bicep' = if (deploymentStage >= 6 && deployApplication) {
  name: 'ch01-java-app'
  params: {
    location: location
    appName: 'ca-legocatalog-java'
    environmentId: environment!.outputs.environmentId
    identityId: registry!.outputs.identityId
    registryLoginServer: registry!.outputs.loginServer
    containerImageName: containerImageName
    databaseHost: database.outputs.fqdn
    databaseName: databaseName
    databaseUsername: postgresAdministratorLogin
    databasePassword: postgresAdministratorPassword
    performanceApiKey: performanceApiKey
    serviceVersion: serviceVersion
    seedStorageName: environment!.outputs.seedShareName
    imagesStorageName: environment!.outputs.imagesShareName
  }
}

output postgresServerName string = database.outputs.serverName
output postgresServerFqdn string = database.outputs.fqdn
output databaseName string = databaseName
output containerRegistryName string = deploymentStage >= 4 ? registry!.outputs.registryName : ''
output containerRegistryLoginServer string = deploymentStage >= 4 ? registry!.outputs.loginServer : ''
output appIdentityId string = deploymentStage >= 4 ? registry!.outputs.identityId : ''
output appIdentityPrincipalId string = deploymentStage >= 4 ? registry!.outputs.principalId : ''
output containerAppsEnvironmentName string = deploymentStage >= 6 ? environment!.outputs.environmentName : ''
output storageAccountName string = deploymentStage >= 6 ? environment!.outputs.storageAccountName : ''
output seedShareName string = deploymentStage >= 6 ? environment!.outputs.seedShareName : ''
output imagesShareName string = deploymentStage >= 6 ? environment!.outputs.imagesShareName : ''
output containerAppName string = 'ca-legocatalog-java'
output applicationUrl string = deploymentStage >= 6 && deployApplication ? app!.outputs.applicationUrl : ''
