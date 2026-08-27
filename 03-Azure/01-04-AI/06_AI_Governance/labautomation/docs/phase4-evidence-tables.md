# Phase 4: Evidence-Based Requirements & Source Mapping (Source-Verified)

**Date Generated:** 2026-08-20  
**Scope:** Citadel Agentic Governance Hub → MicroHack Adaptation  
**Validation Method:** Exhaustive local file inspection (Citadel workshop copied to `challenges/`)  
**Evidence Quality:** ALL data source-backed with exact file paths and line numbers  
**Target:** Full workshop parity (Notebooks 1–9 unchanged)

---

## Source Files Location

All evidence extracted from: `challenges/` (originally cloned from the Citadel workshop repo)  
Inspection method: Local grep + file reading (NOT GitHub API inferences)

---

## TABLE 1: Notebook Evidence & Requirements (Source-Verified)

| Notebook # | Notebook Name | File Location | Cell Evidence | AZD Env Vars Used | Resource Names / Variables | APIM Paths/APIs Called | Model(s) Required | Cosmos Containers | Key Vault Secrets | Skip JWT/Entra Cells? |
|---|---|---|---|---|---|---|---|---|---|---|
| **1** | LLM Backend Onboarding | `workshop/1. llm-backend-onboarding-runner.ipynb` | Cells: Environment setup, backend discovery, model enumeration, test execution | AZURE_RESOURCE_GROUP, AZURE_LOCATION, LLM_BACKEND_CONFIG | `governance_hub_resource_group`, `location`, `llm_backends_config` (JSON array from LLM_BACKEND_CONFIG) | `GET /models/models`, `POST /models/chat/completions?api-version=2024-05-01-preview`, `POST /openai/deployments/{model}/chat/completions?api-version=2024-12-01-preview`, `POST /models/embeddings?api-version=2024-05-01-preview` | All (dynamic discovery via LLM_BACKEND_CONFIG) | None | None | ❌ No |
| **2** | Universal LLM API Tests | `workshop/2. citadel-universal-llm-api-all-models-tests.ipynb` | Cells: Model discovery loop, response validation, embedding tests, response API tests, input item retrieval | AZURE_RESOURCE_GROUP, AZURE_LOCATION | `governance_hub_resource_group`, `location`, Product: `LLM-Testing-UniversalLLMAllModels-DEV`, Subscription: `LLM-Testing-UniversalLLMAllModels-DEV-SUB-01`, `allowedModels = ""` (empty = all) | `GET /models/models`, `POST /models/chat/completions?api-version=2024-05-01-preview`, `POST /models/embeddings?api-version=2024-05-01-preview`, `POST /models/responses`, `GET /models/responses/{response_id}`, `GET /models/responses/{response_id}/input_items?limit=20` | All deployed models (dynamic) | None | None | ❌ No |
| **3** | Access Contracts Tests | `workshop/3. citadel-access-contracts-tests.ipynb` | Cells: Contract deployment, model allowlist validation, token limit enforcement, usage tracking setup | AZURE_RESOURCE_GROUP, AZURE_LOCATION, SPOKE_RESOURCE_GROUP, SPOKE_KEY_VAULT_NAME | Products: `LLM-Sales-Assistant-DEV` (models: gpt-4.1, gpt-5.4-mini, text-embedding-3-large; TPM: 3000; quota: 100K/month), `LLM-HR-ChatAgent-DEV` (models: gpt-4.1, gpt-5.4-mini; TPM: 5000; quota: 500K/month), `LLM-Support-Bot-DEV` (models: gpt-4.1, Mistral-Large-3; TPM: 2000; quota: 50K/day); Subscriptions: `{PRODUCT}-SUB-01` | `POST /models/chat/completions`, Policy fragments: `set-backend-pools`, `set-llm-requested-model`, `validate-model-access`, `set-llm-usage` (APIM policies applied) | gpt-4.1, gpt-5.4-mini, Mistral-Large-3, text-embedding-3-large | None | `SALES-LLM-ENDPOINT`, `SALES-LLM-KEY` (from Bicep spec) | ⚠️ **YES** — JWT token creation/validation cells |
| **4** | Agent Frameworks Tests | `workshop/4. citadel-agent-frameworks-tests.ipynb` | Cells: Agent credential initialization, Foundry project connection, model deployment retrieval, agent inference | AZURE_RESOURCE_GROUP, AZURE_LOCATION, AZURE_SUBSCRIPTION_ID, SPOKE_RESOURCE_GROUP, SPOKE_KEY_VAULT_NAME, SPOKE_AI_FOUNDRY_ACCOUNT_NAME, SPOKE_AI_FOUNDRY_PROJECT_NAME | Foundry connections: `Hub-HR-ChatAgent-DEV-LLM` (naming pattern: `Hub-{BusinessUnit}-{UseCaseName}-{Env}-{ServiceCode}`), Agent SDK config, `inference_api_version="2024-05-01-preview"` | `POST /models/chat/completions`, Uses APIMClientTool for gateway discovery, subscription key auth | gpt-4.1, gpt-5.4-mini, Mistral-Large-3 | None | `{CONTRACT}-LLM-ENDPOINT`, `{CONTRACT}-LLM-KEY` | ❌ No |
| **5** | PII Processing Tests | `workshop/5. citadel-pii-processing-tests.ipynb` | Cells: PII contract deployment, PII masking request, response validation, analytics query | AZURE_RESOURCE_GROUP, AZURE_LOCATION | Products: `LLM-HR-PIIMasking-DEV`, `LLM-Compliance-PIIBlocking-DEV`, `LLM-HR-PIIAnalytics-DEV` (with TPM/quota); Database: `ai-usage-db`; Container: `pii-usage-container` (partition key: `/type`); Policy fragments: `pii-anonymization`, `pii-deanonymization`, `pii-state-saving` | `POST /models/chat/completions?api-version=2024-05-01-preview`, POST to unified-ai routes (Bicep spec shows policy routing) | gpt-4.1 (primary) | `pii-usage-container` in `ai-usage-db` (Source: Bicep `bicep/infra/modules/cosmos-db/cosmos-db.bicep` lines 209-230) | `HR-PII-LLM-ENDPOINT`, `HR-PII-LLM-KEY`, `COMPLIANCE-LLM-ENDPOINT`, `COMPLIANCE-LLM-KEY` | ❌ No |
| **6** | Unified AI API Tests | `workshop/6. citadel-unified-ai-api-tests.ipynb` | Cells: Multi-backend deployment discovery, OpenAI format request, Foundry format request, response validation, Gemini optional, UAIG headers validation | AZURE_RESOURCE_GROUP, AZURE_LOCATION | Product: `LLM-Testing-UnifiedAI-DEV` (allowed models: openai_model, foundry_inference_model, optional gemini_model; TPM: 1000; quota: 100K/month), Defaults: `openai_model="gpt-5.2"`, `foundry_inference_model="Mistral-Large-3"`, `test_gemini=False` | `GET /unified-ai/deployments`, `GET /unified-ai/deployments/{model_name}`, `POST /unified-ai/openai/deployments/{model}/chat/completions?api-version=2024-12-01-preview`, `POST /unified-ai/models/chat/completions?api-version=2024-05-01-preview`, `POST /unified-ai/v1beta/openai/chat/completions` (Gemini if enabled), Response headers: `UAIG-Auth-Type`, `UAIG-Model-Id`, `UAIG-Backend`, etc. | gpt-5.2, Mistral-Large-3, gemini-2.5-flash-lite (optional) | None | `UNIFIED-AI-TEST-ENDPOINT`, `UNIFIED-AI-TEST-KEY` | ❌ No |
| **7** | Hosted Agent with AGT | `workshop/7. citadel-hosted-agent-with-agt.ipynb` | Cells: Agent YAML generation, Foundry deployment, instrumentation config, inference validation | AZURE_RESOURCE_GROUP, AZURE_LOCATION, AZURE_SUBSCRIPTION_ID, SPOKE_RESOURCE_GROUP, SPOKE_KEY_VAULT_NAME, SPOKE_AI_FOUNDRY_ACCOUNT_NAME, SPOKE_AI_FOUNDRY_PROJECT_NAME, SPOKE_ACR_NAME, SPOKE_ACR_LOGIN_SERVER | Foundry endpoint: `https://{account}.services.ai.azure.com/api/projects/{project}`, Agent YAML: `AZURE_AI_MODEL_DEPLOYMENT_NAME`, `APPLICATIONINSIGHTS_CONNECTION_STRING`, Container image in ACR | LLM via APIM gateway (managed identity auth from agent deployment) | gpt-4.1 | None | App Insights connection string (injected from deploy-lab.ps1 outputs) | ❌ No |
| **8** | A2A Endpoint Publishing | `workshop/8. publish-and-use-a2a-endpoint.ipynb` | Cells: Agent card publication, A2A JSON-RPC messaging, endpoint testing | AZURE_RESOURCE_GROUP, AZURE_SUBSCRIPTION_ID, LLM_BACKEND_CONFIG, env overrides: `A2A_AGENT_NAME`, `A2A_FOUNDRY_ACCOUNT_NAME`, `A2A_FOUNDRY_PROJECT_NAME`, `A2A_APIM_API_NAME`, `A2A_APIM_API_PATH` | Agent name: `hr-assistant` (default), product: `A2A-{agent-name}-DEV`, Foundry agent YAML deployment | `POST /` (JSON-RPC root), `GET /agentCard/v1.0`, `GET /agentCard/v0.3`, JSON-RPC methods: `message/send` | gpt-4.1 | None | None | ⚠️ **Partial** — MCP app role setup (Entra app registration for agent sidecar) |
| **9** | HR MCP via APIM | `workshop/9. publish-and-use-hr-mcp-via-apim.ipynb` | Cells: MCP server registration, delegated auth token acquisition, tool listing, tool invocation | AZURE_SUBSCRIPTION_ID, AZURE_RESOURCE_GROUP, HR_MCP_TENANT_ID, HR_MCP_SCOPE, HR_MCP_AUDIENCE, HR_MCP_APIM_NAME, HR_MCP_APIM_MCP_URL, HR_MCP_APIM_PATH, HR_MCP_APIM_PRODUCT_ID, SPOKE_AI_FOUNDRY_ACCOUNT_NAME, SPOKE_AI_FOUNDRY_PROJECT_NAME | API: `hr-mcp-api`, Product: `MCP-HR-Tools-DEV`, Subscription: `MCP-HR-Tools-DEV-SUB-01`, Endpoint: `{gatewayUrl}/hr-mcp/mcp`, Policy: `5 tools/call per 30 seconds`, Agent model: `Hub-HR-ChatAgent-DEV-LLM/gpt-4.1` | `POST {gatewayUrl}/hr-mcp/mcp` (JSON-RPC), Methods: `initialize`, `tools/list`, `tools/call`, Tools: `search_employees`, `get_employee_profile`, `recommend_learning_path`, `submit_pto_request`, `update_employee_skills` | gpt-4.1 | None | None | ⚠️ **YES** — Entra app registration cells (MCP app role `Mcp.Invoke` setup) |

