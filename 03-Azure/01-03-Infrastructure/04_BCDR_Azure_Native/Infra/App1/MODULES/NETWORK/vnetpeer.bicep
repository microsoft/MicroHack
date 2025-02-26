// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.
/*
SUMMARY: Module to create the network peering between two virtual networks.
DESCRIPTION: This module will create a deployment which will create the network peering between two virtual networks.
AUTHOR/S: Cloud for Sovereignty
*/
@description('The VNet on which this peering is created.')
param parHomeNetworkName string

@description('The VNet that this peering targets.')
param parRemoteNetworkId string

@description('Whether to use the remote virtual network\'s gateway or Route Server (typically only true if this is a spoke network).')
param parUseRemoteGateways bool

@description('Whether to allow remote network to utilize gateway links in this home network (typically only true if this is a hub network).')
param parAllowGatewayTransit bool

// Existing VNet resource in which this peering is deployed
resource resHomeVNet 'Microsoft.Network/virtualNetworks@2022-07-01' existing = {
  name: parHomeNetworkName
}

// Peering to the target vnet
resource resPeering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2022-07-01' = {
  name: 'peering-${uniqueString(resourceGroup().id, subscription().id, parRemoteNetworkId)}'
  parent: resHomeVNet
  properties: {
    remoteVirtualNetwork: {
      id: parRemoteNetworkId
    }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: parAllowGatewayTransit
    useRemoteGateways: parUseRemoteGateways
    doNotVerifyRemoteGateways: false
    peeringState: 'Connected'
  }
}
