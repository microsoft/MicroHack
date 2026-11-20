param location string
param capacityName string
@minLength(1)
param capacityAdministrators array
param tags object

resource capacity 'Microsoft.Fabric/capacities@2023-11-01' = {
  name: capacityName
  location: location
  tags: tags
  sku: {
    name: 'F16'
    tier: 'Fabric'
  }
  properties: {
    administration: {
      members: capacityAdministrators
    }
  }
}

output capacityResourceId string = capacity.id