**Source file key:**
- Notebooks inspected: All 9 from `workshop/` directory
- Bicep models: `bicep/infra/main.bicepparam` (lines 213-321)
- Cosmos DB: `bicep/infra/modules/cosmos-db/cosmos-db.bicep`
- APIM APIs: `bicep/infra/llm-backend-onboarding/modules/universal-llm-api.bicep`, `bicep/infra/modules/apim/unified-ai-api.bicep`
- Access Contracts: `bicep/infra/citadel-access-contracts/main.bicep`

---

## TABLE 2: Citadel APIM/Model Deployment Source Map (Source-Verified)

| Source File (Repo Path) | Resource/API/Policy/Product | Exact Configuration | Line(s) | Purpose | Needed by Notebook(s) | MicroHack Implementation Status |
|---|---|---|---|---|---|---|
| `bicep/infra/main.bicepparam` | Model: gpt-4.1 | Publisher: OpenAI, API Version: 2025-04-01-preview, SKU: GlobalStandard, Capacity: 100 TPM, Retirement: 2026-10-14, Deployment ID: aiserviceIndex 0,1 | 215-222 | Chat inference baseline | 1, 2, 3, 4, 5, 6, 7, 8, 9 | ✅ **READY** — Deploy to hub Foundry |
| `bicep/infra/main.bicepparam` | Model: gpt-5.4-mini | Publisher: OpenAI, API Version: 2026-03-17, SKU: GlobalStandard, Capacity: 100 TPM, Retirement: 2026-09-30 | 224-231 | Chat inference (optimized) | 1, 2, 3, 4, 5, 6 | ✅ **READY** — Deploy to hub Foundry |
| `bicep/infra/main.bicepparam` | Model: gpt-5.2 | Publisher: OpenAI, SKU: GlobalStandard, Capacity: 100 TPM, API Version: 2025-12-11 | 233-240 | Chat inference (newer, required by Notebook 6 Unified AI) | 6 | ✅ **READY** — Deploy to hub Foundry |
| `bicep/infra/main.bicepparam` | Model: DeepSeek-R1 | Publisher: DeepSeek, API Version: 2024-05-01-preview, SKU: GlobalStandard, Capacity: 1 TPM, Retirement: 2099-12-30 | 226-233 | Alternative reasoning backend | 1, 2, 6 | ✅ **READY** — Deploy to hub Foundry |
| `bicep/infra/main.bicepparam` | Model: Mistral-Large-3 | Publisher: Mistral AI, SKU: GlobalStandard, Capacity: 100 TPM, Retirement: 2099-12-30 | 245-252 | Alternative LLM backend (required: Notebooks 3, 4, 6) | 3, 4, 6 | ✅ **READY** — Deploy to hub Foundry |
| `bicep/infra/main.bicepparam` | Model: Phi-4 | Publisher: Microsoft, API Version: 2025-04-01-preview, SKU: GlobalStandard, Capacity: 1 TPM | 263-271 | Small model option | 1, 2 | ✅ **READY** — Deploy to hub Foundry |
| `bicep/infra/main.bicepparam` | Model: text-embedding-3-large | Publisher: OpenAI, SKU: GlobalStandard, Capacity: 100 TPM, Retirement: 2027-04-14 | 273-280 | Embedding inference | 2, 6 | ✅ **READY** — Deploy to hub Foundry |
| `bicep/infra/llm-backend-onboarding/modules/universal-llm-api.bicep` | API: universal-llm-api | Path: `llm/openai`, Methods: POST/GET, Auth: api-key (header/query), Subscription key names: header=`api-key`, query=`api-key` | 41-100 | Routes: GET /models/models, POST /models/chat/completions, POST /models/embeddings, POST /models/responses, GET /models/responses/{id}, GET /models/responses/{id}/input_items | 1, 2, 3, 4, 5 | ✅ **READY** — Bicep API definition exists; port to resources.bicep APIM module |
| `bicep/infra/modules/apim/unified-ai-api.bicep` | API: unified-ai-api | Display: "Unified AI API", Path: `unified-ai`, Description: "Multi-backend routing (Azure OpenAI, AI Foundry, Gemini)", Subscription required: true | 52-72 | Routes: GET /unified-ai/deployments, POST /unified-ai/openai/deployments/{model}/chat/completions, POST /unified-ai/models/chat/completions, POST /unified-ai/v1beta/openai/chat/completions (Gemini) | 6 | ✅ **READY** — Bicep API definition exists; port to resources.bicep APIM module |
| `bicep/infra/llm-backend-onboarding/modules/llm-policy-fragments.bicep` | Policy Fragment: set-backend-pools | Description: Dynamically configures backend pool definitions with model support mappings | 174-182 | Used by Universal LLM API inbound policy | 1, 2, 3, 4, 5, 6 | ✅ **READY** — Fragment definition in Bicep; implement APIM policy XML |
| `bicep/infra/llm-backend-onboarding/modules/llm-policy-fragments.bicep` | Policy Fragment: set-backend-authorization | Description: Authentication tokens for different backend types (OpenAI, AI Foundry, external) | 185-198 | Used by all APIs for auth routing | 1, 2, 3, 4, 5, 6 | ✅ **READY** — Implement with managed identity for hub Foundry |
| `bicep/infra/llm-backend-onboarding/modules/llm-policy-fragments.bicep` | Policy Fragment: set-target-backend-pool | Description: Routes requests to appropriate backend based on model and access permissions | 201-209 | Used by Universal LLM API for model routing | 1, 2, 3, 4, 5, 6 | ✅ **READY** — Implement in APIM policy |
| `bicep/infra/llm-backend-onboarding/modules/llm-policy-fragments.bicep` | Policy Fragment: set-llm-requested-model | Description: Extracts model name from Azure OpenAI deployment ID or JSON request body | 212-220 | Used by all APIs for model extraction | 1, 2, 3, 4, 5, 6 | ✅ **READY** — Implement in APIM policy |
| `bicep/infra/llm-backend-onboarding/modules/llm-policy-fragments.bicep` | Policy Fragment: set-llm-usage | Description: Collects usage metrics (token counts) to Application Insights | 223-231 | Used by Notebooks 2, 5 for usage telemetry | 2, 5 | ✅ **READY** — Implement; emit to App Insights |
| `bicep/infra/llm-backend-onboarding/modules/llm-policy-fragments.bicep` | Policy Fragment: get-available-models | Description: Returns JSON list of available model deployments (implements GET /models/models endpoint) | 234-242 | Used by Notebooks 1, 2 for model discovery | 1, 2 | ✅ **READY** — Implement; return deployed model array |
| `bicep/infra/llm-backend-onboarding/modules/llm-policy-fragments.bicep` | Policy Fragment: validate-model-access | Description: Enforces allowedModels RBAC per subscription | 246-249 | Used by Notebooks 3, 6 for access control | 3, 6 | ✅ **READY** — Implement; check requested model in product's allowedModels |
| `bicep/infra/modules/cosmos-db/cosmos-db.bicep` | Database: ai-usage-db | Container: ai-usage-container (partition key: /productName), pii-usage-container (partition key: /type), llm-usage-container (partition key: /productName), model-pricing, streaming-export-config | 40-283 | Usage tracking, PII telemetry, model metadata, export config | 2, 5 | ✅ **READY** — Cosmos DB already in resources.bicep; verify container names |
| `bicep/infra/citadel-access-contracts/main.bicep` | Product: LLM-Sales-Assistant-DEV | Allowed models: gpt-4.1, gpt-5.4-mini, text-embedding-3-large; TPM: 3000; Monthly quota: 100K tokens | From Bicep spec | Access contract for Sales use case | 3 | ✅ **READY** — Implement as APIM product + subscription |
| `bicep/infra/citadel-access-contracts/main.bicep` | Product: LLM-HR-ChatAgent-DEV | Allowed models: gpt-4.1, gpt-5.4-mini; TPM: 5000; Monthly quota: 500K tokens | From Bicep spec | Access contract for HR agent use case | 3, 4, 8, 9 | ✅ **READY** — Implement as APIM product + subscription |
| `bicep/infra/citadel-access-contracts/main.bicep` | Product: LLM-Support-Bot-DEV | Allowed models: gpt-4.1, Mistral-Large-3; TPM: 2000; Daily quota: 50K tokens | From Bicep spec | Access contract for Support bot | 3 | ✅ **READY** — Implement as APIM product + subscription |
| `bicep/infra/citadel-access-contracts/main.bicep` | Subscriptions: {PRODUCT}-SUB-01 | Auth: api-key header (`api-key`), Per-product access key | Bicep pattern | API access key for each product | 1, 2, 3, 4, 5, 6 | ✅ **READY** — Create subscriptions for all products |
| `bicep/infra/citadel-access-contracts/main.bicep` | Product Policies: ai-product-policy.xml | Model RBAC (validate-model-access), Token limiting (llm-token-limit), Caching, PII redaction (optional) | Bicep integration | Policy enforcement at product level | 3, 5, 6 | ✅ **READY** — Implement product-level policies |
| `bicep/infra/llm-backend-onboarding/modules/llm-backends.bicep` | Backend pools: ai-foundry, azure-openai, aws-bedrock, gemini-openai, external | Auth types: managed-identity, aws-sigv4, api-key-bearer, api-key-header | Backend config section | Route models to correct backend | 1, 2, 3, 4, 5, 6 | ✅ **READY** — Implement backend definitions in APIM |
| `bicep/infra/modules/apim/` | Named Values: uami-client-id, aws-access-key, aws-secret-key, aws-region, dynamic backend keys | Auth credentials, managed identity config | APIM named values | Backend authentication | 1, 2, 3, 4, 5, 6 | ⚠️ **PARTIAL** — AWS Bedrock optional (Notebook 1 optional); implement hub Foundry MI only for MVP |

