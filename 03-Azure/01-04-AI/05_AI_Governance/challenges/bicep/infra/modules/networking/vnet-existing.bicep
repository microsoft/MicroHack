param name string
param vnetRG string
param apimSubnetName string
param privateEndpointSubnetName string
param functionAppSubnetName string

@description('Name of the existing AI Foundry agent (network injection) subnet. Required when Foundry network injection is enabled. Leave blank when not using network injection.')
param agentSubnetName string = ''

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2019-11-01' existing = {
  name: name
  scope: resourceGroup(vnetRG)
}

resource apimSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-11-01' existing = {
  name: apimSubnetName
  parent: virtualNetwork
}

resource privateEndpointSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-11-01' existing = {
  name: privateEndpointSubnetName
  parent: virtualNetwork
}

resource functionAppSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-11-01' existing = {
  name: functionAppSubnetName
  parent: virtualNetwork
}

output virtualNetworkId string = virtualNetwork.id
output vnetName string = virtualNetwork.name
output apimSubnetName string = apimSubnet.name
output apimSubnetId string = '${virtualNetwork.id}/subnets/${apimSubnetName}'
output privateEndpointSubnetName string = privateEndpointSubnet.name
output privateEndpointSubnetId string = '${virtualNetwork.id}/subnets/${privateEndpointSubnetName}'
output functionAppSubnetName string = functionAppSubnet.name
output functionAppSubnetId string = '${virtualNetwork.id}/subnets/${functionAppSubnetName}'
output agentSubnetName string = agentSubnetName
output agentSubnetId string = !empty(agentSubnetName) ? '${virtualNetwork.id}/subnets/${agentSubnetName}' : ''
output location string = virtualNetwork.location
output vnetRG string = vnetRG
