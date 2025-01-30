// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.
/*
SUMMARY: Module to create a Public IP Address
DESCRIPTION: This module will create a deployment which will create a Public IP Address
AUTHOR/S: David Smith (CSA FSI)
*/

// param namePrefix string
// var nameSuffix = 'pip'
var location = resourceGroup().location
param Name string
var unique = substring(uniqueString(resourceGroup().id), 0, 8)
var dnsLabelPrefix = '${Name}-${unique}'
// param logAnalyticsWorkspaceId string
param skuName string
var publicIPAllocationMethod = (skuName == 'Standard') ? 'Static' : 'Dynamic'

// Resources
@description('Public IP address')
resource pip 'Microsoft.Network/publicIPAddresses@2024-01-01' = {
  name: '${Name}-pip'
  location: location
  sku: {
    name: skuName
  }
  properties: {
    publicIPAllocationMethod: publicIPAllocationMethod
    dnsSettings: {
      domainNameLabel: dnsLabelPrefix
    }
  }
}

// Define the Diagnostic Settings for the Public IP
// resource publicIPDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
//   name: '${pip.name}-diag'
//   scope: pip
//   properties: {
//     logs: [
//       {
//         category: 'DDoSProtectionNotifications'
//         enabled: true
//       }
//       {
//         category: 'DDoSMitigationFlowLogs'
//         enabled: true
//       }
//       {
//         category: 'DDoSMitigationReports'
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

// Output
@description('Output the public IP ID & FQDN')
output pipId string = pip.id
output pipFqdn string = pip.properties.dnsSettings.fqdn
