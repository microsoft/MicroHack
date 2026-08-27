/**
 * @module llm-policy-fragments
 * @description Generates APIM policy fragments with backend pool configurations
 * 
 * This module creates policy fragments that contain the dynamically generated
 * backend pool configurations based on the LLM backend setup. These fragments
 * are used by the Universal LLM API policy to route requests appropriately.
 */

// ------------------
//    PARAMETERS
// ------------------

@description('Name of the API Management service')
param apimServiceName string

@description('Policy fragment configuration from backend pools module')
param policyFragmentConfig object

@description('User-assigned managed identity client ID for authentication')
param managedIdentityClientId string

@description('LLM backend configuration with model metadata for available models response')
param llmBackendConfig array = []

// ------------------
//    VARIABLES
// ------------------

/**
 * Generate the backend pools array for the set-backend-pools fragment
 * This creates the C# code that will be injected into the policy fragment
 */
var allPools = union(policyFragmentConfig.backendPools, policyFragmentConfig.directBackends)

// Generate C# code for each backend pool with unique variable names using index
var backendPoolsArray = [for (pool, index) in allPools: replace(replace(replace(replace('''
// Pool: POOLNAME (Type: POOLTYPE)
var pool_INDEX = new JObject()
{
    { "poolName", "POOLNAME" },
    { "poolType", "POOLTYPE" },
    { "supportedModels", new JArray(MODELS) }
};
backendPools.Add(pool_INDEX);
''', 'POOLNAME', pool.poolName), 'POOLTYPE', pool.poolType), 'INDEX', string(index)), 'MODELS', join(map(pool.supportedModels, (model) => '"${model}"'), ', '))]

var backendPoolsCode = join(backendPoolsArray, '\n')

// Generate model deployments code using reduce to flatten models from all backends
// Each backend generates code for all its supported models (now with per-model metadata)
// supportedModels is now an array of objects: { name, sku?, capacity?, modelFormat?, modelVersion?, retirementDate? }
var modelDeploymentsCodeResult = reduce(llmBackendConfig, { code: '', index: 0 }, (acc, config) => 
  reduce(config.supportedModels, acc, (modelAcc, model) => {
    code: '${modelAcc.code}\n// Model: ${model.name} from backend: ${config.backendId}\nvar deployment_${modelAcc.index} = new JObject()\n{\n    { "id", "${config.backendId}" },\n    { "type", "${config.backendType}" },\n    { "name", "${model.name}" },\n    { "sku", new JObject() { { "name", "${model.?sku ?? 'Standard'}" }, { "capacity", ${model.?capacity ?? 100} } } },\n    { "properties", new JObject() {\n        { "model", new JObject() { { "format", "${model.?modelFormat ?? 'OpenAI'}" }, { "name", "${model.name}" }, { "version", "${model.?modelVersion ?? '1'}" } } },\n        { "capabilities", new JObject() { { "chatCompletion", "true" } } },\n        { "provisioningState", "Succeeded" }${!empty(model.?retirementDate) ? ',\n        { "retirementDate", "${model.retirementDate}" }' : ''}\n    }}\n};\nmodelDeployments.Add(deployment_${modelAcc.index});'
    index: modelAcc.index + 1
  })
)

var modelDeploymentsCode = modelDeploymentsCodeResult.code

/**
 * Complete policy fragment XML with backend pools configuration
 */
var setBackendPoolsFragmentXml = loadTextContent('./policies/frag-set-backend-pools.xml')

var updatedSetBackendPoolsFragmentXml = replace(setBackendPoolsFragmentXml, '//{backendPoolsCode}', backendPoolsCode)

/**
 * Generate metadata-config fragment for the Unified AI API
 * Maps each model to its backend pool/direct backend + apiVersion + timeout
 */

// Build model-to-pool/backend mapping: for each model, find which pool or direct backend serves it
// Uses the same allPools array that the backend-pools fragment uses
var metadataModelsResult = reduce(llmBackendConfig, { code: '', seenModels: [] }, (acc, config) =>
  reduce(config.supportedModels, acc, (modelAcc, model) => {
    // Find the pool/backend name for this model from allPools
    code: contains(modelAcc.seenModels, model.name) ? modelAcc.code : '${modelAcc.code}${length(modelAcc.seenModels) > 0 ? ',\n' : ''}\t\t\t\'${model.name}\': {\n\t\t\t\t\'backend\': \'${reduce(allPools, '', (poolAcc, pool) => contains(pool.supportedModels, model.name) ? pool.poolName : poolAcc)}\',\n\t\t\t\t\'apiVersion\': \'${model.?apiVersion ?? '2024-02-15-preview'}\',\n\t\t\t\t\'timeout\': ${model.?timeout ?? 120}${!empty(model.?inferenceApiVersion) ? ',\n\t\t\t\t\'inferenceApiVersion\': \'${model.inferenceApiVersion}\'' : ''}\n\t\t\t}'
    seenModels: contains(modelAcc.seenModels, model.name) ? modelAcc.seenModels : union(modelAcc.seenModels, [model.name])
  })
)