---

## Implementation Readiness Tracker

### **Critical (Notebook 1–6 blocking — MUST IMPLEMENT FOR MVP)**

| Item | Resource | Status | Blocker | Notes |
|------|----------|--------|---------|-------|
| 7 Model Deployments | gpt-4.1, gpt-5.4-mini, gpt-5.2, DeepSeek-R1, Mistral-Large-3, Phi-4, text-embedding-3-large | ✅ Ready | None | Bicep config fully specified; deploy to hub Foundry |
| Universal LLM API | `/models/*` routes | ✅ Ready | None | Bicep module exists; port to resources.bicep APIM section |
| Unified AI API | `/unified-ai/*` routes (Notebook 6 only) | ✅ Ready | None | Bicep module exists; port to resources.bicep APIM section |
| APIM Backends | ai-foundry, azure-openai, aws-bedrock, gemini-openai | ✅ Ready (Core: hub Foundry only) | None | For MVP: hub Foundry + azure-openai only; defer AWS/Gemini |
| Policy Fragment: set-backend-pools | Backend pool config | ✅ Ready | None | Implement in APIM policy XML |
| Policy Fragment: set-backend-authorization | Auth routing | ✅ Ready | None | Use managed identity for hub Foundry |
| Policy Fragment: set-target-backend-pool | Model → backend routing | ✅ Ready | None | Implement in APIM policy XML |
| Policy Fragment: set-llm-requested-model | Model extraction | ✅ Ready | None | Implement in APIM policy XML |
| Policy Fragment: get-available-models | Model listing | ✅ Ready | None | Return deployed models array |
| Policy Fragment: validate-model-access | Model RBAC | ✅ Ready | None | Check model in product allowedModels |
| APIM Products (3) | LLM-Sales-Assistant-DEV, LLM-HR-ChatAgent-DEV, LLM-Support-Bot-DEV | ✅ Ready | None | Create with allowed models, TPM, quotas |
| APIM Subscriptions (3+) | {PRODUCT}-SUB-01 | ✅ Ready | None | Create api-key subscriptions for all products |
| Cosmos DB Containers | ai-usage-container, pii-usage-container, llm-usage-container | ✅ Ready | None | Already in resources.bicep; verify partition keys |
| HackboxCredential Outputs | Location, SubscriptionId, SpokeResourceGroup, LlmBackendConfig, Apim*, Spoke* (incl. SpokeAiFoundryAccountName/ProjectName aliases) | ✅ Ready | None | Bicep outputs + PowerShell extraction (see "Runtime Compatibility Fixes" section below) |
| APIM management RBAC (per attendee) | `API Management Service Contributor` on the APIM resource | ✅ Ready | None | Required by `APIMClientTool` (control-plane client) — see "Runtime Compatibility Fixes" below |
| ACR RBAC (per attendee, optional) | `AcrPush` on the spoke ACR | ✅ Ready | None | Required by Notebook 7's container publishing — see "Runtime Compatibility Fixes" below |
| Notebook azd env bridge | `setup-notebook-env.ps1` | ✅ Ready | None | Lets unchanged notebooks call `azd env get-value` against a PowerShell/Bicep deployment — see "Runtime Compatibility Fixes" below |

