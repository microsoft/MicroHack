extension radius
extension kubernetes with {
  namespace: 'default'
  kubeConfig: ''
} as k8s

param namespace string = 'env-azure-prod'
param environmentName string = namespace
param recipeRegistry string = 'ghcr.io/microsoft/adaptive-apps/recipes'
@description('Pinned workshop OCI path for the corrected Azure PostgreSQL recipe.')
param postgresRecipeTemplatePath string
@description('Comma-separated static AKS public egress IP addresses allowed by PostgreSQL.')
param aksEgressIps string
param sqlDatabasesRecipeTemplatePath string = ''
@description('Pinned workshop OCI path for the Azure Event Grid MQTT recipe.')
param mqttRecipeTemplatePath string
@description('Pinned workshop OCI path for the Azure workload-identity recipe.')
param workloadIdentityRecipeTemplatePath string
@description('AKS OIDC issuer URL used by application federated credentials.')
param oidcIssuer string
@description('Event Grid namespace shared by the workshop broker and its workload identities.')
param eventGridNamespaceName string = 'egns-${uniqueString(azureSubscriptionId, azureResourceGroup, environmentName)}'
@description('Actual pod service accounts by Radius identity name. Empty uses the application input.')
param serviceAccountOverrides object = {}
param istioRevision string
param azureSubscriptionId string
param azureResourceGroup string

resource appNamespace 'core/Namespace@v1' = {
  metadata: {
    name: namespace
    labels: {
      'istio.io/rev': istioRevision
    }
  }
}

var baseRecipes = {
  'Radius.Resources/postgreSqlDatabases': {
    default: {
      templateKind: 'bicep'
      templatePath: postgresRecipeTemplatePath
      parameters: {
        aksEgressIps: aksEgressIps
      }
    }
  }
  'Radius.Resources/mqttBrokers': {
    default: {
      templateKind: 'bicep'
      templatePath: mqttRecipeTemplatePath
      parameters: {
        namespaceName: eventGridNamespaceName
      }
    }
  }
  'Radius.Resources/idProviders': {
    default: {
      templateKind: 'bicep'
      templatePath: '${recipeRegistry}/idp-keycloak:latest'
    }
  }
  'Radius.Resources/workloadIdentities': {
    default: {
      templateKind: 'bicep'
      templatePath: workloadIdentityRecipeTemplatePath
      parameters: {
        oidcIssuer: oidcIssuer
        eventGridNamespaceName: eventGridNamespaceName
        serviceAccountOverrides: serviceAccountOverrides
      }
    }
  }
  'Radius.Resources/aiModels': {
    default: {
      templateKind: 'bicep'
      templatePath: '${recipeRegistry}/ai-agent-azure-openai:latest'
    }
  }
  'Radius.Resources/governance': {
    default: {
      templateKind: 'bicep'
      templatePath: '${recipeRegistry}/governance-opa:latest'
    }
  }
  'Radius.Resources/agentGuardrails': {
    default: {
      templateKind: 'bicep'
      templatePath: '${recipeRegistry}/agent-guardrails-agt:latest'
    }
  }
}

var customSqlRecipes = empty(sqlDatabasesRecipeTemplatePath) ? {} : {
  'Radius.Resources/sqlDatabases': {
    default: {
      templateKind: 'bicep'
      templatePath: sqlDatabasesRecipeTemplatePath
    }
  }
}

resource aksEnvironment 'Applications.Core/environments@2023-10-01-preview' = {
  name: environmentName
  dependsOn: [
    appNamespace
  ]
  properties: {
    compute: {
      kind: 'kubernetes'
      namespace: namespace
    }
    providers: {
      azure: {
        scope: '/subscriptions/${azureSubscriptionId}/resourceGroups/${azureResourceGroup}'
      }
    }
    recipes: union(baseRecipes, customSqlRecipes)
  }
}
