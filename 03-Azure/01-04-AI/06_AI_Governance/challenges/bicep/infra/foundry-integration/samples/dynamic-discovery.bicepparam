/*
===========================================
APIM Connection - Dynamic Discovery Configuration
===========================================

This parameter file creates an APIM connection with custom 
dynamic discovery endpoints. Use this when:
- Your APIM uses non-standard endpoints for model discovery
- You need to specify custom endpoints different from APIM defaults
- You're using OpenAI-format APIs instead of AzureOpenAI

USAGE:
  az deployment group create \
    --resource-group <foundry-resource-group> \
    --template-file main.bicep \
    --parameters samples/dynamic-discovery.bicepparam
*/

using '../main.bicep'

// ============================================================================
// REQUIRED: AI Foundry Configuration
// ============================================================================
param aiFoundryAccountName = 'YOUR-AI-FOUNDRY-ACCOUNT-NAME'
param aiFoundryProjectName = 'YOUR-AI-FOUNDRY-PROJECT-NAME'

// ============================================================================
// REQUIRED: Connection Configuration
// ============================================================================
param connectionName = 'citadel-hub-dynamic'

// ============================================================================
// REQUIRED: APIM Gateway Configuration
// ============================================================================
param apimGatewayUrl = 'https://YOUR-APIM-NAME.azure-api.net'
param apiPath = 'openai'

// ============================================================================
// REQUIRED: Authentication
// ============================================================================
param apimSubscriptionKey = 'YOUR-APIM-SUBSCRIPTION-KEY'

// ============================================================================
// APIM Configuration
// ============================================================================
param deploymentInPath = 'true'
param inferenceAPIVersion = '2024-02-01'
param deploymentAPIVersion = '2024-02-01'  // API version for discovery calls

// ============================================================================
// Custom Dynamic Discovery Configuration
// Specify custom endpoints if different from APIM defaults
// ============================================================================

// Endpoint to list all available models/deployments
// Default APIM uses: /deployments
param listModelsEndpoint = '/deployments'

// Endpoint to get details for a specific model/deployment
// Use {deploymentName} as placeholder for the model name
// Default APIM uses: /deployments/{deploymentName}
param getModelEndpoint = '/deployments/{deploymentName}'

// Provider format for parsing discovery responses
// - 'AzureOpenAI': Uses Azure ARM format with value array and properties.model structure
// - 'OpenAI': Uses OpenAI format with data array and id field
param deploymentProvider = 'AzureOpenAI'
