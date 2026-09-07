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
@description('''
Override for the Radius.Resources/mqttBrokers recipe. Empty selects the in-cluster
Mosquitto recipe, which is the AKS default for the reason documented on mqttTemplatePath.
''')
param mqttRecipeTemplatePath string = ''
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

// The AKS environment deliberately uses the in-cluster Mosquitto broker rather than
// 'mqtt-azure-event-grid'. Azure Event Grid accepts a Microsoft Entra JWT only through the
// MQTT v5 enhanced-authentication fields (Authentication Method 'OAUTH2-JWT' plus
// Authentication Data). The workshop application sends the token as a CONNECT password
// instead, which Event Grid always rejects, so the backend never connects and crash-loops
// the whole deployment. Provisioning topic spaces, federated credentials and the Event Grid
// data-plane roles does not change that outcome, because the defect is in the MQTT client.
//
// Only the recipe changes: app.bicep, the resource types and the K3s environment are
// untouched, so this stays a platform-implementation choice rather than an application one.
// Set mqttRecipeTemplatePath to '<registry>/mqtt-azure-event-grid:latest' once the
// application supports MQTT v5 enhanced authentication.
var mqttTemplatePath = empty(mqttRecipeTemplatePath)
  ? '${recipeRegistry}/mqtt:latest'
  : mqttRecipeTemplatePath

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
      templatePath: mqttTemplatePath
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
