// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.
/*
SUMMARY: Module to create a Virtual Network
DESCRIPTION: This module will create a deployment which will create a Virtual Network
AUTHOR/S: David Smith (CSA FSI)
*/

param namePrefix string
var location = resourceGroup().location
var nameSuffix = 'vnet'
var vnetName = '${namePrefix}-${location}-${nameSuffix}'
param vnetConfig object
// param logAnalyticsWorkspaceId string
@description('Network Security Group for the subnets')
var defaultNSGRules = [
  {
    name: 'AllowHTTPFromInternet'
    properties: {
      priority: 100
      direction: 'Inbound'
      access: 'Allow'
      protocol: 'Tcp'
      sourcePortRange: '*'
      sourceAddressPrefix: 'Internet'
      destinationPortRange: '80'
      destinationAddressPrefix: 'VirtualNetwork'
    }
  }
  {
    name: 'AllowHTTPFromLoadBalancer'
    properties: {
      priority: 110
      direction: 'Inbound'
      access: 'Allow'
      protocol: 'Tcp'
      sourcePortRange: '*'
      sourceAddressPrefix: 'AzureLoadBalancer'
      destinationPortRange: '80'
      destinationAddressPrefix: 'VirtualNetwork'
    }
  }
  {
    name: 'IngressfromAzureBastion'
    properties: {
      priority: 200
      direction: 'Inbound'
      access: 'Allow'
      protocol: 'Tcp'
      sourcePortRange: '*'
      // sourceAddressPrefix: vnetConfig.subnets[1].addressPrefix
      sourceAddressPrefix: '10.0.1.0/24'
      destinationPortRanges: [
        '3389'
        '22'
      ]
      destinationAddressPrefix: '*'
    }
  }
  {
    name: 'AllowHTTPOutbound'
    properties: {
      priority: 120
      direction: 'Outbound'
      access: 'Allow'
      protocol: 'Tcp'
      sourcePortRange: '*'
      sourceAddressPrefix: 'VirtualNetwork'
      destinationPortRange: '80'
      destinationAddressPrefix: 'Internet'
    }
  }
]
@description('Network Security Group for the Azure Bastion subnet')
var bastionNSGRules = [
  {
    name: 'AllowHttpsInbound'
    properties: {
      priority: 120
      direction: 'Inbound'
      access: 'Allow'
      protocol: 'Tcp'
      sourcePortRange: '*'
      sourceAddressPrefix: 'Internet'
      destinationPortRange: '443'
      destinationAddressPrefix: '*'
    }
  }
  {
    name: 'AllowGatewayManagerInbound'
    properties: {
      priority: 130
      direction: 'Inbound'
      access: 'Allow'
      protocol: 'Tcp'
      sourcePortRange: '*'
      sourceAddressPrefix: 'GatewayManager'
      destinationPortRange: '443'
      destinationAddressPrefix: '*'
    }
  }
  {
    name: 'AllowAzureLoadBalancerInbound'
    properties: {
      priority: 140
      direction: 'Inbound'
      access: 'Allow'
      protocol: 'Tcp'
      sourcePortRange: '*'
      sourceAddressPrefix: 'AzureLoadBalancer'
      destinationPortRange: '443'
      destinationAddressPrefix: '*'
    }
  }
  {
    name: 'AllowBastionHostCommunication'
    properties: {
      priority: 150
      direction: 'Inbound'
      access: 'Allow'
      protocol: '*'
      sourcePortRange: '*'
      sourceAddressPrefix: 'VirtualNetwork'
      destinationPortRanges: [
        '8080'
        '5701'
      ]
      destinationAddressPrefix: 'VirtualNetwork'
    }
  }
  {
    name: 'AllowSshRdpOutbound'
    properties: {
      priority: 100
      direction: 'Outbound'
      access: 'Allow'
      protocol: '*'
      sourcePortRange: '*'
      sourceAddressPrefix: '*'
      destinationPortRanges: [
        '22'
        '3389'
      ]
      destinationAddressPrefix: 'VirtualNetwork'
    }
  }
  {
    name: 'AllowAzureCloudOutbound'
    properties: {
      priority: 110
      direction: 'Outbound'
      access: 'Allow'
      protocol: 'Tcp'
      sourcePortRange: '*'
      sourceAddressPrefix: '*'
      destinationPortRange: '443'
      destinationAddressPrefix: 'AzureCloud'
    }
  }
  {
    name: 'AllowBastionCommunication'
    properties: {
      priority: 120
      direction: 'Outbound'
      access: 'Allow'
      protocol: '*'
      sourcePortRange: '*'
      sourceAddressPrefix: 'VirtualNetwork'
      destinationPortRanges: [
        '8080'
        '5701'
      ]
      destinationAddressPrefix: 'VirtualNetwork'
    }
  }
  {
    name: 'AllowHttpOutbound'
    properties: {
      priority: 130
      direction: 'Outbound'
      access: 'Allow'
      protocol: '*'
      sourcePortRange: '*'
      sourceAddressPrefix: '*'
      destinationPortRange: '80'
      destinationAddressPrefix: 'Internet'
    }
  }
]

// Resources
@description('Network Security Group for the subnets')
module nsg './nsg.bicep' = [ for subnet in vnetConfig.subnets: {
    name: '${vnetName}-${subnet.name}-nsg'
    scope: resourceGroup()
    params: {
      namePrefix: '${vnetName}-${subnet.name}'
      // logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
      securityRules: (subnet.name == 'AzureBastionSubnet') ? bastionNSGRules : defaultNSGRules
    }
  }]

@description('Virtual Network')
resource virtualNetwork 'Microsoft.Network/virtualNetworks@2024-01-01' = {
  name: vnetName
  location: location
  dependsOn: [
    nsg
  ]
  properties: {
    addressSpace: vnetConfig.addressSpace
    subnets: [ for subnet in vnetConfig.subnets: {
        name: subnet.name
        properties: {
          addressPrefix: subnet.addressPrefix
          networkSecurityGroup: {
            // id: resourceId('Microsoft.Network/networkSecurityGroups', '${namePrefix}-${location}-${nameSuffix}-nsg')
            id: nsg[subnet.name == 'AzureBastionSubnet' ? 1 : 0].outputs.nsgId
          }
        }
      }]
  }
}

// @description('Define the Diagnostic Settings for the VNet')
// resource vnetDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
//   name: '${vnetName}-diag'
//   scope: virtualNetwork
//   properties: {
//     logs: [
//       {
//         category: 'VMProtectionAlerts'
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
@description('Output the virtual network ID & subnets')
output vnets object = virtualNetwork
output name string = vnetName
output id string = virtualNetwork.id
output subnets array = virtualNetwork.properties.subnets
