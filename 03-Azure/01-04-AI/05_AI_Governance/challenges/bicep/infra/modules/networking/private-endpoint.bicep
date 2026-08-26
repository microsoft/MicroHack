param name string
param privateLinkServiceId string
param groupIds array
param dnsZoneName string
param location string

param privateEndpointSubnetId string

// Legacy parameters for backward compatibility (used when dnsZoneResourceId is not provided)
param dnsZoneRG string = ''
param dnsSubId string = ''

// New parameter: Direct DNS zone resource ID (preferred over dnsZoneRG/dnsSubId)
// When provided, this takes precedence over dnsZoneRG/dnsSubId lookup
param dnsZoneResourceId string = ''

param tags object = {}

// Add a parameter to control DNS integration
param enableDnsIntegration bool = !empty(dnsZoneResourceId) || !empty(dnsZoneRG)

// Determine the effective DNS zone ID to use
// Priority: 1) dnsZoneResourceId if provided, 2) Legacy lookup using dnsZoneRG/dnsSubId
var useLegacyDnsLookup = empty(dnsZoneResourceId) && !empty(dnsZoneRG) && !empty(dnsZoneName)

resource privateEndpointDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' existing = if (useLegacyDnsLookup) {
  name: dnsZoneName
  scope: resourceGroup(dnsSubId, dnsZoneRG)
}

// Effective DNS zone ID: use direct resource ID if provided, otherwise use legacy lookup
var effectiveDnsZoneId = !empty(dnsZoneResourceId) ? dnsZoneResourceId : (useLegacyDnsLookup ? privateEndpointDnsZone.id : '')

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2025-05-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: name
        properties: {
          privateLinkServiceId: privateLinkServiceId
          groupIds: groupIds
        }
      }
    ]
  }
}

resource privateEndpointDnsGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2025-05-01' = if (enableDnsIntegration && !empty(effectiveDnsZoneId)) {
  parent: privateEndpoint
  name: 'privateDnsZoneGroup'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'default'
        properties: {
          privateDnsZoneId: effectiveDnsZoneId
        }
      }
    ]
  }
}

output privateEndpointName string = privateEndpoint.name
