/*
===========================================
APIM Connection - Static Models Configuration
===========================================

This parameter file creates an APIM connection with a predefined 
static list of models. Use this when:
- You have a fixed set of known models
- Dynamic discovery is not available/needed
- You want explicit control over available models

USAGE:
  az deployment group create \
    --resource-group <foundry-resource-group> \
    --template-file main.bicep \
    --parameters samples/static-models.bicepparam
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
param connectionName = 'citadel-hub-static'

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
// Static Model List
// Define all models that should be available through this connection
// ============================================================================
param staticModels = [
  {
    name: 'gpt-4o'                    // Deployment name (how you reference it in API calls)
    properties: {
      model: {
        name: 'gpt-4o'                // Actual model name
        version: '2024-11-20'         // Model version
        format: 'OpenAI'              // Provider format
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
    name: 'text-embedding-ada-002'
    properties: {
      model: {
        name: 'text-embedding-ada-002'
        version: '2'
        format: 'OpenAI'
      }
    }
  }
]
