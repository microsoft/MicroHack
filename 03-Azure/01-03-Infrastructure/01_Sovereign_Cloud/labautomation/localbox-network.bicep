@description('Name of the LocalBox virtual network')
param virtualNetworkName string = 'LocalBox-VNet'

param subnetName string = 'LocalBox-Subnet'
param location string = resourceGroup().location
param deployBastion bool = false
param natGatewayName string = 'LocalBox-NatGateway'
param networkSecurityGroupName string = 'LocalBox-NSG'
param resourceTags object

resource networkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2024-07-01' = {
  name: networkSecurityGroupName
  location: location
  tags: resourceTags
  properties: {
    securityRules: []
  }
}

resource natGatewayPublicIp 'Microsoft.Network/publicIPAddresses@2024-07-01' = if (deployBastion) {
  name: '${natGatewayName}-PIP'
  location: location
  tags: resourceTags
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
    idleTimeoutInMinutes: 4
  }
}

resource natGateway 'Microsoft.Network/natGateways@2024-07-01' = if (deployBastion) {
  name: natGatewayName
  location: location
  tags: resourceTags
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIpAddresses: [
      {
        id: natGatewayPublicIp.id
      }
    ]
    idleTimeoutInMinutes: 4
  }
}

resource arcVirtualNetwork 'Microsoft.Network/virtualNetworks@2024-07-01' = {
  name: virtualNetworkName
  location: location
  tags: resourceTags
  properties: {
    addressSpace: {
      addressPrefixes: [
        '172.16.0.0/16'
      ]
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: '172.16.1.0/24'
          privateEndpointNetworkPolicies: 'Enabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
          networkSecurityGroup: {
            id: networkSecurityGroup.id
          }
          natGateway: deployBastion ? {
            id: natGateway.id
          } : null
          defaultOutboundAccess: false
        }
      }
    ]
  }
}

resource bastionHost 'Microsoft.Network/bastionHosts@2024-07-01' = if (deployBastion) {
  name: 'LocalBox-Bastion'
  location: location
  tags: resourceTags
  sku: {
    name: 'Developer'
  }
  properties: {
    virtualNetwork: {
      id: arcVirtualNetwork.id
    }
  }
}

output vnetId string = arcVirtualNetwork.id
output subnetId string = arcVirtualNetwork.properties.subnets[0].id
