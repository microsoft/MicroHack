/**
 * @module private-endpoint-multi-dns
 * @description Private endpoint module that supports multiple DNS zones
 * Used for resources like AI Foundry that require multiple DNS zone configurations
 */

param name string
param privateLinkServiceId string
param groupIds array
param location string
param privateEndpointSubnetId string

@description('Array of DNS zone names to configure for this private endpoint')
param dnsZoneNames array = []

// Legacy parameters for backward compatibility (used when dnsZoneResourceIds is not provided)
param dnsZoneRG string = ''
param dnsSubId string = ''

// New parameter: Array of direct DNS zone resource IDs (preferred over dnsZoneRG/dnsSubId)
@description('Array of DNS zone resource IDs. When provided, takes precedence over dnsZoneRG/dnsSubId lookup')
param dnsZoneResourceIds array = []

param tags object = {}

// Add a parameter to control DNS integration
param enableDnsIntegration bool = length(dnsZoneResourceIds) > 0 || (!empty(dnsZoneRG) && length(dnsZoneNames) > 0)

// Determine if using legacy lookup
var useLegacyDnsLookup = length(dnsZoneResourceIds) == 0 && !empty(dnsZoneRG) && length(dnsZoneNames) > 0

// Reference existing DNS zones using legacy lookup (when dnsZoneResourceIds not provided)
resource privateEndpointDnsZones 'Microsoft.Network/privateDnsZones@2024-06-01' existing = [for zoneName in dnsZoneNames: if (useLegacyDnsLookup) {
  name: zoneName
  scope: resourceGroup(dnsSubId, dnsZoneRG)
}]

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

// DNS zone group using direct resource IDs (preferred)
resource privateEndpointDnsGroupDirect 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2025-05-01' = if (enableDnsIntegration && length(dnsZoneResourceIds) > 0) {
  parent: privateEndpoint
  name: 'privateDnsZoneGroup'
  properties: {
    privateDnsZoneConfigs: [for (zoneId, i) in dnsZoneResourceIds: {
      name: 'dnsConfig${i}'
      properties: {
        privateDnsZoneId: zoneId
      }
    }]
  }
}

// DNS zone group using legacy lookup (when dnsZoneResourceIds not provided)
resource privateEndpointDnsGroupLegacy 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2025-05-01' = if (enableDnsIntegration && length(dnsZoneResourceIds) == 0 && useLegacyDnsLookup) {
  parent: privateEndpoint
  name: 'privateDnsZoneGroup'
  properties: {
    privateDnsZoneConfigs: [for (zoneName, i) in dnsZoneNames: {
      name: 'dnsConfig${i}'
      properties: {
        privateDnsZoneId: privateEndpointDnsZones[i].id
      }
    }]
  }
}

output privateEndpointName string = privateEndpoint.name
