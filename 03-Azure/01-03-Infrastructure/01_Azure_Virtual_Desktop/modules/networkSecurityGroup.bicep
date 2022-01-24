param name string
param tags object
param location string

resource networkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2019-04-01' = {
  name: 'nsg-${name}'
  location: location
  properties: {
    securityRules: []
  }
  tags: tags
}

output id string = networkSecurityGroup.id