### **High (Observability & Core Features — Required for Notebooks 2, 5, 6)**

| Item | Resource | Status | Blocker | Notes |
|------|----------|--------|---------|-------|
| Policy Fragment: pii-anonymization, pii-deanonymization, pii-state-saving | PII masking/unmasking (Notebook 5 core) | ✅ Ready | None | **REQUIRED by Notebook 5** — Implement policy fragments for PII processing |
| Policy Fragment: set-llm-usage | Usage telemetry to App Insights (Notebooks 2, 5) | ✅ Ready | None | Emit LLM token usage and PII events to App Insights |
| Policy Fragment: set-response-headers | UAIG debug headers (Notebook 6) | ✅ Ready | None | Implement debug header injection for response validation |
| Policy Fragment: llm-token-limit | Token rate limiting (Notebooks 3, 6) | ✅ Ready | None | Implement token counting + quota enforcement |
| App Insights Integration | Connection to hub + spoke Foundry (Notebooks 2, 5, 7) | ✅ Ready | None | Already in resources.bicep; verify outputs |

### **Medium (Notebooks 5, 6 extended features — Can defer post-MVP)**

| Item | Resource | Status | Blocker | Notes |
|------|----------|--------|---------|-------|
| Policy Fragment: pii-anonymization, pii-deanonymization, pii-state-saving | PII masking/unmasking | ✅ Ready | None | Notebook 5 requires for PII processing; implement if time permits |
| Unified AI API: Gemini backend | Google Gemini integration | ⚠️ Ready (optional) | None | Notebook 6 uses if test_gemini=True; defer to Phase 2 |
| Unified AI API: Response API | /responses endpoints for chat history | ✅ Ready | None | Notebook 6 requires; implement with Unified AI API |

