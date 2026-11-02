@description('Approved region. No automatic fallback is performed.')
param location string = resourceGroup().location

@minLength(12)
@maxLength(12)
param resourceSuffix string

@minLength(1)
param participantObjectIds array

param chatModelName string = 'gpt-5.4-mini'
param chatModelVersion string = '2026-03-17'
param chatDeploymentName string = 'gpt-5.4-mini'
param embeddingDeploymentName string = 'text-embedding-3-large'

@description('Full-size chat model for the Content Understanding call center analyzer (Challenge 6).')
param analysisModelName string = 'gpt-5.4'
param analysisModelVersion string = '2026-03-05'
param analysisDeploymentName string = 'gpt-5.4'

@description('Review processing geography and model availability before approving deployment.')
param modelSku string = 'GlobalStandard'

@minValue(1)
param chatCapacity int = 200

@minValue(1)
param embeddingCapacity int = 50

@minValue(1)
param analysisCapacity int = 30

@description('Tags for the storage account. The default exempts it from tenant automation that disables public network access.')
param storageTags object = { SecurityControl: 'Ignore' }

var foundryName = 'aicontact${resourceSuffix}'
var projectName = 'contact-center'
var blobContributor = 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
var blobReader = '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1'
var blobOwner = 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b'
var searchWriter = '8ebe5a00-799e-43f5-93ac-243d3dce84a7'
var searchReader = '1407120a-92aa-4202-b7e9-c0e197c71c8f'
var searchManager = '7ca78c08-252a-4471-8644-bb5ff32d4ba0'
var foundryUser = '53ca6127-db72-4b80-b1b0-d745d6d5456d'
var foundryProjectManager = 'eadc314b-1a2d-4efa-be10-5d325db5065e'
var modelUser = '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd'
var cognitiveServicesUser = 'a97b65f3-24c7-4388-baec-2e87135dc908'
var logAnalyticsReader = '73c42c96-874c-492b-b04d-ab87d138a893'
// cu-projects holds the Content Understanding Studio project files (Challenge 6).
var containers = ['knowledge', 'insights', 'calls', 'evaluation', 'crm-state', 'crm-package', 'cu-projects']

resource logs 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: 'log-contact-${resourceSuffix}'
  location: location
  properties: {
    retentionInDays: 30
    sku: { name: 'PerGB2018' }
  }
}

resource insights 'Microsoft.Insights/components@2020-02-02' = {
  name: 'appi-contact-${resourceSuffix}'
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logs.id
  }
}

resource foundry 'Microsoft.CognitiveServices/accounts@2025-06-01' = {
  name: foundryName
  location: location
  kind: 'AIServices'
  identity: { type: 'SystemAssigned' }
  sku: { name: 'S0' }
  properties: {
    allowProjectManagement: true
    customSubDomainName: foundryName
    disableLocalAuth: true
    publicNetworkAccess: 'Enabled'
  }
}

resource project 'Microsoft.CognitiveServices/accounts/projects@2025-06-01' = {
  parent: foundry
  name: projectName
  location: location
  identity: { type: 'SystemAssigned' }
  properties: {
    displayName: 'Contact Center'
    description: 'Contact center MicroHack (fictional training data only)'
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

resource embedding 'Microsoft.CognitiveServices/accounts/deployments@2025-06-01' = {
  parent: foundry
  name: embeddingDeploymentName
  dependsOn: [chat]
  sku: { name: modelSku, capacity: embeddingCapacity }
  properties: {
    model: { format: 'OpenAI', name: 'text-embedding-3-large', version: '1' }
    versionUpgradeOption: 'NoAutoUpgrade'
  }
}

// The Content Understanding call center analyzer needs a full-size chat model; the mini model is not offered for it.
resource analysis 'Microsoft.CognitiveServices/accounts/deployments@2025-06-01' = {
  parent: foundry
  name: analysisDeploymentName
  dependsOn: [embedding]
  sku: { name: modelSku, capacity: analysisCapacity }
  properties: {
    model: { format: 'OpenAI', name: analysisModelName, version: analysisModelVersion }
    versionUpgradeOption: 'NoAutoUpgrade'
  }
}

// Agent traces (the Traces tab) are stored in Application Insights, connected to the project.
resource tracing 'Microsoft.CognitiveServices/accounts/projects/connections@2025-06-01' = {
  parent: project
  name: 'appinsights'
  dependsOn: [analysis]
  properties: {
    category: 'AppInsights'
    target: insights.id
    authType: 'ApiKey'
    isSharedToAll: true
    credentials: { key: insights.properties.ConnectionString }
    metadata: { ApiType: 'Azure', ResourceId: insights.id }
  }
}

resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: 'stcontact${resourceSuffix}'
  location: location
  // Some managed tenants disable public access on new storage accounts unless this tag is set.
  // Cloud Shell, the Search indexer and the CRM reach storage over the public endpoint with Entra ID.
  tags: storageTags
  kind: 'StorageV2'
  sku: { name: 'Standard_LRS' }
  properties: {
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
  }
}

resource blobs 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  parent: storage
  name: 'default'
  properties: {
    deleteRetentionPolicy: { enabled: true, days: 7 }
  }
}

resource blobContainers 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = [for name in containers: {
  parent: blobs
  name: name
  properties: { publicAccess: 'None' }
}]

resource search 'Microsoft.Search/searchServices@2025-05-01' = {
  name: 'search-contact-${resourceSuffix}'
  location: location
  identity: { type: 'SystemAssigned' }
  sku: { name: 'basic' }
  properties: {
    replicaCount: 1
    partitionCount: 1
    hostingMode: 'Default'
    disableLocalAuth: true
    publicNetworkAccess: 'enabled'
    semanticSearch: 'free'
  }
}

