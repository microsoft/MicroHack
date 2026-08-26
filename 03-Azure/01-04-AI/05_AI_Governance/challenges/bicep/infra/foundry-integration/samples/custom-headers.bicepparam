/*
===========================================
APIM Connection - Custom Headers Configuration
===========================================

This parameter file creates an APIM connection with custom headers.
Use this when:
- Your APIM policies require custom headers for routing
- You need to include environment or client identification headers
- You have rate limiting or policy headers to include

USAGE:
  az deployment group create \
    --resource-group <foundry-resource-group> \
    --template-file main.bicep \
    --parameters samples/custom-headers.bicepparam
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
param connectionName = 'citadel-hub-headers'

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

// ============================================================================
// Static Models (required when using custom headers without discovery)
// ============================================================================
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
]

// ============================================================================
// Custom Headers
// These headers are included in all inference requests to APIM
// ============================================================================
param customHeaders = {
  'X-Environment': 'production'       // Environment identifier
  'X-Route-Policy': 'premium'         // Routing policy header
  'X-Client-App': 'foundry-agents'    // Client application identifier
  'X-Business-Unit': 'finance'        // Business unit tracking
}
