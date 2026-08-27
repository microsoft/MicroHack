using './main.bicep'

// =====================================================================
//    CORE — Identify the existing APIM instance and managed identity
// =====================================================================

param apimServiceName = '<your-apim-service-name>'
param managedIdentityName = '<your-managed-identity-name>'

// =====================================================================
//    POLICY FRAGMENTS
// =====================================================================

param updatePolicyFragments = true
param enablePIIAnonymization = true
param enableAIModelInference = true

// =====================================================================
//    NAMED VALUES (auth, Entra, PII, Content Safety)
// =====================================================================

param updateNamedValues = true
param entraAuth = false
param clientAppId = ' '
// param tenantId — defaults to current tenant
param audience = 'https://cognitiveservices.azure.com/.default'
param aiLanguageServiceUrl = ''
param contentSafetyServiceUrl = ''

// =====================================================================
//    JWT AUTHENTICATION NAMED VALUES
//    Required when enableJwtAuth = true
// =====================================================================

param updateJwtNamedValues = true
param enableJwtAuth = false
param jwtTenantId = ''
param jwtAppRegistrationId = ''

// =====================================================================
//    LLM BACKENDS, POOLS & DYNAMIC POLICY FRAGMENTS
//    Define all LLM backends and their supported models.
//    Uncomment and configure the array below to match your environment.
// =====================================================================

param updateLLMBackends = true
param updateLLMBackendPools = true
param updateLLMPolicyFragments = true
param llmBackendConfig = [
  // Example: Azure OpenAI backend
  // {
  //   backendId: 'azure-openai-swedencentral'
  //   backendType: 'azure-openai'
  //   endpoint: 'https://my-openai.openai.azure.com'
  //   authScheme: 'managedIdentity'
  //   supportedModels: [
  //     { name: 'gpt-4o', sku: 'GlobalStandard', capacity: 100, modelFormat: 'OpenAI', modelVersion: '2024-08-06' }
  //   ]
  //   priority: 1
  //   weight: 100
  // }
  // Example: AI Foundry backend
  // {
  //   backendId: 'ai-foundry-eastus'
  //   backendType: 'ai-foundry'
  //   endpoint: 'https://my-project.eastus.inference.ml.azure.com'
  //   authScheme: 'managedIdentity'
  //   supportedModels: [
  //     { name: 'gpt-4o-mini', sku: 'GlobalStandard', capacity: 50, modelFormat: 'OpenAI', modelVersion: '2024-07-18' }
  //   ]
  //   priority: 1
  //   weight: 100
  // }
]

// =====================================================================
//    INFERENCE APIs — Universal LLM & Azure OpenAI
// =====================================================================

param updateUniversalLLMApi = true
param updateAzureOpenAIApi = true

// =====================================================================
//    UNIFIED AI WILDCARD API
// =====================================================================

param updateUnifiedAiApi = true
param enableUnifiedAiApi = true

// =====================================================================
//    AZURE AI SEARCH API
// =====================================================================

param updateAzureAISearchApi = false
param aiSearchInstances = [
  // {
  //   name: 'my-search-instance'
  //   description: 'Azure AI Search Service'
  //   url: 'https://my-search.search.windows.net'
  // }
]

// =====================================================================
//    OPENAI REALTIME WEBSOCKET API
// =====================================================================

param updateOpenAIRealtimeApi = false

// =====================================================================
//    DOCUMENT INTELLIGENCE APIs
// =====================================================================

param updateDocumentIntelligenceApi = false

// =====================================================================
//    REDIS CACHE & EMBEDDINGS BACKEND
//    Required when updateRedisCache or updateEmbeddingsBackend = true
// =====================================================================

param updateRedisCache = false
param enableRedisCache = false
param redisCacheConnectionString = ''

param updateEmbeddingsBackend = false
param enableEmbeddingsBackend = false
param embeddingsBackendUrl = ''

// =====================================================================
//    LOGGING / DIAGNOSTICS SETTINGS
//    Customize what is captured in Application Insights and Azure Monitor.
// =====================================================================

param updateAppInsightsDiagnostics = true

param azureMonitorLogSettings = {
  frontend: {
    request:  { headers: [], body: { bytes: 0 } }
    response: { headers: [], body: { bytes: 0 } }
  }
  backend: {
    request:  { headers: [], body: { bytes: 0 } }
    response: { headers: [], body: { bytes: 0 } }
  }
  largeLanguageModel: {
    logs: 'enabled'
    requests:  { messages: 'all', maxSizeInBytes: 262144 }
    responses: { messages: 'all', maxSizeInBytes: 262144 }
  }
}

param appInsightsLogSettings = {
  headers: [ 'Content-type', 'User-agent', 'x-ms-region', 'x-ratelimit-remaining-tokens', 'x-ratelimit-remaining-requests' ]
  body: { bytes: 0 }
}
