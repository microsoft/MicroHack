@description('Azure region used for all regional resources.')
param location string = resourceGroup().location

@description('Stable suffix shared by globally unique lab resource names.')
@minLength(12)
@maxLength(12)
param resourceSuffix string

@description('Microsoft Entra object ID of the participant who receives lab access.')
param userObjectId string

@description('SKU for the Azure AI Search service.')
@allowed([
  'basic'
  'standard'
])
param searchServiceSku string = 'basic'

var storageAccountName = 'stpdm${resourceSuffix}'
var logAnalyticsWorkspaceName = 'log-pdm-${resourceSuffix}'
var applicationInsightsName = 'appi-pdm-${resourceSuffix}'
var searchServiceName = 'srch-pdm-${resourceSuffix}'
var containerRegistryName = 'acrpdm${resourceSuffix}'
var containerAppsEnvironmentName = 'cae-pdm-${resourceSuffix}'
var cosmosDbAccountName = 'cosmos-pdm-${resourceSuffix}'
var apimName = 'apim-pdm-${resourceSuffix}'
var foundryAccountName = 'aipdm${resourceSuffix}'
var foundryProjectName = 'predictive-maintenance'
var cosmosDatabaseName = 'FactoryOpsDB'
var machineWikiContainerName = 'machine-wiki'

var cognitiveServicesUserRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'a97b65f3-24c7-4388-baec-2e87135dc908')
var searchServiceContributorRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7ca78c08-252a-4471-8644-bb5ff32d4ba0')
var searchIndexDataReaderRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '1407120a-92aa-4202-b7e9-c0e197c71c8f')
var monitoringReaderRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '43d0d8ad-25c7-4714-9337-8ba259a9fe05')
var foundryUserRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '53ca6127-db72-4b80-b1b0-d745d6d5456d')
var storageBlobDataContributorRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe')
var cosmosDbDataContributorRoleId = '00000000-0000-0000-0000-000000000002'

// The 10 Cosmos containers seeded with sample factory-operations data.
// Matches challenge-0/seed-data.sh's `containers_config` in the source hack.
var cosmosContainers = [
  { name: 'Machines', partitionKeyPath: '/type' }
  { name: 'Thresholds', partitionKeyPath: '/machineType' }
  { name: 'Telemetry', partitionKeyPath: '/machineId', defaultTtl: 2592000 } // 30 days
  { name: 'KnowledgeBase', partitionKeyPath: '/machineType' }
  { name: 'PartsInventory', partitionKeyPath: '/category' }
  { name: 'Technicians', partitionKeyPath: '/department' }
  { name: 'WorkOrders', partitionKeyPath: '/status' }
  { name: 'MaintenanceHistory', partitionKeyPath: '/machineId' }
  { name: 'MaintenanceWindows', partitionKeyPath: '/isAvailable' }
  { name: 'Suppliers', partitionKeyPath: '/category' }
]

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    allowBlobPublicAccess: true
    publicNetworkAccess: 'Enabled'
    allowSharedKeyAccess: true
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
  }
}

resource blobServices 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  parent: storageAccount
  name: 'default'
}

resource machineWikiContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: blobServices
  name: machineWikiContainerName
  properties: {
    publicAccess: 'None'
  }
}

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2021-06-01' = {
  name: logAnalyticsWorkspaceName
  location: location
  properties: {
    retentionInDays: 30
    features: {
      searchVersion: 1
    }
    sku: {
      name: 'PerGB2018'
    }
  }
}

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: applicationInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalyticsWorkspace.id
  }
}

resource cosmosDbAccount 'Microsoft.DocumentDB/databaseAccounts@2023-04-15' = {
  name: cosmosDbAccountName
  location: location
  kind: 'GlobalDocumentDB'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
    }
    locations: [
      {
        locationName: location
        failoverPriority: 0
        isZoneRedundant: false
      }
    ]
    databaseAccountOfferType: 'Standard'
    enableAutomaticFailover: false
    enableMultipleWriteLocations: false
    publicNetworkAccess: 'Enabled'
    disableLocalAuth: false
    capabilities: [
      {
        name: 'EnableServerless'
      }
    ]
  }
}