var metadataModelsCode = metadataModelsResult.code

var metadataConfigFragmentXml = loadTextContent('./policies/frag-metadata-config.xml')
var updatedMetadataConfigFragmentXml = replace(metadataConfigFragmentXml, '//{modelsConfigCode}', metadataModelsCode)

/**
 * Enhanced authorization fragment that supports multiple backend types
 */
var setBackendAuthorizationFragmentXml = loadTextContent('./policies/frag-set-backend-authorization.xml')

/**
 * Get available models fragment template
 */
var getAvailableModelsFragmentTemplate = loadTextContent('./policies/frag-get-available-models.xml')

// Inject generated model deployments code into available models template
var updatedGetAvailableModelsFragmentXml = replace(getAvailableModelsFragmentTemplate, '//{modelDeploymentsCode}', modelDeploymentsCode)

// ------------------
//    RESOURCES
// ------------------

resource apimService 'Microsoft.ApiManagement/service@2024-06-01-preview' existing = {
  name: apimServiceName
}

// Named values for AWS Bedrock authentication
// Always created with safe defaults so the policy fragment compiles even when no aws-bedrock backends are configured.
resource awsAccessKeyNamedValue 'Microsoft.ApiManagement/service/namedValues@2024-06-01-preview' = {
  name: 'aws-access-key'
  parent: apimService
  properties: {
    displayName: 'aws-access-key'
    value: 'NOT_CONFIGURED'
    secret: true
  }
}

resource awsSecretKeyNamedValue 'Microsoft.ApiManagement/service/namedValues@2024-06-01-preview' = {
  name: 'aws-secret-key'
  parent: apimService
  properties: {
    displayName: 'aws-secret-key'
    value: 'NOT_CONFIGURED'
    secret: true
  }
}

resource awsRegionNamedValue 'Microsoft.ApiManagement/service/namedValues@2024-06-01-preview' = {
  name: 'aws-region'
  parent: apimService
  properties: {
    displayName: 'aws-region'
    value: 'NOT_CONFIGURED'
    secret: false
  }
}

/**
 * Policy Fragment: Set Backend Pools
 * Contains the dynamically generated backend pool configurations
 */
resource setBackendPoolsFragment 'Microsoft.ApiManagement/service/policyFragments@2024-06-01-preview' = {
  name: 'set-backend-pools'
  parent: apimService
  properties: {
    description: 'Dynamically generated backend pool configurations for LLM routing'
    format: 'rawxml'
    value: updatedSetBackendPoolsFragmentXml
  }
}

/**
 * Policy Fragment: Set Backend Authorization
 * Handles authentication for different backend types (Azure OpenAI, AI Foundry, External)
 */
resource setBackendAuthorizationFragment 'Microsoft.ApiManagement/service/policyFragments@2024-06-01-preview' = {
  name: 'set-backend-authorization'
  parent: apimService
  dependsOn: [
    awsAccessKeyNamedValue
    awsSecretKeyNamedValue
    awsRegionNamedValue
  ]
  properties: {
    description: 'Authentication and routing configuration for different LLM backend types'
    format: 'rawxml'
    value: setBackendAuthorizationFragmentXml
  }
}

/**
 * Policy Fragment: Set Target Backend Pool
 * Determines which backend pool to route requests to based on model and permissions
 */
resource setTargetBackendPoolPolicyFragment 'Microsoft.ApiManagement/service/policyFragments@2024-06-01-preview' = {
  parent: apimService
  name: 'set-target-backend-pool'
  properties: {
    description: 'Determines the target backend pool for LLM requests'
    value: loadTextContent('./policies/frag-set-target-backend-pool.xml')
    format: 'rawxml'
  }
}

resource setLLMUsagePolicyFragment 'Microsoft.ApiManagement/service/policyFragments@2024-06-01-preview' = {
  parent: apimService
  name: 'set-llm-usage'
  properties: {
    description: 'Collects usage metrics for LLM requests'
    value: loadTextContent('./policies/frag-set-llm-usage.xml')
    format: 'rawxml'
  }
}

