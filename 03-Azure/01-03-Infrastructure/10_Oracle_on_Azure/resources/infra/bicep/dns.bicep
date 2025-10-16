// -----------------------------------------------------------------------------------
// Private DNS Zone for Oracle Database on Autonomous Azure (ODAA) FQDN
// -----------------------------------------------------------------------------------

param fqdnODAA string = 'eqsmjgp2.adb.eu-frankfurt-1.oraclecloud.com'
param fqdnODAAApp string = 'eqsmjgp2.adb.eu-frankfurt-1.oraclecloudapps.com'
param fqdnODAAIpv4 string = '10.0.1.165'
param vnetAKSName string

resource vnetAks 'Microsoft.Network/virtualNetworks@2024-10-01' existing = {
  name: vnetAKSName
}

resource pdnsODAA 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: fqdnODAA
  location: 'global'
  properties: {}
}

resource pdnsODAARecord 'Microsoft.Network/privateDnsZones/A@2024-06-01' = {
  parent: pdnsODAA
  name: '@'
  properties: {
    ttl: 3600
    aRecords: [
      {
        ipv4Address: fqdnODAAIpv4
      }
    ]
  }
}

resource fqdnODAA_odaavnet 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  parent: pdnsODAA
  name: 'pdnsODAAAppLink'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnetAks.id
    }
  }
}

resource pdnsODAAApp 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: fqdnODAAApp
  location: 'global'
  properties: {}
}

resource pdnsODAARecordApp 'Microsoft.Network/privateDnsZones/A@2024-06-01' = {
  parent: pdnsODAAApp
  name: '@'
  properties: {
    ttl: 3600
    aRecords: [
      {
        ipv4Address: fqdnODAAIpv4
      }
    ]
  }
}

resource fqdnODAAApp_odaavnet 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  parent: pdnsODAAApp
  name: 'pdnsODAAAppLink'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnetAks.id
    }
  }
}
