@description('Approved region for Foundry, storage and the back-office app. Must support the Microsoft Copilot harness. No automatic fallback is performed.')
param location string = resourceGroup().location

@description('Region for the Playwright workspace that runs browser sessions. Browser Automation is offered in fewer regions than Foundry; West Europe may refuse new workspaces in some subscriptions.')
param browserLocation string = 'switzerlandnorth'

@minLength(12)
@maxLength(12)
param resourceSuffix string

@minLength(1)
param participantObjectIds array

@description('Model for the agents. Must support reasoning and tool calling.')
param chatModelName string = 'gpt-5.4-mini'
param chatModelVersion string = '2026-03-17'
param chatDeploymentName string = 'gpt-5.4-mini'

@description('Second model, used in Challenge 6 to compare quality, time and cost.')
param compareModelName string = 'gpt-5.4'
param compareModelVersion string = '2026-03-05'
param compareDeploymentName string = 'gpt-5.4'

@description('Review processing geography and model availability before approving deployment.')
param modelSku string = 'GlobalStandard'

@minValue(1)
param chatCapacity int = 200

@minValue(1)
param compareCapacity int = 150

@description('Tags for the storage account. The default exempts it from tenant automation that disables public network access.')
param storageTags object = { SecurityControl: 'Ignore' }

@secure()
@description('API key for the ERP. Generated per lab by deploy-lab.ps1; stored only in the app setting and the Foundry connection.')
param erpApiKey string

var foundryName = 'aifrontier${resourceSuffix}'
var projectName = 'frontier-operations'
var blobContributor = 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
var blobOwner = 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b'
var foundryUser = '53ca6127-db72-4b80-b1b0-d745d6d5456d'
var foundryProjectManager = 'eadc314b-1a2d-4efa-be10-5d325db5065e'
var modelUser = '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd'
var logAnalyticsReader = '73c42c96-874c-492b-b04d-ab87d138a893'
var playwrightContributor = '78cf819f-0969-4ebe-8759-015c6efcd5bf'
var rbacAdministrator = 'f58310d9-a9f6-439a-9e8d-f62e7b41a168'
var containers = ['packs', 'ops-state', 'app-package']

// ---------------------------------------------------------------- monitoring

resource logs 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: 'log-frontier-${resourceSuffix}'
  location: location
  properties: {
    retentionInDays: 30
    sku: { name: 'PerGB2018' }
  }
}

resource insights 'Microsoft.Insights/components@2020-02-02' = {
  name: 'appi-frontier-${resourceSuffix}'
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logs.id
  }
}

// ---------------------------------------------------------------- Foundry

resource foundry 'Microsoft.CognitiveServices/accounts@2025-06-01' = {
  name: foundryName
  location: location
  kind: 'AIServices'
  sku: { name: 'S0' }
  identity: { type: 'SystemAssigned' }
  properties: {
    customSubDomainName: foundryName
    allowProjectManagement: true
    publicNetworkAccess: 'Enabled'
    disableLocalAuth: true
  }
}

resource project 'Microsoft.CognitiveServices/accounts/projects@2025-06-01' = {
  parent: foundry
  name: projectName
  location: location
  identity: { type: 'SystemAssigned' }
  properties: {
    displayName: 'Frontier Operations'
    description: 'Frontier Operations MicroHack (fictional training data only)'
  }
}

// Foundry accepts one change per account at a time: create the project, then each model.
resource chat 'Microsoft.CognitiveServices/accounts/deployments@2025-06-01' = {
  parent: foundry
  name: chatDeploymentName
  dependsOn: [project]
  sku: { name: modelSku, capacity: chatCapacity }
  properties: {
    model: { format: 'OpenAI', name: chatModelName, version: chatModelVersion }
    versionUpgradeOption: 'NoAutoUpgrade'
  }
}

resource compare 'Microsoft.CognitiveServices/accounts/deployments@2025-06-01' = {
  parent: foundry
  name: compareDeploymentName
  dependsOn: [chat]
  sku: { name: modelSku, capacity: compareCapacity }
  properties: {
    model: { format: 'OpenAI', name: compareModelName, version: compareModelVersion }
    versionUpgradeOption: 'NoAutoUpgrade'
  }
}

