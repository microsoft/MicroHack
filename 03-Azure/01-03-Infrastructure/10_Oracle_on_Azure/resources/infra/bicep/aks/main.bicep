targetScope = 'subscription'

param prefix string
param postfix string
param location string
param aksVmSize string = 'Standard_D8ds_v5'
param cidr string

resource resourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: '${prefix}${postfix}'
  location: location
}

module infra 'aks.bicep' = {
  name: 'deployAks-${prefix}${postfix}'
  scope: resourceGroup
  params: {
    prefix: '${prefix}${postfix}'
    aksVmSize: aksVmSize
    cidr: cidr
  }
}

