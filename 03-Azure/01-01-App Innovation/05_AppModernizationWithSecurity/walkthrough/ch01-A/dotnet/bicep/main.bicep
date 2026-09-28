targetScope = 'resourceGroup'

@description('Location for all resources. Derived from the resource group by default.')
param location string = resourceGroup().location

@description('Administrator login for the Azure SQL logical server.')
param sqlAdministratorLogin string

@description('Administrator password for the Azure SQL logical server. Never commit this value.')
@secure()
param sqlAdministratorPassword string

@description('Public IP address allowed to reach the SQL server, e.g. your workstation or Codespace.')
param clientIpAddress string

@description('Name of the catalog database.')
param databaseName string = 'LegoCatalog'

@description('Minimum vCores the serverless database scales down to.')
param databaseMinCapacity string = '0.5'

@description('Maximum vCores the serverless database scales up to.')
param databaseMaxCapacity int = 2

@description('Idle minutes before the serverless database auto-pauses. -1 disables auto-pause.')
param databaseAutoPauseDelayMinutes int = 60

@description('SKU of the Azure Container Registry.')
@allowed([
  'Basic'
  'Standard'
  'Premium'
])
param containerRegistrySku string = 'Basic'

@description('Container image (repository:tag) to run, as pushed to the registry by az acr build.')
param containerImageName string = 'lego-catalog/app:latest'

@description('API key protecting GET /perftest/catalog. Never commit this value.')
@secure()
param performanceApiKey string

@description('Version identity reported by the application, e.g. the git commit SHA.')
param serviceVersion string

@description('Maximum number of Container App replicas.')
param maxReplicas int = 3

// Resource names must be globally unique; seed the suffix with the full resource group id
// so the same resource group always produces the same names.
var uniqueSuffix = uniqueString(resourceGroup().id)
var sqlServerName = 'sql-legocatalog-${uniqueSuffix}'
var containerRegistryName = 'acrlegocatalog${uniqueSuffix}'
var storageAccountName = 'stlego${uniqueSuffix}'

var seedShareName = 'catalog-seed'
var imagesShareName = 'catalog-images'
var seedMountPath = '/mnt/seed'
var imagesMountPath = '/mnt/images'

// Built-in AcrPull role, so the Container App can pull with its managed identity
// instead of a registry username and password.
var acrPullRoleDefinitionId = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  '7f951dda-4ed3-4680-a7ca-43fe172d538d'
)

resource sqlServer 'Microsoft.Sql/servers@2023-08-01-preview' = {
  name: sqlServerName
  location: location
  properties: {
    administratorLogin: sqlAdministratorLogin
    administratorLoginPassword: sqlAdministratorPassword
    version: '12.0'
    minimalTlsVersion: '1.2'
    publicNetworkAccess: 'Enabled'
  }
}

resource sqlDatabase 'Microsoft.Sql/servers/databases@2023-08-01-preview' = {
  parent: sqlServer
  name: databaseName
  location: location
  sku: {
    name: 'GP_S_Gen5'
    tier: 'GeneralPurpose'
    family: 'Gen5'
    capacity: databaseMaxCapacity
  }
  properties: {
    collation: 'SQL_Latin1_General_CP1_CI_AS'
    maxSizeBytes: 34359738368
    autoPauseDelay: databaseAutoPauseDelayMinutes
    minCapacity: json(databaseMinCapacity)
    zoneRedundant: false
    readScale: 'Disabled'
    requestedBackupStorageRedundancy: 'Local'
  }
}

resource allowClientIp 'Microsoft.Sql/servers/firewallRules@2023-08-01-preview' = {
  parent: sqlServer
  name: 'AllowClientIp'
  properties: {
    startIpAddress: clientIpAddress
    endIpAddress: clientIpAddress
  }
}

// The Container App runs without VNet integration, so it has no predictable outbound IP.
// 0.0.0.0/0.0.0.0 is the special "Allow access to Azure services" rule. ch07-enterprise
// replaces this with Private Endpoints and removes public access entirely.
resource allowAzureServices 'Microsoft.Sql/servers/firewallRules@2023-08-01-preview' = {
  parent: sqlServer
  name: 'AllowAllWindowsAzureIps'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-11-01-preview' = {
  name: containerRegistryName
  location: location
  sku: {
    name: containerRegistrySku
  }
  properties: {
    adminUserEnabled: false
    publicNetworkAccess: 'Enabled'
  }
}

// ---------------------------------------------------------------------------
// Static content: the seed JSON and the product images live in Azure Files
// rather than inside the container image.
// ---------------------------------------------------------------------------

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    supportsHttpsTrafficOnly: true
  }
}

resource fileService 'Microsoft.Storage/storageAccounts/fileServices@2023-05-01' = {
  parent: storageAccount
  name: 'default'
}

resource seedShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2023-05-01' = {
  parent: fileService
  name: seedShareName
  properties: {
    shareQuota: 1
  }
}

resource imagesShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2023-05-01' = {
  parent: fileService
  name: imagesShareName
  properties: {
    shareQuota: 5
  }
}

// ---------------------------------------------------------------------------
// Identity and registry access
// ---------------------------------------------------------------------------

resource appIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'id-legocatalog-${uniqueSuffix}'
  location: location
}

