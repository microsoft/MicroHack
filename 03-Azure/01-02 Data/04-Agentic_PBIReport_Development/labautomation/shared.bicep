param location string
param capacityName string
param suffix string
@minLength(1)
param capacityAdministrators array
param tags object
param participantSubnets array
@minValue(2)
@maxValue(50)
param bastionScaleUnits int
var desktopSubnets = [for subnet in participantSubnets: {
  name: subnet.name
  properties: {
    addressPrefix: subnet.prefix
    defaultOutboundAccess: false
    natGateway: { id: nat.id }
  }
}]

resource egressIp 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: 'egress-${suffix}'
  location: location
  tags: tags
  sku: { name: 'Standard' }
  properties: { publicIPAllocationMethod: 'Static' }
}
resource nat 'Microsoft.Network/natGateways@2024-05-01' = {
  name: 'nat-${suffix}'
  location: location
  tags: tags
  sku: { name: 'Standard' }
  properties: { publicIpAddresses: [{ id: egressIp.id }] }
}
resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: 'vnet-${suffix}'
  location: location
  tags: tags
  properties: {
    addressSpace: { addressPrefixes: ['10.90.0.0/16'] }
    subnets: concat([
      {
        name: 'AzureBastionSubnet'
        properties: { addressPrefix: '10.90.0.0/26' }
      }
    ], desktopSubnets)
  }
}
resource bastionIp 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: 'bastion-ip-${suffix}'
  location: location
  tags: tags
  sku: { name: 'Standard' }
  properties: { publicIPAllocationMethod: 'Static' }
}
resource bastion 'Microsoft.Network/bastionHosts@2024-05-01' = {
  name: 'bastion-${suffix}'
  location: location
  tags: tags
  sku: { name: 'Standard' }
  properties: {
    scaleUnits: bastionScaleUnits
    enableTunneling: false
    enableIpConnect: false
    enableShareableLink: false
    ipConfigurations: [
      {
        name: 'primary'
        properties: {
          subnet: { id: '${vnet.id}/subnets/AzureBastionSubnet' }
          publicIPAddress: { id: bastionIp.id }
        }
      }
    ]
  }
}

resource capacity 'Microsoft.Fabric/capacities@2023-11-01' = {
  name: capacityName
  location: location
  tags: tags
  sku: {
    name: 'F16'
    tier: 'Fabric'
  }
  properties: {
    administration: {
      members: capacityAdministrators
    }
  }
}

output capacityResourceId string = capacity.id
