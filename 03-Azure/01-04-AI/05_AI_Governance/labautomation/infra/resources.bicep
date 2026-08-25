// ==========================================================================
// Citadel Agentic Governance Hub — resource-group scoped deployment
// Adapted from: https://github.com/mohamedsaif/ai-hub-gateway-solution-accelerator
//
// Deploys Hub + Spoke resources into a single pre-created resource group.
// Entry point: labautomation/deploy-lab.ps1 (MicroHack platform entry point).
// ==========================================================================

targetScope = 'resourceGroup'

@minLength(1)
@description('Azure region for all resources. Validated for Foundry model availability.')
param location string

@minLength(1)
@description('Deterministic suffix for resource naming (DNS-safe, lowercase).')
param resourceToken string

@description('Primary Entra user object ID for initial RBAC grants. Multi-user RBAC is applied post-deployment.')
param principalId string = ''

@description('Principal type for RBAC assignments: User (interactive) or ServicePrincipal (CI/CD).')
@allowed(['User', 'ServicePrincipal'])
param principalType string = 'User'

@description('Tags to apply to all resources.')
param tags object = {}

// ===== Hub Resource Naming =====
var hubFoundryAccountName = 'aif-hub-${resourceToken}'
var hubFoundryProjectName = 'citadel-hub-project'
var apimName = 'apim-citadel-${resourceToken}'
var cosmosAccountName = 'cos-citadel-${resourceToken}'
var eventHubNamespace = 'evh-citadel-${resourceToken}'
var eventHubName = 'usage-events'
var keyVaultName = 'kv-hub-${resourceToken}'
var laName = 'law-citadel-${resourceToken}'
var aiName = 'appi-citadel-${resourceToken}'
var storageAccountName = 'stcitadel${replace(resourceToken, '-', '')}'
var logicAppName = 'la-usage-ingestion-${resourceToken}'
var apimMIName = 'mi-apim-${resourceToken}'
var logicAppMIName = 'mi-logicapp-${resourceToken}'

// ===== Spoke Resource Naming =====
var spokeFoundryAccountName = 'aif-spoke-${resourceToken}'
var spokeFoundryProjectName = 'citadel-agents-project'
var spokeLaName = 'law-spoke-${resourceToken}'
var spokeAiName = 'appi-spoke-${resourceToken}'
var spokeKeyVaultName = 'kv-spoke-${resourceToken}'
var spokeAcrName = 'acrcitadel${replace(resourceToken, '-', '')}'

// ===== Computed Values =====
var cosmosApi = '2024-11-15'
var aiServicesApi = '2025-04-01-preview'
var cosmosDatabaseName = 'citadel-hub'
var cosmosContainers = [
  { name: 'usage-events', partitionKey: '/eventId' }
  { name: 'contracts', partitionKey: '/contractId' }
  { name: 'models', partitionKey: '/modelId' }
  { name: 'config', partitionKey: '/configId' }
]

// ===== Managed Identities =====
resource apimMI 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: apimMIName
  location: location
  tags: tags
}

resource logicAppMI 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: logicAppMIName
  location: location
  tags: tags
}

// ===== Hub: Observability (Log Analytics + Application Insights) =====
resource laHub 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: laName
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

resource aiHub 'Microsoft.Insights/components@2020-02-02' = {
  name: aiName
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: laHub.id
  }
}

// ===== Hub: Key Vault =====
resource kvHub 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  tags: tags
  properties: {
    tenantId: subscription().tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    enableRbacAuthorization: true
    publicNetworkAccess: 'Enabled'
  }
}

// ===== Hub: Azure AI Foundry Account (AIServices) =====
resource hubFoundryAccount 'Microsoft.CognitiveServices/accounts@2025-04-01-preview' = {
  name: hubFoundryAccountName
  location: location
  kind: 'AIServices'
  tags: tags
  sku: {
    name: 'S0'
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    customSubDomainName: hubFoundryAccountName
    publicNetworkAccess: 'Enabled'
    allowProjectManagement: true
  }
}

// ===== Hub: Foundry Project =====
resource hubFoundryProject 'Microsoft.CognitiveServices/accounts/projects@2025-04-01-preview' = {
  parent: hubFoundryAccount
  name: hubFoundryProjectName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    description: 'Citadel Agentic Governance Hub - Primary project for governance demonstrations'
  }
}

// ===== Hub: Cosmos DB Account (NoSQL, serverless, keyless) =====
resource cosmosAccount 'Microsoft.DocumentDB/databaseAccounts@2024-11-15' = {
  name: cosmosAccountName
  location: location
  tags: tags
  kind: 'GlobalDocumentDB'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    databaseAccountOfferType: 'Standard'
    disableLocalAuth: true
    publicNetworkAccess: 'Enabled'
    capabilities: [
      {
        name: 'EnableServerless'
      }
    ]
    locations: [
      {
        locationName: location
        failoverPriority: 0
      }
    ]
  }
}

// ===== Hub: Cosmos DB Database =====
resource cosmosDb 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2024-11-15' = {
  parent: cosmosAccount
  name: cosmosDatabaseName
  properties: {
    resource: {
      id: cosmosDatabaseName
    }
  }
}

// ===== Hub: Cosmos DB Containers (expanded with AI Governance containers) =====
var cosmosContainersPhase4 = concat(cosmosContainers, [
  { name: 'ai-usage-container', partitionKey: '/productName' }
  { name: 'pii-usage-container', partitionKey: '/type' }
  { name: 'llm-usage-container', partitionKey: '/productName' }
])

resource cosmosContainers_resource 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2024-11-15' = [for container in cosmosContainersPhase4: {
  parent: cosmosDb
  name: container.name
  properties: {
    resource: {
      id: container.name
      partitionKey: {
        paths: [
          container.partitionKey
        ]
        kind: 'Hash'
      }
    }
  }
}]

// ==========================================================================
// PHASE 4: CITADEL AI GOVERNANCE HUB
// Model Deployments, APIM Infrastructure, Policies, Products, Subscriptions
// ==========================================================================