// Agent traces (the Traces tab) are stored in Application Insights, connected to the project.
resource tracing 'Microsoft.CognitiveServices/accounts/projects/connections@2025-06-01' = {
  parent: project
  name: 'appinsights'
  dependsOn: [compare]
  properties: {
    category: 'AppInsights'
    target: insights.id
    authType: 'ApiKey'
    isSharedToAll: true
    credentials: { key: insights.properties.ConnectionString }
    metadata: { ApiType: 'Azure', ResourceId: insights.id }
  }
}

// The ERP's API key lives only here and in the app's settings. Agents use it through the OpenAPI tool.
resource erpConnection 'Microsoft.CognitiveServices/accounts/projects/connections@2025-06-01' = {
  parent: project
  name: 'erp'
  dependsOn: [tracing]
  properties: {
    category: 'CustomKeys'
    target: 'https://${app.properties.defaultHostName}'
    authType: 'CustomKeys'
    isSharedToAll: true
    credentials: { keys: { 'x-api-key': erpApiKey } }
    metadata: {}
  }
}

// ---------------------------------------------------------------- browser automation

resource browser 'Microsoft.LoadTestService/playwrightWorkspaces@2025-09-01' = {
  name: 'pw-frontier-${resourceSuffix}'
  location: browserLocation
  properties: {
    localAuth: 'Disabled'
    regionalAffinity: 'Disabled'
  }
}

var browserMcpEndpoint = '${replace(browser.properties.dataplaneUri, '.api.playwright.microsoft.com', '.mcp.playwright.microsoft.com')}/mcp'

// Browser Automation reaches the Playwright workspace with the project's managed identity.
resource browserConnection 'Microsoft.CognitiveServices/accounts/projects/connections@2025-06-01' = {
  parent: project
  name: 'browser'
  dependsOn: [erpConnection]
  properties: {
    category: 'PlaywrightWorkspace'
    target: browserMcpEndpoint
    #disable-next-line BCP036 // The service accepts ProjectManagedIdentity; the type definitions are behind.
    authType: 'ProjectManagedIdentity'
    audience: 'https://mcp.playwright.microsoft.com'
    isSharedToAll: true
    // The portal treats a Playwright connection without the workspace's resource ID as a deprecated preview connection.
    metadata: {
      resourceId: browser.id
      enableRecording: 'false'
    }
  }
}

resource projectBrowser 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(browser.id, project.id, playwrightContributor)
  scope: browser
  properties: { principalId: project.identity.principalId, principalType: 'ServicePrincipal', roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', playwrightContributor) }
}

// ---------------------------------------------------------------- storage

// Some managed tenants disable public access on new storage accounts unless this tag is set.
// Cloud Shell and the back-office app reach storage over the public endpoint with Entra ID.
resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: 'stfrontier${resourceSuffix}'
  location: location
  kind: 'StorageV2'
  sku: { name: 'Standard_LRS' }
  tags: storageTags
  properties: {
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false
    supportsHttpsTrafficOnly: true
    publicNetworkAccess: 'Enabled'
  }
}

resource blobs 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  parent: storage
  name: 'default'
}

resource blobContainers 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = [for name in containers: {
  parent: blobs
  name: name
  properties: { publicAccess: 'None' }
}]

// ---------------------------------------------------------------- back-office app (ERP API + partner portal)

// A dependency-free Python WSGI app on Azure Functions Flex Consumption (serverless,
// no App Service plan quota needed). deploy-lab.ps1 publishes the code with an Entra token.
resource plan 'Microsoft.Web/serverfarms@2024-04-01' = {
  name: 'plan-frontier-${resourceSuffix}'
  location: location
  kind: 'functionapp'
  sku: { name: 'FC1', tier: 'FlexConsumption' }
  properties: { reserved: true }
}

resource app 'Microsoft.Web/sites@2024-04-01' = {
  name: 'ops-frontier-${resourceSuffix}'
  location: location
  kind: 'functionapp,linux'
  identity: { type: 'SystemAssigned' }
  properties: {
    serverFarmId: plan.id
    httpsOnly: true
    functionAppConfig: {
      deployment: {
        storage: {
          type: 'blobContainer'
          value: '${storage.properties.primaryEndpoints.blob}app-package'
          authentication: { type: 'SystemAssignedIdentity' }
        }
      }
      scaleAndConcurrency: { maximumInstanceCount: 40, instanceMemoryMB: 2048 }
      runtime: { name: 'python', version: '3.12' }
    }
    siteConfig: {
      minTlsVersion: '1.2'
      appSettings: [
        { name: 'AzureWebJobsStorage__accountName', value: storage.name }
        { name: 'STORAGE_ACCOUNT', value: storage.name }
        { name: 'ERP_API_KEY', value: erpApiKey }
        { name: 'APPLICATIONINSIGHTS_CONNECTION_STRING', value: insights.properties.ConnectionString }
      ]
    }
  }
}

