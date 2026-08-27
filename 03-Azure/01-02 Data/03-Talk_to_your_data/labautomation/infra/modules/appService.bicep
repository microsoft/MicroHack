// Linux App Service (webshop). Faithful Bicep port of infra/modules/app_service_linux.

@description('Azure region.')
param location string

@description('Lab/environment name (used for tagging and default names).')
param envName string

@description('Resource ID of the delegated snet-appservice subnet for VNet integration.')
param subnetId string

@description('App Service Plan name. Defaults to asp-sqlhack-<envName>.')
param servicePlanName string = 'asp-sqlhack-${envName}'

@description('Web App name. Defaults to app-sqlhack-<envName>.')
param webAppName string = 'app-sqlhack-${envName}'

@description('App Service Plan SKU.')
param sku string = 'B1'

@description('SQL database the webshop connects to.')
param sqlDatabase string

@description('SQL Managed Instance FQDN.')
param sqlServerFqdn string

@description('SQL login used by the webshop.')
param sqlAdminLogin string

@description('SQL password used by the webshop.')
@secure()
param sqlPassword string

@description('Tags to apply to all resources.')
param tags object = {}

var mergedTags = union(tags, {
  environment: envName
})

resource servicePlan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: servicePlanName
  location: location
  tags: mergedTags
  kind: 'linux'
  sku: {
    name: sku
  }
  properties: {
    reserved: true
  }
}

resource webApp 'Microsoft.Web/sites@2023-12-01' = {
  name: webAppName
  location: location
  tags: mergedTags
  properties: {
    serverFarmId: servicePlan.id
    virtualNetworkSubnetId: subnetId
    siteConfig: {
      linuxFxVersion: 'NODE|24-lts'
      appSettings: [
        {
          name: 'SQL_DATABASE'
          value: sqlDatabase
        }
        {
          name: 'SQL_PASSWORD'
          value: sqlPassword
        }
        {
          name: 'SQL_SERVER'
          value: sqlServerFqdn
        }
        {
          name: 'SQL_USER'
          value: sqlAdminLogin
        }
        {
          name: 'SCM_DO_BUILD_DURING_DEPLOYMENT'
          value: 'true'
        }
        {
          name: 'PORT'
          value: '3000'
        }
      ]
    }
  }
}

output servicePlanId string = servicePlan.id
output servicePlanName string = servicePlan.name
output webAppId string = webApp.id
output webAppName string = webApp.name
output defaultHostname string = webApp.properties.defaultHostName
