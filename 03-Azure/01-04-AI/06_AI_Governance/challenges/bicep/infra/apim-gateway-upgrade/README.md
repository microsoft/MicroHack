# APIM Gateway Upgrade

As the AI Governance Hub solution accelerator evolves, you may need to update the API Management gateway configuration to add new APIs, modify policies, or adjust logging settings. 

This deployment allows you to seamlessly apply updates to an existing APIM instance without needing to re-provision the entire service or associated infrastructure.

Notes:
- Update the configuration of an **existing** API Management instance without re-provisioning the APIM service or surrounding landing-zone infrastructure. 
- This deployment is designed to run **after** the main accelerator (`bicep/infra/main.bicep`) has provisioned the full environment.

## What this deployment updates

| Category | Resources Updated |
|---|---|
| **Policy Fragments** | All static fragments (auth, usage, throttling, PII, AI Foundry, Unified AI) and dynamic LLM fragments (backend pools, authorization, target routing, model access) |
| **APIs** | Universal LLM API, Azure OpenAI API, Unified AI Wildcard API, Azure AI Search API, OpenAI Realtime WebSocket API, Document Intelligence APIs — including OpenAPI specs, API-level policies, and operation-level policies |
| **LLM Backends** | Backend definitions, backend pools, and associated policy fragments for dynamic model routing |
| **Named Values** | UAMI client ID, Entra auth flag, client/tenant/audience, PII service URL/key, Content Safety URL, JWT authentication values (TenantId, AppRegistrationId, Issuer, OpenIdConfigUrl) |
| **Logging / Diagnostics** | APIM-level Application Insights diagnostic configuration and per-API Azure Monitor diagnostic configuration |
| **Redis Cache** | APIM cache entity backed by Azure Managed Redis (for semantic caching) |
| **Embeddings Backend** | APIM backend targeting AI Foundry embeddings endpoint (for semantic caching) |

>**NOTE**: It is very important depending on the gab between the newer gateway implementation and the existing one, try to make the initial run of this upgrade deployment with as many feature flags turned **on** as possible to ensure the APIM instance is fully updated, this will mean that backend routing configurations must be in place as well. Use this in non-production environment first to detect any potential issues before applying to production.

## What this deployment does NOT do

- Provision a new APIM service instance
- Create or modify loggers (Application Insights logger and Azure Monitor logger must already exist)
- Configure Event Hub loggers
- Publish to API Center
- Deploy sample MCP servers
- Modify networking, VNet, or private endpoint settings
- Create managed identities, Key Vaults, or other infrastructure
- Provision Azure Managed Redis (the Redis instance must already exist for cache updates)

## Prerequisites

1. The APIM service referenced by `apimServiceName` must already exist in the target resource group.
2. The user-assigned managed identity referenced by `managedIdentityName` must already exist in the same resource group.
3. The following APIM loggers must be pre-provisioned on the APIM instance:
   - `appinsights-logger` — Application Insights logger
   - `azuremonitor` — Azure Monitor logger
4. Azure CLI authenticated with permissions to deploy to the target resource group.

## Usage

### 1. Configure Parameters

Edit `main.bicepparam` to match your environment:

```bicep
param apimServiceName = 'my-apim-instance'
param managedIdentityName = 'my-apim-identity'
```

### 2. Toggle Feature Flags

Enable or disable individual configuration sections by setting the feature flag parameters to `true` or `false`:

```bicep
// Only update policies and logging, skip API definitions
param updatePolicyFragments = true
param updateUniversalLLMApi = false
param updateAzureOpenAIApi = false
param updateUnifiedAiApi = false
param updateAppInsightsDiagnostics = true
param updateNamedValues = false
param updateJwtNamedValues = false
```

### 3. Configure LLM Backends

Provide the LLM backend configuration array that matches your current environment:

```bicep
param llmBackendConfig = [
  {
    backendId: 'azure-openai-swedencentral'
    backendType: 'azure-openai'
    endpoint: 'https://my-openai.openai.azure.com'
    authScheme: 'managedIdentity'
    supportedModels: [
      { name: 'gpt-4o', sku: 'GlobalStandard', capacity: 100, modelFormat: 'OpenAI', modelVersion: '2024-08-06' }
    ]
    priority: 1
    weight: 100
  }
]
```

### 4. Deploy

Run the deployment scoped to the resource group containing the APIM instance:

