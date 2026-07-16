// =============================================================================
// Module: containerapp-env.bicep  (Azure Container Apps managed environment)
// -----------------------------------------------------------------------------
// The shared environment both apps (api + frontend) run in. Apps in the same
// environment can reach each other by app name for service discovery — this is
// what lets the frontend's nginx proxy to the api (see API_HOST/API_PORT).
//
// STARTER SKELETON — compiles as-is; decisions left as // TODO.
// =============================================================================

@description('Azure region for the environment.')
param location string

@description('Name of the Container Apps managed environment.')
param environmentName string

@description('Resource ID of the Log Analytics workspace to send logs to.')
param logAnalyticsWorkspaceId string

@description('Tags applied to the environment.')
param tags object = {}

// Derive the workspace customerId + shared key from the passed-in workspace id.
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' existing = {
  name: last(split(logAnalyticsWorkspaceId, '/'))
}

resource environment 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: environmentName
  location: location
  tags: tags
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalyticsWorkspace.properties.customerId
        sharedKey: logAnalyticsWorkspace.listKeys().primarySharedKey
      }
    }
    // TODO: Decide whether you need a custom VNet (internal-only environment),
    //       zone redundancy, or workload profiles (Consumption vs Dedicated).
    //       The default is the public, Consumption-only profile — fine to start.
  }
}

@description('The resource ID of the managed environment.')
output environmentId string = environment.id

@description('The default domain of the environment (apps get <app>.<defaultDomain>).')
output defaultDomain string = environment.properties.defaultDomain