// ===== Phase 4: Model Configuration =====
// 7 models deployed to hub Foundry for Notebooks 1-6
var aiFoundryModels = [
  {
    name: 'gpt-4.1'
    publisher: 'OpenAI'
    version: '2025-04-14'
    sku: 'GlobalStandard'
    capacity: 100
    retirementDate: '2026-10-14'
  }
  {
    name: 'gpt-5.4-mini'
    publisher: 'OpenAI'
    version: '2026-03-17'
    sku: 'GlobalStandard'
    capacity: 100
    retirementDate: '2026-09-30'
  }
  {
    name: 'gpt-5.2'
    publisher: 'OpenAI'
    version: '2025-12-11'
    sku: 'GlobalStandard'
    capacity: 100
    retirementDate: '2027-02-05'
  }
  {
    name: 'text-embedding-3-large'
    publisher: 'OpenAI'
    version: '1'
    sku: 'GlobalStandard'
    capacity: 100
    retirementDate: '2027-04-14'
  }
  {
    name: 'Mistral-Large-3'
    publisher: 'Mistral AI'
    version: '1'
    sku: 'GlobalStandard'
    capacity: 100
    retirementDate: '2099-12-30'
  }
  {
    name: 'Phi-4'
    publisher: 'Microsoft'
    version: '7'
    sku: 'GlobalStandard'
    capacity: 1
    retirementDate: '2099-10-14'
  }
]

// ===== Phase 4: Model Deployments to Hub Foundry Account =====
// Each model deployed to support Notebooks 1-6
// @batchSize(1) serializes deployments to avoid Cognitive Services account conflicts
@batchSize(1)
resource hubFoundryModelDeployments 'Microsoft.CognitiveServices/accounts/deployments@2025-04-01-preview' = [for (model, index) in aiFoundryModels: {
  parent: hubFoundryAccount
  name: replace(model.name, '.', '-')
  sku: {
    name: model.sku
    capacity: model.capacity
  }
  properties: {
    model: {
      format: model.publisher
      name: model.name
      version: model.version
    }
  }
}]

// ===== Phase 4: APIM Named Values (Backend Authentication) =====
// Managed identity client ID for hub Foundry backend authentication
resource apimNamedValueUamiClientId 'Microsoft.ApiManagement/service/namedValues@2023-09-01-preview' = {
  parent: apim
  name: 'uami-client-id'
  properties: {
    displayName: 'Hub.Foundry.UAMI.Client.ID'
    value: apimMI.properties.clientId
    secret: false
  }
}

// ===== Phase 4: APIM Backends =====
// Hub Foundry backend with managed identity
resource apimBackendHubFoundry 'Microsoft.ApiManagement/service/backends@2023-09-01-preview' = {
  parent: apim
  name: 'backend-hub-foundry'
  properties: {
    title: 'Hub Foundry Backend'
    description: 'Hub Foundry AI Services backend for model inference via managed identity'
    url: 'https://${hubFoundryAccountName}.openai.azure.com'
    protocol: 'http'
    circuitBreaker: {
      rules: [
        {
          name: 'serverErrorRule'
          tripDuration: 'PT1M'
          failureCondition: {
            count: 5
            interval: 'PT1M'
            statusCodeRanges: [
              { min: 500, max: 599 }
            ]
          }
        }
      ]
    }
  }
}

// RBAC: allow the APIM managed identity to call the hub Foundry account (Cognitive Services OpenAI User)
resource roleAssignmentApimMiOpenAiUser 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(hubFoundryAccount.id, apimMI.id, 'CognitiveServicesOpenAIUser')
  scope: hubFoundryAccount
  properties: {
    principalId: apimMI.properties.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd')
  }
}

// ===== Phase 4: APIM Policy Fragments =====
// Policy fragment: Extract available models from deployment list
resource policyFragmentGetAvailableModels 'Microsoft.ApiManagement/service/policyFragments@2023-09-01-preview' = {
  parent: apim
  name: 'get-available-models'
  properties: {
    format: 'xml'
    value: '<fragment><!-- Returns deployed models array to client --><return-response><set-header name="Content-Type" exists-action="override"><value>application/json</value></set-header><set-body>@{var models = new JArray(); models.Add("gpt-4.1"); models.Add("gpt-5.4-mini"); models.Add("gpt-5.2"); models.Add("text-embedding-3-large"); models.Add("Mistral-Large-3"); models.Add("Phi-4"); return models.ToString();}</set-body></return-response></fragment>'
  }
}

// Policy fragment: Validate model access per subscription (DISABLED - XML syntax pending)
/*
resource policyFragmentValidateModelAccess 'Microsoft.ApiManagement/service/policyFragments@2023-09-01-preview' = {
  parent: apim
  name: 'validate-model-access'
  properties: {
    format: 'xml'
    value: '<fragment><!-- Validate requested model against subscription allowedModels list --><choose><when condition="@{string requestedModel = context.Request.BodyAsString; string allowedModels = context.Product.Name; !allowedModels.Contains(requestedModel)}"><set-status code="403" reason="Model not allowed for this subscription"/></when></choose></fragment>'
  }
}
*/

// Policy fragment: Set backend pools for model routing (DISABLED)
/*
resource policyFragmentSetBackendPools 'Microsoft.ApiManagement/service/policyFragments@2023-09-01-preview' = {
  parent: apim
  name: 'set-backend-pools'
  properties: {
    format: 'xml'
    value: '<fragment><!-- Define backend pools for routing based on model type --><set-variable name="selectedBackend" value="backend-hub-foundry"/></fragment>'
  }
}
*/

// Policy fragment: Set backend authorization (DISABLED - XML syntax pending)
/*
resource policyFragmentSetBackendAuthorization 'Microsoft.ApiManagement/service/policyFragments@2023-09-01-preview' = {
  parent: apim
  name: 'set-backend-authorization'
  properties: {
    format: 'xml'
    value: '<fragment><!-- Acquire managed identity token for hub Foundry backend --><set-variable name="hubFoundryAccessToken" value="@{var ma = new ManagedIdentity(); return ma.GetToken("https://${hubFoundryAccountName}.openai.azure.com/"); }"/></fragment>'
  }
}
*/

// Policy fragment: Set target backend pool (DISABLED - requires authorization to work)
/*
resource policyFragmentSetTargetBackendPool 'Microsoft.ApiManagement/service/policyFragments@2023-09-01-preview' = {
  parent: apim
  name: 'set-target-backend-pool'
  properties: {
    format: 'xml'
    value: '<fragment><!-- Route to selected backend --><set-backend-service base-id="backend-hub-foundry" backend-id="backend-hub-foundry"/></fragment>'
  }
}
*/

