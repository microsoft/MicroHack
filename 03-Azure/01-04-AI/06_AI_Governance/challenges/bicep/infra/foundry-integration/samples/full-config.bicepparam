/*
===========================================
APIM Connection - Full Configuration Example
===========================================

This parameter file demonstrates ALL available configuration options
for an APIM connection. Use this as a reference for understanding
all possible settings.

NOTE: This is a comprehensive example. In practice, you would only
include the parameters relevant to your specific use case.

USAGE:
  az deployment group create \
    --resource-group <foundry-resource-group> \
    --template-file main.bicep \
    --parameters samples/full-config.bicepparam
*/

using '../main.bicep'

// ============================================================================
// REQUIRED: AI Foundry Configuration
// ============================================================================

// Name of your AI Foundry account (Cognitive Services resource)
param aiFoundryAccountName = 'YOUR-AI-FOUNDRY-ACCOUNT-NAME'

// Name of the specific project within the AI Foundry account
param aiFoundryProjectName = 'YOUR-AI-FOUNDRY-PROJECT-NAME'

// ============================================================================
// REQUIRED: Connection Configuration
// ============================================================================

// Unique name for this connection (will appear in Foundry portal)
param connectionName = 'citadel-hub-full-config'

// ============================================================================
// REQUIRED: APIM Gateway Configuration
// ============================================================================

// Full URL to your APIM gateway (without trailing slash)
param apimGatewayUrl = 'https://YOUR-APIM-NAME.azure-api.net'

// API path as configured in APIM (without leading slash)
param apiPath = 'openai'

// ============================================================================
// REQUIRED: Authentication
// ============================================================================

// APIM subscription key - use Key Vault reference in production!
// Example Key Vault reference: @Microsoft.KeyVault(SecretUri=https://myvault.vault.azure.net/secrets/apim-key)
param apimSubscriptionKey = 'YOUR-APIM-SUBSCRIPTION-KEY'

// Authentication type (currently only ApiKey is supported)
param authType = 'ApiKey'

// Whether to share this connection with all users in the project
param isSharedToAll = true

// ============================================================================
// APIM Request Configuration
// ============================================================================

// How deployment name is passed in requests:
// 'true'  - In URL path: /deployments/{name}/chat/completions
// 'false' - In request body: { "model": "{name}" }
param deploymentInPath = 'true'

// API version for inference calls (chat completions, embeddings)
param inferenceAPIVersion = '2024-02-01'

// API version for deployment management/discovery calls
param deploymentAPIVersion = '2024-02-01'

// ============================================================================
// MODEL CONFIGURATION
// Choose ONE of the following approaches:
// 1. Leave staticModels and discovery params empty (APIM defaults)
// 2. staticModels (define models explicitly)
// 3. Custom discovery endpoints (listModelsEndpoint, getModelEndpoint, deploymentProvider)
// ============================================================================

// Option 2: Static model list (comment out if using discovery)
param staticModels = [
  {
    name: 'gpt-4o'
    properties: {
      model: {
        name: 'gpt-4o'
        version: '2024-11-20'
        format: 'OpenAI'
      }
    }
  }
  {
    name: 'gpt-4o-mini'
    properties: {
      model: {
        name: 'gpt-4o-mini'
        version: '2024-07-18'
        format: 'OpenAI'
      }
    }
  }
  {
    name: 'text-embedding-3-large'
    properties: {
      model: {
        name: 'text-embedding-3-large'
        version: '1'
        format: 'OpenAI'
      }
    }
  }
]

// Option 3: Custom discovery (uncomment and configure if not using static models)
// param listModelsEndpoint = '/deployments'
// param getModelEndpoint = '/deployments/{deploymentName}'
// param deploymentProvider = 'AzureOpenAI'

// ============================================================================
// OPTIONAL: Custom Headers
// Additional headers to include in all inference requests
// ============================================================================
param customHeaders = {
  'X-Environment': 'production'
  'X-Route-Policy': 'enterprise'
  'X-Client-App': 'foundry-agents'
  'X-Correlation-ID': 'citadel-integration'
}

// ============================================================================
// OPTIONAL: Custom Authentication Configuration
// Customize how the API key is sent in request headers
// ============================================================================
param authConfig = {
  type: 'api_key'
  name: 'api-key'
  format: '{api_key}'
}