// The mock CRM: a dependency-free Python WSGI app on Azure Functions Flex Consumption (serverless,
// no App Service plan quota needed). deploy-lab.ps1 publishes the code with an Entra token.
resource plan 'Microsoft.Web/serverfarms@2024-04-01' = {
  name: 'plan-contact-${resourceSuffix}'
  location: location
  kind: 'functionapp'
  sku: { name: 'FC1', tier: 'FlexConsumption' }
  properties: { reserved: true }
}

resource crm 'Microsoft.Web/sites@2024-04-01' = {
  name: 'crm-contact-${resourceSuffix}'
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
          value: '${storage.properties.primaryEndpoints.blob}crm-package'
          authentication: { type: 'SystemAssignedIdentity' }
        }
      }
      scaleAndConcurrency: { maximumInstanceCount: 40, instanceMemoryMB: 2048 }
      runtime: { name: 'python', version: '3.12' }
    }
    siteConfig: {
      minTlsVersion: '1.2'
      ftpsState: 'Disabled'
      appSettings: [
        { name: 'AzureWebJobsStorage__accountName', value: storage.name }
        { name: 'STORAGE_ACCOUNT', value: storage.name }
        { name: 'APPLICATIONINSIGHTS_CONNECTION_STRING', value: insights.properties.ConnectionString }
      ]
    }
  }
  dependsOn: [blobContainers]
}

resource crmFtp 'Microsoft.Web/sites/basicPublishingCredentialsPolicies@2024-04-01' = {
  parent: crm
  name: 'ftp'
  properties: { allow: false }
}

resource crmScm 'Microsoft.Web/sites/basicPublishingCredentialsPolicies@2024-04-01' = {
  parent: crm
  name: 'scm'
  properties: { allow: false }
}

// The Functions host keeps its leases in storage, so it needs Blob Data Owner; the CRM state uses the same role.
resource crmStorage 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storage.id, crm.id, blobOwner)
  scope: storage
  properties: { principalId: crm.identity.principalId, principalType: 'ServicePrincipal', roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', blobOwner) }
}
resource participantFoundry 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for id in participantObjectIds: {
  name: guid(project.id, id, foundryUser)
  scope: project
  properties: { principalId: id, principalType: 'User', roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', foundryUser) }
}]

// Lets participants add knowledge and tool connections to their own project.
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

// Content Understanding and voice sessions use the account's data plane.
resource participantCognitive 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for id in participantObjectIds: {
  name: guid(foundry.id, id, cognitiveServicesUser)
  scope: foundry
  properties: { principalId: id, principalType: 'User', roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', cognitiveServicesUser) }
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

resource participantBlobs 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for id in participantObjectIds: {
  name: guid(storage.id, id, blobContributor)
  scope: storage
  properties: { principalId: id, principalType: 'User', roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', blobContributor) }
}]

resource participantSearchData 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for id in participantObjectIds: {
  name: guid(search.id, id, searchWriter)
  scope: search
  properties: { principalId: id, principalType: 'User', roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', searchWriter) }
}]

resource participantSearchConfig 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for id in participantObjectIds: {
  name: guid(search.id, id, searchManager)
  scope: search
  properties: { principalId: id, principalType: 'User', roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', searchManager) }
}]

// Search reads the knowledge and insights containers and calls the embedding model while indexing.
resource searchStorage 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storage.id, search.id, blobReader)
  scope: storage
  properties: { principalId: search.identity.principalId, principalType: 'ServicePrincipal', roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', blobReader) }
}

resource searchModel 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(foundry.id, search.id, modelUser)
  scope: foundry
  properties: { principalId: search.identity.principalId, principalType: 'ServicePrincipal', roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', modelUser) }
}

// Foundry IQ connects to Search with the project managed identity (API keys are disabled).
resource projectSearchReader 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(search.id, project.id, searchReader)
  scope: search
  properties: { principalId: project.identity.principalId, principalType: 'ServicePrincipal', roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', searchReader) }
}

resource projectSearchManager 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(search.id, project.id, searchManager)
  scope: search
  properties: { principalId: project.identity.principalId, principalType: 'ServicePrincipal', roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', searchManager) }
}

resource projectSearchWriter 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(search.id, project.id, searchWriter)
  scope: search
  properties: { principalId: project.identity.principalId, principalType: 'ServicePrincipal', roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', searchWriter) }
}

resource projectModel 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(foundry.id, project.id, modelUser)
  scope: foundry
  properties: { principalId: project.identity.principalId, principalType: 'ServicePrincipal', roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', modelUser) }
}

// Content Understanding reads recorded calls from storage with the account identity.
resource foundryStorage 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storage.id, foundry.id, blobReader)
  scope: storage
  properties: { principalId: foundry.identity.principalId, principalType: 'ServicePrincipal', roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', blobReader) }
}

output FoundryAccountName string = foundry.name
output FoundryProjectEndpoint string = 'https://${foundry.name}.services.ai.azure.com/api/projects/${project.name}'
output ModelDeploymentName string = chat.name
output EmbeddingDeploymentName string = embedding.name
output AnalysisModelDeploymentName string = analysis.name
output StorageAccountName string = storage.name
output SearchServiceName string = search.name
output SearchEndpoint string = 'https://${search.name}.search.windows.net'
output CrmWebAppName string = crm.name
output CrmUrl string = 'https://${crm.properties.defaultHostName}'
output ApplicationInsightsName string = insights.name
