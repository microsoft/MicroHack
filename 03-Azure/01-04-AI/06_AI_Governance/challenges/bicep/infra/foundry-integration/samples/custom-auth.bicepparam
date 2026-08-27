/*
===========================================
APIM Connection - Custom Authentication Configuration
===========================================

This parameter file creates an APIM connection with custom 
authentication header configuration. Use this when:
- Your APIM expects a different header name than 'api-key'
- You need Bearer token format authentication
- You have custom authentication header requirements

USAGE:
  az deployment group create \
    --resource-group <foundry-resource-group> \
    --template-file main.bicep \
    --parameters samples/custom-auth.bicepparam
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
param connectionName = 'citadel-hub-custom-auth'

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
// Static Models
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
// Custom Authentication Configuration
// Customize how the API key is sent in request headers
// ============================================================================
param authConfig = {
  type: 'api_key'
  name: 'Ocp-Apim-Subscription-Key'   // Custom header name (default: api-key)
  format: '{api_key}'                  // Format template with {api_key} placeholder
}

/*
Common authConfig patterns:

1. Standard APIM Subscription Key (default):
   { type: 'api_key', name: 'api-key', format: '{api_key}' }

2. APIM Standard Header:
   { type: 'api_key', name: 'Ocp-Apim-Subscription-Key', format: '{api_key}' }

3. Bearer Token Format:
   { type: 'api_key', name: 'Authorization', format: 'Bearer {api_key}' }

4. Custom X-API-Key Header:
   { type: 'api_key', name: 'X-API-Key', format: '{api_key}' }

5. Custom Token Format:
   { type: 'api_key', name: 'X-API-Token', format: 'Token {api_key}' }
*/
