// @module universal-llm-api
// @description Creates the Universal LLM API that uses dynamic backend routing
// 
// This module creates an API in APIM that routes requests to the appropriate
// backend pool based on the model specified in the request.

// ------------------
//    PARAMETERS
// ------------------

@description('Name of the API Management service')
param apimServiceName string

@description('Path for the Universal LLM API')
param apiPath string = 'llm'

@description('Display name for the API')
param apiDisplayName string = 'Universal LLM API'

@description('Description for the API')
param apiDescription string = 'Unified API endpoint for all LLM models with dynamic routing and load balancing'

@description('Enable subscription key authentication')
param enableSubscriptionKey bool = true

// ------------------
//    VARIABLES
// ------------------

var policyXml = loadTextContent('./policies/universal-llm-api-policy.xml')

// ------------------
//    RESOURCES
// ------------------

resource apimService 'Microsoft.ApiManagement/service@2024-06-01-preview' existing = {
  name: apimServiceName
}

// Universal LLM API - OpenAI-compatible endpoint
resource universalLlmApi 'Microsoft.ApiManagement/service/apis@2024-06-01-preview' = {
  name: 'universal-llm-api'
  parent: apimService
  properties: {
    apiType: 'http'
    description: apiDescription
    displayName: apiDisplayName
    format: 'openapi+json'
    path: '${apiPath}/openai'
    protocols: [
      'https'
    ]
    subscriptionKeyParameterNames: {
      header: 'api-key'
      query: 'api-key'
    }
    subscriptionRequired: enableSubscriptionKey
    value: loadTextContent('./policies/universal-llm-openapi.json')
  }
}

// API Policy
resource universalLlmApiPolicy 'Microsoft.ApiManagement/service/apis/policies@2024-06-01-preview' = {
  name: 'policy'
  parent: universalLlmApi
  properties: {
    format: 'rawxml'
    value: policyXml
  }
}

// AI Models Inference API - Alternative endpoint for inference
resource modelsInferenceApi 'Microsoft.ApiManagement/service/apis@2024-06-01-preview' = {
  name: 'models-inference-api'
  parent: apimService
  properties: {
    apiType: 'http'
    description: 'AI Models Inference API endpoint for unified model access'
    displayName: 'Models Inference API'
    format: 'openapi+json'
    path: '${apiPath}/models'
    protocols: [
      'https'
    ]
    subscriptionKeyParameterNames: {
      header: 'api-key'
      query: 'api-key'
    }
    subscriptionRequired: enableSubscriptionKey
    value: loadTextContent('./policies/models-inference-openapi.json')
  }
}

// Models Inference API Policy
resource modelsInferenceApiPolicy 'Microsoft.ApiManagement/service/apis/policies@2024-06-01-preview' = {
  name: 'policy'
  parent: modelsInferenceApi
  properties: {
    format: 'rawxml'
    value: policyXml
  }
}

// ------------------
//    OUTPUTS
// ------------------

@description('Universal LLM API name')
output universalLlmApiName string = universalLlmApi.name

@description('Universal LLM API path')
output universalLlmApiPath string = universalLlmApi.properties.path

@description('Models Inference API name')
output modelsInferenceApiName string = modelsInferenceApi.name

@description('Models Inference API path')
output modelsInferenceApiPath string = modelsInferenceApi.properties.path
