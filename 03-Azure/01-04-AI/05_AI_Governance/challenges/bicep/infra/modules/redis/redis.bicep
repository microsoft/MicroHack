@description('Name of the Azure Managed Redis resource (Microsoft.Cache/redisEnterprise).')
param name string

@description('Location for the Redis resource')
param location string = resourceGroup().location

@description('Tags to be applied to Redis and related resources')
param tags object = {}

@description('Redis Enterprise / Azure Managed Redis SKU name. Allowed values align to Microsoft.Cache/redisEnterprise@2025-07-01.')
@allowed([
  'Enterprise_E1'
  'Enterprise_E5'
  'Enterprise_E10'
  'Enterprise_E20'
  'Enterprise_E50'
  'Enterprise_E100'
  'Enterprise_E200'
  'Enterprise_E400'
  'EnterpriseFlash_F300'
  'EnterpriseFlash_F700'
  'EnterpriseFlash_F1500'
  'Balanced_B0'
  'Balanced_B1'
  'Balanced_B3'
  'Balanced_B5'
  'Balanced_B10'
  'Balanced_B20'
  'Balanced_B50'
  'Balanced_B100'
  'Balanced_B150'
  'Balanced_B250'
  'Balanced_B350'
  'Balanced_B500'
  'Balanced_B700'
  'Balanced_B1000'
  'MemoryOptimized_M10'
  'MemoryOptimized_M20'
  'MemoryOptimized_M50'
  'MemoryOptimized_M100'
  'MemoryOptimized_M150'
  'MemoryOptimized_M250'
  'MemoryOptimized_M350'
  'MemoryOptimized_M500'
  'MemoryOptimized_M700'
  'MemoryOptimized_M1000'
  'MemoryOptimized_M1500'
  'MemoryOptimized_M2000'
  'ComputeOptimized_X3'
  'ComputeOptimized_X5'
  'ComputeOptimized_X10'
  'ComputeOptimized_X20'
  'ComputeOptimized_X50'
  'ComputeOptimized_X100'
  'ComputeOptimized_X150'
  'ComputeOptimized_X250'
  'ComputeOptimized_X350'
  'ComputeOptimized_X500'
  'ComputeOptimized_X700'
  'FlashOptimized_A250'
  'FlashOptimized_A500'
  'FlashOptimized_A700'
  'FlashOptimized_A1000'
  'FlashOptimized_A1500'
  'FlashOptimized_A2000'
  'FlashOptimized_A4500'
])
param skuName string = 'Balanced_B10'

@description('Redis Enterprise cluster capacity. Only used for Enterprise_* and EnterpriseFlash_* SKUs. Valid values are (2, 4, 6, ...) for Enterprise SKUs and (3, 9, 15, ...) for EnterpriseFlash SKUs.')
param skuCapacity int = 2

@description('Whether public endpoint access is allowed for this Redis. If Disabled, private endpoints are the exclusive access method.')
@allowed(['Enabled', 'Disabled'])
param publicNetworkAccess string = 'Disabled'

@description('Minimum TLS version for Redis connections')
param minimumTlsVersion string = '1.2'

@description('Whether to create a private endpoint for Redis')
param usePrivateEndpoint bool = true

// Networking parameters
@description('Name of the Virtual Network')
param vNetName string

@description('Name of the private endpoint subnet')
param privateEndpointSubnetName string

@description('Resource group containing the Virtual Network')
param vNetRG string

@description('Name of the Redis private endpoint')
param redisPrivateEndpointName string

@description('DNS zone name for Redis private endpoint')
param redisDnsZoneName string = 'privatelink.redis.azure.net'

// DNS Zone parameters (legacy approach - used when dnsZoneResourceId is not provided)
@description('Resource group containing the DNS zones')
param dnsZoneRG string = ''

@description('Subscription ID containing the DNS zones')
param dnsSubscriptionId string = ''

@description('Direct DNS zone resource ID for Redis (preferred over dnsZoneRG/dnsSubscriptionId)')
param dnsZoneResourceId string = ''

// Existing VNet and subnet for private endpoint
resource vnet 'Microsoft.Network/virtualNetworks@2022-01-01' existing = {
  name: vNetName
  scope: resourceGroup(vNetRG)
}

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2022-01-01' existing = {
  name: privateEndpointSubnetName
  parent: vnet
}

var usesSkuCapacity = startsWith(skuName, 'Enterprise_') || startsWith(skuName, 'EnterpriseFlash_')
var redisSku = usesSkuCapacity ? {
  name: skuName
  capacity: skuCapacity
} : {
  name: skuName
}

resource redis 'Microsoft.Cache/redisEnterprise@2025-07-01' = {
  name: name
  location: location
  tags: union(tags, { 'azd-service-name': name })
  sku: redisSku
  properties: {
    minimumTlsVersion: minimumTlsVersion
    publicNetworkAccess: publicNetworkAccess
  }
}

resource redisDb 'Microsoft.Cache/redisEnterprise/databases@2025-07-01' = {
  name: 'default'
  parent: redis
  properties: {
    accessKeysAuthentication: 'Enabled'
    evictionPolicy: 'NoEviction'
    clusteringPolicy: 'EnterpriseCluster'
    clientProtocol: 'Encrypted'
    modules: [
      {name: 'RediSearch' }
    ]
    // Per Azure Managed Redis Private Link guidance, clients connect on port 10000.
    port: 10000
  }
}

module privateEndpoint '../networking/private-endpoint.bicep' = if (usePrivateEndpoint) {
  name: '${name}-pe'
  params: {
    groupIds: [
      'redisEnterprise'
    ]
    dnsZoneName: redisDnsZoneName
    name: redisPrivateEndpointName
    privateLinkServiceId: redis.id
    location: location
    dnsZoneRG: dnsZoneRG
    privateEndpointSubnetId: subnet.id
    dnsSubId: dnsSubscriptionId
    dnsZoneResourceId: dnsZoneResourceId
    tags: tags
  }
  dependsOn: [
    redisDb
  ]
}

var redisHostName = redis.properties.hostName
var redisPort = redisDb.properties.port
var redisPrimaryKey = redisDb.listKeys().primaryKey

@secure()
output redisCacheConnectionString string = '${redisHostName}:${redisPort},password=${redisPrimaryKey},ssl=true'

output redisResourceId string = redis.id
output hostName string = redisHostName
output port int = redisPort
