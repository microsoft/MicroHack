# 🚀 Citadel Backend Contract

## Overview

Automate the onboarding of LLM backends to your APIM-based AI Gateway with a streamlined, infrastructure-as-code approach using **Bicep parameter files** (`.bicepparam`).

This package enables dynamic LLM backend routing without modifying APIM policies:

- 📦 **Automatic Backend Creation**: Create APIM backends from configuration
- ⚖️ **Load Balancing**: Distribute requests across multiple backends for the same model
- 🔄 **Automatic Failover**: Route to healthy backends when others are unavailable
- 🔌 **Multi-Provider Support**: Microsoft Foundry, Azure OpenAI, Amazon Bedrock, and external LLM providers
- 📝 **Declarative Configuration**: Simple `.bicepparam` files for version control

## What Gets Created

| Resource | Description |
|----------|-------------|
| **APIM Backends** | Individual backend resources for each LLM endpoint |
| **Backend Pools** | Load-balanced pools for models with multiple backends |
| **Policy Fragments** | Dynamic routing logic for model-based routing |
| **Get Available Models Fragment** | Returns available model deployments with capabilities (similar to Azure Cognitive Services API) |
| **Metadata Config Fragment** | Centralized model routing config for the Unified AI API — always deployed with backend onboarding to stay in sync |

## Prerequisites

- Existing deployment of AI Citadel Governance Hub with:
  - User-assigned managed identity configured
  - APIs for Universal LLM API and Azure OpenAI API
- LLM backends deployed and accessible:
  - Microsoft Foundry with model deployments
  - Azure OpenAI resources with model deployments
  - Amazon Bedrock with foundation model access
  - APIM can reach the target backends from network perspective
- Verify APIM's user assigned managed identity has required roles:
   - `Cognitive Services OpenAI User` for Azure OpenAI
   - `Cognitive Services User` for Microsoft Foundry
- For Amazon Bedrock:
   - AWS IAM user with Bedrock access and access keys generated
   - Provide `awsAccessKey`, `awsSecretKey`, and `awsRegion` parameters when deploying — these are stored as secret APIM named values (`aws-access-key`, `aws-secret-key`, `aws-region`)
   - If these parameters are not provided, the named values are created with a `NOT_CONFIGURED` placeholder and the gateway returns a `500 AWSCredentialsNotConfigured` error at runtime when a Bedrock backend is invoked

## Quick Start

### 1. Copy the Parameter Template

```bash
cp main.bicepparam llm-backends-dev-local.bicepparam
```

### 2. Configure Your Backends

Edit `llm-backends-dev-local.bicepparam`:

```bicep
using 'main.bicep'

param apim = {
  subscriptionId: '00000000-0000-0000-0000-000000000000' // Replace with your subscription ID
  resourceGroupName: 'rg-citadel-governance-hub'         // Replace with your APIM resource group
  name: 'apim-citadel-governance-hub'                    // Replace with your APIM name
}

param apimManagedIdentity = {
  subscriptionId: '00000000-0000-0000-0000-000000000000' // Replace with your subscription ID
  resourceGroupName: 'rg-citadel-governance-hub'         // Replace with your identity resource group
  name: 'id-apim-citadel'                                // Replace with your managed identity name
}

param llmBackendConfig = [
  {
    backendId: 'aif-citadel-primary'
    backendType: 'ai-foundry'
    endpoint: 'https://aif-RESOURCE_TOKEN-0.cognitiveservices.azure.com/'
    authScheme: 'managedIdentity'
    supportedModels: [
      { "name": "gpt-4o-mini", "sku": "GlobalStandard", "capacity": 100, "modelFormat": "OpenAI", "modelVersion": "2024-07-18", "retirementDate": "2026-09-30" },
      { "name": "gpt-4o", "sku": "GlobalStandard", "capacity": 100, "modelFormat": "OpenAI", "modelVersion": "2024-11-20", "retirementDate": "2026-09-30" },
      { "name": "gpt-4.1", "sku": "GlobalStandard", "capacity": 100, "modelFormat": "OpenAI", "modelVersion": "2025-04-14", "retirementDate": "2026-10-14", "apiVersion": "2025-04-01-preview", "timeout": 180 },
      { "name": "DeepSeek-R1", "sku": "GlobalStandard", "capacity": 1, "modelFormat": "DeepSeek", "modelVersion": "1", "retirementDate": "2099-12-30", "inferenceApiVersion": "2024-05-01-preview" },
      { "name": "Phi-4", "sku": "GlobalStandard", "capacity": 1, "modelFormat": "Microsoft", "modelVersion": "3", "retirementDate": "2099-12-30", "inferenceApiVersion": "2024-05-01-preview" },
      { "name": "text-embedding-3-large", "sku": "GlobalStandard", "capacity": 100, "modelFormat": "OpenAI", "modelVersion": "1", "retirementDate": "2027-04-14" }
    ]
    priority: 1
    weight: 100
  }
]
```

