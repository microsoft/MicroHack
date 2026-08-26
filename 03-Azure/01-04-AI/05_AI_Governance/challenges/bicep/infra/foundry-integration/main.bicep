/*
===========================================
Azure AI Foundry - APIM Connection Integration
===========================================

This Bicep template creates an APIM connection in an existing Azure AI Foundry project.
It enables Foundry agents to access AI models through your Azure API Management gateway.

SUPPORTED SCENARIOS:
1. Basic APIM connection with APIM defaults (dynamic discovery using /deployments endpoints)
2. APIM with Static Model List (predefined models, no dynamic discovery needed)
3. APIM with Custom Dynamic Discovery endpoints
4. APIM with Custom Headers for policy routing
5. APIM with Custom Authentication configuration

DEPLOYMENT:
Make sure you are logged into the subscription where the AI Foundry resource exists.
  az account set --subscription <foundry-subscription-id>
  az deployment group create \
    --resource-group <foundry-resource-group> \
    --template-file main.bicep \
    --parameters main.bicepparam

REFERENCES:
- https://learn.microsoft.com/en-us/azure/ai-foundry/agents/how-to/ai-gateway
- https://github.com/azure-ai-foundry/foundry-samples/blob/main/infrastructure/infrastructure-setup-bicep/01-connections/apim-and-modelgateway-integration-guide.md
*/

// ============================================================================
// TARGET SCOPE
// ============================================================================
targetScope = 'resourceGroup'

// ============================================================================
// REQUIRED PARAMETERS
// ============================================================================

@description('Name of the AI Foundry account (Cognitive Services account)')
param aiFoundryAccountName string

@description('Name of the AI Foundry project')
param aiFoundryProjectName string

@description('Name for the APIM connection')
param connectionName string

@description('APIM gateway URL (e.g., https://my-apim.azure-api.net)')
param apimGatewayUrl string

@description('API path in APIM (e.g., openai, azure-openai-service-api)')
param apiPath string

// ============================================================================
// AUTHENTICATION PARAMETERS
// ============================================================================

@description('APIM subscription key for API access')
@secure()
param apimSubscriptionKey string

@allowed(['ApiKey'])
@description('Authentication type (ApiKey is currently supported)')
param authType string = 'ApiKey'

@description('Share connection to all project users')
param isSharedToAll bool = false

// ============================================================================
// APIM CONFIGURATION PARAMETERS
// ============================================================================

@allowed(['true', 'false'])
@description('Whether deployment name is in URL path (true) or request body (false). REQUIRED.')
param deploymentInPath string = 'false'

@description('API version for inference calls (chat completions, embeddings). Leave empty for APIM defaults.')
param inferenceAPIVersion string = ''

@description('API version for deployment management/discovery calls. Leave empty for APIM defaults.')
param deploymentAPIVersion string = ''

// ============================================================================
// MODEL DISCOVERY CONFIGURATION
// Choose EITHER static models OR dynamic discovery, not both.
// If neither is specified, APIM defaults will be used (/deployments endpoints).
// ============================================================================

// Note: When useApimDefaults is true and no static models or custom discovery is configured,
// APIM will automatically use its default discovery endpoints (/deployments).
// This parameter is for documentation purposes - the actual behavior is determined by
// whether staticModels or custom discovery parameters are provided.

// OPTION 1: Static Model List
@description('Static model list (use this OR dynamic discovery, not both)')
param staticModels array = []
/*
Example staticModels format:
[
  {
    name: 'gpt-4o-deployment'        // Deployment name in APIM
    properties: {
      model: {
        name: 'gpt-4o'               // Model name
        version: '2024-11-20'        // Model version
        format: 'OpenAI'             // Provider format
      }
    }
  }
]
*/

// OPTION 2: Dynamic Discovery Configuration
@description('Endpoint for listing models (e.g., /deployments, /models). Required for custom dynamic discovery.')
param listModelsEndpoint string = '/deployments'

@description('Endpoint for getting model details (e.g., /deployments/{deploymentName}). Required for custom dynamic discovery.')
param getModelEndpoint string = '/deployments/{deployment-id}'

@allowed(['', 'AzureOpenAI', 'OpenAI'])
@description('Provider format for model discovery responses')
param deploymentProvider string = 'AzureOpenAI'

// ============================================================================
// OPTIONAL: CUSTOM HEADERS
// ============================================================================

