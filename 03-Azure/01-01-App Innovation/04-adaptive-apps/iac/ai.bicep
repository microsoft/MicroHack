// Adds the portable AI capability and agent to the existing Adaptive Apps model.

extension radius
extension radiusResources

@description('The Radius Environment ID. The rad CLI injects this value.')
param environment string

@description('Published Adaptive Apps container image registry.')
param imageRegistry string = 'ghcr.io/microsoft/adaptive-apps'

@description('Container image tag for the AI agent.')
param imageTag string = 'latest'

@description('Model or Azure deployment name requested through the aiModels contract.')
param aiModel string

@description('Kubernetes service account used by the AI agent.')
param aiAgentServiceAccountName string = 'default'

@description('Enable AKS workload-identity metadata for the AI agent.')
param enableAzureWorkloadIdentity bool = false

@description('User-assigned managed identity client ID for Azure OpenAI access.')
param aiAgentClientId string = ''

@description('Microsoft Entra tenant ID used by the workload identity.')
param workloadIdentityTenantId string = ''

var aiAgentExtensions = enableAzureWorkloadIdentity ? [
  {
    kind: 'kubernetesMetadata'
    labels: {
      'azure.workload.identity/use': 'true'
    }
  }
] : []

resource tradingApp 'Applications.Core/applications@2023-10-01-preview' = {
  name: 'adaptive-apps'
  properties: {
    environment: environment
  }
}

resource tradingAI 'Radius.Resources/aiModels@2025-08-01-preview' = {
  name: 'trading-ai'
  properties: {
    environment: environment
    application: tradingApp.id
    model: aiModel
  }
}

resource aiAgent 'Applications.Core/containers@2023-10-01-preview' = {
  name: 'ai-agent'
  properties: {
    application: tradingApp.id
    container: {
      image: '${imageRegistry}/ai-agent:${imageTag}'
      ports: {
        http: {
          containerPort: 7000
        }
      }
      env: {
        ASPNETCORE_URLS: {
          value: 'http://+:7000'
        }
        CONNECTION_AI_SECRETS_APIKEY: {
          value: tradingAI.properties.secrets.apiKey
        }
        AZURE_CLIENT_ID: {
          value: aiAgentClientId
        }
        AZURE_TENANT_ID: {
          value: workloadIdentityTenantId
        }
      }
    }
    extensions: aiAgentExtensions
    connections: {
      ai: {
        source: tradingAI.id
      }
    }
    runtimes: {
      kubernetes: {
        pod: {
          serviceAccountName: aiAgentServiceAccountName
        }
      }
    }
  }
}
