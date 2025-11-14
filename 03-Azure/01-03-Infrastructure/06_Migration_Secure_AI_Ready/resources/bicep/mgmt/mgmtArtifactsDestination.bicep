
@description('The flavor of ArcBox you want to deploy. Valid values are: \'Full\', \'ITPro\'')
@allowed([
  'ITPro'
])
param flavor string = 'ITPro'

@description('Azure Region to deploy the Log Analytics Workspace')
param location string = resourceGroup().location

@description('Choice to deploy Bastion to connect to the client VM')
param deployBastion bool = false

@description('Bastion host Sku name')
@allowed([
  'Basic'
  'Standard'
  'Developer'
])
param bastionSku string = 'Basic'

@description('DNS Server configuration')
param dnsServers array = []

@maxLength(7)
@description('The naming prefix for the nested virtual machines. Example: ArcBox-Win2k19')
param Prefix string = 'MHBox'

var userName = contains(deployer().userPrincipalName, '@') ? substring(deployer().userPrincipalName, 0, indexOf(deployer().userPrincipalName, '@')) : deployer().userPrincipalName

var namingPrefix = '${Prefix}-${userName}'

@description('Name of the VNet')
var virtualNetworkNameDST string = '${namingPrefix}-destination-VNet'

@description('Name of the subnet in the virtual network')
var subnetDSTName string = '${namingPrefix}-destination-Subnet'

@description('Name of the NAT Gateway')
var natGatewayNameDST string = '${namingPrefix}-destination-NatGateway'

@description('Name of the Network Security Group')
var networkSecurityGroupDSTName string = '${namingPrefix}-destination-NSG'

@description('Name of the Bastion Network Security Group')
var bastionDSTNetworkSecurityGroupName string = '${namingPrefix}-destination-Bastion-NSG'
var subnetDSTAddressPrefix = '10.2.1.0/24'
var DSTaddressPrefix = '10.2.0.0/16'
var bastionDSTSubnetName = 'AzureBastionSubnet'
var bastionDSTSubnetRef = '${destinationVirtualNetwork.id}/subnets/${bastionDSTSubnetName}'
var bastionDSTName = '${namingPrefix}-destination-Bastion'
var bastionDSTSubnetIpPrefix = '10.2.3.64/26'
var bastionDSTPublicIpAddressName = '${bastionDSTName}-PIP'

var primaryDSTSubnet = [
  {
    name: subnetDSTName
    properties: {
      addressPrefix: subnetDSTAddressPrefix
      privateEndpointNetworkPolicies: 'Enabled'
      privateLinkServiceNetworkPolicies: 'Enabled'
      networkSecurityGroup: {
        id: networkSecurityGroupDST.id
      }
      natGateway: (deployBastion || flavor != 'ITPro') ? {
        id: natGatewayDST.id
      } : null
      defaultOutboundAccess: false
    }
  }
]
var bastionDSTSubnet = bastionSku != 'Developer'
  ? [
      {
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: bastionDSTSubnetIpPrefix
          networkSecurityGroup: {
            id: bastionnetworkSecurityGroupDST.id
          }
        }
      }
    ]
  : []

resource destinationVirtualNetwork 'Microsoft.Network/virtualNetworks@2024-07-01' = {
  name: virtualNetworkNameDST
  location: location
  dependsOn: [
    
  ]
  properties: {
    addressSpace: {
      addressPrefixes: [
        DSTaddressPrefix
      ]
    }
    dhcpOptions: {
      dnsServers: dnsServers
    }
    subnets: (deployBastion == false && flavor != 'DataOps')
      ? primaryDSTSubnet
          : (deployBastion == true && flavor != 'DataOps')
              ? union(primaryDSTSubnet, bastionDSTSubnet)
              : (deployBastion == true && flavor == 'DataOps')
                  ? union(primaryDSTSubnet, bastionDSTSubnet)
                  : primaryDSTSubnet
  }
}


resource natDSTGatewayPublicIp 'Microsoft.Network/publicIPAddresses@2024-07-01' = if (deployBastion || flavor != 'ITPro') {
  name: '${natGatewayNameDST}-PIP'
  location: location
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
    idleTimeoutInMinutes: 4
  }
  sku: {
    name: 'Standard'
  }
}

