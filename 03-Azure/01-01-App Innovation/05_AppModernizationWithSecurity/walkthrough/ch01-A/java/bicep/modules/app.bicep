param location string
param appName string
param environmentId string
param identityId string
param registryLoginServer string
param containerImageName string
param databaseHost string
param databaseName string
param databaseUsername string
@secure()
param databasePassword string
@secure()
param performanceApiKey string
param serviceVersion string
param seedStorageName string
param imagesStorageName string

resource app 'Microsoft.App/containerApps@2024-03-01' = {
  name: appName
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${identityId}': {}
    }
  }
  properties: {
    environmentId: environmentId
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
          server: registryLoginServer
          identity: identityId
        }
      ]
      secrets: [
        {
          name: 'catalog-database-password'
          value: databasePassword
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
          image: '${registryLoginServer}/${containerImageName}'
          resources: {
            cpu: 1
            memory: '2Gi'
          }
          env: [
            {
              name: 'CATALOG_DATABASE_HOST'
              value: databaseHost
            }
            {
              name: 'CATALOG_DATABASE_NAME'
              value: databaseName
            }
            {
              name: 'CATALOG_DATABASE_USERNAME'
              value: databaseUsername
            }
            {
              name: 'CATALOG_DATABASE_PASSWORD'
              secretRef: 'catalog-database-password'
            }
            {
              name: 'CATALOG_DATABASE_SSL_MODE'
              value: 'require'
            }
            {
              name: 'CATALOG_STARTUP_IMPORT_ENABLED'
              value: 'true'
            }
            {
              name: 'CATALOG_SEED_PATH'
              value: '/mnt/seed/catalog.json'
            }
            {
              name: 'CATALOG_IMAGES_PATH'
              value: '/mnt/images'
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
            {
              name: 'OTEL_SDK_DISABLED'
              value: 'true'
            }
            {
              name: 'OTEL_EXPORTER_OTLP_ENDPOINT'
              value: 'http://localhost:4317'
            }
          ]
          volumeMounts: [
            {
              volumeName: 'seed'
              mountPath: '/mnt/seed'
            }
            {
              volumeName: 'images'
              mountPath: '/mnt/images'
            }
          ]
          probes: [
            {
              type: 'Startup'
              httpGet: {
                path: '/healthz'
                port: 8080
              }
              periodSeconds: 5
              failureThreshold: 60
              timeoutSeconds: 3
            }
            {
              type: 'Liveness'
              httpGet: {
                path: '/healthz'
                port: 8080
              }
              periodSeconds: 30
              timeoutSeconds: 3
            }
            {
              type: 'Readiness'
              httpGet: {
                path: '/readyz'
                port: 8080
              }
              periodSeconds: 10
              timeoutSeconds: 6
              failureThreshold: 30
            }
          ]
        }
      ]
      volumes: [
        {
          name: 'seed'
          storageType: 'AzureFile'
          storageName: seedStorageName
        }
        {
          name: 'images'
          storageType: 'AzureFile'
          storageName: imagesStorageName
        }
      ]
      scale: {
        minReplicas: 0
        maxReplicas: 3
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
}

output applicationUrl string = 'https://${app.properties.configuration.ingress.fqdn}'