// Policy fragment: Extract LLM requested model (DISABLED)
/*
resource policyFragmentSetLlmRequestedModel 'Microsoft.ApiManagement/service/policyFragments@2023-09-01-preview' = {
  parent: apim
  name: 'set-llm-requested-model'
  properties: {
    format: 'xml'
    value: '<fragment><!-- Extract model from request path or body --><set-variable name="requestedModel" value="@{var path = context.Request.Url.Path; var model = path.Split(new[]{"/"}, System.StringSplitOptions.None)[3]; return model; }"/></fragment>'
  }
}
*/

// Policy fragment: Track LLM usage (DISABLED)
/*
resource policyFragmentSetLlmUsage 'Microsoft.ApiManagement/service/policyFragments@2023-09-01-preview' = {
  parent: apim
  name: 'set-llm-usage'
  properties: {
    format: 'xml'
    value: '<fragment><!-- Log usage to Application Insights --><trace severity="information" message="@{return "LLM Usage: Model=" + context.Variables["requestedModel"] + ", Product=" + context.Product.Name; }"/></fragment>'
  }
}
*/

// Policy fragment: PII Anonymization (DISABLED)
/*
resource policyFragmentPiiAnonymization 'Microsoft.ApiManagement/service/policyFragments@2023-09-01-preview' = {
  parent: apim
  name: 'pii-anonymization'
  properties: {
    format: 'xml'
    value: '<fragment><!-- PII masking: replace sensitive patterns --><set-body>@{string body = context.Request.Body.AsString(); body = System.Text.RegularExpressions.Regex.Replace(body, @"\\b\\d{3}-\\d{2}-\\d{4}\\b", "***-**-****"); return body; }</set-body></fragment>'
  }
}

// Policy fragment: PII Deanonymization
resource policyFragmentPiiDeanonymization 'Microsoft.ApiManagement/service/policyFragments@2023-09-01-preview' = {
  parent: apim
  name: 'pii-deanonymization'
  properties: {
    format: 'xml'
    value: '<fragment><!-- PII deanonymization: restore from masking layer --><set-variable name="piiRestored" value="true"/></fragment>'
  }
}

// Policy fragment: PII State Saving
resource policyFragmentPiiStateSaving 'Microsoft.ApiManagement/service/policyFragments@2023-09-01-preview' = {
  parent: apim
  name: 'pii-state-saving'
  properties: {
    format: 'xml'
    value: '<fragment><!-- Save PII state to Cosmos DB pii-usage-container --><send-request mode="new" response-variable-name="piiStateResponse" timeout="20"><set-url>https://${cosmosAccountName}.documents.azure.com/dbs/${cosmosDatabaseName}/colls/pii-usage-container/docs</set-url><set-method>POST</set-method></send-request></fragment>'
  }
}
*/

// ===== Phase 4: APIM API - Universal LLM API =====
// Universal endpoint for all LLM backends (/models/*)
resource apiUniversalLlm 'Microsoft.ApiManagement/service/apis@2023-09-01-preview' = {
  parent: apim
  name: 'universal-llm-api'
  properties: {
    displayName: 'Universal LLM API'
    description: 'Gateway for Azure OpenAI and AI Foundry models - supports GPT, embedding, and other inference types'
    path: 'models'
    protocols: [
      'https'
    ]
    subscriptionRequired: true
    subscriptionKeyParameterNames: {
      header: 'api-key'
      query: 'api-key'
    }
  }
}

// Universal LLM API: Operation - GET /models/models (list available models)
resource apiUniversalLlmOpGetModels 'Microsoft.ApiManagement/service/apis/operations@2023-09-01-preview' = {
  parent: apiUniversalLlm
  name: 'get-models'
  properties: {
    displayName: 'List Available Models'
    method: 'GET'
    urlTemplate: '/models'
    description: 'Returns list of available model deployments'
  }
}

// Universal LLM API: Operation policy - GET /models/models
// Simplest possible policy: static JSON list of the 6 deployed models, no backend call
resource apiUniversalLlmOpGetModelsPolicy 'Microsoft.ApiManagement/service/apis/operations/policies@2023-09-01-preview' = {
  parent: apiUniversalLlmOpGetModels
  name: 'policy'
  properties: {
    format: 'xml'
    value: '<policies><inbound><base/><return-response><set-status code="200" reason="OK"/><set-header name="Content-Type" exists-action="override"><value>application/json</value></set-header><set-body>["gpt-4.1","gpt-5.4-mini","gpt-5.2","text-embedding-3-large","Mistral-Large-3","Phi-4"]</set-body></return-response></inbound><backend><base/></backend><outbound><base/></outbound><on-error><base/></on-error></policies>'
  }
}

// Universal LLM API: Operation - POST /models/chat/completions
resource apiUniversalLlmOpChatCompletions 'Microsoft.ApiManagement/service/apis/operations@2023-09-01-preview' = {
  parent: apiUniversalLlm
  name: 'post-chat-completions'
  properties: {
    displayName: 'Create Chat Completion'
    method: 'POST'
    urlTemplate: '/chat/completions'
    description: 'Generate chat completions using requested model'
  }
}