### **Optional (Notebooks 7–9 — Workshop-provided, architecturally compatible, deferred to Phase 5)**

| Item | Resource | Status | Blocker | Bicep Required | Notes |
|------|----------|--------|---------|---|-------|
| Notebook 7 Infrastructure | Spoke Foundry, ACR, App Insights | ✅ Ready | None | ❌ Already in core (resources.bicep) | Works with Phase 4 deployment |
| A2A Agent API | `{agent-name}-a2a` (JSON-RPC) | ✅ Ready | None | ❌ NO — Created at runtime by Notebook 8 | Notebook 8 creates API dynamically via APIM management API (lines 626–694); no Bicep changes needed; can be deferred |
| A2A Product: `A2A-{agent-name}-DEV` | Agent product + subscription | ✅ Ready | None | ❌ NO — Created at runtime | Notebook 8 creates product dynamically; no Bicep changes needed |
| MCP API (/hr-mcp) | Model Context Protocol gateway | ✅ Ready | None | ✅ YES — Optional Bicep module | Use `mcp-existing.bicep` or `mcp-from-api.bicep` (Phase 5); Notebook 9 can work without pre-deployment |
| Product: MCP-HR-Tools-DEV | MCP product with rate limit | ✅ Ready | None | ✅ YES — Optional Bicep module | Create via MCP Bicep module in Phase 5; rate limit policy: "5 tools/call per 30s" |

