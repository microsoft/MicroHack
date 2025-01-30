param namePrefix string
param nameSuffix string
var location = resourceGroup().location
var Name = '${namePrefix}-${nameSuffix}'
param faultDomainCount int = 2
param updateDomainCount int = 5

resource availabilitySet 'Microsoft.Compute/availabilitySets@2024-07-01' = {
  name: Name
  location: location
  properties: {
    platformFaultDomainCount: faultDomainCount
    platformUpdateDomainCount: updateDomainCount
  }
  sku: {
    name: 'Aligned'
  }
}

output avsetId string = availabilitySet.id