### 3. Deploy

```bash
az deployment sub create --name llm-backend-onboarding --location swedencentral --template-file main.bicep --parameters llm-backends-generated-local.bicepparam
```

## Configuration Reference

### Backend Configuration Properties

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `backendId` | string | Yes | Unique identifier for the backend (usually the name of the backend resource) |
| `backendType` | string | Yes | `ai-foundry`, `azure-openai`, `aws-bedrock`, or `external` |
| `endpoint` | string | Yes | Base URL of the LLM service |
| `authScheme` | string | Yes | `managedIdentity`, `apiKey`, or `token` |
| `supportedModels` | array | Yes | Array of model objects (see Model Object Properties below) |
| `priority` | number | No | 1-5, default 1 (lower = higher priority) |
| `weight` | number | No | 1-1000, default 100 (load balancing weight) |

### Model Object Properties

Each model in the `supportedModels` array has these properties:

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `name` | string | Yes | Model name (e.g., `gpt-4o`, `DeepSeek-R1`, `Phi-4`) |
| `sku` | string | No | SKU name for the deployment (default: `Standard`). Used in `get-available-models` response |
| `capacity` | number | No | Capacity/TPM quota (default: 100). Used in `get-available-models` response |
| `modelFormat` | string | No | Model format identifier, e.g., `OpenAI`, `DeepSeek`, `Microsoft` (default: `OpenAI`). Used in `get-available-models` response |
| `modelVersion` | string | No | Version of the model (default: `1`). Used in `get-available-models` response |
| `retirementDate` | string (date) | No | Optional retirement date for the model. Used in `get-available-models` response |
| `apiVersion` | string | No | API version for OpenAI-type requests (default: `2024-02-15-preview`). Used by Unified AI API for backend routing |
| `timeout` | number | No | Request timeout in seconds (default: `120`). Used by Unified AI API for per-model timeout configuration |
| `inferenceApiVersion` | string | No | API version for inference-type requests (e.g., `2024-05-01-preview`). Used by Unified AI API for non-OpenAI models |

### Backend Types

#### AI Foundry (`ai-foundry`)
- Uses Azure AI Foundry project endpoints
- Endpoint format: `https://<resource>.cognitiveservices.azure.com/`
- Authentication: Managed identity with Cognitive Services scope
- No URL rewriting required

#### Azure OpenAI (`azure-openai`)
- Uses Azure OpenAI Service endpoints
- Endpoint format: `https://<resource>.openai.azure.com/`
- Authentication: Managed identity with Cognitive Services scope
- Automatic URL rewriting to include `/deployments/{model}/`

#### External (`external`)
- Uses external LLM provider endpoints
- Authentication: API key or backend credentials
- No URL rewriting

