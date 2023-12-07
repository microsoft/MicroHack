// Module Paramaters
@description('Location to deploy all resources')
param location string

@description('Prefix used in the Naming for multiple Deployments in the same Subscription')
param prefix string

@description('Suffix used in the Naming for multiple Deployments in the same Subscription')
param suffix string

@description('Number of the deployment used for multiple Deployments in the same Subscription')
param deployment int

var nsgName = '${prefix}${deployment}${suffix}-destination-nsg'
var vnetName = '${prefix}${deployment}${suffix}-destination-vnet'
var bastionName = '${prefix}${deployment}${suffix}-destination-bastion'
var bastionPipName = '${prefix}${deployment}${suffix}-destination-bastion-pip'
var lbName = '${prefix}${deployment}${suffix}-destination-plb-frontend'
var lbPublicIPAddressName = '${prefix}${deployment}${suffix}-destination-plb-frontend-pip'

// Resources
// https://learn.microsoft.com/en-us/azure/templates/microsoft.network/networksecuritygroups?pivots=deployment-language-bicep
@description('Network security group in destination network')
resource destinationVnetNsg 'Microsoft.Network/networkSecurityGroups@2022-05-01' = {
  name: nsgName
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
  name: vnetName
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
  name: bastionPipName
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
  name: bastionName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    enableTunneling: true
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

// https://learn.microsoft.com/en-us/azure/templates/microsoft.network/loadbalancers?pivots=deployment-language-bicep
@description('Loadbalancer for VMs')
resource lb 'Microsoft.Network/loadBalancers@2021-08-01' = {
  name: lbName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    frontendIPConfigurations: [
      {
        name: 'LoadBalancerFrontEnd'
        properties: {
          publicIPAddress: {
            id: lbPublicIPAddress.id
          }
        }
      }
    ]
    backendAddressPools: [
      {
        name: 'LoadBalancerBackEndPool'
        properties: {
          loadBalancerBackendAddresses: [
            {
              name: 'linuxVmDestination1'
              properties: {
                ipAddress: '10.2.1.4'
                subnet: {
                  id: destinationVnet.properties.subnets[0].id
                }
                // virtualNetwork: {
                //   id: destinationVnet.id
                // }
              }
            }
            {
              name: 'linuxVmDestination2'
              properties: {
                ipAddress: '10.2.1.5'
                subnet: {
                  id: destinationVnet.properties.subnets[0].id
                }
                // virtualNetwork: {
                //   id: destinationVnet.id
                // }
              }
            }
          ]
        }
      }
    ]
    loadBalancingRules: [
      {
        name: 'myHTTPRule'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', lbName, 'LoadBalancerFrontEnd')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', lbName, 'LoadBalancerBackEndPool')
          }
          frontendPort: 80
          backendPort: 80
          enableFloatingIP: false
          idleTimeoutInMinutes: 15
          protocol: 'Tcp'
          enableTcpReset: true
          loadDistribution: 'Default'
          disableOutboundSnat: true
          probe: {
            id: resourceId('Microsoft.Network/loadBalancers/probes', lbName, 'loadBalancerHealthProbe')
          }
        }
      }
    ]
    probes: [
      {
        name: 'loadBalancerHealthProbe'
        properties: {
          protocol: 'Tcp'
          port: 80
          intervalInSeconds: 5
          numberOfProbes: 2
        }
      }
    ]
    outboundRules: []
  }
}

// https://learn.microsoft.com/en-us/azure/templates/microsoft.network/publicipaddresses?pivots=deployment-language-bicep
@description('Load Balancer Public IP')
resource lbPublicIPAddress 'Microsoft.Network/publicIPAddresses@2021-08-01' = {
  name: lbPublicIPAddressName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Static'
  }
}
