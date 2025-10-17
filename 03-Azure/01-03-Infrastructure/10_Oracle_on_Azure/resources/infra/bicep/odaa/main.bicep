targetScope = 'subscription'

param prefix string = 'odaa'
param postfix string = '1'
param location string = 'germanywestcentral'
param cidr string = '10.0.0.0'
@secure()
param password string

resource resourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: '${prefix}${postfix}'
  location: location
}

module infra 'adb.bicep' = {
  name: 'deployADB-${prefix}${postfix}'
  scope: resourceGroup
  params: {
    prefix: '${prefix}${postfix}'
    cidr: cidr
    password: password
  }
}

