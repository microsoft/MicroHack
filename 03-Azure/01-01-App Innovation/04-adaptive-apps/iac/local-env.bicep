extension radius
extension kubernetes with {
  namespace: 'default'
  kubeConfig: ''
} as k8s

param namespace string = 'env-local-prod'
param environmentName string = namespace
param recipeRegistry string = 'ghcr.io/microsoft/adaptive-apps/recipes'
@description('Pinned workshop OCI path for the corrected Kubernetes PostgreSQL recipe.')
param postgresRecipeTemplatePath string

resource appNamespace 'core/Namespace@v1' = {
  metadata: {
    name: namespace
    labels: {
      'istio-injection': 'enabled'
    }
  }
}

resource localEnvironment 'Applications.Core/environments@2023-10-01-preview' = {
  name: environmentName
  dependsOn: [
    appNamespace
  ]
  properties: {
    compute: {
      kind: 'kubernetes'
      namespace: namespace
    }
    providers: {}
    recipes: {
      'Radius.Resources/postgreSqlDatabases': {
        default: {
          templateKind: 'bicep'
          templatePath: postgresRecipeTemplatePath
        }
      }
      'Radius.Resources/mqttBrokers': {
        default: {
          templateKind: 'bicep'
          templatePath: '${recipeRegistry}/mqtt:latest'
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
          templatePath: '${recipeRegistry}/workload-identity-local:latest'
        }
      }
      'Radius.Resources/aiModels': {
        default: {
          templateKind: 'bicep'
          templatePath: '${recipeRegistry}/ai-agent-kaito:latest'
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
  }
}