resource cosmosDatabase 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2023-04-15' = {
  parent: cosmosDbAccount
  name: cosmosDatabaseName
  properties: {
    resource: {
      id: cosmosDatabaseName
    }
  }
}

resource cosmosContainerResources 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2023-04-15' = [
  for container in cosmosContainers: {
    parent: cosmosDatabase
    name: container.name
    properties: {
      resource: {
        id: container.name
        partitionKey: {
          paths: [container.partitionKeyPath]
          kind: 'Hash'
        }
        defaultTtl: contains(container, 'defaultTtl') ? container.defaultTtl : -1
      }
    }
  }
]

resource searchService 'Microsoft.Search/searchServices@2023-11-01' = {
  name: searchServiceName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  sku: {
    name: searchServiceSku
  }
  properties: {
    hostingMode: 'default'
    replicaCount: 1
    partitionCount: 1
    publicNetworkAccess: 'enabled'
    disableLocalAuth: false
    authOptions: {
      aadOrApiKey: {
        aadAuthFailureMode: 'http401WithBearerChallenge'
      }
    }
  }
}

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: containerRegistryName
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: true
    publicNetworkAccess: 'Enabled'
    networkRuleBypassOptions: 'AzureServices'
  }
}

// Stretch-goal target for Challenge 5: participants can optionally push their
// own container image here and deploy it to this environment. No container
// app is pre-created; participants create their own.
resource containerAppsEnvironment 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: containerAppsEnvironmentName
  location: location
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalyticsWorkspace.properties.customerId
        sharedKey: logAnalyticsWorkspace.listKeys().primarySharedKey
      }
    }
  }
}

resource aiFoundry 'Microsoft.CognitiveServices/accounts@2025-04-01-preview' = {
  name: foundryAccountName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  sku: {
    name: 'S0'
  }
  kind: 'AIServices'
  properties: {
    allowProjectManagement: true
    customSubDomainName: foundryAccountName
    disableLocalAuth: false
    publicNetworkAccess: 'Enabled'
    networkAcls: {
      defaultAction: 'Allow'
    }
  }
}

resource aiProject 'Microsoft.CognitiveServices/accounts/projects@2025-04-01-preview' = {
  parent: aiFoundry
  name: foundryProjectName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    description: 'Predictive Maintenance MicroHack project'
    displayName: 'Predictive Maintenance'
  }
  dependsOn: [
    applicationInsights
  ]
}

resource aiProjectAppInsightsConnection 'Microsoft.CognitiveServices/accounts/projects/connections@2025-04-01-preview' = {
  parent: aiProject
  name: applicationInsightsName
  properties: {
    authType: 'ApiKey'
    category: 'AppInsights'
    target: applicationInsights.id
    useWorkspaceManagedIdentity: false
    isSharedToAll: true
    credentials: {
      key: applicationInsights.properties.InstrumentationKey
    }
    metadata: {
      ApiType: 'Azure'
      ResourceId: applicationInsights.id
    }
  }
}

resource gpt5_4MiniDeployment 'Microsoft.CognitiveServices/accounts/deployments@2025-04-01-preview' = {
  parent: aiFoundry
  name: 'gpt-5.4-mini'
  sku: {
    capacity: 50
    name: 'GlobalStandard'
  }
  properties: {
    model: {
      name: 'gpt-5.4-mini'
      format: 'OpenAI'
      version: '2026-03-17'
    }
  }
}

resource gpt5_4Deployment 'Microsoft.CognitiveServices/accounts/deployments@2025-04-01-preview' = {
  parent: aiFoundry
  name: 'gpt-5.4'
  sku: {
    capacity: 50
    name: 'GlobalStandard'
  }
  properties: {
    model: {
      name: 'gpt-5.4'
      format: 'OpenAI'
      version: '2026-03-05'
    }
  }
  dependsOn: [
    gpt5_4MiniDeployment
  ]
}

