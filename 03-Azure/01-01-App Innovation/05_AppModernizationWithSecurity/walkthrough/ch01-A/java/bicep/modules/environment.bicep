param location string
param environmentName string
param workspaceName string
param storageAccountName string

var seedShareName = 'catalog-seed'
var imagesShareName = 'catalog-images'

resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    allowBlobPublicAccess: false
  }
}

resource files 'Microsoft.Storage/storageAccounts/fileServices@2023-05-01' = {
  parent: storage
  name: 'default'
}

resource seed 'Microsoft.Storage/storageAccounts/fileServices/shares@2023-05-01' = {
  parent: files
  name: seedShareName
  properties: {
    shareQuota: 1
    enabledProtocols: 'SMB'
  }
}

resource images 'Microsoft.Storage/storageAccounts/fileServices/shares@2023-05-01' = {
  parent: files
  name: imagesShareName
  properties: {
    shareQuota: 5
    enabledProtocols: 'SMB'
  }
}

resource workspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: workspaceName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

resource environment 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: environmentName
  location: location
  properties: {
    workloadProfiles: [
      {
        name: 'Consumption'
        workloadProfileType: 'Consumption'
      }
    ]
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: workspace.properties.customerId
        sharedKey: workspace.listKeys().primarySharedKey
      }
    }
  }
}

// SMB mounts use the account key; image pulls use managed identity instead.
resource seedMount 'Microsoft.App/managedEnvironments/storages@2024-03-01' = {
  parent: environment
  name: seedShareName
  properties: {
    azureFile: {
      accountName: storage.name
      accountKey: storage.listKeys().keys[0].value
      shareName: seed.name
      accessMode: 'ReadOnly'
    }
  }
}

resource imagesMount 'Microsoft.App/managedEnvironments/storages@2024-03-01' = {
  parent: environment
  name: imagesShareName
  properties: {
    azureFile: {
      accountName: storage.name
      accountKey: storage.listKeys().keys[0].value
      shareName: images.name
      accessMode: 'ReadOnly'
    }
  }
}

output environmentId string = environment.id
output environmentName string = environment.name
output storageAccountName string = storage.name
output seedShareName string = seedMount.name
output imagesShareName string = imagesMount.name
