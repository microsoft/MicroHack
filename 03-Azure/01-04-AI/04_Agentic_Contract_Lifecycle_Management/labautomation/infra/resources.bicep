// ==========================================================================
// Foundry CLM Microhack — resource module (resource-group scope)
// Mirrors labautomation/deploy.sh so `azd up` produces the same resources, model
// deployments, and .env contract the challenges expect.
// ==========================================================================
@description('Azure region for all resources.')
param location string

@description('Short, unique token used to name globally-unique resources.')
param resourceToken string

@description('Object id of the user/service principal running the deployment (for RBAC). Leave empty to skip role assignments.')
param principalId string = ''

@description('Principal type for RBAC assignments: User or ServicePrincipal.')
@allowed([ 'User', 'ServicePrincipal' ])
param principalType string = 'User'

@description('Provision the optional Azure SQL backing store for the contract-status tool ("true"/"false").')
param deploySql string = 'false'

@description('Admin password for the optional Azure SQL server (required when deploySql is true).')
@secure()
param sqlAdminPassword string = ''

@description('Provision the optional Grounding with Bing Search resource + project connection for web grounding ("true"/"false").')
param deployBing string = 'false'

@description('Tags applied to every resource.')
param tags object = {}

// ---- Fixed names (match deploy.sh + .env contract) -----------------------
var foundryName = 'clmfoundry${resourceToken}'
var projectName = 'clm-project'
var searchName = 'clmsearch${resourceToken}'
var appInsightsName = 'clm-appinsights-${resourceToken}'
var logAnalyticsName = 'clm-logs-${resourceToken}'
var searchIndexName = 'clm-corpus'
var searchConnectionName = 'clm-search'
var appInsightsConnectionName = 'clm-appinsights'
var bingName = 'clmbing${resourceToken}'
var bingConnectionName = 'clm-bing'

// ---- Model deployment names ----------------------------------------------
// NOTE: these are the *deployment* names (what the app calls at runtime via the
// MODEL_* env vars); the underlying catalog model/version is set below. In
// swedencentral offers the base `gpt-5.4` flagship, so the orchestrator
// deployment (named `gpt-5.4`) runs the `gpt-5.4` catalog model directly.
var gptOrchestrator = 'gpt-5.4'
var gptMini = 'gpt-4.1-mini'
var gpt56sol = 'gpt-5.6-sol'
// Orchestrator catalog model + version — confirm the exact model/version offered
// in your region's Foundry model catalog and update here if needed
// (`az cognitiveservices model list --location <region>`).
var gptOrchestratorModel = 'gpt-5.4'
var gptOrchestratorVersion = '2026-03-05'
// Clause & Risk catalog model + version. Runs the gpt-5.6-sol flagship for
// structured legal reasoning; verify the exact version in your region's catalog.
var gpt56solModel = 'gpt-5.6-sol'
var gpt56solVersion = '2026-07-09'
// Renewal / lightweight agent catalog model. gpt-4o-mini is deprecating in
// swedencentral (fires ServiceModelDeprecating on new deployments), so the
// renewal deployment runs gpt-4.1-mini instead — same GlobalStandard SKU, a later
// deprecation horizon, and still cheap/fast for the high-frequency agent.
var gptMiniModel = 'gpt-4.1-mini'
var gptMiniVersion = '2025-04-14'

// ---- Built-in role definition ids ----------------------------------------
var roleAiDeveloper = '64702f94-c441-49e6-a78b-ef80e0188fee'            // Azure AI Developer
var roleCognitiveServicesUser = 'a97b65f3-24c7-4388-baec-2e87135dc908' // Cognitive Services User
var roleSearchIndexDataContributor = '8ebe5a00-799e-43f5-93ac-243d3dce84a7'
var roleSearchServiceContributor = '7ca78c08-252a-4471-8644-bb5ff32d4ba0'
var roleSearchIndexDataReader = '1407120a-92aa-4202-b7e9-c0e197c71c8f'

var wantSql = toLower(deploySql) == 'true' && !empty(sqlAdminPassword)
var wantBing = toLower(deployBing) == 'true'
var assignUserRoles = !empty(principalId)

// ==========================================================================
// Observability — Log Analytics + Application Insights
// ==========================================================================
resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: logAnalyticsName
  location: location
  tags: tags
  properties: {
    sku: { name: 'PerGB2018' }
    retentionInDays: 30
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id
  }
}

// ==========================================================================
// Corpus source of truth — SharePoint document library (bring-your-own)
// ==========================================================================
// The original contract PDFs live in a SharePoint Online document library, which
// is Microsoft 365 (not an Azure Resource Manager resource) and therefore not
// provisioned here. Challenge 1's src/scripts/seed_corpus.py creates the Azure AI
// Search SharePoint Online data source + indexer that crawls that library into
// the clm-corpus index. See the challenge-0 README for the prerequisite Entra
// app registration and .env values (SHAREPOINT_*).

