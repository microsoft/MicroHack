// Locals
param location string = resourceGroup().location

/*
* Network
*/
resource destinationVnetNsg 'Microsoft.Network/networkSecurityGroups@2022-05-01' = {
  name: 'destination-vnet-nsg'
  location: location
  properties: {
    securityRules: [
      {
        name: 'default-allow-80'
        properties: {
          priority: 1000
          access: 'Allow'
          direction: 'Inbound'
          destinationPortRange: '80'
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
        '10.2.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'destination-subnet'
        properties: {
          addressPrefix: '10.2.1.0/24'
          networkSecurityGroup: {
            id: destinationVnetNsg.id
          }
        }
      }
      {
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: '10.2.2.0/24'
        }
      }
    ]
  }
}

resource destinationBastionPip 'Microsoft.Network/publicIPAddresses@2022-05-01' = {
  name: 'destination-bastion-pip'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource sourceBastion 'Microsoft.Network/bastionHosts@2022-07-01' = {
  name: 'destination-bastion'
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          publicIPAddress: {
            id: destinationBastionPip.id
          }
          subnet: {
            id: destinationVnet.properties.subnets[1].id
          }
        }
      }
    ]
  }
}
