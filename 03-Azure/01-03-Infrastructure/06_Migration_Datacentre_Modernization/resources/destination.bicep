@description('Location for all resources')
param location string

// Network

resource destinationVnetNsg 'Microsoft.Network/networkSecurityGroups@2022-05-01' = {
  name: 'destination-vnet-nsg'
  location: location
  properties: {
    securityRules: [
      {
        name: 'default-allow-3389'
        properties: {
          priority: 1000
          access: 'Allow'
          direction: 'Inbound'
          destinationPortRange: '3389'
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'default-allow-22'
        properties: {
          priority: 2000
          access: 'Allow'
          direction: 'Inbound'
          destinationPortRange: '22'
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

resource destinationVnet 'Microsoft.Network/virtualNetworks@2022-05-01' = {
  name: 'destination-vnet'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.1.2.0/24'
      ]
    }
    subnets: [
      {
        name: 'destination-subnet'
        properties: {
          addressPrefix: '10.1.2.0/24'
          networkSecurityGroup: {
            id: destinationVnetNsg.id
          }
        }
      }
    ]
  }
}
