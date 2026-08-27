targetScope = 'subscription'

/**
 * @module LLM Backend Onboarding
 * @description Deploys LLM backends, backend pools, and policy fragments to an existing APIM instance
 * 
 * This deployment enables dynamic LLM backend routing in Azure API Management (APIM), allowing:
 * - Route requests to multiple LLM providers (Azure OpenAI, AI Foundry, external providers)
 * - Load balance across multiple backends for the same model
 * - Automatic failover when backends are unavailable
 * - Flexible authentication schemes per backend
 * 
 * Usage:
 *   az deployment sub create \
 *     --location <location> \
 *     --template-file main.bicep \
 *     --parameters main.bicepparam
 */

// ============================================================================
// PARAMETERS
// ============================================================================

@description('APIM resource coordinates for the existing API Management instance')
param apim object

@description('User-assigned managed identity resource coordinates for APIM authentication')
param apimManagedIdentity object

@description('Configuration array for LLM backends')
@metadata({
  description: '''
  Each backend object should have:
  - backendId: Unique identifier (used in APIM backend resource name)
  - backendType: 'ai-foundry' | 'azure-openai' | 'aws-bedrock' | 'external'
  - endpoint: Base URL of the LLM service (e.g., https://xxx.services.ai.azure.com/models)
  - authScheme: 'managedIdentity' | 'apiKey' | 'token' (legacy, replaced by authType)
  - authType: (Optional) 'managed-identity' | 'aws-sigv4' | 'api-key-bearer' | 'api-key-header' | 'none'
  - authConfig: (Optional) { namedValueKey: 'apim-named-value-name' } — credential source for api-key auth types
  - supportedModels: Array of model objects, each with:
    - name: Model name (required)
    - sku: (Optional) SKU name for deployment, default 'Standard'
    - capacity: (Optional) Capacity/TPM quota, default 100
    - modelFormat: (Optional) Model format identifier, default 'OpenAI'
    - modelVersion: (Optional) Version of the model, default '1'
    - retirementDate: (Optional) Retirement date for the model in YYYY-MM-DD format
    - apiVersion: (Optional) API version for OpenAI-type requests, default '2024-02-15-preview'
    - timeout: (Optional) Request timeout in seconds, default 120
    - inferenceApiVersion: (Optional) API version for inference-type requests (e.g., '2024-05-01-preview')
  - priority: (Optional) 1-5, default 1 (lower = higher priority)
  - weight: (Optional) 1-1000, default 100 (higher = more traffic)
  '''
  example: [
    {
      backendId: 'ai-foundry-eastus-gpt4'
      backendType: 'ai-foundry'
      endpoint: 'https://my-foundry.services.ai.azure.com/'
      authScheme: 'managedIdentity'
      supportedModels: [
        { name: 'gpt-4o', sku: 'GlobalStandard', capacity: 100, modelFormat: 'OpenAI', modelVersion: '2024-11-20', retirementDate: '2026-09-30' }
        { name: 'gpt-4o-mini', sku: 'GlobalStandard', capacity: 100, modelFormat: 'OpenAI', modelVersion: '2024-07-18', retirementDate: '2026-09-30' }
        { name: 'Phi-4', sku: 'GlobalStandard', capacity: 1, modelFormat: 'Microsoft', modelVersion: '3', inferenceApiVersion: '2024-05-01-preview' }
      ]
      priority: 1
      weight: 100
    }
  ]
})
param llmBackendConfig array

@description('Whether to configure circuit breaker for backends (recommended for production)')
param configureCircuitBreaker bool = true

@description('AWS access key ID for Amazon Bedrock authentication (required when using aws-bedrock backends)')
@secure()
param awsAccessKey string = ''

@description('AWS secret access key for Amazon Bedrock authentication (required when using aws-bedrock backends)')
@secure()
param awsSecretKey string = ''

@description('AWS region for Amazon Bedrock (e.g., us-east-1)')
param awsRegion string = ''

@description('Model alias definitions for grouping models under a single alias name')
@metadata({
  description: '''
  Each alias object should have:
  - name: Alias name that clients use (e.g., "gpt-advanced")
  - models: Array of model names included in the alias (must exist in llmBackendConfig)
  - strategy: (Optional) "priority" (default, first available) or "weighted" (round-robin)
  - weights: (Optional) Array of weights matching models array (required when strategy is "weighted")
  '''
})
param modelAliases array = []

@description('Key Vault name for storing backend credentials (required when backends use api-key auth with Key Vault references)')
param keyVaultName string = ''

// @description('Whether to deploy the Universal LLM API (set to false if API already exists)')
// param deployUniversalLlmApi bool = true

// @description('API path for the Universal LLM API (default: llm)')
// param universalLlmApiPath string = 'llm'

