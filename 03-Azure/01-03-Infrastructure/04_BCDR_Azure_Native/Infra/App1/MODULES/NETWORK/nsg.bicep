// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.
/*
SUMMARY: Module to create a Network Security Groups.
DESCRIPTION: This module will create a deployment which will create NSGs 
AUTHOR/S: David Smith (CSA FSI)
*/

param namePrefix string
var nameSuffix = 'nsg'
var location = resourceGroup().location
var Name = '${namePrefix}-${nameSuffix}'
param securityRules array
// param logAnalyticsWorkspaceId string

// Resources
@description('Network Security Group and rules')
resource nsg 'Microsoft.Network/networkSecurityGroups@2024-01-01' = {
  name: Name
  location: location
  properties: {
    securityRules: securityRules
  }
}

// Define the Diagnostic Settings for the NSG
// resource nsgDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
//   name: '${Name}-diag'
//   scope: nsg
//   properties: {
//     logs: [
//       {
//         category: 'NetworkSecurityGroupEvent'
//         enabled: true
//       }
//       {
//         category: 'NetworkSecurityGroupRuleCounter'
//         enabled: true
//       }
//     ]
//     metrics: []
//     workspaceId: logAnalyticsWorkspaceId
//   }
// }

// Output
@description('Output the NSG ID')
output name string = Name
output nsgId string = nsg.id
