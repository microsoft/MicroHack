// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.
/*
SUMMARY: Module to create an Azure Traffic Manager
DESCRIPTION: This module will create a deployment which will create an Azure Traffic Manager
AUTHOR/S: David Smith (CSA FSI)
*/

param namePrefix string
var nameSuffix = 'trafficmanager'
var location = resourceGroup().location
var unique = substring(uniqueString(resourceGroup().id), 0, 8)
var Name = '${namePrefix}-${location}-${nameSuffix}-${unique}'
param endpoint1Target string
param endpoint2Target string
// param logAnalyticsWorkspaceId string

//Resources
@description('Traffic Manager Profile')
resource trafficManager 'Microsoft.Network/trafficmanagerprofiles@2022-04-01' = {
  name: Name
  location: 'global'
  properties: {
    profileStatus: 'Enabled'
    trafficRoutingMethod: 'Priority'
    dnsConfig: {
      relativeName: Name
      ttl: 30
    }
    monitorConfig: {
      protocol: 'TCP'
      port: 80 // http port
      path: null
    }
    endpoints: [
      {
        name: 'vmEndpt1'
        type: 'Microsoft.Network/trafficManagerProfiles/externalEndpoints'
        properties: {
          target: endpoint1Target
          endpointStatus: 'Enabled'
          priority: 1
        }
      }
      {
        name: 'vmEndpt2'
        type: 'Microsoft.Network/trafficManagerProfiles/externalEndpoints'
        properties: {
          target: endpoint2Target
          endpointStatus: 'Enabled'
          priority: 2
        }
      }
    ]
  }
}

// Define the Diagnostic Settings for the Traffic Manager
// resource trafficManagerDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
//   name: 'trafficManagerDiagSettings'
//   scope: trafficManager
//   properties: {
//     logs: [
//       {
//         category: 'ProbeHealthStatusEvents'
//         enabled: true
//       }
//     ]
//     metrics: [
//       {
//         category: 'AllMetrics'
//         enabled: true
//       }
//     ]
//     workspaceId: logAnalyticsWorkspaceId
//   }
// }

//Output
@description('Output the Traffic Manager ID & FQDN')
output trafficManagerId string = trafficManager.id
output trafficManagerfqdn string = trafficManager.properties.dnsConfig.fqdn
