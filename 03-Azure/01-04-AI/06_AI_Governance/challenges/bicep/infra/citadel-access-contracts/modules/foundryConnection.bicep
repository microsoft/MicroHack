/*
===========================================
Foundry APIM Connection Module
===========================================

Creates an APIM connection in an existing Azure AI Foundry project.
This enables Foundry agents to access AI models through the APIM gateway.

REFERENCES:
- https://learn.microsoft.com/en-us/azure/ai-foundry/agents/how-to/ai-gateway
*/

// ============================================================================
// REQUIRED PARAMETERS
// ============================================================================

@description('Name of the AI Foundry account (Cognitive Services account)')
param aiFoundryAccountName string

@description('Name of the AI Foundry project')
param aiFoundryProjectName string

@description('Name for the APIM connection')
param connectionName string

@description('Target URL for the APIM connection (gateway + API path)')
param targetUrl string

@description('APIM subscription key for API access')
@secure()
param apimSubscriptionKey string

// ============================================================================
// OPTIONAL PARAMETERS
// ============================================================================

@allowed(['ApiKey'])
@description('Authentication type (ApiKey is currently supported)')
param authType string = 'ApiKey'

@allowed(['ApiManagement', 'ModelGateway'])
@description('Foundry connection category. Use ModelGateway for portal-compatible model gateway connections.')
param connectionCategory string = 'ApiManagement'

@description('Share connection to all project users')
param isSharedToAll bool = false

@allowed(['true', 'false'])
@description('Whether deployment name is in URL path (true) or request body (false)')
param deploymentInPath string = 'false'

@description('API version for inference calls. Leave empty for APIM defaults.')
param inferenceAPIVersion string = ''

@description('API version for deployment discovery calls. Leave empty for APIM defaults.')
param deploymentAPIVersion string = ''

@description('Static model list (optional - use this OR dynamic discovery)')
param staticModels array = []

@description('Endpoint for listing models. Leave empty for APIM defaults.')
param listModelsEndpoint string = ''

@description('Endpoint for getting model details. Leave empty for APIM defaults.')
param getModelEndpoint string = ''

@allowed(['', 'AzureOpenAI', 'OpenAI'])
@description('Provider format for model discovery responses')
param deploymentProvider string = ''

@description('Custom headers to include in requests')
param customHeaders object = {}

@description('Custom authentication configuration')
param authConfig object = {}

// ============================================================================
// VARIABLES
// ============================================================================

// Validation flags
var hasStaticModels = length(staticModels) > 0
var hasCustomDiscovery = !empty(listModelsEndpoint) && !empty(getModelEndpoint) && !empty(deploymentProvider)
var hasCustomHeaders = !empty(customHeaders)
var hasAuthConfig = !empty(authConfig)
var hasInferenceAPIVersion = !empty(inferenceAPIVersion)
var hasDeploymentAPIVersion = !empty(deploymentAPIVersion)

// ============================================================================
// METADATA CONSTRUCTION
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

var modelDiscoveryMetadata = hasCustomDiscovery ? {
  modelDiscovery: string({
    listModelsEndpoint: listModelsEndpoint
    getModelEndpoint: getModelEndpoint
    deploymentProvider: deploymentProvider
  })
} : {}

var staticModelsMetadata = hasStaticModels && !hasCustomDiscovery ? {
  models: string(staticModels)
} : {}

// Always emit customHeaders (portal requires this field even if empty)
var customHeadersMetadata = {
  customHeaders: hasCustomHeaders ? string(customHeaders) : '{}'
}

var authConfigMetadata = hasAuthConfig ? {
  authConfig: string(authConfig)
} : {}

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
    category: connectionCategory
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