@description('Custom headers to include in requests (key-value pairs)')
param customHeaders object = {}
/*
Example customHeaders format:
{
  'X-Environment': 'production'
  'X-Route-Policy': 'premium'
  'X-Client-App': 'foundry-agents'
}
*/

// ============================================================================
// OPTIONAL: CUSTOM AUTHENTICATION CONFIGURATION
// ============================================================================

@description('Custom authentication configuration for API key header')
param authConfig object = {}
/*
Example authConfig format:
{
  type: 'api_key'
  name: 'x-api-key'              // Custom header name (default: api-key)
  format: '{api_key}'            // Format template (default: just the key)
}

Common patterns:
- Bearer token: { type: 'api_key', name: 'Authorization', format: 'Bearer {api_key}' }
- Custom header: { type: 'api_key', name: 'X-API-Token', format: 'Token {api_key}' }
*/

// ============================================================================
// VARIABLES
// ============================================================================

// Validation flags
var hasStaticModels = length(staticModels) > 0
var hasCustomDiscovery = listModelsEndpoint != '' && getModelEndpoint != '' && deploymentProvider != ''
var hasCustomHeaders = !empty(customHeaders)
var hasAuthConfig = !empty(authConfig)
var hasInferenceAPIVersion = inferenceAPIVersion != ''
var hasDeploymentAPIVersion = deploymentAPIVersion != ''

// Build target URL
var targetUrl = '${apimGatewayUrl}/${apiPath}'

// ============================================================================
// METADATA CONSTRUCTION
// Build metadata object based on provided parameters
// ============================================================================

var baseMetadata = {
  deploymentInPath: deploymentInPath
}

var inferenceVersionMetadata = hasInferenceAPIVersion ? {
  inferenceAPIVersion: inferenceAPIVersion
} : {}

var deploymentVersionMetadata = hasDeploymentAPIVersion ? {
  deploymentAPIVersion: deploymentAPIVersion
} : {}

// Model discovery metadata - only include if custom endpoints provided
var modelDiscoveryMetadata = hasCustomDiscovery ? {
  modelDiscovery: string({
    listModelsEndpoint: listModelsEndpoint
    getModelEndpoint: getModelEndpoint
    deploymentProvider: deploymentProvider
  })
} : {}

// Static models metadata - only include if models provided and no custom discovery
var staticModelsMetadata = hasStaticModels && !hasCustomDiscovery ? {
  models: string(staticModels)
} : {}

// Custom headers metadata
var customHeadersMetadata = hasCustomHeaders ? {
  customHeaders: string(customHeaders)
} : {}

// Auth config metadata
var authConfigMetadata = hasAuthConfig ? {
  authConfig: string(authConfig)
} : {}

// Final metadata combining all configurations
var metadata = union(
  baseMetadata,
  inferenceVersionMetadata,
  deploymentVersionMetadata,
  modelDiscoveryMetadata,
  staticModelsMetadata,
  customHeadersMetadata,
  authConfigMetadata
)

// ============================================================================
// EXISTING RESOURCES
// ============================================================================

resource aiFoundry 'Microsoft.CognitiveServices/accounts@2025-04-01-preview' existing = {
  name: aiFoundryAccountName
}

resource aiProject 'Microsoft.CognitiveServices/accounts/projects@2025-04-01-preview' existing = {
  name: aiFoundryProjectName
  parent: aiFoundry
}

// ============================================================================
// APIM CONNECTION RESOURCE
// ============================================================================

resource apimConnection 'Microsoft.CognitiveServices/accounts/projects/connections@2025-04-01-preview' = {
  name: connectionName
  parent: aiProject
  properties: {
    category: 'ApiManagement'
    target: targetUrl
    authType: authType
    isSharedToAll: isSharedToAll
    credentials: {
      key: apimSubscriptionKey
    }
    metadata: metadata
  }
}

// ============================================================================
// OUTPUTS
// ============================================================================

@description('Name of the created connection')
output connectionName string = apimConnection.name

@description('ID of the created connection')
output connectionId string = apimConnection.id

@description('Target URL for the APIM connection')
output targetUrl string = targetUrl

@description('Authentication type used')
output authType string = authType

@description('Whether static models are configured')
output hasStaticModels bool = hasStaticModels

@description('Whether custom discovery is configured')
output hasCustomDiscovery bool = hasCustomDiscovery

@description('Whether using APIM default discovery (no static models, no custom discovery)')
output usingApimDefaults bool = !hasStaticModels && !hasCustomDiscovery

@description('Final metadata configuration')
output metadata object = metadata