resource textEmbeddingDeployment 'Microsoft.CognitiveServices/accounts/deployments@2025-04-01-preview' = {
  parent: aiFoundry
  name: 'text-embedding-3-large'
  sku: {
    capacity: 10
    name: 'Standard'
  }
  properties: {
    model: {
      name: 'text-embedding-3-large'
      format: 'OpenAI'
      version: '1'
    }
  }
  dependsOn: [
    gpt5_4Deployment
  ]
}

resource aiSearchConnection 'Microsoft.CognitiveServices/accounts/connections@2025-04-01-preview' = {
  parent: aiFoundry
  name: '${foundryAccountName}-aisearch'
  properties: {
    category: 'CognitiveSearch'
    target: 'https://${searchServiceName}.search.windows.net'
    authType: 'ApiKey'
    isSharedToAll: true
    credentials: {
      key: searchService.listAdminKeys().primaryKey
    }
    metadata: {
      ApiType: 'Azure'
      ResourceId: searchService.id
      location: location
    }
  }
}

resource apim 'Microsoft.ApiManagement/service@2023-03-01-preview' = {
  name: apimName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  sku: {
    name: 'BasicV2'
    capacity: 1
  }
  properties: {
    publisherEmail: 'admin@contoso.com'
    publisherName: 'Contoso'
  }
}

// --- Role assignments: system identities needed to run the platform ---

