@description('Injected by Radius. Contains resource identity, environment scope, and developer input properties.')
param context object

@description('Database name. Defaults to the Radius resource name.')
param databaseName string = context.resource.name

var skuMap = {
  S: { name: 'GP_Gen5', capacity: 2 }
  M: { name: 'GP_Gen5', capacity: 4 }
  L: { name: 'GP_Gen5', capacity: 8 }
}
var sizeKey = context.resource.properties.?size ?? 'S'
var sku = skuMap[sizeKey]
var seed = uniqueString(context.resource.id)
var serverName = 'sql-${take(seed, 10)}'
var adminPassword = '${uniqueString(context.resource.id)}Aa1!'

module sqlServer 'br/public:avm/res/sql/server:0.12.0' = {
  name: 'sql-server-${seed}'
  params: {
    name: serverName
    location: resourceGroup().location
    administratorLogin: 'sqladmin'
    administratorLoginPassword: adminPassword
    databases: [
      {
        name: databaseName
        sku: {
          name: '${sku.name}_${sku.capacity}'
        }
      }
    ]
    // Azure rejects tag names containing '/', so Radius metadata uses a hyphen.
    tags: {
      'radapp.io-environment': context.environment.id
      'radapp.io-resource': context.resource.id
      'radapp.io-application': context.application == null ? '' : context.application.name
    }
  }
}

output result object = {
  resources: [
    sqlServer.outputs.resourceId
  ]
  values: {
    host: sqlServer.outputs.fullyQualifiedDomainName
    port: 1433
    database: databaseName
    username: 'sqladmin'
  }
  secrets: {
    password: adminPassword
  }
}
