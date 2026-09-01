@description('Radius-provided recipe context.')
param context object

@description('PostgreSQL database name.')
param database string = 'trading'

@description('PostgreSQL administrator username.')
param user string = 'tradeadmin'

@secure()
@description('PostgreSQL administrator password.')
#disable-next-line secure-parameter-default
param password string = '${uniqueString(context.resource.id)}Aa1!'

@description('Comma-separated static public egress IP addresses used by AKS.')
@minLength(7)
param aksEgressIps string

@description('Azure region for PostgreSQL resources.')
param location string = resourceGroup().location

@description('PostgreSQL client image tag used only by the schema initializer.')
param clientTag string = '16-alpine'

var sizeKey = context.resource.properties.?size ?? 'S'
var skuBySize = {
  S: {
    name: 'Standard_B1ms'
    tier: 'Burstable'
  }
  M: {
    name: 'Standard_B2s'
    tier: 'Burstable'
  }
  L: {
    name: 'Standard_D2s_v3'
    tier: 'GeneralPurpose'
  }
}
var serverName = 'pg-${uniqueString(context.resource.id)}'
var egressIps = map(filter(split(aksEgressIps, ','), ip => !empty(trim(ip))), ip => trim(ip))
var schemaSql = loadTextContent('trading-schema.sql')
var schemaRevision = take(uniqueString(schemaSql), 8)
var initializerName = 'postgres-${uniqueString(context.resource.id)}-schema-${schemaRevision}'
// app.bicep binds this Secret by name, so the name must stay stable and predictable. Deriving
// it from the schema revision or the resource ID hash would change it whenever the schema
// changes and make it impossible to reference from the application template.
var credentialsName = '${context.resource.name}-credentials'
var port = 5432

// The `result` output must be evaluated without any runtime reference() call.
// The Radius deployment engine resolves `references(<collection>, 'full')` to the
// template's resource metadata, which exposes `resourceId` rather than `id`, so a
// `map(aksFirewallRules, rule => rule.id)` throws while the outputs are evaluated.
// That failure is logged only as a warning: the deployment still reports success but
// returns no outputs at all, so Radius silently records none of the recipe values.
// Building the IDs and Kubernetes names from compile-time values keeps the output
// evaluable. See resources/validate-postgres-recipes.sh for the regression guard.
var firewallRuleIds = [
  for (egressIp, index) in egressIps: resourceId(
    'Microsoft.DBforPostgreSQL/flexibleServers/firewallRules',
    serverName,
    'aks-egress-${index + 1}'
  )
]

extension kubernetes with {
  kubeConfig: ''
  namespace: context.runtime.kubernetes.namespace
} as k8s

resource server 'Microsoft.DBforPostgreSQL/flexibleServers@2024-08-01' = {
  name: serverName
  location: location
  sku: {
    name: skuBySize[sizeKey].name
    tier: skuBySize[sizeKey].tier
  }
  properties: {
    administratorLogin: user
    administratorLoginPassword: password
    version: '16'
    storage: {
      storageSizeGB: 32
    }
    backup: {
      backupRetentionDays: 7
      geoRedundantBackup: 'Disabled'
    }
    highAvailability: {
      mode: 'Disabled'
    }
    network: {
      publicNetworkAccess: 'Enabled'
    }
    createMode: 'Default'
  }
  // Azure rejects tag names containing '/', so Radius metadata uses a hyphen on Azure
  // resources. The Kubernetes resources below keep the 'radapp.io/...' label form,
  // which is a valid Kubernetes label key.
  tags: {
    'radapp.io-environment': context.environment.id
    'radapp.io-resource': context.resource.id
    'radapp.io-application': context.application == null ? '' : context.application.name
  }
}

resource databaseResource 'Microsoft.DBforPostgreSQL/flexibleServers/databases@2024-08-01' = {
  parent: server
  name: database
  properties: {
    charset: 'UTF8'
    collation: 'en_US.utf8'
  }
}

// PostgreSQL Flexible Server serializes control-plane operations per server. Bicep infers
// dependencies only from `parent:`, so without the explicit chain below ARM fans every child
// out in parallel and the losers fail with ServerIsBusy. Each child therefore waits on the
// previous one. This also makes the schema initializer transitively wait for the database.
resource requireSecureTransport 'Microsoft.DBforPostgreSQL/flexibleServers/configurations@2024-08-01' = {
  parent: server
  name: 'require_secure_transport'
  properties: {
    value: 'on'
    source: 'user-override'
  }
  dependsOn: [
    databaseResource
  ]
}

