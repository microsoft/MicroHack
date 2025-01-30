// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.
/*
SUMMARY: Module to create Azure Bastion.
DESCRIPTION: This module will create a deployment which will create the Azure Bastion Hosts
AUTHOR/S: David Smith (CSA FSI)
*/

param namePrefix string
var nameSuffix = 'bastion'
var location = resourceGroup().location
var Name = '${namePrefix}-${location}-${nameSuffix}'
param bastionSubnetId string
//param logAnalyticsWorkspaceId string

module bastionpublicIp '../NETWORK/pip.bicep' = {
  name: '${Name}-pip'
  scope: resourceGroup()
  params: {
    Name: Name
    //logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    skuName: 'Standard'
  }
}



resource bastion 'Microsoft.Network/bastionHosts@2024-05-01' = {
  name: Name
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'bastionIpConfig'
        properties: {
          subnet: {
            id: bastionSubnetId
          }
          publicIPAddress: {
            id: bastionpublicIp.outputs.pipId
          }
        }
      }
    ]
  }
  dependsOn: [
    bastionpublicIp
  ]
}

// resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
//   name: '${bastion.name}-diagnostic'
//   scope: bastion
//   properties: {
//     workspaceId: logAnalyticsWorkspaceId
//     logs: [
//       {
//         category: 'BastionAuditLogs'
//         enabled: true
//         retentionPolicy: {
//           days: 0
//           enabled: false
//         }
//       }
//     ]
//     metrics: [
//       {
//         category: 'AllMetrics'
//         enabled: true
//         retentionPolicy: {
//           days: 0
//           enabled: false
//         }
//       }
//     ]
//   }
// }