resource appInsightsMonitoringReaderForProject 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: applicationInsights
  name: guid(applicationInsights.id, aiProject.id, monitoringReaderRoleId)
  properties: {
    roleDefinitionId: monitoringReaderRoleId
    principalId: aiProject.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource searchCognitiveServicesUserForFoundry 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: aiFoundry
  name: guid(searchService.id, aiFoundry.id, cognitiveServicesUserRoleId, 'search-to-cognitive')
  properties: {
    roleDefinitionId: cognitiveServicesUserRoleId
    principalId: searchService.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource searchContributorForFoundry 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: searchService
  name: guid(searchService.id, aiFoundry.id, searchServiceContributorRoleId)
  properties: {
    roleDefinitionId: searchServiceContributorRoleId
    principalId: aiFoundry.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource searchContributorForProject 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: searchService
  name: guid(searchService.id, aiProject.id, searchServiceContributorRoleId)
  properties: {
    roleDefinitionId: searchServiceContributorRoleId
    principalId: aiProject.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource searchIndexDataReaderForProject 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: searchService
  name: guid(searchService.id, aiProject.id, searchIndexDataReaderRoleId)
  properties: {
    roleDefinitionId: searchIndexDataReaderRoleId
    principalId: aiProject.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource apimCosmosDataContributor 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2025-05-01-preview' = {
  parent: cosmosDbAccount
  name: guid(apim.id, cosmosDbAccount.id, cosmosDbDataContributorRoleId)
  properties: {
    roleDefinitionId: '${cosmosDbAccount.id}/sqlRoleDefinitions/${cosmosDbDataContributorRoleId}'
    principalId: apim.identity.principalId
    scope: cosmosDbAccount.id
  }
}

// --- Role assignments: participant access ---
// The lab resource group is deployed ahead of time by the platform, so the
// participant needs explicit data-plane RBAC for services that don't grant
// data access through subscription/resource-group Owner alone.

resource participantFoundryUser 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: aiProject
  name: guid(aiProject.id, userObjectId, foundryUserRoleId)
  properties: {
    roleDefinitionId: foundryUserRoleId
    principalId: userObjectId
    principalType: 'User'
  }
}

resource participantCosmosDataContributor 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2025-05-01-preview' = {
  parent: cosmosDbAccount
  name: guid(cosmosDbAccount.id, userObjectId, cosmosDbDataContributorRoleId)
  properties: {
    roleDefinitionId: '${cosmosDbAccount.id}/sqlRoleDefinitions/${cosmosDbDataContributorRoleId}'
    principalId: userObjectId
    scope: cosmosDbAccount.id
  }
}

resource participantStorageBlobDataContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: storageAccount
  name: guid(storageAccount.id, userObjectId, storageBlobDataContributorRoleId)
  properties: {
    roleDefinitionId: storageBlobDataContributorRoleId
    principalId: userObjectId
    principalType: 'User'
  }
}

// --- APIM: Machine API and Maintenance API, proxying Cosmos DB via APIM's managed identity ---
// These are static conversions of the inline XML policies generated by
// challenge-0/seed-data.sh in the source hack (function policy_query_all /
// policy_query_by_id), with the collection and field names substituted in.

var cosmosResourceAudience = 'https://${cosmosDbAccountName}.documents.azure.com'
var cosmosDataPlaneUrl = 'https://${cosmosDbAccountName}.documents.azure.com/'

// NOTE: Bicep triple-quoted (''') multi-line strings do NOT support ${...} string
// interpolation - any ${...} placeholders below are emitted as literal text. The
// placeholders are therefore substituted afterwards via nested replace() calls.
func cosmosQueryAllPolicy(resourceAudience string, dataPlaneUrl string, collection string) string => replace(replace(replace('''
<policies>
    <inbound>
        <base />
        <set-variable name="requestDateString" value="@(DateTime.UtcNow.ToString(&quot;r&quot;))" />
        <authentication-managed-identity resource="${resourceAudience}" output-token-variable-name="msi-access-token" ignore-error="false" />
        <send-request mode="new" response-variable-name="cosmosResponse" timeout="30">
            <set-url>@("${dataPlaneUrl}" + "dbs/FactoryOpsDB/colls/${collection}/docs")</set-url>
            <set-method>POST</set-method>
            <set-header name="Authorization" exists-action="override">
                <value>@("type=aad&amp;ver=1.0&amp;sig=" + (string)context.Variables["msi-access-token"])</value>
            </set-header>
            <set-header name="x-ms-date" exists-action="override">
                <value>@(context.Variables.GetValueOrDefault&lt;string&gt;("requestDateString"))</value>
            </set-header>
            <set-header name="x-ms-version" exists-action="override"><value>2018-12-31</value></set-header>
            <set-header name="x-ms-documentdb-isquery" exists-action="override"><value>true</value></set-header>
            <set-header name="x-ms-documentdb-query-enablecrosspartition" exists-action="override"><value>true</value></set-header>
            <set-header name="Content-Type" exists-action="override"><value>application/query+json</value></set-header>
            <set-header name="Accept" exists-action="override"><value>application/json</value></set-header>
            <set-body>@{
                return JsonConvert.SerializeObject(new {
                    query = "SELECT * FROM c",
                    parameters = new object[0]
                });
            }</set-body>
        </send-request>
        <choose>
            <when condition="@(((IResponse)context.Variables["cosmosResponse"]).StatusCode == 200)">
                <return-response>
                    <set-status code="200" reason="OK" />
                    <set-header name="Content-Type" exists-action="override"><value>application/json</value></set-header>
                    <set-body>@{
                        var response = ((IResponse)context.Variables["cosmosResponse"]).Body.As&lt;JObject&gt;();
                        return response["Documents"].ToString();
                    }</set-body>
                </return-response>
            </when>
            <otherwise>
                <return-response>
                    <set-status code="502" reason="Cosmos DB Query Failed" />
                    <set-header name="Content-Type" exists-action="override"><value>application/json</value></set-header>
                    <set-body>@{ return ((IResponse)context.Variables["cosmosResponse"]).Body.As&lt;string&gt;(); }</set-body>
                </return-response>
            </otherwise>
        </choose>
    </inbound>
    <backend><base /></backend>
    <outbound><base /></outbound>
    <on-error><base /></on-error>
</policies>
''', '\${resourceAudience}', resourceAudience), '\${dataPlaneUrl}', dataPlaneUrl), '\${collection}', collection)

func cosmosQueryByFieldPolicy(resourceAudience string, dataPlaneUrl string, collection string, paramName string, field string) string => replace(replace(replace(replace(replace('''
<policies>
    <inbound>
        <base />
        <set-variable name="requestDateString" value="@(DateTime.UtcNow.ToString(&quot;r&quot;))" />
        <authentication-managed-identity resource="${resourceAudience}" output-token-variable-name="msi-access-token" ignore-error="false" />
        <set-variable name="${paramName}" value="@(context.Request.MatchedParameters[&quot;${paramName}&quot;])" />
        <send-request mode="new" response-variable-name="cosmosResponse" timeout="30">
            <set-url>@("${dataPlaneUrl}" + "dbs/FactoryOpsDB/colls/${collection}/docs")</set-url>
            <set-method>POST</set-method>
            <set-header name="Authorization" exists-action="override">
                <value>@("type=aad&amp;ver=1.0&amp;sig=" + (string)context.Variables["msi-access-token"])</value>
            </set-header>
            <set-header name="x-ms-date" exists-action="override">
                <value>@(context.Variables.GetValueOrDefault&lt;string&gt;("requestDateString"))</value>
            </set-header>
            <set-header name="x-ms-version" exists-action="override"><value>2018-12-31</value></set-header>
            <set-header name="x-ms-documentdb-isquery" exists-action="override"><value>true</value></set-header>
            <set-header name="x-ms-documentdb-query-enablecrosspartition" exists-action="override"><value>true</value></set-header>
            <set-header name="Content-Type" exists-action="override"><value>application/query+json</value></set-header>
            <set-header name="Accept" exists-action="override"><value>application/json</value></set-header>
            <set-body>@{
                string v = context.Variables["${paramName}"] as string;
                return JsonConvert.SerializeObject(new {
                    query = "SELECT * FROM c WHERE c.${field} = @${paramName}",
                    parameters = new object[] { new { name = "@${paramName}", value = v } }
                });
            }</set-body>
        </send-request>
        <choose>
            <when condition="@(((IResponse)context.Variables["cosmosResponse"]).StatusCode == 200)">
                <return-response>
                    <set-status code="200" reason="OK" />
                    <set-header name="Content-Type" exists-action="override"><value>application/json</value></set-header>
                    <set-body>@{
                        var response = ((IResponse)context.Variables["cosmosResponse"]).Body.As&lt;JObject&gt;();
                        return response["Documents"].ToString();
                    }</set-body>
                </return-response>
            </when>
            <otherwise>
                <return-response>
                    <set-status code="502" reason="Cosmos DB Query Failed" />
                    <set-header name="Content-Type" exists-action="override"><value>application/json</value></set-header>
                    <set-body>@{ return ((IResponse)context.Variables["cosmosResponse"]).Body.As&lt;string&gt;(); }</set-body>
                </return-response>
            </otherwise>
        </choose>
    </inbound>
    <backend><base /></backend>
    <outbound><base /></outbound>
    <on-error><base /></on-error>
</policies>
''', '\${resourceAudience}', resourceAudience), '\${dataPlaneUrl}', dataPlaneUrl), '\${collection}', collection), '\${paramName}', paramName), '\${field}', field)

resource machineApi 'Microsoft.ApiManagement/service/apis@2023-03-01-preview' = {
  parent: apim
  name: 'machine-api'
  properties: {
    displayName: 'Machine API'
    description: 'Machines via Cosmos DB (APIM Managed Identity)'
    path: 'machine'
    protocols: ['https']
    subscriptionRequired: true
  }
}

resource machineApiListOperation 'Microsoft.ApiManagement/service/apis/operations@2023-03-01-preview' = {
  parent: machineApi
  name: 'list-machines'
  properties: {
    displayName: 'List Machines'
    description: 'Retrieves all machines from the factory operations database.'
    method: 'GET'
    urlTemplate: '/'
    responses: [
      { statusCode: 200, description: 'OK' }
    ]
  }
}

resource machineApiListPolicy 'Microsoft.ApiManagement/service/apis/operations/policies@2023-03-01-preview' = {
  parent: machineApiListOperation
  name: 'policy'
  properties: {
    format: 'rawxml'
    value: cosmosQueryAllPolicy(cosmosResourceAudience, cosmosDataPlaneUrl, 'Machines')
  }
}

resource machineApiGetOperation 'Microsoft.ApiManagement/service/apis/operations@2023-03-01-preview' = {
  parent: machineApi
  name: 'get-machine'
  properties: {
    displayName: 'Get Machine'
    description: 'Retrieves a specific machine by its unique identifier.'
    method: 'GET'
    urlTemplate: '/{id}'
    templateParameters: [
      { name: 'id', type: 'string', required: true }
    ]
    responses: [
      { statusCode: 200, description: 'OK' }
      { statusCode: 404, description: 'Not Found' }
    ]
  }
}

resource machineApiGetPolicy 'Microsoft.ApiManagement/service/apis/operations/policies@2023-03-01-preview' = {
  parent: machineApiGetOperation
  name: 'policy'
  properties: {
    format: 'rawxml'
    value: cosmosQueryByFieldPolicy(cosmosResourceAudience, cosmosDataPlaneUrl, 'Machines', 'id', 'id')
  }
}

resource maintenanceApi 'Microsoft.ApiManagement/service/apis@2023-03-01-preview' = {
  parent: apim
  name: 'maintenance-api'
  properties: {
    displayName: 'Maintenance API'
    description: 'Thresholds via Cosmos DB (APIM Managed Identity)'
    path: 'maintenance'
    protocols: ['https']
    subscriptionRequired: true
  }
}

resource maintenanceApiListOperation 'Microsoft.ApiManagement/service/apis/operations@2023-03-01-preview' = {
  parent: maintenanceApi
  name: 'list-thresholds'
  properties: {
    displayName: 'List Thresholds'
    description: 'Retrieves all operational thresholds for factory equipment.'
    method: 'GET'
    urlTemplate: '/'
    responses: [
      { statusCode: 200, description: 'OK' }
    ]
  }
}

resource maintenanceApiListPolicy 'Microsoft.ApiManagement/service/apis/operations/policies@2023-03-01-preview' = {
  parent: maintenanceApiListOperation
  name: 'policy'
  properties: {
    format: 'rawxml'
    value: cosmosQueryAllPolicy(cosmosResourceAudience, cosmosDataPlaneUrl, 'Thresholds')
  }
}

resource maintenanceApiGetOperation 'Microsoft.ApiManagement/service/apis/operations@2023-03-01-preview' = {
  parent: maintenanceApi
  name: 'get-threshold'
  properties: {
    displayName: 'Get Threshold'
    description: 'Retrieves operational thresholds for a specific machine type.'
    method: 'GET'
    urlTemplate: '/{machineType}'
    templateParameters: [
      { name: 'machineType', type: 'string', required: true }
    ]
    responses: [
      { statusCode: 200, description: 'OK' }
      { statusCode: 404, description: 'Not Found' }
    ]
  }
}

resource maintenanceApiGetPolicy 'Microsoft.ApiManagement/service/apis/operations/policies@2023-03-01-preview' = {
  parent: maintenanceApiGetOperation
  name: 'policy'
  properties: {
    format: 'rawxml'
    value: cosmosQueryByFieldPolicy(cosmosResourceAudience, cosmosDataPlaneUrl, 'Thresholds', 'machineType', 'machineType')
  }
}

output storageAccountName string = storageAccountName
output machineWikiContainerName string = machineWikiContainerName
output logAnalyticsWorkspaceName string = logAnalyticsWorkspaceName
output searchServiceName string = searchServiceName
output searchServiceEndpoint string = 'https://${searchServiceName}.search.windows.net/'
output aiFoundryHubName string = foundryAccountName
output aiFoundryProjectName string = foundryProjectName
output aiFoundryHubEndpoint string = 'https://ml.azure.com/home?wsid=${aiFoundry.id}'
output aiFoundryProjectEndpoint string = 'https://ai.azure.com/build/overview?wsid=${aiProject.id}'
output containerRegistryName string = containerRegistryName
output acrName string = containerRegistryName
output applicationInsightsName string = applicationInsightsName
output cosmosDbAccountName string = cosmosDbAccountName
output cosmosDbDatabaseName string = cosmosDatabaseName
output cosmosDbEndpoint string = cosmosDbAccount.properties.documentEndpoint
output containerAppEnvironmentName string = containerAppsEnvironmentName
output apimName string = apimName
output apimGatewayUrl string = apim.properties.gatewayUrl