// ============================================================================
// EXISTING RESOURCES
// ============================================================================

resource apimRg 'Microsoft.Resources/resourceGroups@2022-09-01' existing = {
  scope: subscription(apim.subscriptionId)
  name: apim.resourceGroupName
}

resource apimService 'Microsoft.ApiManagement/service@2024-06-01-preview' existing = {
  scope: apimRg
  name: apim.name
}

resource identityRg 'Microsoft.Resources/resourceGroups@2022-09-01' existing = {
  scope: subscription(apimManagedIdentity.subscriptionId)
  name: apimManagedIdentity.resourceGroupName
}

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  scope: identityRg
  name: apimManagedIdentity.name
}

// ============================================================================
// MODULES
// ============================================================================

/**
 * Step 1: Create LLM Backends
 * Creates individual APIM backend resources for each LLM endpoint
 */
module llmBackends 'modules/llm-backends.bicep' = {
  name: 'llm-backends-deployment-${uniqueString(deployment().name)}'
  scope: apimRg
  params: {
    apimServiceName: apim.name
    managedIdentityClientId: managedIdentity.properties.clientId
    llmBackendConfig: llmBackendConfig
    configureCircuitBreaker: configureCircuitBreaker
  }
}

/**
 * Step 2: Create Backend Pools
 * Groups backends by supported models for load balancing and failover
 */
module llmBackendPools 'modules/llm-backend-pools.bicep' = {
  name: 'llm-backend-pools-deployment-${uniqueString(deployment().name)}'
  scope: apimRg
  params: {
    apimServiceName: apim.name
    backendDetails: llmBackends.outputs.backendDetails
  }
}

/**
 * Step 3: Generate Policy Fragments
 * Creates dynamic policy fragments with backend pool configurations
 */
module llmPolicyFragments 'modules/llm-policy-fragments.bicep' = {
  name: 'llm-policy-fragments-deployment-${uniqueString(deployment().name)}'
  scope: apimRg
  params: {
    apimServiceName: apim.name
    policyFragmentConfig: llmBackendPools.outputs.policyFragmentConfig
    managedIdentityClientId: managedIdentity.properties.clientId
    llmBackendConfig: llmBackendConfig
    awsAccessKey: awsAccessKey
    awsSecretKey: awsSecretKey
    awsRegion: awsRegion
    modelAliases: modelAliases
    keyVaultName: keyVaultName
  }
}

// /**
//  * Step 4: Deploy Universal LLM API (Optional)
//  * Creates the unified API endpoint that uses the dynamic backends
//  */
// module universalLlmApi 'modules/universal-llm-api.bicep' = if (deployUniversalLlmApi) {
//   name: 'universal-llm-api-deployment-${uniqueString(deployment().name)}'
//   scope: apimRg
//   params: {
//     apimServiceName: apim.name
//     apiPath: universalLlmApiPath
//   }
// }

// ============================================================================
// OUTPUTS
// ============================================================================

@description('Name of the APIM service')
output apimServiceName string = apim.name

@description('Gateway URL for the APIM service')
output apimGatewayUrl string = apimService.properties.gatewayUrl

@description('Array of created backend IDs')
output backendIds array = llmBackends.outputs.backendIds

@description('Array of created backend pool names')
output poolNames array = llmBackendPools.outputs.poolNames

@description('Mapping of models to their backend pools')
output modelToPoolMap object = llmBackendPools.outputs.modelToPoolMap

@description('Mapping of models to direct backends (single-backend models)')
output modelToBackendMap object = llmBackendPools.outputs.modelToBackendMap

@description('All supported models across all backends')
output supportedModels array = union([], map(llmBackendConfig, config => config.supportedModels))

// @description('Universal LLM API endpoint (if deployed)')
// output universalLlmApiEndpoint string = deployUniversalLlmApi ? '${apimService.properties.gatewayUrl}/${universalLlmApiPath}' : ''

@description('Policy fragment names')
output policyFragments object = {
  setBackendPools: llmPolicyFragments.outputs.setBackendPoolsFragmentName
  setBackendAuthorization: llmPolicyFragments.outputs.setBackendAuthorizationFragmentName
  setTargetBackendPool: llmPolicyFragments.outputs.setTargetBackendPoolFragmentName
  getAvailableModels: llmPolicyFragments.outputs.getAvailableModelsFragmentName
  validateModelAccess: llmPolicyFragments.outputs.validateModelAccessFragmentName
  metadataConfig: llmPolicyFragments.outputs.metadataConfigFragmentName
  responsesIdSecurity: llmPolicyFragments.outputs.responsesIdSecurityFragmentName
  responsesIdCacheStore: llmPolicyFragments.outputs.responsesIdCacheStoreFragmentName
}
