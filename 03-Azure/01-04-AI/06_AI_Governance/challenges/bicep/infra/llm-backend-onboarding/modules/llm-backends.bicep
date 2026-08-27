/**
 * @module llm-backends
 * @description Creates APIM backends for LLM services (AI Foundry, Azure OpenAI, Amazon Bedrock, and other providers)
 * 
 * This module dynamically creates backend resources based on the provided configuration array.
 * Each backend represents an LLM endpoint that can serve one or more model deployments.
 * 
 * Supported backend types:
 * - ai-foundry: Azure AI Foundry projects with model deployments
 * - azure-openai: Azure OpenAI Service endpoints
 * - aws-bedrock: Amazon Bedrock endpoints with AWS SigV4 authentication
 * - external: Other LLM providers (OpenAI, Anthropic, etc.)
 */

// ------------------
//    PARAMETERS
// ------------------

@description('Name of the API Management service')
param apimServiceName string

@description('User-assigned managed identity client ID for authentication')
param managedIdentityClientId string

@description('Configuration array for LLM backends')
param llmBackendConfig array

@description('Whether to configure circuit breaker for backends')
param configureCircuitBreaker bool = true

// ------------------
//    RESOURCES
// ------------------

resource apimService 'Microsoft.ApiManagement/service@2024-06-01-preview' existing = {
  name: apimServiceName
}

// Create individual backends for each LLM endpoint
resource llmBackends 'Microsoft.ApiManagement/service/backends@2024-06-01-preview' = [for (config, i) in llmBackendConfig: {
  name: config.backendId
  parent: apimService
  properties: {
    description: 'LLM Backend: ${config.backendType} - ${config.backendId} - Supports models: ${join(map(config.supportedModels, m => m.name), ', ')}'
    url: config.endpoint
    protocol: 'http'
    
    // Circuit breaker configuration for resilience
    circuitBreaker: configureCircuitBreaker ? {
      rules: [
        {
          failureCondition: {
            count: 3
            errorReasons: [
              'Server errors'
            ]
            interval: 'PT5M'
            statusCodeRanges: [
              {
                min: 429
                max: 429
              }
              {
                min: 500
                max: 503
              }
            ]
          }
          name: '${config.backendId}-breaker-rule'
          tripDuration: 'PT1M'
          acceptRetryAfter: true
        }
      ]
    } : null
    
    // Backend authorization configuration
    // Determines the effective authType: explicit authType > default from backendType
    // managed-identity: configure credentials.managedIdentity on the backend resource (native APIM backend auth)
    // api-key-bearer/api-key-header: credentials handled in policy fragments via named values
    // aws-sigv4: credentials handled in policy fragments
    // none: no auth configured
    credentials: {
      // Managed Identity authorization (native backend auth — no policy expression needed)
      #disable-next-line BCP037
      managedIdentity: (config.?authType ?? (config.backendType == 'aws-bedrock' ? 'aws-sigv4' : (config.backendType == 'external' ? 'none' : (config.backendType == 'aws-bedrock-mantle' || config.backendType == 'gemini-openai' ? 'api-key-bearer' : 'managed-identity')))) == 'managed-identity' ? {
        clientId: managedIdentityClientId
        resource: 'https://cognitiveservices.azure.com'
      } : null
      // Header-based credentials (managed identity client ID hint for Azure backends)
      header: (config.?authType ?? (config.backendType == 'aws-bedrock' ? 'aws-sigv4' : (config.backendType == 'external' ? 'none' : 'managed-identity'))) == 'managed-identity' ? {
        'x-ms-client-id': [
          managedIdentityClientId
        ]
      } : {}
    }
    
    // TLS configuration for secure communication
    tls: {
      validateCertificateChain: true
      validateCertificateName: true
    }
  }
}]

// ------------------
//    OUTPUTS
// ------------------

@description('Array of created backend IDs')
output backendIds array = [for (config, i) in llmBackendConfig: llmBackends[i].name]

@description('Array of backend configurations with resource IDs')
output backendDetails array = [for (config, i) in llmBackendConfig: {
  backendId: config.backendId
  backendType: config.backendType
  authType: config.?authType ?? ''
  authConfigNamedValue: config.?authConfig.?namedValueKey ?? ''
  resourceId: llmBackends[i].id
  supportedModels: config.supportedModels
  priority: config.?priority ?? 1
  weight: config.?weight ?? 100
}]