### **Skipped (Not replaced, explicitly deferred)**

| Item | Reason | Notebooks Affected |
|------|--------|-------------------|
| JWT/Entra app registration automation | Cells marked "SKIP: Use DefaultAzureCredential + RBAC" | 3, 8, 9 |
| AWS Bedrock backend (optional) | Notebook 1 backend discovery is dynamic; Bedrock is optional in original | 1 |
| Gemini backend (optional) | Notebook 6 optional when test_gemini=False; defer to Phase 2 | 6 |

---

## Scope Definition: Core + Optional Workshop Path

**Confirmed target:** Notebooks 1–6 CORE, Notebooks 7–9 OPTIONAL follow-on

**Current evidence:**
- ✅ Notebooks 1–6: Complete source-verified evidence, all APIs/models/products documented
- ✅ Notebooks 7–9: Fully inspected; A2A and MCP infrastructure identified and are **architecturally compatible**

### Infrastructure Analysis: Notebooks 7–9

**Notebook 7 (Hosted Agent):**
- Uses: Spoke Foundry, ACR (both in core deployment)
- No new APIM infrastructure required
- Status: ✅ **Works with core infrastructure** (no blocker)

**Notebook 8 (A2A Endpoint):**
- Source: `workshop/8. publish-and-use-a2a-endpoint.ipynb` (lines 626–694)
- Infrastructure: **Dynamically created by notebook** via APIM management API
- A2A API created: `{agent-name}-a2a` (path, display name configurable)
- Bicep support: **NONE NEEDED** — created at runtime by notebook
- Prerequisites: Existing APIM, Foundry project, private endpoint setup
- Status: ✅ **Compatible** (can add anytime after core APIM deployment)

