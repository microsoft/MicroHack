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

@description('Password for Windows account. Password must have 3 of the following: 1 lower case character, 1 upper case character, 1 number, and 1 special character. The value must be between 12 and 123 characters long')
@minLength(12)
@maxLength(123)
@secure()
param windowsAdminPassword string?

param windowsAdminUserName string?

var userName = contains(deployer().userPrincipalName, '@') ? substring(deployer().userPrincipalName, 0, indexOf(deployer().userPrincipalName, '@')) : deployer().userPrincipalName

var namingPrefix = '${Prefix}-${userName}'

@description('Name of the VNet')
var virtualNetworkName string = '${namingPrefix}-Source-VNet'

@description('Name of the subnet in the virtual network')
var subnetName string = '${namingPrefix}-SourceSubnet'

@description('Name of the NAT Gateway')
var natGatewayName string = '${namingPrefix}-Source-NatGateway'

@description('Name of the Network Security Group')
var networkSecurityGroupName string = '${namingPrefix}-Source-NSG'

@description('Name of the Bastion Network Security Group')
var bastionNetworkSecurityGroupName string = '${namingPrefix}-SourceBastion-NSG'

var unique = uniqueString(resourceGroup().id)
var shortunique = substring(unique, 0, 4)
var keyVaultName = toLower('${namingPrefix}SRC${shortunique}')

var subnetAddressPrefix = '10.1.1.0/24'
var addressPrefix = '10.1.0.0/16'
var bastionSubnetName = 'AzureBastionSubnet'
var bastionSubnetRef = '${sourceVirtualNetwork.id}/subnets/${bastionSubnetName}'
var bastionName = '${namingPrefix}-SourceBastion'
var bastionSubnetIpPrefix = '10.1.3.64/26'
var bastionPublicIpAddressName = '${bastionName}-PIP'

var primarySubnet = [
  {
    name: subnetName
    properties: {
      addressPrefix: subnetAddressPrefix
      privateEndpointNetworkPolicies: 'Enabled'
      privateLinkServiceNetworkPolicies: 'Enabled'
      networkSecurityGroup: {
        id: networkSecurityGroup.id
      }
      natGateway: (deployBastion || flavor != 'ITPro') ? {
        id: natGateway.id
      } : null
      defaultOutboundAccess: false
    }
  }
]
var bastionSubnet = bastionSku != 'Developer'
  ? [
      {
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: bastionSubnetIpPrefix
          networkSecurityGroup: {
            id: bastionNetworkSecurityGroup.id
          }
        }
      }
    ]
  : []

resource sourceVirtualNetwork 'Microsoft.Network/virtualNetworks@2024-07-01' = {
  name: virtualNetworkName
  location: location
  dependsOn: [
    
  ]
  properties: {
    addressSpace: {
      addressPrefixes: [
        addressPrefix
      ]
    }
    dhcpOptions: {
      dnsServers: dnsServers
    }
    subnets: (deployBastion == false && flavor != 'DataOps')
      ? primarySubnet
          : (deployBastion == true && flavor != 'DataOps')
              ? union(primarySubnet, bastionSubnet)
              : (deployBastion == true && flavor == 'DataOps')
                  ? union(primarySubnet, bastionSubnet)
                  : primarySubnet
  }
}


resource natGatewayPublicIp 'Microsoft.Network/publicIPAddresses@2024-07-01' = if (deployBastion || flavor != 'ITPro') {
  name: '${natGatewayName}-PIP'
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

resource natGateway 'Microsoft.Network/natGateways@2024-07-01' = if (deployBastion || flavor != 'ITPro') {
  name: natGatewayName
  location: location
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

resource networkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: networkSecurityGroupName
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
    ]
  }
}

resource bastionNetworkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2024-05-01' = if (deployBastion == true) {
  name: bastionNetworkSecurityGroupName
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

resource publicIpAddress 'Microsoft.Network/publicIPAddresses@2024-05-01' = if (deployBastion == true) {
  name: bastionPublicIpAddressName
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

resource bastionHost 'Microsoft.Network/bastionHosts@2024-05-01' = if (deployBastion == true) {
  name: bastionName
  location: location
  dependsOn: [
    
  ]
  sku: {
    name: bastionSku
  }
  properties: {
    virtualNetwork: bastionSku == 'Developer'
      ? {
          id: sourceVirtualNetwork.id
        }
      : null
    ipConfigurations: bastionSku != 'Developer'
      ? [
          {
            name: 'IpConf'
            properties: {
              publicIPAddress: {
                id: publicIpAddress.id
              }
              subnet: {
                id: bastionSubnetRef
              }
            }
          }
        ]
      : null
  }
}


module keyVault 'br/public:avm/res/key-vault/vault:0.5.1' = {
  name: '${namingPrefix}-kvsrc'
  dependsOn: [
    
  ]
  params: {
    name: toLower(keyVaultName)
    enablePurgeProtection: false
    enableSoftDelete: false
    location: location
  }
}

resource kv 'Microsoft.KeyVault/vaults@2024-04-01-preview' existing = {
  name: keyVaultName
  dependsOn: [
    keyVault
  ]
}

resource windowsAdminPassword_kv_secret 'Microsoft.KeyVault/vaults/secrets@2024-04-01-preview' = if (!empty(windowsAdminPassword)) {
  name: 'windowsAdminPassword'
  parent: kv
  properties: {
    value: windowsAdminPassword
  }
  dependsOn: [
    keyVault
  ]
}

resource windowsAdminUserName_kv_secret 'Microsoft.KeyVault/vaults/secrets@2024-04-01-preview' = if (!empty(windowsAdminUserName)) {
  name: 'windowsAdminUserName'
  parent: kv
  properties: {
    value: windowsAdminUserName
  }
  dependsOn: [
    keyVault
  ]
}

output vnetId string = sourceVirtualNetwork.id
output subnetId string = sourceVirtualNetwork.properties.subnets[0].id
