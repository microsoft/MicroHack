// Virtual network with all subnets, NSGs and the SQL MI route table.
// Faithful Bicep port of infra/modules/vnet (main.tf, nsg.tf, route_table.tf).

@description('Azure region.')
param location string

@description('AZD/lab environment name (used for tagging).')
param envName string

@description('Name of the virtual network.')
param vnetName string = 'SQLHACK-SHARED-vnet'

@description('Address space for the virtual network.')
param addressSpace array = [
  '10.0.0.0/16'
]

@description('Tags to apply to all resources.')
param tags object = {}

var mergedTags = union(tags, {
  environment: envName
})

// ─────────────────────────────────────────────
// NSGs
// ─────────────────────────────────────────────

// ManagedInstance subnet NSG. In the Terraform version the NSG was created empty
// and the 3342 rule was added by the SQL MI module; here it is inlined.
resource sqlMiNsg 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: 'nsg-sqlhackmi'
  location: location
  tags: mergedTags
  properties: {
    securityRules: [
      {
        name: 'allow-sqlmi-inbound-tcp-3342-internet'
        properties: {
          priority: 1000
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '3342'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

resource bastionNsg 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: 'sqlhack-shared-bastion-nsg'
  location: location
  tags: mergedTags
  properties: {
    securityRules: [
      {
        name: 'allow-bastion-inbound-https-internet'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'allow-bastion-inbound-gateway-manager'
        properties: {
          priority: 110
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: 'GatewayManager'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'allow-bastion-inbound-azure-lb'
        properties: {
          priority: 120
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: 'AzureLoadBalancer'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'allow-bastion-inbound-host-comm'
        properties: {
          priority: 130
          direction: 'Inbound'
          access: 'Allow'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRanges: [
            '8080'
            '5701'
          ]
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
        }
      }
      {
        name: 'deny-bastion-inbound-all'
        properties: {
          priority: 4096
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'allow-bastion-outbound-ssh-rdp'
        properties: {
          priority: 100
          direction: 'Outbound'
          access: 'Allow'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRanges: [
            '22'
            '3389'
          ]
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'VirtualNetwork'
        }
      }
      {
        name: 'allow-bastion-outbound-azure-cloud'
        properties: {
          priority: 110
          direction: 'Outbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'AzureCloud'
        }
      }
      {
        name: 'allow-bastion-outbound-host-comm'
        properties: {
          priority: 120
          direction: 'Outbound'
          access: 'Allow'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRanges: [
            '8080'
            '5701'
          ]
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
        }
      }
      {
        name: 'allow-bastion-outbound-session-info'
        properties: {
          priority: 130
          direction: 'Outbound'
          access: 'Allow'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '80'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'Internet'
        }
      }
    ]
  }
}

resource managementNsg 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: 'sqlhack-shared-mgmt-nsg'
  location: location
  tags: mergedTags
  properties: {
    securityRules: [
      {
        name: 'allow-mgmt-inbound-vnet'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
        }
      }
      {
        name: 'allow-mgmt-inbound-bastion'
        properties: {
          priority: 110
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRanges: [
            '22'
            '3389'
          ]
          sourceAddressPrefix: '10.0.4.0/24'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'deny-mgmt-inbound-all'
        properties: {
          priority: 4096
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

resource teamJumpboxNsg 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: 'sqlhack-shared-jump-nsg'
  location: location
  tags: mergedTags
  properties: {
    securityRules: [
      {
        name: 'allow-jump-inbound-bastion'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRanges: [
            '22'
            '3389'
          ]
          sourceAddressPrefix: '10.0.4.0/24'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'allow-jump-inbound-vnet'
        properties: {
          priority: 110
          direction: 'Inbound'
          access: 'Allow'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
        }
      }
      {
        name: 'deny-jump-inbound-all'
        properties: {
          priority: 4096
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

resource appServiceNsg 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: 'SQLHACK-appservice-nsg'
  location: location
  tags: mergedTags
  properties: {
    securityRules: [
      {
        name: 'allow-appservice-inbound-vnet'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
        }
      }
      {
        name: 'allow-appservice-inbound-alb'
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
        name: 'deny-appservice-inbound-all'
        properties: {
          priority: 4096
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

resource fabricNsg 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: 'sqlhack-shared-fabric-nsg'
  location: location
  tags: mergedTags
  properties: {
    securityRules: [
      {
        name: 'allow-fabric-inbound-vnet'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
        }
      }
      {
        name: 'deny-fabric-inbound-all'
        properties: {
          priority: 4096
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

resource streamingNsg 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: 'SQLHACK-streaming-nsg'
  location: location
  tags: mergedTags
  properties: {
    securityRules: [
      {
        name: 'allow-streaming-inbound-vnet'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
        }
      }
      {
        name: 'deny-streaming-inbound-all'
        properties: {
          priority: 4096
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

// ─────────────────────────────────────────────
// Route table for the ManagedInstance subnet
// ─────────────────────────────────────────────
resource sqlMiRouteTable 'Microsoft.Network/routeTables@2023-11-01' = {
  name: 'rt-sqlhackmi'
  location: location
  tags: mergedTags
  properties: {
    disableBgpRoutePropagation: false
  }
}

// ─────────────────────────────────────────────
// Virtual network with inline subnets
// ─────────────────────────────────────────────
resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: vnetName
  location: location
  tags: mergedTags
  properties: {
    addressSpace: {
      addressPrefixes: addressSpace
    }
    subnets: [
      {
        name: 'GatewaySubnet'
        properties: {
          addressPrefixes: [
            '10.0.0.0/24'
          ]
          defaultOutboundAccess: false
        }
      }
      {
        name: 'ManagedInstance'
        properties: {
          addressPrefixes: [
            '10.0.1.0/24'
          ]
          defaultOutboundAccess: false
          networkSecurityGroup: {
            id: sqlMiNsg.id
          }
          routeTable: {
            id: sqlMiRouteTable.id
          }
          delegations: [
            {
              name: 'sql-mi-delegation'
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
          addressPrefixes: [
            '10.0.2.0/24'
          ]
          defaultOutboundAccess: false
          networkSecurityGroup: {
            id: managementNsg.id
          }
        }
      }
      {
        name: 'TeamJumpbox'
        properties: {
          addressPrefixes: [
            '10.0.3.0/24'
          ]
          defaultOutboundAccess: false
          networkSecurityGroup: {
            id: teamJumpboxNsg.id
          }
        }
      }
      {
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefixes: [
            '10.0.4.0/24'
          ]
          defaultOutboundAccess: false
          networkSecurityGroup: {
            id: bastionNsg.id
          }
        }
      }
      {
        name: 'snet-appservice'
        properties: {
          addressPrefixes: [
            '10.0.5.0/24'
          ]
          defaultOutboundAccess: false
          networkSecurityGroup: {
            id: appServiceNsg.id
          }
          delegations: [
            {
              name: 'appservice-delegation'
              properties: {
                serviceName: 'Microsoft.Web/serverFarms'
              }
            }
          ]
        }
      }
      {
        name: 'fabric_vnet'
        properties: {
          addressPrefixes: [
            '10.0.6.0/24'
          ]
          defaultOutboundAccess: false
          networkSecurityGroup: {
            id: fabricNsg.id
          }
          delegations: [
            {
              name: 'powerplatform-delegation'
              properties: {
                serviceName: 'Microsoft.PowerPlatform/vnetaccesslinks'
              }
            }
          ]
        }
      }
      {
        name: 'StreamingVnet'
        properties: {
          addressPrefixes: [
            '10.0.7.0/24'
          ]
          defaultOutboundAccess: false
          networkSecurityGroup: {
            id: streamingNsg.id
          }
        }
      }
    ]
  }
}

output vnetName string = vnet.name
output vnetId string = vnet.id
output managedInstanceSubnetId string = resourceId('Microsoft.Network/virtualNetworks/subnets', vnet.name, 'ManagedInstance')
output appServiceSubnetId string = resourceId('Microsoft.Network/virtualNetworks/subnets', vnet.name, 'snet-appservice')
output fabricSubnetName string = 'fabric_vnet'
output sqlMiNsgName string = sqlMiNsg.name