// ==========================================================================
// Azure AI Search — Foundry IQ backing store (AAD data-plane auth enabled)
// ==========================================================================
resource search 'Microsoft.Search/searchServices@2024-06-01-preview' = {
  name: searchName
  location: location
  tags: tags
  sku: { name: 'basic' }
  identity: { type: 'SystemAssigned' }
  properties: {
    partitionCount: 1
    replicaCount: 1
    hostingMode: 'default'
    semanticSearch: 'free'
    // Allow BOTH AAD and API keys so AAD-based seeding (DefaultAzureCredential)
    // and portal/key access both work.
    authOptions: {
      aadOrApiKey: {
        aadAuthFailureMode: 'http401WithBearerChallenge'
      }
    }
  }
}

// ==========================================================================
// Foundry (AI Services) account + project + model deployments
// ==========================================================================
resource account 'Microsoft.CognitiveServices/accounts@2025-04-01-preview' = {
  name: foundryName
  location: location
  tags: tags
  kind: 'AIServices'
  sku: { name: 'S0' }
  identity: { type: 'SystemAssigned' }
  properties: {
    customSubDomainName: foundryName
    publicNetworkAccess: 'Enabled'
    disableLocalAuth: false
    // Required so the child `projects` resource below can be created under this
    // AIServices account (otherwise: "Project can only be created under
    // AIServices Kind account with allowProjectManagement set to true").
    allowProjectManagement: true
  }
}

resource project 'Microsoft.CognitiveServices/accounts/projects@2025-04-01-preview' = {
  parent: account
  name: projectName
  location: location
  tags: tags
  identity: { type: 'SystemAssigned' }
  properties: {
    displayName: 'CLM Microhack'
    description: 'Contract Lifecycle Management multi-agent microhack project.'
  }
}

// Model deployments must be serialized on a single account.
resource deployOrchestrator 'Microsoft.CognitiveServices/accounts/deployments@2025-04-01-preview' = {
  parent: account
  name: gptOrchestrator
  sku: { name: 'GlobalStandard', capacity: 30 }
  properties: {
    model: { format: 'OpenAI', name: gptOrchestratorModel, version: gptOrchestratorVersion }
  }
}

resource deployMini 'Microsoft.CognitiveServices/accounts/deployments@2025-04-01-preview' = {
  parent: account
  name: gptMini
  sku: { name: 'GlobalStandard', capacity: 30 }
  properties: {
    model: { format: 'OpenAI', name: gptMiniModel, version: gptMiniVersion }
  }
  dependsOn: [ deployOrchestrator ]
}

// Clause & Risk agent runs on gpt-5.6-sol — its own dedicated deployment.
resource deployGpt56Sol 'Microsoft.CognitiveServices/accounts/deployments@2025-04-01-preview' = {
  parent: account
  name: gpt56sol
  sku: { name: 'GlobalStandard', capacity: 30 }
  properties: {
    model: { format: 'OpenAI', name: gpt56solModel, version: gpt56solVersion }
  }
  dependsOn: [ deployMini ]
}

// Foundry IQ connection: project -> Azure AI Search (deploy.sh only sets the
// name and relies on the portal; here we actually create it).
resource searchConnection 'Microsoft.CognitiveServices/accounts/projects/connections@2025-04-01-preview' = {
  parent: project
  name: searchConnectionName
  properties: {
    category: 'CognitiveSearch'
    target: 'https://${search.name}.search.windows.net'
    authType: 'AAD'
    isSharedToAll: true
    metadata: {
      ApiType: 'Azure'
      ResourceId: search.id
      location: location
    }
  }
}

// Observability connection: project -> Application Insights. Foundry stores
// traces in App Insights, but the portal Tracing tab only renders them once the
// resource is *connected* to the project — creating the App Insights component
// alone is not enough. (Challenge 3.)
resource appInsightsConnection 'Microsoft.CognitiveServices/accounts/projects/connections@2025-04-01-preview' = {
  parent: project
  name: appInsightsConnectionName
  properties: {
    category: 'AppInsights'
    target: appInsights.id
    authType: 'ApiKey'
    isSharedToAll: true
    credentials: {
      key: appInsights.properties.ConnectionString
    }
    metadata: {
      ApiType: 'Azure'
      ResourceId: appInsights.id
    }
  }
}

// ==========================================================================
// agent (Ch4 "Go Further"). The Bing account is a global resource; the project
// connection (category ApiKey, resolved by name AZURE_BING_CONNECTION_NAME) is
// what build_web_search_tool() attaches to the agent. Bing search data leaves
// the Azure compliance boundary — provision only when web grounding is wanted.
// ==========================================================================
#disable-next-line BCP081
resource bing 'Microsoft.Bing/accounts@2020-06-10' = if (wantBing) {
  name: bingName
  location: 'global'
  sku: { name: 'G1' }
  kind: 'Bing.Grounding'
  tags: tags
}

resource bingConnection 'Microsoft.CognitiveServices/accounts/projects/connections@2025-04-01-preview' = if (wantBing) {
  parent: project
  name: bingConnectionName
  properties: {
    category: 'ApiKey'
    target: 'https://api.bing.microsoft.com/'
    authType: 'ApiKey'
    credentials: {
      #disable-next-line BCP318 BCP422
      key: bing.listKeys().key1
    }
    isSharedToAll: true
    metadata: {
      ApiType: 'Azure'
      Location: 'global'
      #disable-next-line BCP318
      ResourceId: bing.id
      type: 'bing_grounding'
    }
  }
}