#### Amazon Bedrock (`aws-bedrock`)
- Uses Amazon Bedrock runtime endpoints
- Endpoint format: `https://bedrock-runtime.<aws-region>.amazonaws.com`
- Authentication: AWS Signature Version 4 (SigV4) using IAM access keys stored as APIM named values
- Path construction: `/model/{model-id}/converse`
- Requires additional parameters: `awsAccessKey`, `awsSecretKey`, `awsRegion`
- See [Microsoft Learn: Import Amazon Bedrock API](https://learn.microsoft.com/en-us/azure/api-management/amazon-bedrock-passthrough-llm-api) for detailed APIM integration guidance

## Example Configurations

### Single AI Foundry Backend

```bicep
param llmBackendConfig = [
  {
    backendId: 'aif-citadel-primary'
    backendType: 'ai-foundry'
    endpoint: 'https://aif-RESOURCE_TOKEN-0.cognitiveservices.azure.com/'
    authScheme: 'managedIdentity'
    supportedModels: [
      { "name": "gpt-4o-mini", "sku": "GlobalStandard", "capacity": 100, "modelFormat": "OpenAI", "modelVersion": "2024-07-18", "retirementDate": "2026-09-30" },
      { "name": "gpt-4o", "sku": "GlobalStandard", "capacity": 100, "modelFormat": "OpenAI", "modelVersion": "2024-11-20", "retirementDate": "2026-09-30" },
      { "name": "gpt-4.1", "sku": "GlobalStandard", "capacity": 100, "modelFormat": "OpenAI", "modelVersion": "2025-04-14", "retirementDate": "2026-10-14", "apiVersion": "2025-04-01-preview", "timeout": 180 },
      { "name": "DeepSeek-R1", "sku": "GlobalStandard", "capacity": 1, "modelFormat": "DeepSeek", "modelVersion": "1", "retirementDate": "2099-12-30", "inferenceApiVersion": "2024-05-01-preview" },
      { "name": "Phi-4", "sku": "GlobalStandard", "capacity": 1, "modelFormat": "Microsoft", "modelVersion": "3", "retirementDate": "2099-12-30", "inferenceApiVersion": "2024-05-01-preview" },
      { "name": "text-embedding-3-large", "sku": "GlobalStandard", "capacity": 100, "modelFormat": "OpenAI", "modelVersion": "1", "retirementDate": "2027-04-14" }
    ]
    priority: 1
    weight: 100
  }
]
```

### Load Balancing Across Regions

As `DeepSeek-R1` is available in 2 different backends, the onboarding script will automatically create a backend pool for `DeepSeek-R1` and distribute traffic based on the specified priority/weights.

```bicep
param llmBackendConfig = [
  {
    backendId: 'aif-citadel-primary'
    backendType: 'ai-foundry'
    endpoint: 'https://aif-RESOURCE_TOKEN-0.cognitiveservices.azure.com/'
    authScheme: 'managedIdentity'
    supportedModels: [
      { "name": "gpt-4o-mini", "sku": "GlobalStandard", "capacity": 100, "modelFormat": "OpenAI", "modelVersion": "2024-07-18", "retirementDate": "2026-09-30" },
      { "name": "gpt-4o", "sku": "GlobalStandard", "capacity": 100, "modelFormat": "OpenAI", "modelVersion": "2024-11-20", "retirementDate": "2026-09-30" },
      { "name": "gpt-4.1", "sku": "GlobalStandard", "capacity": 100, "modelFormat": "OpenAI", "modelVersion": "2025-04-14", "retirementDate": "2026-10-14", "apiVersion": "2025-04-01-preview", "timeout": 180 },
      { "name": "DeepSeek-R1", "sku": "GlobalStandard", "capacity": 1, "modelFormat": "DeepSeek", "modelVersion": "1", "retirementDate": "2099-12-30", "inferenceApiVersion": "2024-05-01-preview" },
      { "name": "Phi-4", "sku": "GlobalStandard", "capacity": 1, "modelFormat": "Microsoft", "modelVersion": "3", "retirementDate": "2099-12-30", "inferenceApiVersion": "2024-05-01-preview" },
      { "name": "text-embedding-3-large", "sku": "GlobalStandard", "capacity": 100, "modelFormat": "OpenAI", "modelVersion": "1", "retirementDate": "2027-04-14" }
    ]
    priority: 1
    weight: 100
  }
  {
    backendId: 'aif-citadel-secondary'
    backendType: 'ai-foundry'
    endpoint: 'https://aif-RESOURCE_TOKEN-1.cognitiveservices.azure.com/'
    authScheme: 'managedIdentity'
    supportedModels: [
      { "name": "gpt-5", "sku": "GlobalStandard", "capacity": 50, "modelFormat": "OpenAI", "modelVersion": "1", "retirementDate": "2027-02-05" },
      { "name": "DeepSeek-R1", "sku": "GlobalStandard", "capacity": 1, "modelFormat": "DeepSeek", "modelVersion": "1", "retirementDate": "2099-12-30", "inferenceApiVersion": "2024-05-01-preview" }
    ]
    priority: 2
    weight: 50
  }
]
```

### Mixed Providers

This is mixing Azure OpenAI and Microsoft Foundry backends. Common models across providers will be automatically load balanced (like `DeepSeek-R1` and `text-embedding-3-large` in the below example), while unique models will be routed to their specific backend.

```bicep
param llmBackendConfig = [
  {
    backendId: 'aif-citadel-primary'
    backendType: 'ai-foundry'
    endpoint: 'https://aif-RESOURCE_TOKEN-0.cognitiveservices.azure.com/'
    authScheme: 'managedIdentity'
    supportedModels: [
      { "name": "gpt-4o-mini", "sku": "GlobalStandard", "capacity": 100, "modelFormat": "OpenAI", "modelVersion": "2024-07-18", "retirementDate": "2026-09-30" },
      { "name": "gpt-4o", "sku": "GlobalStandard", "capacity": 100, "modelFormat": "OpenAI", "modelVersion": "2024-11-20", "retirementDate": "2026-09-30" },
      { "name": "gpt-4.1", "sku": "GlobalStandard", "capacity": 100, "modelFormat": "OpenAI", "modelVersion": "2025-04-14", "retirementDate": "2026-10-14", "apiVersion": "2025-04-01-preview", "timeout": 180 },
      { "name": "DeepSeek-R1", "sku": "GlobalStandard", "capacity": 1, "modelFormat": "DeepSeek", "modelVersion": "1", "retirementDate": "2099-12-30", "inferenceApiVersion": "2024-05-01-preview" },
      { "name": "Phi-4", "sku": "GlobalStandard", "capacity": 1, "modelFormat": "Microsoft", "modelVersion": "3", "retirementDate": "2099-12-30", "inferenceApiVersion": "2024-05-01-preview" },
      { "name": "text-embedding-3-large", "sku": "GlobalStandard", "capacity": 100, "modelFormat": "OpenAI", "modelVersion": "1", "retirementDate": "2027-04-14" }
    ]
    priority: 1
    weight: 100
  }
  {
    backendId: 'aoai-eastus-gpt4'
    backendType: 'azure-openai'
    endpoint: 'https://YOUR-AOAI-RESOURCE.openai.azure.com/'
    authScheme: 'managedIdentity'
    supportedModels: [
      { "name": "gpt-5", "sku": "GlobalStandard", "capacity": 100, "modelFormat": "OpenAI", "modelVersion": "2025-08-07", "retirementDate": "2027-02-05" },
      { "name": "DeepSeek-R1", "sku": "GlobalStandard", "capacity": 1, "modelFormat": "DeepSeek", "modelVersion": "1", "retirementDate": "2099-12-30", "inferenceApiVersion": "2024-05-01-preview" },
      { "name": "text-embedding-3-large", "sku": "GlobalStandard", "capacity": 100, "modelFormat": "OpenAI", "modelVersion": "1", "retirementDate": "2027-04-14" }
    ]
    priority: 1
    weight: 100
  }
]
```

### Amazon Bedrock Backend

This example adds an Amazon Bedrock backend alongside Azure backends. The `aws-bedrock` backend type uses AWS SigV4 authentication via IAM access keys stored as APIM named values.

```bicep
param llmBackendConfig = [
  {
    backendId: 'aif-citadel-primary'
    backendType: 'ai-foundry'
    endpoint: 'https://aif-RESOURCE_TOKEN-0.cognitiveservices.azure.com/'
    authScheme: 'managedIdentity'
    supportedModels: [
      { "name": "gpt-4o", "sku": "GlobalStandard", "capacity": 100, "modelFormat": "OpenAI", "modelVersion": "2024-11-20", "retirementDate": "2026-09-30" }
    ]
    priority: 1
    weight: 100
  }
  {
    backendId: 'bedrock-us-east-1'
    backendType: 'aws-bedrock'
    endpoint: 'https://bedrock-runtime.us-east-1.amazonaws.com'
    authScheme: 'awsSigV4'
    supportedModels: [
      { "name": "us.anthropic.claude-3-5-haiku-20241022-v1:0", "sku": "OnDemand", "capacity": 1, "modelFormat": "Anthropic", "modelVersion": "1", "retirementDate": "2099-12-30" }
      { "name": "us.anthropic.claude-3-5-sonnet-20241022-v2:0", "sku": "OnDemand", "capacity": 1, "modelFormat": "Anthropic", "modelVersion": "2", "retirementDate": "2099-12-30" }
      { "name": "us.amazon.nova-pro-v1:0", "sku": "OnDemand", "capacity": 1, "modelFormat": "Amazon", "modelVersion": "1", "retirementDate": "2099-12-30" }
    ]
    priority: 1
    weight: 100
  }
]

// AWS credentials for Bedrock authentication
param awsAccessKey = '<your-aws-access-key-id>'
param awsSecretKey = '<your-aws-secret-access-key>'
param awsRegion = 'us-east-1'
```

> **Important**: Store AWS access keys securely. Consider using Azure Key Vault references for the APIM named values in production. See [Create IAM user access keys](https://docs.aws.amazon.com/IAM/latest/UserGuide/access-key-self-managed.html#Using_CreateAccessKey) for generating AWS access keys.

## Request Flow

```
1. Client → APIM Gateway
   POST /models/chat/completions
   Body: { "model": "gpt-4o", "messages": [...] }

2. Extract Model
   → requestedModel = "gpt-4o"

3. Find Backend Pool
   → matches "gpt-4o-backend-pool" (load balanced)
   or direct backend if single provider

4. Authenticate
   → Get managed identity token
   → Set Authorization header

5. Route to Backend
   → Forward to healthy backend in pool

6. Return Response
   → Client receives response with usage headers
```

## Get Available Models API

The `get-available-models` policy fragment enables an API endpoint that returns all available model deployments with their capabilities, similar to the Azure Cognitive Services deployment list API.

This policy fragment is designed to support Microsoft Foundry integration with Citadel Governance Hub, allowing clients to query available models dynamically from Foundry portal experience.

>NOTE: This policy fragment is included in the `/deployments` get operation of the Universal LLM API by default. Currently this Microsoft Foundry feature is in `preview` and may change in future releases.

### Usage

Include the policy fragment in any API operation to return available models:

```xml
<inbound>
    <include-fragment fragment-id="get-available-models" />
</inbound>
```

### Response Format

```json
{
    "value": [
        {
            "id": "aif-citadel-primary",
            "type": "ai-foundry",
            "name": "gpt-4o",
            "sku": { "name": "GlobalStandard", "capacity": 100 },
            "properties": {
                "model": { "format": "OpenAI", "name": "gpt-4o", "version": "2024-11-20" },
                "capabilities": { "chatCompletion": "true" },
                "provisioningState": "Succeeded"
            }
        },
        {
            "id": "aif-citadel-primary",
            "type": "ai-foundry",
            "name": "gpt-4o-mini",
            "sku": { "name": "GlobalStandard", "capacity": 100 },
            "properties": {
                "model": { "format": "OpenAI", "name": "gpt-4o-mini", "version": "2024-11-20" },
                "capabilities": { "chatCompletion": "true" },
                "provisioningState": "Succeeded"
            }
        }
    ]
}
```

The response is dynamically generated based on the `llmBackendConfig` parameter, using the optional metadata fields (`sku`, `capacity`, `modelFormat`, `modelVersion`).

## Monitoring

### Key Metrics

Connected Application Insights to APIM provides insights into backend performance:

| Metric | Description |
|--------|-------------|
| Application Map | Visual representation of dependencies performance |
| Performance | For both operations and dependencies |
| Failures | Failures by backend |
| Latency | Response time per backend |

### Application Insights Query

```kusto
// this query calculates LLM backend duration percentiles and count by target
let start=ago(24h);
let end=now();
let timeGrain=5m;

let dataset=dependencies
// additional filters can be applied here
| where timestamp > start and timestamp < end
| where client_Type != "Browser"
;
// calculate duration percentiles and count for all dependencies (overall)
dataset
| summarize avg_duration=sum(itemCount * duration)/sum(itemCount), percentiles(duration, 50, 95, 99), count_=sum(itemCount)
| project operation_Name="Overall", avg_duration, percentile_duration_50, percentile_duration_95, percentile_duration_99, count_
| union(dataset
// change 'target' on the below line to segment by a different property
| summarize avg_duration=sum(itemCount * duration)/sum(itemCount), percentiles(duration, 50, 95, 99), count_=sum(itemCount) by target
| sort by avg_duration desc, count_ desc
)
```

## Troubleshooting

### "Model not supported" Error

1. Check model name in `supportedModels` array (case-insensitive)
2. Verify backend pool was created in APIM
3. Review policy fragment deployment

### "403 Forbidden" Error

1. Check `allowedBackendPools` policy variable
2. Verify RBAC configuration
3. Review product/subscription access

### "401 Unauthorized" Error

1. Verify APIM's managed identity has required roles:
   - `Cognitive Services OpenAI User` for Azure OpenAI
   - `Cognitive Services User` for AI Foundry
2. For Amazon Bedrock: Verify AWS IAM access keys are valid and stored as named values (`aws-access-key`, `aws-secret-key`, `aws-region`)
3. `Unauthorized model access` indicates used access contract product is restricted for the model
4. Check named value `uami-client-id` is set correctly to APIM's managed identity client ID

### "500 AWSCredentialsNotConfigured" Error

This error means an `aws-bedrock` backend was matched but the AWS credentials named values are still set to the `NOT_CONFIGURED` placeholder. To fix:

1. Redeploy with the `awsAccessKey`, `awsSecretKey`, and `awsRegion` parameters set to valid values, **or**
2. Manually update the APIM named values `aws-access-key`, `aws-secret-key`, and `aws-region` in the Azure Portal

## Files

```
llm-backend-onboarding/
├── main.bicep                    # Main deployment template
├── main.bicepparam               # Parameter file template
├── README.md                     # This file
└── modules/
    ├── llm-backends.bicep        # Creates APIM backend resources
    ├── llm-backend-pools.bicep   # Creates load-balanced pools
    ├── llm-policy-fragments.bicep # Generates routing policy fragments
    ├── universal-llm-api.bicep   # Creates Universal LLM API
    └── policies/
        ├── frag-set-backend-pools.xml
        ├── frag-set-backend-authorization.xml
        ├── frag-set-target-backend-pool.xml
        ├── frag-set-llm-requested-model.xml
        ├── frag-set-llm-usage.xml
        ├── frag-get-available-models.xml
        ├── frag-metadata-config.xml          # Unified AI API metadata (always deployed)
        ├── universal-llm-api-policy.xml
        ├── universal-llm-openapi.json
        └── models-inference-openapi.json
```

## Related Guides

- [Citadel Access Contracts](../citadel-access-contracts/README.md) - Configure use case access to governance hub
- [Gateway Routing Guide](../../../guides/llm-routing-architecture.md) - Detailed routing architecture guide
- [Full Deployment Guide](../../../guides/full-deployment-guide.md) - Complete Citadel deployment guide