resource minimumTlsVersion 'Microsoft.DBforPostgreSQL/flexibleServers/configurations@2024-08-01' = {
  parent: server
  name: 'ssl_min_protocol_version'
  properties: {
    value: 'TLSv1.2'
    source: 'user-override'
  }
  dependsOn: [
    requireSecureTransport
  ]
}

@batchSize(1)
resource aksFirewallRules 'Microsoft.DBforPostgreSQL/flexibleServers/firewallRules@2024-08-01' = [
  for (egressIp, index) in egressIps: {
    parent: server
    name: 'aks-egress-${index + 1}'
    properties: {
      startIpAddress: egressIp
      endIpAddress: egressIp
    }
    dependsOn: [
      minimumTlsVersion
    ]
  }
]

resource credentials 'core/Secret@v1' = {
  metadata: {
    name: credentialsName
    labels: {
      resource: context.resource.name
      'radapp.io/application': context.application == null ? '' : context.application.name
    }
  }
  stringData: {
    password: password
  }
  type: 'Opaque'
}

resource initSql 'core/ConfigMap@v1' = {
  metadata: {
    name: initializerName
    labels: {
      resource: context.resource.name
      'radapp.io/application': context.application == null ? '' : context.application.name
    }
  }
  data: {
    'init.sql': schemaSql
  }
}

resource schemaInitializer 'batch/Job@v1' = {
  metadata: {
    name: initializerName
    labels: {
      app: 'postgres-schema-initializer'
      resource: context.resource.name
      'radapp.io/application': context.application == null ? '' : context.application.name
    }
  }
  spec: {
    backoffLimit: 6
    activeDeadlineSeconds: 900
    template: {
      metadata: {
        labels: {
          app: 'postgres-schema-initializer'
          resource: context.resource.name
        }
      }
      spec: {
        restartPolicy: 'Never'
        containers: [
          {
            name: 'schema-initializer'
            image: 'postgres:${clientTag}'
            command: [
              'sh'
              '-ceu'
              '''
for attempt in $(seq 1 60); do
  if psql --set=ON_ERROR_STOP=1 --file=/schema/init.sql; then
    exit 0
  fi
  echo "Azure PostgreSQL is not ready for TLS schema initialization (attempt ${attempt}/60)." >&2
  sleep 5
done
exit 1
'''
            ]
            env: [
              {
                name: 'PGHOST'
                value: server.properties.fullyQualifiedDomainName
              }
              {
                name: 'PGPORT'
                value: string(port)
              }
              {
                name: 'PGDATABASE'
                value: databaseResource.name
              }
              {
                name: 'PGUSER'
                value: user
              }
              {
                name: 'PGSSLMODE'
                value: 'require'
              }
              {
                name: 'PGPASSWORD'
                valueFrom: {
                  secretKeyRef: {
                    name: credentials.metadata.name
                    key: 'password'
                  }
                }
              }
            ]
            volumeMounts: [
              {
                name: 'schema'
                mountPath: '/schema'
                readOnly: true
              }
            ]
          }
        ]
        volumes: [
          {
            name: 'schema'
            configMap: {
              name: initSql.metadata.name
            }
          }
        ]
      }
    }
  }
  dependsOn: [
    aksFirewallRules
    requireSecureTransport
    minimumTlsVersion
  ]
}

output result object = {
  resources: concat([
    server.id
    databaseResource.id
    requireSecureTransport.id
    minimumTlsVersion.id
    '/planes/kubernetes/local/namespaces/${context.runtime.kubernetes.namespace}/providers/core/Secret/${credentialsName}'
    '/planes/kubernetes/local/namespaces/${context.runtime.kubernetes.namespace}/providers/core/ConfigMap/${initializerName}'
    '/planes/kubernetes/local/namespaces/${context.runtime.kubernetes.namespace}/providers/batch/Job/${initializerName}'
  ], firewallRuleIds)
  values: {
    host: server.properties.fullyQualifiedDomainName
    port: port
    database: databaseResource.name
    username: user
    // The password is deliberately not returned as a recipe value. Radius treats `secrets` as a
    // framework-owned property (pkg/resourceutil.BasicProperties), so a `secrets` map nested in
    // `values` is dropped by the recipe-output copier, and a top-level `secrets` object is instead
    // materialized into a managed Radius.Security/secrets resource that is surfaced only through a
    // reserved `secrets.name` reference this resource type does not declare. Either way
    // `properties.secrets.password` never resolves. Consumers bind the Kubernetes Secret above by
    // name. See resources/validate-postgres-recipes.sh for the regression guard.
  }
}