// ==========================================================================
// Azure SQL (optional) — contract status / renewal dates function tool
// ==========================================================================
resource sqlServer 'Microsoft.Sql/servers@2023-08-01' = if (wantSql) {
  name: 'clmsql${resourceToken}'
  location: location
  tags: tags
  properties: {
    administratorLogin: 'clmadmin'
    administratorLoginPassword: sqlAdminPassword
    minimalTlsVersion: '1.2'
    publicNetworkAccess: 'Enabled'
  }
}

resource sqlDb 'Microsoft.Sql/servers/databases@2023-08-01' = if (wantSql) {
  parent: sqlServer
  name: 'clmdb'
  location: location
  tags: tags
  sku: { name: 'Basic', tier: 'Basic' }
}

resource sqlFirewall 'Microsoft.Sql/servers/firewallRules@2023-08-01' = if (wantSql) {
  parent: sqlServer
  name: 'AllowAzure'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

// ==========================================================================
// Role assignments
// ==========================================================================
// -- Deploying user / service principal -----------------------------------
resource raUserAiDeveloper 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (assignUserRoles) {
  name: guid(account.id, principalId, roleAiDeveloper)
  scope: account
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleAiDeveloper)
    principalId: principalId
    principalType: principalType
  }
}

resource raUserCognitiveUser 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (assignUserRoles) {
  name: guid(account.id, principalId, roleCognitiveServicesUser)
  scope: account
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleCognitiveServicesUser)
    principalId: principalId
    principalType: principalType
  }
}

resource raUserSearchIndexContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (assignUserRoles) {
  name: guid(search.id, principalId, roleSearchIndexDataContributor)
  scope: search
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleSearchIndexDataContributor)
    principalId: principalId
    principalType: principalType
  }
}

resource raUserSearchServiceContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (assignUserRoles) {
  name: guid(search.id, principalId, roleSearchServiceContributor)
  scope: search
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleSearchServiceContributor)
    principalId: principalId
    principalType: principalType
  }
}

// -- Foundry account managed identity (grounding / Foundry IQ retrieval) ---
// Agentic retrieval needs BOTH a data-plane read role (query the index) and a
// control-plane role (read the index/semantic-config definition), on BOTH the
// account AND the project managed identities — depending on region/preview the
// tool call runs under either identity, and granting only the account MI Data
// Reader surfaces as `400 tool_user_error … Access denied, check managed identity
// access to search service`.
resource raAccountSearchReader 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(search.id, account.id, roleSearchIndexDataReader)
  scope: search
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleSearchIndexDataReader)
    principalId: account.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource raAccountSearchServiceContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(search.id, account.id, roleSearchServiceContributor)
  scope: search
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleSearchServiceContributor)
    principalId: account.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// -- Foundry project managed identity (Agent Framework retrieval tool calls) --
resource raProjectSearchReader 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(search.id, project.id, roleSearchIndexDataReader)
  scope: search
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleSearchIndexDataReader)
    principalId: project.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource raProjectSearchServiceContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(search.id, project.id, roleSearchServiceContributor)
  scope: search
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleSearchServiceContributor)
    principalId: project.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// ==========================================================================
// Outputs — consumed by the postprovision hook to write .env
// ==========================================================================
output AZURE_AI_PROJECT_ENDPOINT string = 'https://${account.name}.services.ai.azure.com/api/projects/${project.name}'

output MODEL_ORCHESTRATOR string = gptOrchestrator
// The Intake & Drafting agent shares the gpt-5.4 orchestrator deployment (the
// highest-quota flagship in the project). Clause & Risk runs on gpt-5.6-sol.
output MODEL_DRAFTING string = gptOrchestrator
output MODEL_CLAUSE_RISK string = gpt56sol
output MODEL_RENEWAL string = gptMini

output AZURE_SEARCH_ENDPOINT string = 'https://${search.name}.search.windows.net'
output AZURE_SEARCH_INDEX string = searchIndexName
output AZURE_SEARCH_CONNECTION_NAME string = searchConnectionName

// Empty unless Bing was provisioned — build_web_search_tool() treats an empty
// value as "web search off", so the Clause & Risk agent stays corpus-only.
output AZURE_BING_CONNECTION_NAME string = wantBing ? bingConnectionName : ''

#disable-next-line outputs-should-not-contain-secrets
output APPLICATIONINSIGHTS_CONNECTION_STRING string = appInsights.properties.ConnectionString
output AZURE_TRACING_GEN_AI_CONTENT_RECORDING_ENABLED string = 'true'

#disable-next-line outputs-should-not-contain-secrets BCP318
output AZURE_SQL_CONNECTION_STRING string = wantSql ? 'Driver={ODBC Driver 18 for SQL Server};Server=tcp:${sqlServer.properties.fullyQualifiedDomainName},1433;Database=clmdb;Uid=clmadmin;Pwd=${sqlAdminPassword};Encrypt=yes;TrustServerCertificate=no;' : ''