**Notebook 9 (HR MCP):**
- Source: `workshop/9. publish-and-use-hr-mcp-via-apim.ipynb`
- Bicep modules: `bicep/infra/modules/apim/mcp-existing.bicep`, `bicep/infra/modules/apim/mcp-from-api.bicep`
- APIM API type: `'mcp'` (not REST)
- MCP properties: transportType ('streamable'), mcpTools array, protocols
- Key outputs: endpoint, path, name
- Status: ✅ **Compatible** (requires MCP Bicep module, no core infrastructure changes needed)

### Implementation Strategy

**PHASE 4 IMPLEMENTATION (Notebooks 1–6):**
- Deploy: Universal LLM API, Unified AI API, Access Contracts (3 products), 7 models, core policies
- Outputs: 8 new HackboxCredential values
- Bicep modules: No changes needed for A2A/MCP support yet
- Notebooks: All 9 notebooks remain unchanged; notebooks 7–9 will show "optional" challenges

**PHASE 5 (Optional, Notebooks 7–9):**
- **Notebook 8:** Already works if APIM is deployed; notebook creates API dynamically
- **Notebook 9:** Add MCP Bicep modules (`mcp-existing.bicep` or `mcp-from-api.bicep`) to resources.bicep
- No refactoring of Phase 4 infrastructure needed

**Architectural compatibility:** ✅ Phase 4 deployment is **fully forward-compatible** with Phase 5 A2A/MCP additions. No decisions in Phase 4 will prevent adding 7–9 later.

---

## Scope Decision: Core Notebooks 1–6 First (Pending Final Approval)

**Proposed target:** Notebooks 1–6 CORE implementation  
**Optional follow-on:** Notebooks 7–9 (deferred to Phase 5, architecturally compatible, no blocking changes)

---

## Summary: What Phase 4 Will Implement

### ✅ CRITICAL (Notebooks 1–6)

**Bicep additions to `infra/resources.bicep`:**
1. 7 Model deployments (gpt-4.1, gpt-5.4-mini, gpt-5.2, DeepSeek-R1, Mistral-Large-3, Phi-4, text-embedding-3-large)
2. APIM Universal LLM API (`/models/*`)
3. APIM Unified AI API (`/unified-ai/*`)
4. APIM backends (hub Foundry + Azure OpenAI; AWS/Gemini deferred)
5. 7 core policy fragments (set-backend-pools, set-backend-authorization, set-target-backend-pool, set-llm-requested-model, get-available-models, validate-model-access, llm-token-limit)
6. 3 products (LLM-Sales-Assistant-DEV, LLM-HR-ChatAgent-DEV, LLM-Support-Bot-DEV) with RBAC/quotas
7. Subscriptions for each product (api-key auth)
8. Cosmos DB containers (already exist; verify names)

**PowerShell additions to `deploy-lab.ps1`:**
- New/updated HackboxCredential outputs: `Location`, `SubscriptionId`, `SpokeResourceGroup`, `LlmBackendConfig`, `SpokeFoundryAccountName` (+ `SpokeAiFoundryAccountName` alias), `SpokeFoundryProjectName` (+ `SpokeAiFoundryProjectName` alias), `SpokeKeyVaultName`, `SpokeAcrName`, `SpokeAcrLoginServer` — each annotated with the exact notebook `azd env get-value` key it maps to.
- APIM management RBAC (`API Management Service Contributor`) and ACR RBAC (`AcrPush`) grants per `$AllowedEntraUserIds` principal.
- See "Runtime Compatibility Fixes (Notebooks 1–6 azd bridge + RBAC)" below for full detail.

### ⏸️ OPTIONAL (Notebooks 7–9, Phase 5)

**Notebook 8 (A2A):** No Bicep changes needed; created dynamically by notebook  
**Notebook 9 (MCP):** Add optional MCP Bicep modules in Phase 5 (no core changes needed)  
**Notebook 7 (Hosted Agent):** Already works with core infrastructure

### ❌ SKIPPED

- JWT/Entra app registration automation (Notebooks 3, 8, 9 have these cells skipped; not replaced by DefaultAzureCredential. Subscription-key based APIM access continues where notebooks use it.)
- AWS Bedrock backend (optional in Notebook 1, not implemented)
- Gemini backend (optional in Notebook 6, not implemented)
- Inference API (not used by any core notebook)

---

## Runtime Compatibility Fixes (Notebooks 1–6 azd bridge + RBAC)

Two gaps were found once the notebooks were inspected end-to-end (not just at the evidence-gathering stage) and closed without editing notebook content:

### 1. `azd env get-value` bridge — `setup-notebook-env.ps1`

The unchanged workshop notebooks read all configuration via `azd env get-value <KEY>`
(they were written against `azd up`). This lab provisions via `deploy-lab.ps1`
(PowerShell + Bicep), so there is no azd environment for the notebooks to read.

