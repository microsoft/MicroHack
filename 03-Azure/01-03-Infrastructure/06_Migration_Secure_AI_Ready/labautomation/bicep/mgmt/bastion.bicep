targetScope = 'resourceGroup'

param bastionName string
param location string = resourceGroup().location
param tags object = {}

@allowed([
  'Basic'
  'Standard'
  'Developer'
])
param bastionSku string = 'Basic'

param virtualNetworkId string

@description('Dedicated Bastion subnet ID; unused for Developer SKU.')
param bastionSubnetId string

@description('Dedicated Bastion public IP ID; unused for Developer SKU.')
param publicIpAddressId string

resource bastionHost 'Microsoft.Network/bastionHosts@2024-05-01' = {
  name: bastionName
  location: location
  tags: tags
  sku: {
    name: bastionSku
  }
  properties: {
    virtualNetwork: bastionSku == 'Developer'
      ? {
          id: virtualNetworkId
        }
      : null
    ipConfigurations: bastionSku != 'Developer'
      ? [
          {
            name: 'IpConf'
            properties: {
              publicIPAddress: {
                id: publicIpAddressId
              }
              subnet: {
                id: bastionSubnetId
              }
            }
          }
        ]
      : null
  }
}
