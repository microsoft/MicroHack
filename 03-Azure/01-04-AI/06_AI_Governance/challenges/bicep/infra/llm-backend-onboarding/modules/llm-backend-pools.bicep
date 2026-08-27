/**
 * @module llm-backend-pools
 * @description Creates APIM backend pools that group backends by supported models
 * 
 * This module analyzes the LLM backend configuration and creates backend pools.
 * Each pool groups backends that support the same model, enabling:
 * - Load balancing across multiple backends for the same model
 * - Automatic failover if one backend becomes unavailable
 * - Priority-based and weighted routing strategies
 */

// ------------------
//    PARAMETERS
// ------------------

@description('Name of the API Management service')
param apimServiceName string

@description('Array of backend details from llm-backends module output')
param backendDetails array

// ------------------
//    VARIABLES
// ------------------

// Extract model names from supportedModels objects for each backend
// supportedModels can be either array of strings (legacy) or array of objects with 'name' property (new)
var normalizedBackendDetails = [for backend in backendDetails: {
  backendId: backend.backendId
  backendType: backend.backendType
  authType: backend.?authType ?? ''
  authConfigNamedValue: backend.?authConfigNamedValue ?? ''
  resourceId: backend.resourceId
  priority: backend.priority
  weight: backend.weight
  // Extract model names - handle both string arrays and object arrays
  modelNames: map(backend.supportedModels, m => m.name)
}]

// Group backends by supported models to create backend pools
var modelToBackendsMap = reduce(normalizedBackendDetails, {}, (acc, backend) => union(acc, reduce(backend.modelNames, {}, (modelAcc, model) => union(modelAcc, {
  '${model}': union(
    contains(acc, model) ? acc[model] : [],
    [{
        backendId: backend.backendId
        backendType: backend.backendType
        authType: backend.authType
        authConfigNamedValue: backend.authConfigNamedValue
        resourceId: backend.resourceId
        priority: backend.priority
        weight: backend.weight
      }]
  )
}))))

// Create pool configurations only for models supported by multiple backends
// Note: Pool names must only contain letters, numbers, and hyphens (dots are stripped from model names)
var poolConfigs = map(
  filter(items(modelToBackendsMap), (item) => length(item.value) > 1),
  (item) => {
    modelName: item.key
    poolName: '${replace(item.key, '.', '')}-backend-pool'
    backends: item.value
  }
)

// ------------------
//    RESOURCES
// ------------------

resource apimService 'Microsoft.ApiManagement/service@2024-06-01-preview' existing = {
  name: apimServiceName
  // Note: We don't use this directly as pools are created as children of the service
}

// Create backend pools for models with multiple backend options
resource backendPools 'Microsoft.ApiManagement/service/backends@2024-06-01-preview' = [for config in poolConfigs: {
  name: config.poolName
  parent: apimService
  properties: {
    description: 'Backend pool for model: ${config.modelName}'
    type: 'Pool'
    #disable-next-line BCP035
    pool: {
      services: [for backend in config.backends: {
        id: '/backends/${backend.backendId}'
        priority: backend.priority
        weight: backend.weight
      }]
    }
  }
}]

// ------------------
//    OUTPUTS
// ------------------

@description('Array of created backend pool names')
output poolNames array = [for (config, i) in poolConfigs: backendPools[i].name]

@description('Mapping of models to their backend pool names')
output modelToPoolMap object = reduce(poolConfigs, {}, (acc, config) => union(acc, {
  '${config.modelName}': config.poolName
}))

@description('Mapping of models to backend IDs (for models with single backend)')
output modelToBackendMap object = reduce(
  filter(items(modelToBackendsMap), (item) => length(item.value) == 1),
  {},
  (acc, item) => union(acc, {
    '${item.key}': item.value[0].backendId
  })
)

@description('Complete pool configurations including backend details')
output poolDetails array = [for (config, i) in poolConfigs: {
  modelName: config.modelName
  poolName: config.poolName
  poolType: 'pool'
  backends: config.backends
}]

@description('Configuration for policy fragment generation')
output policyFragmentConfig object = {
  backendPools: map(poolConfigs, config => {
    poolName: config.poolName
    poolType: length(config.backends) > 0 ? config.backends[0].backendType : 'mixed'
    authType: length(config.backends) > 0 ? config.backends[0].authType : ''
    authConfigNamedValue: length(config.backends) > 0 ? config.backends[0].authConfigNamedValue : ''
    supportedModels: [config.modelName]
  })
  directBackends: map(
    filter(items(modelToBackendsMap), (item) => length(item.value) == 1),
    (item) => {
      poolName: item.value[0].backendId
      poolType: item.value[0].backendType
      authType: item.value[0].authType
      authConfigNamedValue: item.value[0].authConfigNamedValue
      supportedModels: [item.key]
    }
  )
}