resource natGatewayDST 'Microsoft.Network/natGateways@2024-07-01' = if (deployBastion || flavor != 'ITPro') {
  name: natGatewayNameDST
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIpAddresses: [
      {
        id: natDSTGatewayPublicIp.id
      }
    ]
    idleTimeoutInMinutes: 4
  }
}


resource networkSecurityGroupDST 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: networkSecurityGroupDSTName
  location: location
  dependsOn: [
    
  ]
  properties: {
    securityRules: [
      {
        name: 'allow_traefik_lb_external'
        properties: {
          priority: 204
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '32323'
        }
      }
      {
        name: 'allow_WebApp_Inbound'
        properties: {
          priority: 214
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '80'
        }
      }      
    ]
  }
}

resource bastionnetworkSecurityGroupDST 'Microsoft.Network/networkSecurityGroups@2024-05-01' = if (deployBastion == true) {
  name: bastionDSTNetworkSecurityGroupName
  location: location
  dependsOn: [
    
  ]
  properties: {
    securityRules: [
      {
        name: 'bastion_allow_https_inbound'
        properties: {
          priority: 200
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: 'Internet'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '443'
        }
      }
      {
        name: 'bastion_allow_gateway_manager_inbound'
        properties: {
          priority: 201
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: 'GatewayManager'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '443'
        }
      }
      {
        name: 'bastion_allow_load_balancer_inbound'
        properties: {
          priority: 202
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: 'AzureLoadBalancer'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '443'
        }
      }
      {
        name: 'bastion_allow_host_comms'
        properties: {
          priority: 203
          protocol: '*'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: 'VirtualNetwork'
          sourcePortRange: '*'
          destinationAddressPrefix: 'VirtualNetwork'
          destinationPortRanges: [
            '8080'
            '5701'
          ]
        }
      }
      {
        name: 'bastion_allow_ssh_rdp_outbound'
        properties: {
          priority: 204
          protocol: '*'
          access: 'Allow'
          direction: 'Outbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: 'VirtualNetwork'
          destinationPortRanges: [
            '22'
            '3389'
          ]
        }
      }
      {
        name: 'bastion_allow_azure_cloud_outbound'
        properties: {
          priority: 205
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Outbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: 'AzureCloud'
          destinationPortRange: '443'
        }
      }
      {
        name: 'bastion_allow_bastion_comms'
        properties: {
          priority: 206
          protocol: '*'
          access: 'Allow'
          direction: 'Outbound'
          sourceAddressPrefix: 'VirtualNetwork'
          sourcePortRange: '*'
          destinationAddressPrefix: 'VirtualNetwork'
          destinationPortRanges: [
            '8080'
            '5701'
          ]
        }
      }
      {
        name: 'bastion_allow_get_session_info'
        properties: {
          priority: 207
          protocol: '*'
          access: 'Allow'
          direction: 'Outbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: 'Internet'
          destinationPortRanges: [
            '80'
            '443'
          ]
        }
      }
    ]
  }
}

resource publicIpAddressDST 'Microsoft.Network/publicIPAddresses@2024-05-01' = if (deployBastion == true) {
  name: bastionDSTPublicIpAddressName
  location: location
  dependsOn: [
    
  ]
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
    idleTimeoutInMinutes: 4
  }
  sku: {
    name: 'Standard'
  }
}

resource bastionHostDST 'Microsoft.Network/bastionHosts@2024-05-01' = if (deployBastion == true) {
  name: bastionDSTName
  location: location
  dependsOn: [
    
  ]
  sku: {
    name: bastionSku
  }
  properties: {
    virtualNetwork: bastionSku == 'Developer'
      ? {
          id: destinationVirtualNetwork.id
        }
      : null
    ipConfigurations: bastionSku != 'Developer'
      ? [
          {
            name: 'IpConf'
            properties: {
              publicIPAddress: {
                id: publicIpAddressDST.id
              }
              subnet: {
                id: bastionDSTSubnetRef
              }
            }
          }
        ]
      : null
  }
}



output vnetId string = destinationVirtualNetwork.id
output subnetId string = destinationVirtualNetwork.properties.subnets[0].id
