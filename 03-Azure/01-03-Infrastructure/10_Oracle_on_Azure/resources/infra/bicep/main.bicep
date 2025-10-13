targetScope = 'subscription'

param prefix string = 'odaa'
param location string = 'germanywestcentral'
param lawName string = 'odaa'
param postfix string = ''
param subnetAksName string = 'aks'
// param vnetODAAName string = 'ODAAvnet'
// param subnetODAAName string = 'odaasubnet'
param aksVmSize string = 'Standard_D8ds_v5'
param vnetCIDR string = '10.10.0.0'

resource resourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: prefix
  location: location
}

module infra 'infra.bicep' = {
  name: 'deployInfra'
  scope: resourceGroup
  params: {
    prefix: prefix
    location: location
    lawName: lawName
    postfix: postfix
    subnetAksName: subnetAksName
    aksVmSize: aksVmSize
    vnetCIDR: vnetCIDR
  }
}