// Model-routing policy: read the requested "model" from the request body, validate it
// against the chat-capable models deployed to backend-hub-foundry, then route to that
// model's own deployment. Auth via APIM managed identity. No access-contract/token-limit/
// PII fragments are referenced here - those remain disabled.
resource apiUniversalLlmOpChatCompletionsPolicy 'Microsoft.ApiManagement/service/apis/operations/policies@2023-09-01-preview' = {
  parent: apiUniversalLlmOpChatCompletions
  name: 'policy'
  properties: {
    format: 'xml'
    value: '<policies><inbound><base/><authentication-managed-identity resource="https://cognitiveservices.azure.com" client-id="{{Hub.Foundry.UAMI.Client.ID}}" output-token-variable-name="msi-access-token" ignore-error="false"/><set-header name="Authorization" exists-action="override"><value>@("Bearer " + (string)context.Variables["msi-access-token"])</value></set-header><set-variable name="requestedModel" value="@{var body = context.Request.Body?.As&lt;JObject&gt;(preserveContent: true); string m = body != null ? (string)body[&quot;model&quot;] : null; return string.IsNullOrEmpty(m) ? &quot;gpt-4.1&quot; : m;}"/><choose><when condition="@{string[] allowed = new string[] {&quot;gpt-4.1&quot;,&quot;gpt-5.4-mini&quot;,&quot;gpt-5.2&quot;,&quot;Mistral-Large-3&quot;,&quot;Phi-4&quot;}; string requested = (string)context.Variables[&quot;requestedModel&quot;]; return !allowed.Contains(requested);}"><return-response><set-status code="400" reason="Bad Request"/><set-header name="Content-Type" exists-action="override"><value>application/json</value></set-header><set-body>@{return new JObject(new JProperty("error","unsupported model requested for chat completions"),new JProperty("requestedModel",(string)context.Variables["requestedModel"])).ToString();}</set-body></return-response></when></choose><set-variable name="deploymentName" value="@(((string)context.Variables[&quot;requestedModel&quot;]).Replace(&quot;.&quot;, &quot;-&quot;))"/><set-backend-service backend-id="backend-hub-foundry"/><rewrite-uri template="@(&quot;/openai/deployments/&quot; + (string)context.Variables[&quot;deploymentName&quot;] + &quot;/chat/completions?api-version=2024-10-21&quot;)"/></inbound><backend><base/></backend><outbound><base/></outbound><on-error><base/></on-error></policies>'
  }
  dependsOn: [
    apimNamedValueUamiClientId
    apimBackendHubFoundry
  ]
}

// Universal LLM API: Operation - POST /models/embeddings
resource apiUniversalLlmOpEmbeddings 'Microsoft.ApiManagement/service/apis/operations@2023-09-01-preview' = {
  parent: apiUniversalLlm
  name: 'post-embeddings'
  properties: {
    displayName: 'Create Embeddings'
    method: 'POST'
    urlTemplate: '/embeddings'
    description: 'Generate embeddings using text-embedding-3-large'
  }
}

// Embeddings policy: same shape as chat-completions, but only one embedding model is
// deployed (text-embedding-3-large), so routing is a straight validate-then-route.
resource apiUniversalLlmOpEmbeddingsPolicy 'Microsoft.ApiManagement/service/apis/operations/policies@2023-09-01-preview' = {
  parent: apiUniversalLlmOpEmbeddings
  name: 'policy'
  properties: {
    format: 'xml'
    value: '<policies><inbound><base/><authentication-managed-identity resource="https://cognitiveservices.azure.com" client-id="{{Hub.Foundry.UAMI.Client.ID}}" output-token-variable-name="msi-access-token" ignore-error="false"/><set-header name="Authorization" exists-action="override"><value>@("Bearer " + (string)context.Variables["msi-access-token"])</value></set-header><set-variable name="requestedModel" value="@{var body = context.Request.Body?.As&lt;JObject&gt;(preserveContent: true); string m = body != null ? (string)body[&quot;model&quot;] : null; return string.IsNullOrEmpty(m) ? &quot;text-embedding-3-large&quot; : m;}"/><choose><when condition="@{return (string)context.Variables[&quot;requestedModel&quot;] != &quot;text-embedding-3-large&quot;;}"><return-response><set-status code="400" reason="Bad Request"/><set-header name="Content-Type" exists-action="override"><value>application/json</value></set-header><set-body>@{return new JObject(new JProperty("error","unsupported model requested for embeddings"),new JProperty("requestedModel",(string)context.Variables["requestedModel"])).ToString();}</set-body></return-response></when></choose><set-backend-service backend-id="backend-hub-foundry"/><rewrite-uri template="/openai/deployments/text-embedding-3-large/embeddings?api-version=2024-10-21"/></inbound><backend><base/></backend><outbound><base/></outbound><on-error><base/></on-error></policies>'
  }
  dependsOn: [
    apimNamedValueUamiClientId
    apimBackendHubFoundry
  ]
}

// Universal LLM API: Operation - POST /models/responses (response tracking)
resource apiUniversalLlmOpPostResponses 'Microsoft.ApiManagement/service/apis/operations@2023-09-01-preview' = {
  parent: apiUniversalLlm
  name: 'post-responses'
  properties: {
    displayName: 'Record LLM Response'
    method: 'POST'
    urlTemplate: '/responses'
    description: 'Log LLM response for audit trail'
  }
}

// Universal LLM API: Operation - GET /models/responses/{response_id}
resource apiUniversalLlmOpGetResponse 'Microsoft.ApiManagement/service/apis/operations@2023-09-01-preview' = {
  parent: apiUniversalLlm
  name: 'get-response'
  properties: {
    displayName: 'Get Response'
    method: 'GET'
    urlTemplate: '/responses/{response_id}'
    templateParameters: [
      {
        name: 'response_id'
        required: true
        type: 'string'
        description: 'Response UUID'
      }
    ]
    description: 'Retrieve stored LLM response'
  }
}

// Universal LLM API: Operation - GET /models/responses/{response_id}/input_items
resource apiUniversalLlmOpGetResponseInputItems 'Microsoft.ApiManagement/service/apis/operations@2023-09-01-preview' = {
  parent: apiUniversalLlm
  name: 'get-response-input-items'
  properties: {
    displayName: 'Get Response Input Items'
    method: 'GET'
    urlTemplate: '/responses/{response_id}/input_items'
    templateParameters: [
      {
        name: 'response_id'
        required: true
        type: 'string'
        description: 'Response UUID'
      }
    ]
    description: 'Retrieve input items for stored response'
  }
}

// ===== Phase 4: APIM API - Unified AI API =====
// Multi-backend routing API for OpenAI, Foundry, Gemini formats
resource apiUnifiedAi 'Microsoft.ApiManagement/service/apis@2023-09-01-preview' = {
  parent: apim
  name: 'unified-ai-api'
  properties: {
    displayName: 'Unified AI API'
    description: 'Multi-backend routing for Azure OpenAI, AI Foundry, and Gemini (Notebook 6 support)'
    path: 'unified-ai'
    protocols: [
      'https'
    ]
    subscriptionRequired: true
    subscriptionKeyParameterNames: {
      header: 'api-key'
      query: 'api-key'
    }
  }
}

// Unified AI API: Operation - GET /unified-ai/deployments
resource apiUnifiedAiOpGetDeployments 'Microsoft.ApiManagement/service/apis/operations@2023-09-01-preview' = {
  parent: apiUnifiedAi
  name: 'get-deployments'
  properties: {
    displayName: 'List Deployments'
    method: 'GET'
    urlTemplate: '/deployments'
    description: 'Returns available deployments across backends'
  }
}

