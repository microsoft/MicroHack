// ==========================================================================
// Foundry CLM Microhack — main deployment (subscription scope)
// Entry point for `azd up`. Creates the resource group and provisions all
// resources via the resources module.
// ==========================================================================
targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the azd environment (used to name the resource group + resources).')
param environmentName string

@minLength(1)
@description('Azure region for all resources. Must offer gpt-5.4, gpt-4.1-mini and gpt-5.6-sol.')
param location string

@description('Object id of the user/service principal running the deployment (azd provides AZURE_PRINCIPAL_ID). Used for RBAC.')
param principalId string = ''

@description('Principal type for RBAC assignments: User (interactive azd) or ServicePrincipal (CI).')
@allowed([ 'User', 'ServicePrincipal' ])
param principalType string = 'User'

@description('Provision the optional Azure SQL backing store for the contract-status tool ("true"/"false").')
param deploySql string = 'false'

@description('Admin password for the optional Azure SQL server (required when deploySql is true).')
@secure()
param sqlAdminPassword string = ''

@description('Provision the optional Grounding with Bing Search resource + project connection for web grounding ("true"/"false").')
param deployBing string = 'false'

var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))
var tags = {
  'azd-env-name': environmentName
  project: 'foundry-clm-microhack'
}

resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: 'rg-clm-microhack'
  location: location
  tags: tags
}

module resources 'resources.bicep' = {
  name: 'clm-resources'
  scope: rg
  params: {
    location: location
    resourceToken: resourceToken
    principalId: principalId
    principalType: principalType
    deploySql: deploySql
    sqlAdminPassword: sqlAdminPassword
    deployBing: deployBing
    tags: tags
  }
}

// ---- Outputs (surfaced by `azd env get-values` for the postprovision hook) --
output AZURE_LOCATION string = location
output AZURE_RESOURCE_GROUP string = rg.name

output AZURE_AI_PROJECT_ENDPOINT string = resources.outputs.AZURE_AI_PROJECT_ENDPOINT

output MODEL_ORCHESTRATOR string = resources.outputs.MODEL_ORCHESTRATOR
output MODEL_DRAFTING string = resources.outputs.MODEL_DRAFTING
output MODEL_CLAUSE_RISK string = resources.outputs.MODEL_CLAUSE_RISK
output MODEL_RENEWAL string = resources.outputs.MODEL_RENEWAL

output AZURE_SEARCH_ENDPOINT string = resources.outputs.AZURE_SEARCH_ENDPOINT
output AZURE_SEARCH_INDEX string = resources.outputs.AZURE_SEARCH_INDEX
output AZURE_SEARCH_CONNECTION_NAME string = resources.outputs.AZURE_SEARCH_CONNECTION_NAME
output AZURE_BING_CONNECTION_NAME string = resources.outputs.AZURE_BING_CONNECTION_NAME

#disable-next-line outputs-should-not-contain-secrets
output APPLICATIONINSIGHTS_CONNECTION_STRING string = resources.outputs.APPLICATIONINSIGHTS_CONNECTION_STRING
output AZURE_TRACING_GEN_AI_CONTENT_RECORDING_ENABLED string = resources.outputs.AZURE_TRACING_GEN_AI_CONTENT_RECORDING_ENABLED

#disable-next-line outputs-should-not-contain-secrets
output AZURE_SQL_CONNECTION_STRING string = resources.outputs.AZURE_SQL_CONNECTION_STRING