/**
 * Policy Fragment: Set LLM Requested Model
 * Extracts the requested model from either Azure OpenAI endpoint or inference endpoint
 */
resource setLLMRequestedModelPolicyFragment 'Microsoft.ApiManagement/service/policyFragments@2024-06-01-preview' = {
  parent: apimService
  name: 'set-llm-requested-model'
  properties: {
    description: 'Extracts the requested model from deployment-id (Azure OpenAI) or request body (Inference)'
    value: loadTextContent('./policies/frag-set-llm-requested-model.xml')
    format: 'rawxml'
  }
}

/**
 * Policy Fragment: Get Available Models
 * Returns a JSON response listing all available model deployments with their capabilities
 */
resource getAvailableModelsFragment 'Microsoft.ApiManagement/service/policyFragments@2024-06-01-preview' = {
  parent: apimService
  name: 'get-available-models'
  properties: {
    description: 'Returns a JSON response listing all available model deployments with their capabilities'
    value: updatedGetAvailableModelsFragmentXml
    format: 'rawxml'
  }
}

/**
 * Policy Fragment: Validate Model Access
 * Restricts access to specific models based on the allowedModels variable
 */
resource validateModelAccessFragment 'Microsoft.ApiManagement/service/policyFragments@2024-06-01-preview' = {
  parent: apimService
  name: 'validate-model-access'
  properties: {
    description: 'Validates that the requested model is in the allowed models list for the product'
    value: loadTextContent('./policies/frag-validate-model-access.xml')
    format: 'rawxml'
  }
}

/**
 * Policy Fragment: Responses API ID Security (inbound)
 * Enforces per-subscription ownership of OpenAI Responses API response_id values
 * and hydrates routing for GET/DELETE operations on /responses/{id}.
 */
resource responsesIdSecurityFragment 'Microsoft.ApiManagement/service/policyFragments@2024-06-01-preview' = {
  parent: apimService
  name: 'responses-id-security'
  properties: {
    description: 'Inbound: validates response_id ownership and hydrates routing for /responses operations'
    value: loadTextContent('./policies/frag-responses-id-security.xml')
    format: 'rawxml'
  }
}

/**
 * Policy Fragment: Responses API ID Cache Store (outbound)
 * Records response_id → "<subscriptionId>|<requestedModel>|<userId>" in APIM cache
 * after a successful POST /responses, enabling subsequent ownership checks.
 */
resource responsesIdCacheStoreFragment 'Microsoft.ApiManagement/service/policyFragments@2024-06-01-preview' = {
  parent: apimService
  name: 'responses-id-cache-store'
  properties: {
    description: 'Outbound: caches response_id ownership for newly created Responses API objects'
    value: loadTextContent('./policies/frag-responses-id-cache-store.xml')
    format: 'rawxml'
  }
}

/**
 * Policy Fragment: Metadata Configuration
 * Provides centralized configuration for the Unified AI API with dynamically generated model mappings
 */
resource metadataConfigFragment 'Microsoft.ApiManagement/service/policyFragments@2024-06-01-preview' = {
  parent: apimService
  name: 'metadata-config'
  properties: {
    description: 'Dynamically generated metadata configuration for Unified AI API routing'
    value: updatedMetadataConfigFragmentXml
    format: 'rawxml'
  }
}

// ------------------
//    OUTPUTS
// ------------------

@description('Name of the set-backend-pools fragment')
output setBackendPoolsFragmentName string = setBackendPoolsFragment.name

@description('Name of the set-backend-authorization fragment')
output setBackendAuthorizationFragmentName string = setBackendAuthorizationFragment.name

@description('Name of the set-target-backend-pool fragment')
output setTargetBackendPoolFragmentName string = setTargetBackendPoolPolicyFragment.name

@description('Name of the get-available-models fragment')
output getAvailableModelsFragmentName string = getAvailableModelsFragment.name

@description('Name of the validate-model-access fragment')
output validateModelAccessFragmentName string = validateModelAccessFragment.name

@description('Name of the metadata-config fragment')
output metadataConfigFragmentName string = metadataConfigFragment.name

@description('Name of the responses-id-security fragment')
output responsesIdSecurityFragmentName string = responsesIdSecurityFragment.name

@description('Name of the responses-id-cache-store fragment')
output responsesIdCacheStoreFragmentName string = responsesIdCacheStoreFragment.name

@description('Generated backend pools configuration code')
output backendPoolsCode string = backendPoolsCode