// Unified AI API: Operation - GET /unified-ai/deployments/{model_name}
resource apiUnifiedAiOpGetDeployment 'Microsoft.ApiManagement/service/apis/operations@2023-09-01-preview' = {
  parent: apiUnifiedAi
  name: 'get-deployment'
  properties: {
    displayName: 'Get Deployment Details'
    method: 'GET'
    urlTemplate: '/deployments/{model_name}'
    templateParameters: [
      {
        name: 'model_name'
        required: true
        type: 'string'
        description: 'Model deployment name'
      }
    ]
    description: 'Get details for specific deployment'
  }
}

// Unified AI API: Operation - POST /unified-ai/openai/deployments/{model}/chat/completions
resource apiUnifiedAiOpOpenAiCompletions 'Microsoft.ApiManagement/service/apis/operations@2023-09-01-preview' = {
  parent: apiUnifiedAi
  name: 'post-openai-chat-completions'
  properties: {
    displayName: 'OpenAI Chat Completions'
    method: 'POST'
    urlTemplate: '/openai/deployments/{model}/chat/completions'
    templateParameters: [
      {
        name: 'model'
        required: true
        type: 'string'
        description: 'Model deployment name (gpt-5.2, Mistral-Large-3, etc.)'
      }
    ]
    description: 'Create chat completions in OpenAI format'
  }
}

// Unified AI API: Operation - POST /unified-ai/models/chat/completions
resource apiUnifiedAiOpFoundryCompletions 'Microsoft.ApiManagement/service/apis/operations@2023-09-01-preview' = {
  parent: apiUnifiedAi
  name: 'post-foundry-chat-completions'
  properties: {
    displayName: 'Foundry Inference API Chat Completions'
    method: 'POST'
    urlTemplate: '/models/chat/completions'
    description: 'Create chat completions in AI Foundry inference format'
  }
}

// Unified AI API: Operation - POST /unified-ai/v1beta/openai/chat/completions (Gemini optional)
resource apiUnifiedAiOpGeminiCompletions 'Microsoft.ApiManagement/service/apis/operations@2023-09-01-preview' = {
  parent: apiUnifiedAi
  name: 'post-gemini-chat-completions'
  properties: {
    displayName: 'Gemini Chat Completions (Optional)'
    method: 'POST'
    urlTemplate: '/v1beta/openai/chat/completions'
    description: 'Create chat completions using Google Gemini (optional, deferred to Phase 5)'
  }
}

// ===== Phase 4: APIM Products (Access Contracts) =====
// Product 1: LLM-Sales-Assistant-DEV
resource productSalesAssistant 'Microsoft.ApiManagement/service/products@2023-09-01-preview' = {
  parent: apim
  name: 'llm-sales-assistant-dev'
  properties: {
    displayName: 'LLM-Sales-Assistant-DEV'
    description: 'Access contract for Sales Assistant use case - Chat + embedding models (Notebook 3)'
    state: 'published'
    subscriptionRequired: true
    approvalRequired: false
    terms: 'Access to gpt-4.1, gpt-5.4-mini, text-embedding-3-large at 3000 TPM'
  }
}

// Product 1: Add APIs
resource productSalesAssistantApiUniversal 'Microsoft.ApiManagement/service/products/apis@2023-09-01-preview' = {
  parent: productSalesAssistant
  name: 'universal-llm-api'
  properties: {}
}

// Product 2: LLM-HR-ChatAgent-DEV
resource productHrChatAgent 'Microsoft.ApiManagement/service/products@2023-09-01-preview' = {
  parent: apim
  name: 'llm-hr-chatagent-dev'
  properties: {
    displayName: 'LLM-HR-ChatAgent-DEV'
    description: 'Access contract for HR ChatAgent - High throughput agent use case (Notebooks 3, 4, 8, 9)'
    state: 'published'
    subscriptionRequired: true
    approvalRequired: false
    terms: 'Access to gpt-4.1, gpt-5.4-mini at 5000 TPM with 500K monthly quota'
  }
}

// Product 2: Add APIs
resource productHrChatAgentApiUniversal 'Microsoft.ApiManagement/service/products/apis@2023-09-01-preview' = {
  parent: productHrChatAgent
  name: 'universal-llm-api'
  properties: {}
}

// Product 3: LLM-Support-Bot-DEV
resource productSupportBot 'Microsoft.ApiManagement/service/products@2023-09-01-preview' = {
  parent: apim
  name: 'llm-support-bot-dev'
  properties: {
    displayName: 'LLM-Support-Bot-DEV'
    description: 'Access contract for Support Bot - Alternative models with daily quota (Notebook 3)'
    state: 'published'
    subscriptionRequired: true
    approvalRequired: false
    terms: 'Access to gpt-4.1, Mistral-Large-3 at 2000 TPM with 50K daily quota'
  }
}

// Product 3: Add APIs
resource productSupportBotApiUniversal 'Microsoft.ApiManagement/service/products/apis@2023-09-01-preview' = {
  parent: productSupportBot
  name: 'universal-llm-api'
  properties: {}
}

// Product 4: LLM-Testing-UniversalLLMAllModels-DEV (Notebook 2 - all models)
resource productUniversalLlmTest 'Microsoft.ApiManagement/service/products@2023-09-01-preview' = {
  parent: apim
  name: 'llm-testing-universalllm-dev'
  properties: {
    displayName: 'LLM-Testing-UniversalLLMAllModels-DEV'
    description: 'Test product with access to all deployed models (Notebook 2)'
    state: 'published'
    subscriptionRequired: true
    approvalRequired: false
    terms: 'Unrestricted access to all deployed models for testing'
  }
}

// Product 4: Add APIs
resource productUniversalLlmTestApiUniversal 'Microsoft.ApiManagement/service/products/apis@2023-09-01-preview' = {
  parent: productUniversalLlmTest
  name: 'universal-llm-api'
  properties: {}
}

// Product 5: LLM-Testing-UnifiedAI-DEV (Notebook 6 - multi-backend)
resource productUnifiedAiTest 'Microsoft.ApiManagement/service/products@2023-09-01-preview' = {
  parent: apim
  name: 'llm-testing-unifiedai-dev'
  properties: {
    displayName: 'LLM-Testing-UnifiedAI-DEV'
    description: 'Test product for unified AI multi-backend routing (Notebook 6)'
    state: 'published'
    subscriptionRequired: true
    approvalRequired: false
    terms: 'Access to gpt-5.2 and Mistral-Large-3 via multi-backend routing'
  }
}

