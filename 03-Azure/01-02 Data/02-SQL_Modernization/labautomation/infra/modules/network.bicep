param location string
param vnetName string
param vnetAddressPrefix string
param managedInstanceSubnetPrefix string
param managementSubnetPrefix string
param teamSubnetPrefix string
param bastionSubnetPrefix string
param PrivateEndpointsSubnetPrefix string
param tags object

resource managedInstanceNsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: '${vnetName}-mi-nsg'
  location: location
  tags: tags

  properties: {
    securityRules: [
      {
        name: 'allow-mi-subnet-inbound'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: managedInstanceSubnetPrefix
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'allow-health-probe-inbound'
        properties: {
          priority: 110
          direction: 'Inbound'
          access: 'Allow'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'AzureLoadBalancer'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'allow-tds-inbound'
        properties: {
          priority: 1000
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '1433'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'allow-redirect-inbound'
        properties: {
          priority: 1010
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '11000-11999'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

resource managedInstanceRouteTable 'Microsoft.Network/routeTables@2024-05-01' = {
  name: '${vnetName}-mi-rt'
  location: location
  tags: tags

  properties: {
    disableBgpRoutePropagation: false
  }
}

resource vmNsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: '${vnetName}-vm-nsg'
  location: location
  tags: tags

  properties: {
    securityRules: [
      {
        name: 'allow-rdp-from-bastion'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '3389'
          sourceAddressPrefix: bastionSubnetPrefix
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'allow-sql-from-vnet'
        properties: {
          priority: 110
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '1433'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: vnetName
  location: location
  tags: tags

  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }

    subnets: [
      {
        name: 'ManagedInstance'
        properties: {
          addressPrefix: managedInstanceSubnetPrefix

          networkSecurityGroup: {
            id: managedInstanceNsg.id
          }

          routeTable: {
            id: managedInstanceRouteTable.id
          }

          delegations: [
            {
              name: 'managed-instance-delegation'
              properties: {
                serviceName: 'Microsoft.Sql/managedInstances'
              }
            }
          ]
        }
      }
      {
        name: 'Management'
        properties: {
          addressPrefix: managementSubnetPrefix

          networkSecurityGroup: {
            id: vmNsg.id
          }
        }
      }
      {
        name: 'TeamJumpServers'
        properties: {
          addressPrefix: teamSubnetPrefix

          networkSecurityGroup: {
            id: vmNsg.id
          }
        }
      }
      {
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: bastionSubnetPrefix
        }
      }
      {
        name: 'PrivateEndpointsSubnet'
        properties: {
          addressPrefix: PrivateEndpointsSubnetPrefix
        }
      }
    ]
  }
}

output vnetId string = vnet.id

output managedInstanceSubnetId string = resourceId(
  'Microsoft.Network/virtualNetworks/subnets',
  vnet.name,
  'ManagedInstance'
)

output managementSubnetId string = resourceId(
  'Microsoft.Network/virtualNetworks/subnets',
  vnet.name,
  'Management'
)

output teamSubnetId string = resourceId(
  'Microsoft.Network/virtualNetworks/subnets',
  vnet.name,
  'TeamJumpServers'
)

output bastionSubnetId string = resourceId(
  'Microsoft.Network/virtualNetworks/subnets',
  vnet.name,
  'AzureBastionSubnet'
)

output PrivateEndpointsSubnetId string = resourceId(
  'Microsoft.Network/virtualNetworks/subnets',
  vnet.name,
  'PrivateEndpointsSubnet'
)
