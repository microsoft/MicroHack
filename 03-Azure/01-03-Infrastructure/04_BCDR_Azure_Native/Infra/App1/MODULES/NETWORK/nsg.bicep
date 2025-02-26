param namePrefix string
var nameSuffix = 'nsg'
var location = resourceGroup().location
var Name = '${namePrefix}-${nameSuffix}'
param securityRules array

// Resources
@description('Network Security Group and rules')
resource nsg 'Microsoft.Network/networkSecurityGroups@2024-01-01' = {
  name: Name
  location: location
  properties: {
    securityRules: securityRules
  }
}

// Output
@description('Output the NSG ID')
output name string = Name
output nsgId string = nsg.id