```bash
az deployment group create --name gateway-upgrade-$(date +%Y%m%d%H%M) --resource-group <your-resource-group> --template-file main.bicep --parameters main.bicepparam
```

## When to use this

| Scenario | Use this deployment? |
|---|---|
| Updated API policies (routing logic, rate limiting, auth) | **Yes** |
| Changed LLM backend configuration (new models, endpoints) | **Yes** |
| Updated policy fragments (usage tracking, PII, throttling) | **Yes** |
| Tuning Application Insights or Azure Monitor log capture | **Yes** |
| Updating named values (audience, PII URL, Content Safety URL) | **Yes** |
| Adding a new LLM backend or model to existing pools | **Yes** |
| Updating JWT authentication configuration | **Yes** |
| Updating Unified AI Wildcard API | **Yes** |
| Updating Redis cache or embeddings backend config | **Yes** |
| Initial environment provisioning | No — use `bicep/infra/main.bicep` |
| Changing APIM SKU, networking, or VNet configuration | No — use `bicep/infra/main.bicep` |
| Adding Event Hub loggers | No — use `bicep/infra/main.bicep` |
| Publishing to API Center | No — use `bicep/infra/main.bicep` |

## Parameter Reference

### Core Parameters

| Parameter | Required | Description |
|---|---|---|
| `apimServiceName` | Yes | Name of the existing APIM instance |
| `managedIdentityName` | Yes | Name of the existing user-assigned managed identity |

### Feature Flags

| Parameter | Default | Description |
|---|---|---|
| `updatePolicyFragments` | `true` | Update static policy fragments |
| `updateUniversalLLMApi` | `true` | Update Universal LLM API spec and policy |
| `updateAzureOpenAIApi` | `true` | Update Azure OpenAI API spec and policy |
| `updateUnifiedAiApi` | `true` | Update Unified AI Wildcard API, product, and policy |
| `updateAzureAISearchApi` | `false` | Update Azure AI Search API spec and policy |
| `updateOpenAIRealtimeApi` | `false` | Update OpenAI Realtime WebSocket API |
| `updateDocumentIntelligenceApi` | `false` | Update Document Intelligence APIs |
| `updateAppInsightsDiagnostics` | `true` | Update APIM-level App Insights diagnostics |
| `updateNamedValues` | `true` | Update APIM named values |
| `updateJwtNamedValues` | `true` | Update JWT authentication named values |
| `updateLLMBackends` | `true` | Update LLM backend definitions |
| `updateLLMBackendPools` | `true` | Update LLM backend pools |
| `updateLLMPolicyFragments` | `true` | Update dynamic LLM policy fragments |
| `updateRedisCache` | `false` | Update APIM Redis cache entity |
| `updateEmbeddingsBackend` | `false` | Update APIM embeddings backend |

### Feature-Specific Parameters

| Parameter | Default | Description |
|---|---|---|
| `enablePIIAnonymization` | `true` | Enable PII anonymization policy fragments |
| `enableAIModelInference` | `true` | Enable AI model inference fragments |
| `entraAuth` | `false` | Use Entra ID auth (disables subscription keys) |
| `enableUnifiedAiApi` | `true` | Enable the Unified AI Wildcard API |
| `enableJwtAuth` | `false` | Enable JWT authentication named values and security-handler fragment |
| `jwtTenantId` | `''` | JWT Tenant ID (required when `enableJwtAuth` is true) |
| `jwtAppRegistrationId` | `''` | JWT App Registration Client ID (required when `enableJwtAuth` is true) |
| `enableRedisCache` | `false` | Enable APIM Redis cache entity (requires `redisCacheConnectionString`) |
| `enableEmbeddingsBackend` | `false` | Enable APIM embeddings backend (requires `embeddingsBackendUrl`) |

### Logging Settings

| Parameter | Description |
|---|---|
| `azureMonitorLogSettings` | Frontend/backend headers & body bytes, LLM log settings for Azure Monitor |
| `appInsightsLogSettings` | Headers to capture and body bytes for Application Insights |

## File structure

```
apim-gateway-upgrade/
├── main.bicep          # Deployment template (resource group scope)
├── main.bicepparam     # Parameter file — configure before deploying
└── README.md           # This guide
```

All API specs, policy XML files, and sub-modules are referenced from `../modules/apim/` — no duplication of policy or spec files.
