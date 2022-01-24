param name string
param tags object
param location string
param vnetAddressPrefix string
param snetAddressPrefix string
param snetName string
param networkSecurityGroupId string
param dnsServer string

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2021-02-01' = {
  name: 'vn-${name}'
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
    dhcpOptions: (!empty(dnsServer) ? {
      dnsServers: [
        dnsServer
      ]
    } : json('null'))
    subnets: [
      {
        name: snetName
        properties: {
          addressPrefix: snetAddressPrefix
          networkSecurityGroup: {
            id: networkSecurityGroupId
          }
        }
      }
    ]
  }
}

output id string = virtualNetwork.id
output name string = virtualNetwork.name
