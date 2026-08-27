/*
===========================================
APIM Connection - Using APIM Defaults
===========================================

This parameter file creates an APIM connection using APIM's default 
dynamic discovery endpoints:
- List Deployments: /deployments
- Get Deployment: /deployments/{deploymentName}
- Provider: AzureOpenAI

This is the simplest configuration - APIM defaults handle model discovery automatically.

USAGE:
  az deployment group create \
    --resource-group <foundry-resource-group> \
    --template-file main.bicep \
    --parameters main.bicepparam
*/

using 'main.bicep'

// ============================================================================
// REQUIRED: AI Foundry Configuration
// ============================================================================
param aiFoundryAccountName = 'YOUR-AI-FOUNDRY-ACCOUNT-NAME'
param aiFoundryProjectName = 'YOUR-AI-FOUNDRY-PROJECT-NAME'

// ============================================================================
// REQUIRED: Connection Configuration
// ============================================================================
param connectionName = 'citadel-hub-connection'

// ============================================================================
// REQUIRED: APIM Gateway Configuration
// ============================================================================
param apimGatewayUrl = 'https://YOUR-APIM-NAME.azure-api.net'
param apiPath = 'models'  // e.g., 'openai', 'models' are supported by default

// ============================================================================
// REQUIRED: Authentication
// ============================================================================
param apimSubscriptionKey = 'YOUR-APIM-SUBSCRIPTION-KEY'  // Use Key Vault reference in production!

// ============================================================================
// APIM Configuration
// ============================================================================
param deploymentInPath = 'false'
param inferenceAPIVersion = '2024-02-01'

// ============================================================================
// OPTIONAL: Configurations
// ============================================================================
param customHeaders = {}

// Using APIM defaults - no static models or custom discovery parameters provided
// APIM will automatically use /deployments endpoints for model discovery
