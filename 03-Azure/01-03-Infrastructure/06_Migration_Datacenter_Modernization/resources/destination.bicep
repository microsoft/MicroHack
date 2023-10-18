// Module Paramaters
@description('Location to deploy all resources')
param location string

@description('Prefix used in the Naming for multiple Deployments in the same Subscription')
param prefix string

@description('Suffix used in the Naming for multiple Deployments in the same Subscription')
param suffix string

@description('Number of the deployment used for multiple Deployments in the same Subscription')
param deployment int

// Resources
// https://learn.microsoft.com/en-us/azure/templates/microsoft.network/networksecuritygroups?pivots=deployment-language-bicep
@description('Network security group in destination network')
resource destinationVnetNsg 'Microsoft.Network/networkSecurityGroups@2022-05-01' = {
  name: '${prefix}${deployment}${suffix}-destination-vnet-nsg'
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

// https://learn.microsoft.com/en-us/azure/templates/Microsoft.Network/virtualNetworks?pivots=deployment-language-bicep
@description('Virtual network for the destination resources')
resource destinationVnet 'Microsoft.Network/virtualNetworks@2022-05-01' = {
  name: '${prefix}${deployment}${suffix}-destination-vnet'
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

// https://learn.microsoft.com/en-us/azure/templates/microsoft.network/publicipaddresses?pivots=deployment-language-bicep
@description('Destination Bastion Public IP')
resource destinationBastionPip 'Microsoft.Network/publicIPAddresses@2022-05-01' = {
  name: '${prefix}${deployment}${suffix}-destination-bastion-pip'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

// https://learn.microsoft.com/en-us/azure/templates/microsoft.network/bastionhosts?pivots=deployment-language-bicep
@description('Destination Network Bastion to access the destination Servers')
resource destinationBastion 'Microsoft.Network/bastionHosts@2022-07-01' = {
  name: '${prefix}${deployment}${suffix}-destination-bastion'
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