// Product 5: Add APIs
resource productUnifiedAiTestApiUnified 'Microsoft.ApiManagement/service/products/apis@2023-09-01-preview' = {
  parent: productUnifiedAiTest
  name: 'unified-ai-api'
  properties: {}
}

// Product 6: LLM-HR-PIIMasking-DEV (Notebook 5 - PII masking)
resource productHrPiiMasking 'Microsoft.ApiManagement/service/products@2023-09-01-preview' = {
  parent: apim
  name: 'llm-hr-piimasking-dev'
  properties: {
    displayName: 'LLM-HR-PIIMasking-DEV'
    description: 'PII masking and deanonymization (Notebook 5 - core feature)'
    state: 'published'
    subscriptionRequired: true
    approvalRequired: false
    terms: 'PII processing with anonymization/deanonymization for HR use case'
  }
}

// Product 6: Add APIs
resource productHrPiiMaskingApiUniversal 'Microsoft.ApiManagement/service/products/apis@2023-09-01-preview' = {
  parent: productHrPiiMasking
  name: 'universal-llm-api'
  properties: {}
}

// Product 7: LLM-Compliance-PIIBlocking-DEV (Notebook 5 - PII blocking)
resource productCompliancePiiBlocking 'Microsoft.ApiManagement/service/products@2023-09-01-preview' = {
  parent: apim
  name: 'llm-compliance-piiblocking-dev'
  properties: {
    displayName: 'LLM-Compliance-PIIBlocking-DEV'
    description: 'PII detection and blocking policy (Notebook 5 - compliance feature)'
    state: 'published'
    subscriptionRequired: true
    approvalRequired: false
    terms: 'Detects and blocks PII patterns in requests/responses'
  }
}

// Product 7: Add APIs
resource productCompliancePiiBlockingApiUniversal 'Microsoft.ApiManagement/service/products/apis@2023-09-01-preview' = {
  parent: productCompliancePiiBlocking
  name: 'universal-llm-api'
  properties: {}
}

// Product 8: LLM-HR-PIIAnalytics-DEV (Notebook 5 - PII analytics)
resource productHrPiiAnalytics 'Microsoft.ApiManagement/service/products@2023-09-01-preview' = {
  parent: apim
  name: 'llm-hr-piianalytics-dev'
  properties: {
    displayName: 'LLM-HR-PIIAnalytics-DEV'
    description: 'PII analytics and telemetry (Notebook 5 - observability)'
    state: 'published'
    subscriptionRequired: true
    approvalRequired: false
    terms: 'Tracks PII events to Cosmos DB pii-usage-container'
  }
}

// Product 8: Add APIs
resource productHrPiiAnalyticsApiUniversal 'Microsoft.ApiManagement/service/products/apis@2023-09-01-preview' = {
  parent: productHrPiiAnalytics
  name: 'universal-llm-api'
  properties: {}
}

// ===== Phase 4: APIM Subscriptions (API Keys per Product) =====
// Each subscription provides subscription-key auth for its product

// Subscription for LLM-Sales-Assistant-DEV
resource subscriptionSalesAssistant 'Microsoft.ApiManagement/service/subscriptions@2023-09-01-preview' = {
  parent: apim
  name: 'llm-sales-assistant-dev-sub-01'
  properties: {
    scope: productSalesAssistant.id
    displayName: 'LLM-Sales-Assistant-DEV-SUB-01'
    state: 'active'
    allowTracing: true
  }
}

// Subscription for LLM-HR-ChatAgent-DEV
resource subscriptionHrChatAgent 'Microsoft.ApiManagement/service/subscriptions@2023-09-01-preview' = {
  parent: apim
  name: 'llm-hr-chatagent-dev-sub-01'
  properties: {
    scope: productHrChatAgent.id
    displayName: 'LLM-HR-ChatAgent-DEV-SUB-01'
    state: 'active'
    allowTracing: true
  }
}

// Subscription for LLM-Support-Bot-DEV
resource subscriptionSupportBot 'Microsoft.ApiManagement/service/subscriptions@2023-09-01-preview' = {
  parent: apim
  name: 'llm-support-bot-dev-sub-01'
  properties: {
    scope: productSupportBot.id
    displayName: 'LLM-Support-Bot-DEV-SUB-01'
    state: 'active'
    allowTracing: true
  }
}

// Subscription for LLM-Testing-UniversalLLMAllModels-DEV
resource subscriptionUniversalLlmTest 'Microsoft.ApiManagement/service/subscriptions@2023-09-01-preview' = {
  parent: apim
  name: 'llm-testing-universalllm-dev-sub-01'
  properties: {
    scope: productUniversalLlmTest.id
    displayName: 'LLM-Testing-UniversalLLMAllModels-DEV-SUB-01'
    state: 'active'
    allowTracing: true
  }
}

// Subscription for LLM-Testing-UnifiedAI-DEV
resource subscriptionUnifiedAiTest 'Microsoft.ApiManagement/service/subscriptions@2023-09-01-preview' = {
  parent: apim
  name: 'llm-testing-unifiedai-dev-sub-01'
  properties: {
    scope: productUnifiedAiTest.id
    displayName: 'LLM-Testing-UnifiedAI-DEV-SUB-01'
    state: 'active'
    allowTracing: true
  }
}

// Subscription for LLM-HR-PIIMasking-DEV
resource subscriptionHrPiiMasking 'Microsoft.ApiManagement/service/subscriptions@2023-09-01-preview' = {
  parent: apim
  name: 'llm-hr-piimasking-dev-sub-01'
  properties: {
    scope: productHrPiiMasking.id
    displayName: 'LLM-HR-PIIMasking-DEV-SUB-01'
    state: 'active'
    allowTracing: true
  }
}

// Subscription for LLM-Compliance-PIIBlocking-DEV
resource subscriptionCompliancePiiBlocking 'Microsoft.ApiManagement/service/subscriptions@2023-09-01-preview' = {
  parent: apim
  name: 'llm-compliance-piiblocking-dev-sub-01'
  properties: {
    scope: productCompliancePiiBlocking.id
    displayName: 'LLM-Compliance-PIIBlocking-DEV-SUB-01'
    state: 'active'
    allowTracing: true
  }
}

