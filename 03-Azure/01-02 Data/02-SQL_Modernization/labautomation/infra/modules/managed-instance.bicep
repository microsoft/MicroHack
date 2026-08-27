param location string
param managedInstanceName string
param subnetId string
param privateEndpointName string
param privateEndpointSubnetId string
param vnetId string
param administratorLogin string

@secure()
param administratorLoginPassword string

@allowed([
  4
  8
  16
  24
  32
  40
  64
  80
])
param vCores int = 8

@minValue(32)
@maxValue(16384)
param storageSizeInGB int = 256

param tags object

resource managedInstance 'Microsoft.Sql/managedInstances@2025-02-01-preview' = {
  name: managedInstanceName
  location: location
  tags: tags

  identity: {
    type: 'SystemAssigned'
  }

  sku: {
    name: 'GP_Gen5'
    tier: 'GeneralPurpose'
    family: 'Gen5'
    capacity: vCores
  }

  properties: {
    administratorLogin: administratorLogin
    administratorLoginPassword: administratorLoginPassword

    subnetId: subnetId
    licenseType: 'LicenseIncluded'

    vCores: vCores
    storageSizeInGB: storageSizeInGB

    isGeneralPurposeV2: true

    publicDataEndpointEnabled: false
    //publicDataEndpointEnabled: true
    proxyOverride: 'Proxy'
    //proxyOverride: 'Redirect'
    minimalTlsVersion: '1.2'
    requestedBackupStorageRedundancy: 'Local'
    timezoneId: 'UTC'
  }
}

resource managedInstancePrivateEndpoint 'Microsoft.Network/privateEndpoints@2024-05-01' = {
  name: privateEndpointName
  location: location

  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }

    privateLinkServiceConnections: [
      {
        name: 'managedInstanceConnection'

        properties: {
          privateLinkServiceId: managedInstance.id
          groupIds: [
            'managedInstance'
          ]
        }
      }
    ]
  }
}

resource sqlPrivateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: 'privatelink${environment().suffixes.sqlServerHostname}'
  location: 'global'
}

resource sqlPrivateDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  name: 'vnet-link'
  parent: sqlPrivateDnsZone
  location: 'global'

  properties: {
    registrationEnabled: false

    virtualNetwork: {
      id: vnetId
    }
  }
}

resource managedInstancePrivateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-05-01' = {
  name: 'default'
  parent: managedInstancePrivateEndpoint

  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'sql'

        properties: {
          privateDnsZoneId: sqlPrivateDnsZone.id
        }
      }
    ]
  }
}

output managedInstanceName string = managedInstance.name

output fullyQualifiedDomainName string = managedInstance.properties.fullyQualifiedDomainName

output sqlmiPrincipalId string = managedInstance.identity.principalId
