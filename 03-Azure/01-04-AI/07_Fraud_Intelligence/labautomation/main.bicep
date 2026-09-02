@description('Azure region used for all regional resources.')
param location string = resourceGroup().location

@description('Stable suffix shared by globally unique lab resource names.')
@minLength(12)
@maxLength(12)
param resourceSuffix string

@description('Microsoft Entra object ID of the participant who receives lab access.')
param userObjectId string

var logAnalyticsName = 'log-fraud-${resourceSuffix}'
var applicationInsightsName = 'appi-fraud-${resourceSuffix}'
var containerAppsEnvironmentName = 'cae-fraud-${resourceSuffix}'
var foundryAccountName = 'aifraud${resourceSuffix}'
var foundryProjectName = 'fraud-intelligence'
var cosmosAccountName = 'cosmosfraud${resourceSuffix}'
var foundryUserRoleDefinitionId = '53ca6127-db72-4b80-b1b0-d745d6d5456d'
var cosmosDataContributorRoleDefinitionId = '00000000-0000-0000-0000-000000000002'

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
	name: logAnalyticsName
	location: location
	properties: {
		publicNetworkAccessForIngestion: 'Enabled'
		publicNetworkAccessForQuery: 'Enabled'
		retentionInDays: 30
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
		Flow_Type: 'Bluefield'
		Request_Source: 'rest'
		WorkspaceResourceId: logAnalytics.id
		publicNetworkAccessForIngestion: 'Enabled'
		publicNetworkAccessForQuery: 'Enabled'
	}
}

resource containerAppsEnvironment 'Microsoft.App/managedEnvironments@2025-01-01' = {
	name: containerAppsEnvironmentName
	location: location
	properties: {
		appLogsConfiguration: {
			destination: 'log-analytics'
			logAnalyticsConfiguration: {
				customerId: logAnalytics.properties.customerId
				sharedKey: logAnalytics.listKeys().primarySharedKey
			}
		}
	}
}

resource alertManager 'Microsoft.App/containerApps@2025-01-01' = {
	name: 'alert-manager'
	location: location
	properties: {
		environmentId: containerAppsEnvironment.id
		configuration: {
			activeRevisionsMode: 'Single'
			ingress: {
				external: true
				allowInsecure: false
				targetPort: 8000
				transport: 'auto'
				traffic: [
					{
						latestRevision: true
						weight: 100
					}
				]
			}
		}
		template: {
			containers: [
				{
					name: 'alert-manager'
					image: 'ghcr.io/dsanchor/fraud-alert-manager:sha-e7c4ecc'
					resources: {
						cpu: json('0.5')
						memory: '1Gi'
					}
				}
			]
			scale: {
				minReplicas: 1
				maxReplicas: 1
			}
		}
	}
}

resource foundryAccount 'Microsoft.CognitiveServices/accounts@2025-06-01' = {
	name: foundryAccountName
	location: location
	kind: 'AIServices'
	identity: {
		type: 'SystemAssigned'
	}
	properties: {
		allowProjectManagement: true
		customSubDomainName: foundryAccountName
		disableLocalAuth: false
		publicNetworkAccess: 'Enabled'
		restrictOutboundNetworkAccess: false
	}
	sku: {
		name: 'S0'
	}
}

resource foundryProject 'Microsoft.CognitiveServices/accounts/projects@2025-06-01' = {
	parent: foundryAccount
	name: foundryProjectName
	location: location
	identity: {
		type: 'SystemAssigned'
	}
	properties: {
		description: 'Fraud Intelligence MicroHack project'
		displayName: 'Fraud Intelligence'
	}
}

resource embeddingDeployment 'Microsoft.CognitiveServices/accounts/deployments@2025-06-01' = {
	parent: foundryAccount
	name: 'text-embedding-3-large'
	dependsOn: [
		chatDeployment
	]
	properties: {
		model: {
			format: 'OpenAI'
			name: 'text-embedding-3-large'
			version: '1'
		}
		versionUpgradeOption: 'OnceNewDefaultVersionAvailable'
	}
	sku: {
		name: 'GlobalStandard'
		capacity: 100
	}
}

resource chatDeployment 'Microsoft.CognitiveServices/accounts/deployments@2025-06-01' = {
	parent: foundryAccount
	name: 'gpt-5.6-luna'
	properties: {
		model: {
			format: 'OpenAI'
			name: 'gpt-5.6-luna'
			version: '2026-07-09'
		}
		versionUpgradeOption: 'OnceNewDefaultVersionAvailable'
	}
	sku: {
		name: 'GlobalStandard'
		capacity: 150
	}
}

resource participantFoundryUser 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
	name: guid(foundryProject.id, userObjectId, foundryUserRoleDefinitionId)
	scope: foundryProject
	properties: {
		principalId: userObjectId
		principalType: 'User'
		roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', foundryUserRoleDefinitionId)
	}
}

resource projectIdentityFoundryUser 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
	name: guid(foundryAccount.id, foundryProject.id, foundryUserRoleDefinitionId)
	scope: foundryAccount
	properties: {
		principalId: foundryProject.identity.principalId
		principalType: 'ServicePrincipal'
		roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', foundryUserRoleDefinitionId)
	}
}

resource cosmosAccount 'Microsoft.DocumentDB/databaseAccounts@2025-04-15' = {
	name: cosmosAccountName
	location: location
	kind: 'GlobalDocumentDB'
	properties: {
		capabilities: [
			{
				name: 'EnableServerless'
			}
		]
		consistencyPolicy: {
			defaultConsistencyLevel: 'Session'
		}
		databaseAccountOfferType: 'Standard'
		locations: [
			{
				failoverPriority: 0
				isZoneRedundant: false
				locationName: location
			}
		]
		minimalTlsVersion: 'Tls12'
		publicNetworkAccess: 'Enabled'
	}
}

resource cosmosDatabase 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2025-04-15' = {
	parent: cosmosAccount
	name: 'aml'
	properties: {
		resource: {
			id: 'aml'
		}
	}
}

resource participantCosmosDataContributor 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2025-04-15' = {
	parent: cosmosAccount
	name: guid(cosmosAccount.id, userObjectId, cosmosDataContributorRoleDefinitionId)
	properties: {
		principalId: userObjectId
		roleDefinitionId: '${cosmosAccount.id}/sqlRoleDefinitions/${cosmosDataContributorRoleDefinitionId}'
		scope: cosmosAccount.id
	}
}

output applicationInsightsName string = applicationInsights.name
output applicationInsightsConnectionString string = applicationInsights.properties.ConnectionString
output alertManagerUrl string = 'https://${alertManager.properties.configuration.ingress.fqdn}'
output cosmosAccountName string = cosmosAccount.name
output cosmosEndpoint string = cosmosAccount.properties.documentEndpoint
output foundryAccountName string = foundryAccount.name
output foundryProjectName string = foundryProject.name