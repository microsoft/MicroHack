extension radius
extension kubernetes with {
  namespace: 'default'
  kubeConfig: ''
} as k8s

param namespace string = 'env-azure-prod'
param environmentName string = namespace
param recipeRegistry string = 'ghcr.io/microsoft/adaptive-apps/recipes'
param sqlDatabasesRecipeTemplatePath string = ''
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
      templatePath: '${recipeRegistry}/postgres-azure-flex:latest'
    }
  }
  'Radius.Resources/mqttBrokers': {
    default: {
      templateKind: 'bicep'
      templatePath: '${recipeRegistry}/mqtt-azure-event-grid:latest'
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
      templatePath: '${recipeRegistry}/workload-identity-azure:latest'
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