resource appFtp 'Microsoft.Web/sites/basicPublishingCredentialsPolicies@2024-04-01' = {
  parent: app
  name: 'ftp'
  properties: { allow: false }
}

resource appScm 'Microsoft.Web/sites/basicPublishingCredentialsPolicies@2024-04-01' = {
  parent: app
  name: 'scm'
  properties: { allow: false }
}

// The Functions host keeps its leases in storage, so it needs Blob Data Owner; the app state uses the same role.
resource appStorage 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storage.id, app.id, blobOwner)
  scope: storage
  properties: { principalId: app.identity.principalId, principalType: 'ServicePrincipal', roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', blobOwner) }
}

// ---------------------------------------------------------------- participant roles

resource participantFoundry 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for id in participantObjectIds: {
  name: guid(project.id, id, foundryUser)
  scope: project
  properties: { principalId: id, principalType: 'User', roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', foundryUser) }
}]

// Lets participants add tool connections, toolboxes and guardrails to their own project.
resource participantProjectManager 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for id in participantObjectIds: {
  name: guid(project.id, id, foundryProjectManager)
  scope: project
  properties: { principalId: id, principalType: 'User', roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', foundryProjectManager) }
}]

resource participantModels 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for id in participantObjectIds: {
  name: guid(foundry.id, id, modelUser)
  scope: foundry
  properties: { principalId: id, principalType: 'User', roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', modelUser) }
}]

// A harness agent returns files through its own identity, which needs Foundry User on the project.
// Participants may grant exactly that role, on their own project, and nothing else.
resource participantGrantAgents 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for id in participantObjectIds: {
  name: guid(project.id, id, rbacAdministrator)
  scope: project
  properties: {
    principalId: id
    principalType: 'User'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', rbacAdministrator)
    conditionVersion: '2.0'
    condition: '((!(ActionMatches{\'Microsoft.Authorization/roleAssignments/write\'})) OR (@Request[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAnyValues:GuidEquals {${foundryUser}})) AND ((!(ActionMatches{\'Microsoft.Authorization/roleAssignments/delete\'})) OR (@Resource[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAnyValues:GuidEquals {${foundryUser}}))'
  }
}]

resource participantBlobs 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for id in participantObjectIds: {
  name: guid(storage.id, id, blobContributor)
  scope: storage
  properties: { principalId: id, principalType: 'User', roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', blobContributor) }
}]

// The Traces tab queries Application Insights and its Log Analytics workspace as the signed-in user.
resource participantTraces 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for id in participantObjectIds: {
  name: guid(insights.id, id, logAnalyticsReader)
  scope: insights
  properties: { principalId: id, principalType: 'User', roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', logAnalyticsReader) }
}]

resource participantLogs 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for id in participantObjectIds: {
  name: guid(logs.id, id, logAnalyticsReader)
  scope: logs
  properties: { principalId: id, principalType: 'User', roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', logAnalyticsReader) }
}]

// Lets participants open Live View and Take control of browser sessions.
resource participantBrowser 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for id in participantObjectIds: {
  name: guid(browser.id, id, playwrightContributor)
  scope: browser
  properties: { principalId: id, principalType: 'User', roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', playwrightContributor) }
}]

// ---------------------------------------------------------------- outputs

output FoundryAccountName string = foundry.name
output FoundryProjectEndpoint string = 'https://${foundry.name}.services.ai.azure.com/api/projects/${project.name}'
output FoundryProjectResourceId string = project.id
output ModelDeploymentName string = chat.name
output CompareModelDeploymentName string = compare.name
output StorageAccountName string = storage.name
output BackOfficeAppName string = app.name
output BackOfficeUrl string = 'https://${app.properties.defaultHostName}'
output PlaywrightWorkspaceName string = browser.name
output BrowserConnectionName string = browserConnection.name
output ErpConnectionName string = erpConnection.name
output ApplicationInsightsName string = insights.name
