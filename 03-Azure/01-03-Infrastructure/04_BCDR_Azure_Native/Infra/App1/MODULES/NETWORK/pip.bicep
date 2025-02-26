var location = resourceGroup().location
param Name string
var unique = substring(uniqueString(resourceGroup().id), 0, 8)
var dnsLabelPrefix = '${Name}-${unique}'
// param logAnalyticsWorkspaceId string
param skuName string
var publicIPAllocationMethod = (skuName == 'Standard') ? 'Static' : 'Dynamic'

// Resources
@description('Public IP address')
resource pip 'Microsoft.Network/publicIPAddresses@2024-01-01' = {
  name: '${Name}-pip'
  location: location
  sku: {
    name: skuName
  }
  properties: {
    publicIPAllocationMethod: publicIPAllocationMethod
    dnsSettings: {
      domainNameLabel: dnsLabelPrefix
    }
  }
}

// Output
@description('Output the public IP ID & FQDN')
output pipId string = pip.id
output pipFqdn string = pip.properties.dnsSettings.fqdn