// Subscription for LLM-HR-PIIAnalytics-DEV
resource subscriptionHrPiiAnalytics 'Microsoft.ApiManagement/service/subscriptions@2023-09-01-preview' = {
  parent: apim
  name: 'llm-hr-piianalytics-dev-sub-01'
  properties: {
    scope: productHrPiiAnalytics.id
    displayName: 'LLM-HR-PIIAnalytics-DEV-SUB-01'
    state: 'active'
    allowTracing: true
  }
}

// ===== Hub: Event Hub Namespace =====
resource eventHubNamespace_resource 'Microsoft.EventHub/namespaces@2022-10-01-preview' = {
  name: eventHubNamespace
  location: location
  tags: tags
  sku: {
    name: 'Basic'
    capacity: 1
  }
  properties: {
    minimumTlsVersion: '1.2'
    publicNetworkAccess: 'Enabled'
    kafkaEnabled: false
  }
}

// ===== Hub: Event Hub =====
resource eventHub 'Microsoft.EventHub/namespaces/eventhubs@2022-10-01-preview' = {
  parent: eventHubNamespace_resource
  name: eventHubName
  properties: {
    messageRetentionInDays: 1
    partitionCount: 1
  }
}

// ===== Hub: Storage Account for Logic App =====
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  tags: tags
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    minimumTlsVersion: 'TLS1_2'
    publicNetworkAccess: 'Enabled'
  }
}

// ===== Hub: API Management =====
resource apim 'Microsoft.ApiManagement/service@2023-09-01-preview' = {
  name: apimName
  location: location
  tags: tags
  sku: {
    name: 'StandardV2'
    capacity: 1
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${apimMI.id}': {}
    }
  }
  properties: {
    publisherEmail: 'governance@citadel.ai'
    publisherName: 'Citadel Governance'
    virtualNetworkType: 'None'
    publicNetworkAccess: 'Enabled'
  }
}

// ===== Hub: APIM Logger (Application Insights) =====
resource apimLoggerAppInsights 'Microsoft.ApiManagement/service/loggers@2023-09-01-preview' = {
  parent: apim
  name: 'appinsights-logger'
  properties: {
    loggerType: 'applicationInsights'
    resourceId: aiHub.id
    credentials: {
      instrumentationKey: aiHub.properties.InstrumentationKey
    }
    isBuffered: true
  }
}

// ===== Spoke: Azure AI Foundry Account (AIServices) =====
resource spokeFoundryAccount 'Microsoft.CognitiveServices/accounts@2025-04-01-preview' = {
  name: spokeFoundryAccountName
  location: location
  kind: 'AIServices'
  tags: tags
  sku: {
    name: 'S0'
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    customSubDomainName: spokeFoundryAccountName
    publicNetworkAccess: 'Enabled'
    allowProjectManagement: true
  }
}

// ===== Spoke: Foundry Project =====
resource spokeFoundryProject 'Microsoft.CognitiveServices/accounts/projects@2025-04-01-preview' = {
  parent: spokeFoundryAccount
  name: spokeFoundryProjectName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    description: 'Citadel Agentic Governance - Attendee agent development environment'
  }
}

// ===== Spoke: Observability (Log Analytics + Application Insights) =====
resource laSpoke 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: spokeLaName
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

resource aiSpoke 'Microsoft.Insights/components@2020-02-02' = {
  name: spokeAiName
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: laSpoke.id
  }
}

// ===== Spoke: Key Vault =====
resource kvSpoke 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: spokeKeyVaultName
  location: location
  tags: tags
  properties: {
    tenantId: subscription().tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    enableRbacAuthorization: true
    publicNetworkAccess: 'Enabled'
  }
}

// ===== Spoke: Azure Container Registry =====
resource acrSpoke 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: replace(spokeAcrName, '-', '')
  location: location
  tags: tags
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: true
    publicNetworkAccess: 'Enabled'
  }
}

// ===== Connect App Insights to Hub Foundry for Agent Tracing =====
resource hubFoundryAppInsightsConnection 'Microsoft.CognitiveServices/accounts/connections@2025-04-01-preview' = {
  parent: hubFoundryAccount
  name: '${hubFoundryAccountName}-appinsights'
  properties: {
    category: 'AppInsights'
    target: aiHub.id
    authType: 'ApiKey'
    isSharedToAll: true
    credentials: {
      key: reference(aiHub.id, '2020-02-02').InstrumentationKey
    }
    metadata: {
      ApiType: 'Azure'
      ResourceId: aiHub.id
    }
  }
}

// ===== Connect App Insights to Spoke Foundry for Agent Tracing =====
resource spokeFoundryAppInsightsConnection 'Microsoft.CognitiveServices/accounts/connections@2025-04-01-preview' = {
  parent: spokeFoundryAccount
  name: '${spokeFoundryAccountName}-appinsights'
  properties: {
    category: 'AppInsights'
    target: aiSpoke.id
    authType: 'ApiKey'
    isSharedToAll: true
    credentials: {
      key: reference(aiSpoke.id, '2020-02-02').InstrumentationKey
    }
    metadata: {
      ApiType: 'Azure'
      ResourceId: aiSpoke.id
    }
  }
}

// ===== Outputs (returned to deploy-lab.ps1 for HackboxCredential) =====

output HUB_FOUNDRY_PROJECT_ENDPOINT string = 'https://${hubFoundryAccountName}.services.ai.azure.com/api/projects/${hubFoundryProjectName}'
output SPOKE_FOUNDRY_PROJECT_ENDPOINT string = 'https://${spokeFoundryAccountName}.services.ai.azure.com/api/projects/${spokeFoundryProjectName}'

output APIM_GATEWAY_URL string = 'https://${apim.name}.azure-api.net'

// Phase 4: Subscription keys for products (for HackboxCredential distribution to notebooks)
output SALES_ASSISTANT_SUBSCRIPTION_KEY string = listSecrets(subscriptionSalesAssistant.id, '2023-09-01-preview').primaryKey
output SALES_ASSISTANT_SUBSCRIPTION_ID string = subscriptionSalesAssistant.name

