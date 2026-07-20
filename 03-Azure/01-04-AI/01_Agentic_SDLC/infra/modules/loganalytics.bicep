// =============================================================================
// Module: loganalytics.bicep  (Log Analytics workspace)
// -----------------------------------------------------------------------------
// The Container Apps Environment sends logs here. It is a hard dependency of the
// managed environment, so we provision it first and pass its id/key upstream.
//
// STARTER SKELETON — compiles as-is; decisions left as // TODO.
// =============================================================================

@description('Azure region for the workspace.')
param location string

@description('Name of the Log Analytics workspace.')
param workspaceName string

@description('Tags applied to the workspace.')
param tags object = {}

// TODO: Tune retention for cost vs. how long you need logs during the event.
//       30 days is the free-tier default.
@minValue(30)
@maxValue(730)
param retentionInDays int = 30

resource workspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: workspaceName
  location: location
  tags: tags
  properties: {
    // TODO: PerGB2018 is the standard pay-as-you-go SKU. Revisit if you have a
    //       committed-tier or a capacity reservation.
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: retentionInDays
  }
}

@description('The resource ID of the Log Analytics workspace.')
output workspaceId string = workspace.id

@description('The customer/workspace GUID used by the Container Apps environment.')
output customerId string = workspace.properties.customerId