resource acrPullAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: containerRegistry
  name: guid(containerRegistry.id, appIdentity.id, acrPullRoleDefinitionId)
  properties: {
    roleDefinitionId: acrPullRoleDefinitionId
    principalId: appIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

// ---------------------------------------------------------------------------
// Azure Container Apps
// ---------------------------------------------------------------------------

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: 'log-legocatalog-${uniqueSuffix}'
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

// Workload profiles environment (v2). The Consumption profile scales automatically and
// takes no minimum or maximum node count.
resource containerAppsEnvironment 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: 'cae-legocatalog-${uniqueSuffix}'
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
        customerId: logAnalytics.properties.customerId
        sharedKey: logAnalytics.listKeys().primarySharedKey
      }
    }
  }
}

resource seedStorage 'Microsoft.App/managedEnvironments/storages@2024-03-01' = {
  parent: containerAppsEnvironment
  name: seedShareName
  properties: {
    azureFile: {
      accountName: storageAccount.name
      accountKey: storageAccount.listKeys().keys[0].value
      shareName: seedShare.name
      accessMode: 'ReadOnly'
    }
  }
}

resource imagesStorage 'Microsoft.App/managedEnvironments/storages@2024-03-01' = {
  parent: containerAppsEnvironment
  name: imagesShareName
  properties: {
    azureFile: {
      accountName: storageAccount.name
      accountKey: storageAccount.listKeys().keys[0].value
      shareName: imagesShare.name
      accessMode: 'ReadOnly'
    }
  }
}

resource containerApp 'Microsoft.App/containerApps@2024-03-01' = {
  name: 'ca-legocatalog'
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${appIdentity.id}': {}
    }
  }
  properties: {
    environmentId: containerAppsEnvironment.id
    workloadProfileName: 'Consumption'
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: true
        targetPort: 8080
        transport: 'auto'
        allowInsecure: false
        traffic: [
          {
            latestRevision: true
            weight: 100
          }
        ]
      }
      registries: [
        {
          server: containerRegistry.properties.loginServer
          identity: appIdentity.id
        }
      ]
      secrets: [
        {
          name: 'catalog-database-password'
          value: sqlAdministratorPassword
        }
        {
          name: 'perftest-api-key'
          value: performanceApiKey
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'catalog'
          image: '${containerRegistry.properties.loginServer}/${containerImageName}'
          resources: {
            cpu: json('1.0')
            memory: '2Gi'
          }
          env: [
            {
              name: 'CATALOG_DATABASE_HOST'
              value: sqlServer.properties.fullyQualifiedDomainName
            }
            {
              name: 'CATALOG_DATABASE_NAME'
              value: sqlDatabase.name
            }
            {
              name: 'CATALOG_DATABASE_USERNAME'
              value: sqlAdministratorLogin
            }
            {
              name: 'CATALOG_DATABASE_PASSWORD'
              secretRef: 'catalog-database-password'
            }
            {
              name: 'CATALOG_SEED_PATH'
              value: '${seedMountPath}/catalog.json'
            }
            {
              name: 'CATALOG_IMAGES_PATH'
              value: imagesMountPath
            }
            {
              name: 'CATALOG_STARTUP_IMPORT_ENABLED'
              value: 'true'
            }
            {
              name: 'PERFTEST_API_KEY'
              secretRef: 'perftest-api-key'
            }
            {
              name: 'DEPLOYMENT_ENVIRONMENT'
              value: 'lab'
            }
            {
              name: 'OTEL_SERVICE_VERSION'
              value: serviceVersion
            }
          ]
          volumeMounts: [
            {
              volumeName: 'seed'
              mountPath: seedMountPath
            }
            {
              volumeName: 'images'
              mountPath: imagesMountPath
            }
          ]
          probes: [
            {
              type: 'Liveness'
              httpGet: {
                path: '/healthz'
                port: 8080
              }
              initialDelaySeconds: 10
              periodSeconds: 30
            }
            {
              type: 'Readiness'
              httpGet: {
                path: '/readyz'
                port: 8080
              }
              initialDelaySeconds: 5
              periodSeconds: 10
              failureThreshold: 30
            }
          ]
        }
      ]
      volumes: [
        {
          name: 'seed'
          storageType: 'AzureFile'
          storageName: seedStorage.name
        }
        {
          name: 'images'
          storageType: 'AzureFile'
          storageName: imagesStorage.name
        }
      ]
      scale: {
        minReplicas: 0
        maxReplicas: maxReplicas
        rules: [
          {
            name: 'http-scaling'
            http: {
              metadata: {
                concurrentRequests: '50'
              }
            }
          }
        ]
      }
    }
  }
  dependsOn: [
    acrPullAssignment
  ]
}

@description('Fully qualified domain name of the SQL server, for CATALOG_DATABASE_HOST.')
output sqlServerFqdn string = sqlServer.properties.fullyQualifiedDomainName
@description('Name of the SQL server resource.')
output sqlServerName string = sqlServer.name

@description('Name of the catalog database, for CATALOG_DATABASE_NAME.')
output databaseName string = sqlDatabase.name

@description('Name of the container registry, for az acr build.')
output containerRegistryName string = containerRegistry.name

@description('Login server of the container registry.')
output containerRegistryLoginServer string = containerRegistry.properties.loginServer

@description('Storage account holding the seed and image file shares.')
output storageAccountName string = storageAccount.name

@description('File share holding catalog.json.')
output seedShareName string = seedShare.name

@description('File share holding the product images.')
output imagesShareName string = imagesShare.name

@description('Public URL of the deployed application.')
output applicationUrl string = 'https://${containerApp.properties.configuration.ingress.fqdn}'