output HR_CHATAGENT_SUBSCRIPTION_KEY string = listSecrets(subscriptionHrChatAgent.id, '2023-09-01-preview').primaryKey
output HR_CHATAGENT_SUBSCRIPTION_ID string = subscriptionHrChatAgent.name

output SUPPORT_BOT_SUBSCRIPTION_KEY string = listSecrets(subscriptionSupportBot.id, '2023-09-01-preview').primaryKey
output SUPPORT_BOT_SUBSCRIPTION_ID string = subscriptionSupportBot.name

output UNIVERSAL_LLM_TEST_SUBSCRIPTION_KEY string = listSecrets(subscriptionUniversalLlmTest.id, '2023-09-01-preview').primaryKey
output UNIVERSAL_LLM_TEST_SUBSCRIPTION_ID string = subscriptionUniversalLlmTest.name

output UNIFIED_AI_TEST_SUBSCRIPTION_KEY string = listSecrets(subscriptionUnifiedAiTest.id, '2023-09-01-preview').primaryKey
output UNIFIED_AI_TEST_SUBSCRIPTION_ID string = subscriptionUnifiedAiTest.name

output PII_MASKING_SUBSCRIPTION_KEY string = listSecrets(subscriptionHrPiiMasking.id, '2023-09-01-preview').primaryKey
output PII_MASKING_SUBSCRIPTION_ID string = subscriptionHrPiiMasking.name

output PII_BLOCKING_SUBSCRIPTION_KEY string = listSecrets(subscriptionCompliancePiiBlocking.id, '2023-09-01-preview').primaryKey
output PII_BLOCKING_SUBSCRIPTION_ID string = subscriptionCompliancePiiBlocking.name

output PII_ANALYTICS_SUBSCRIPTION_KEY string = listSecrets(subscriptionHrPiiAnalytics.id, '2023-09-01-preview').primaryKey
output PII_ANALYTICS_SUBSCRIPTION_ID string = subscriptionHrPiiAnalytics.name

// Phase 4: LLM Backend Config (JSON array for Notebook 1 dynamic discovery)
output LLM_BACKEND_CONFIG string = base64(string([
  {
    name: 'gpt-4.1'
    publisher: 'Azure OpenAI'
    endpoint: 'https://${hubFoundryAccountName}.openai.azure.com'
    models: [ 'gpt-4.1' ]
  }
  {
    name: 'gpt-5.4-mini'
    publisher: 'Azure OpenAI'
    endpoint: 'https://${hubFoundryAccountName}.openai.azure.com'
    models: [ 'gpt-5.4-mini' ]
  }
  {
    name: 'gpt-5.2'
    publisher: 'Azure OpenAI'
    endpoint: 'https://${hubFoundryAccountName}.openai.azure.com'
    models: [ 'gpt-5.2' ]
  }
  {
    name: 'text-embedding-3-large'
    publisher: 'Azure OpenAI'
    endpoint: 'https://${hubFoundryAccountName}.openai.azure.com'
    models: [ 'text-embedding-3-large' ]
  }
  {
    name: 'Mistral-Large-3'
    publisher: 'Azure OpenAI'
    endpoint: 'https://${hubFoundryAccountName}.openai.azure.com'
    models: [ 'Mistral-Large-3' ]
  }
  {
    name: 'Phi-4'
    publisher: 'Azure OpenAI'
    endpoint: 'https://${hubFoundryAccountName}.openai.azure.com'
    models: [ 'Phi-4' ]
  }
]))

output COSMOS_ENDPOINT string = cosmosAccount.properties.documentEndpoint
output COSMOS_DATABASE string = cosmosDatabaseName

output KEY_VAULT_URL string = kvHub.properties.vaultUri
output KEY_VAULT_NAME string = kvHub.name

output LOG_ANALYTICS_WORKSPACE_ID string = laHub.properties.customerId
output LOG_ANALYTICS_WORKSPACE_NAME string = laHub.name
output LOG_ANALYTICS_WORKSPACE_RESOURCE_ID string = laHub.id

output APPLICATIONINSIGHTS_CONNECTION_STRING string = aiHub.properties.ConnectionString
output APPLICATIONINSIGHTS_INSTRUMENTATION_KEY string = reference(aiHub.id, '2020-02-02').InstrumentationKey

output SPOKE_LOG_ANALYTICS_WORKSPACE_ID string = laSpoke.properties.customerId
output SPOKE_LOG_ANALYTICS_WORKSPACE_NAME string = laSpoke.name

output SPOKE_APP_INSIGHTS_CONNECTION_STRING string = aiSpoke.properties.ConnectionString

output EVENT_HUB_NAMESPACE string = eventHubNamespace_resource.name
output EVENT_HUB_CONNECTION_STRING string = listKeys('${eventHubNamespace_resource.id}/AuthorizationRules/RootManageSharedAccessKey', eventHubNamespace_resource.apiVersion).primaryConnectionString

output STORAGE_ACCOUNT_NAME string = storageAccount.name
output STORAGE_ACCOUNT_CONNECTION_STRING string = 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${listKeys(storageAccount.id, storageAccount.apiVersion).keys[0].value};EndpointSuffix=core.windows.net'

output APIM_NAME string = apim.name
output APIM_IDENTITY_PRINCIPAL_ID string = apimMI.properties.principalId

output HUB_FOUNDRY_ACCOUNT_RESOURCE_ID string = hubFoundryAccount.id
output HUB_FOUNDRY_MANAGED_IDENTITY_PRINCIPAL_ID string = hubFoundryAccount.identity.principalId

output SPOKE_FOUNDRY_ACCOUNT_RESOURCE_ID string = spokeFoundryAccount.id
output SPOKE_FOUNDRY_MANAGED_IDENTITY_PRINCIPAL_ID string = spokeFoundryAccount.identity.principalId

// Phase 4: Spoke Foundry details for agent deployment (Notebook 4, 7)
output SPOKE_FOUNDRY_ACCOUNT_NAME string = spokeFoundryAccountName
output SPOKE_FOUNDRY_PROJECT_NAME string = spokeFoundryProjectName
output SPOKE_KEY_VAULT_NAME string = spokeKeyVaultName
output SPOKE_ACR_NAME string = spokeAcrName
output SPOKE_ACR_LOGIN_SERVER string = '${replace(spokeAcrName, '-', '')}.azurecr.io'

output RESOURCE_GROUP_NAME string = resourceGroup().name
output LOCATION string = location
