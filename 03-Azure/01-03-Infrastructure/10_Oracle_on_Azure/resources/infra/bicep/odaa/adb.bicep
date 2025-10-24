param prefix string
// param vnetCIDR string
// param subnetCIDR string
param cidr string
@secure()
param password string


resource vnet 'Microsoft.Network/virtualNetworks@2021-05-01' = {
  name: prefix
  location: resourceGroup().location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '${cidr}/16'
      ]
    }
  }
}

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2021-05-01' = {
  name: prefix
  parent: vnet
  properties: {
    addressPrefix: '${cidr}/24'
        delegations: [
      {
        name: 'Oracle.Database/networkAttachments'
        properties: {
          serviceName: 'Oracle.Database/networkAttachments'
        }
        type: 'Microsoft.Network/virtualNetworks/subnets/delegations'
      }
    ]
  }
}

resource adb 'Oracle.Database/autonomousDatabases@2025-03-01' = {
  name: prefix
  location: resourceGroup().location
  properties: {
    adminPassword: password
    dataBaseType: 'Regular'
    // autonomousMaintenanceScheduleType: 'Regular'
    // characterSet: 'AL32UTF8'
    computeCount: 2
    computeModel: 'ECPU'
    customerContacts: [
      {
        email: 'maik.sandmann@gmx.net'
      }
    ]
    dataStorageSizeInGbs: 20
    databaseEdition: 'EnterpriseEdition'
    dbVersion: '23ai'
    dbWorkload: 'OLTP'
    displayName: prefix
    isAutoScalingEnabled: false
    isAutoScalingForStorageEnabled: false
    isLocalDataGuardEnabled: false
    isMtlsConnectionRequired: false
    licenseModel: 'BringYourOwnLicense'
    // ncharacterSet: 'AL16UTF16'
    openMode: 'ReadWrite'
    // permissionLevel: 'Restricted'
    // privateEndpointIp: '10.0.1.165'
    // privateEndpointLabel: prefix
    subnetId: subnet.id
    vnetId: vnet.id
    backupRetentionPeriodInDays: 1

  }
}
