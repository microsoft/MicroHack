// param lbName string = 'myLoadBalancer'
var location = resourceGroup().location
param namePrefix string
var nameSuffix = 'lb'
var Name = '${namePrefix}-${location}-${nameSuffix}'
// param logAnalyticsWorkspaceId string

@description('Public IP for the Load Balancer')
module lbPip './pip.bicep' = {
  name: '${Name}-pip'
  scope: resourceGroup()
  params: {
    Name: Name
    // logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    skuName: 'Standard'
  }
}

@description('Load Balancer for the VMs')
resource loadBalancer 'Microsoft.Network/loadBalancers@2024-01-01' = {
  name: Name
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    frontendIPConfigurations: [
      {
        name: 'frontendConfig'
        properties: {
          publicIPAddress: {
            id: lbPip.outputs.pipId
          }
        }
      }
    ]
    backendAddressPools: [
      {
        name: 'backendPool'
      }
    ]
    loadBalancingRules: [
      {
        name: 'httpRule'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/loadBalancers/frontendIpConfigurations', Name, 'frontendConfig')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', Name, 'backendPool')
          }
          probe: {
            id: resourceId('Microsoft.Network/loadBalancers/probes', Name, 'httpProbe')
          }
          protocol: 'Tcp'
          frontendPort: 80
          backendPort: 80
          enableFloatingIP: false
          idleTimeoutInMinutes: 4
          loadDistribution: 'Default'
        }
      }
    ]
    probes: [
      {
        name: 'httpProbe'
        properties: {
          protocol: 'Http'
          port: 80
          requestPath: '/'
          intervalInSeconds: 5
          numberOfProbes: 2
        }
      }
    ]
  }
}

output backendAddressPools array = loadBalancer.properties.backendAddressPools
output lbPipid string = lbPip.outputs.pipId
output loadBalancerId string = loadBalancer.id
output fqdn string = lbPip.outputs.pipFqdn