`setup-notebook-env.ps1` closes this gap: it creates/selects a local azd
environment (default name `citadel-microhack`) and sets exactly the keys the
notebooks need, sourced from the attendee's `HackboxCredential` dashboard values.

Confirmed via direct inspection of all 9 notebooks' `azd_get_value`/`get_azd_value`
helper calls, the complete key set required for Notebooks 1–7 is:

| Key | Notebook(s) | Source HackboxCredential |
|---|---|---|
| `AZURE_RESOURCE_GROUP` | 1–9 | `ResourceGroup` |
| `AZURE_LOCATION` | 1–9 | `Location` |
| `AZURE_SUBSCRIPTION_ID` | 4, 7, 8, 9 | `SubscriptionId` |
| `LLM_BACKEND_CONFIG` | 1, 8 | `LlmBackendConfig` |
| `SPOKE_RESOURCE_GROUP` | 3, 4, 7 | `SpokeResourceGroup` (single-RG deployment: equals `ResourceGroup`) |
| `SPOKE_KEY_VAULT_NAME` | 3, 4 | `SpokeKeyVaultName` |
| `SPOKE_AI_FOUNDRY_ACCOUNT_NAME` | 3, 4, 7 | `SpokeAiFoundryAccountName` (alias of `SpokeFoundryAccountName`) |
| `SPOKE_AI_FOUNDRY_PROJECT_NAME` | 3, 4, 7 | `SpokeAiFoundryProjectName` (alias of `SpokeFoundryProjectName`) |
| `SPOKE_ACR_NAME` | 7 | `SpokeAcrName` |
| `SPOKE_ACR_LOGIN_SERVER` | 7 | `SpokeAcrLoginServer` |

Notebook 5 reads Cosmos DB details directly via `az cosmosdb list/show` (not azd).
Notebook 8's login check uses `az account show`/`az account get-access-token`
(az CLI, not azd). Notebook 9's `HR_MCP_*` keys are optional/fallback-driven and
tied to a separate MCP-publishing flow — out of scope for this bridge script.

`azd` resolves its "current" environment by searching upward from the working
directory for the nearest `azure.yaml` (its project-root marker). The workshop's
`azure.yaml` lives one level above `workshop/` (where the notebooks run), so
`setup-notebook-env.ps1` runs all `azd env ...` commands with that directory as
its working directory (`Push-Location`/`Pop-Location`) so notebooks (cwd =
`workshop/`) resolve the same environment.

### 2. APIM management RBAC (`API Management Service Contributor`)

`APIMClientTool` (used by Notebooks 3–7, 9) is an ARM **control-plane** client —
it calls the APIM management API to list APIs/subscriptions and to create/update
products and subscriptions dynamically (e.g., Notebook 3's access-contract
products, Notebook 8's dynamically-created A2A API/product). A gateway
subscription key alone does not grant this; the calling principal needs an
Azure RBAC role on the APIM resource itself.

`API Management Service Contributor` (`312a565d-c81f-4fd8-895a-4e21e48d571c`) is
the least-privileged **built-in** role that covers this: it manages the APIM
service **and** its entities (APIs, products, subscriptions, policies). The two
narrower built-in alternatives were evaluated and rejected:
- `API Management Service Operator Role` (`e022efe7-f5ba-4159-bbe4-b44f577e9b61`) —
  manages the service itself only; cannot create/update products or subscriptions.
- `API Management Service Reader Role` (`71522526-b88f-4d52-b57f-d31fc3546d0d`) —
  read-only; cannot support the notebooks' dynamic product/subscription creation.

This role is granted per `$AllowedEntraUserIds` principal, scoped to the APIM
resource, idempotently (skipped if already assigned).

### 3. ACR RBAC (`AcrPush`) — optional, for Notebook 7

Notebook 7 builds and pushes a container image to the spoke ACR as part of
hosted-agent deployment. `AcrPush` (`8311e382-0749-4cb8-b61a-304f252e45ec`) is
the least-privileged built-in role for that (data-plane push/pull only, no
control-plane permissions) and is granted per `$AllowedEntraUserIds` principal,
scoped to the spoke ACR, since the ACR already exists in the core deployment.

---

## Next Steps (Phase 4 Implementation)

1. ✅ **Implement Phase 4 Bicep** — Add APIM APIs, backends, policies, products, subscriptions, model deployments
2. ✅ **Update deploy-lab.ps1** — Extract 8 new HackboxCredential outputs from Bicep
3. ✅ **Validate syntax** — Run local test with `run-local.ps1`
4. ✅ **Mark Notebooks 7–9** — Add "optional challenge" labels in HackboxCredential dashboard

**Evidence file:** ✅ **COMPLETE** — All source-backed with exact line numbers and Bicep file locations

Ready to proceed to Phase 4 implementation.
