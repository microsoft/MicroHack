// Portable stock-trading application adapted from microsoft/adaptive-apps.
// Challenge 05 keeps AI, OIDC, and governance out of the core deployment.
// Optional parameters let later challenges add those capabilities without
// changing the platform boundary demonstrated here.

extension radius
extension radiusResources

@description('The Radius Environment ID. The rad CLI injects this value.')
param environment string

@description('Published Adaptive Apps container image registry.')
param imageRegistry string = 'ghcr.io/microsoft/adaptive-apps'

@description('Container image tag shared by the application services.')
param imageTag string = 'latest'

@description('Username for the frontend local sign-in.')
param authUsername string = 'admin'

@description('Password for the frontend local sign-in.')
@secure()
param authPassword string

@description('Secret used to sign frontend session cookies.')
@secure()
#disable-next-line secure-parameter-default
param sessionSecret string = uniqueString(environment, 'session')

@description('OIDC client ID presented by the frontend. Leave empty to keep OIDC disabled.')
param oidcClientId string = ''

@description('OIDC client secret presented by the frontend. Leave empty to keep OIDC disabled.')
@secure()
param oidcClientSecret string = ''

@description('OIDC issuer reachable from the frontend container.')
param oidcIssuer string = ''

@description('OIDC authorization endpoint reachable from the frontend container.')
param oidcAuthEndpoint string = ''

@description('OIDC authorization endpoint reachable from the participant browser.')
param oidcBrowserAuthEndpoint string = ''

@description('OIDC token endpoint reachable from the frontend container.')
param oidcTokenEndpoint string = ''

@description('OIDC user-info endpoint reachable from the frontend container.')
param oidcUserInfoEndpoint string = ''

@description('Public frontend URL used to build the OIDC callback URI.')
param appBaseUrl string = 'http://localhost:3000'

@description('Pre-provisioned managed identity client ID for the backend. Leave empty for Challenge 05.')
param backendClientId string = ''

@description('Pre-provisioned managed identity client ID for the frontend. Leave empty for Challenge 05.')
param frontendClientId string = ''

@description('Kubernetes service account bound by the workload-identity recipe.')
param workloadIdentityServiceAccountName string = 'default'

@description('Entra tenant ID for workload identity. Leave empty for Challenge 05.')
param workloadIdentityTenantId string = ''

@description('Enable Istio sidecar injection when the platform portfolio includes Istio.')
param enableIstioInjection bool = true

var kubernetesMetadataExtension = enableIstioInjection ? [
  {
    kind: 'kubernetesMetadata'
    annotations: {
      'sidecar.istio.io/inject': 'true'
    }
    labels: {
      'azure.workload.identity/use': 'true'
    }
  }
] : [
  {
    kind: 'kubernetesMetadata'
    labels: {
      'azure.workload.identity/use': 'true'
    }
  }
]

resource tradingApp 'Applications.Core/applications@2023-10-01-preview' = {
  name: 'adaptive-apps'
  properties: {
    environment: environment
  }
}

resource tradingDb 'Radius.Resources/postgreSqlDatabases@2025-08-01-preview' = {
  name: 'trading-db'
  properties: {
    environment: environment
    application: tradingApp.id
    size: 'S'
  }
}

resource tradingMqtt 'Radius.Resources/mqttBrokers@2025-08-01-preview' = {
  name: 'trading-mqtt'
  properties: {
    environment: environment
    application: tradingApp.id
  }
}

resource backendIdentity 'Radius.Resources/workloadIdentities@2025-08-01-preview' = {
  name: 'backend-identity'
  properties: {
    environment: environment
    application: tradingApp.id
    #disable-next-line BCP073
    clientId: backendClientId
    serviceAccountName: workloadIdentityServiceAccountName
  }
}

resource frontendIdentity 'Radius.Resources/workloadIdentities@2025-08-01-preview' = {
  name: 'frontend-identity'
  properties: {
    environment: environment
    application: tradingApp.id
    #disable-next-line BCP073
    clientId: frontendClientId
    serviceAccountName: workloadIdentityServiceAccountName
  }
}

resource backend 'Applications.Core/containers@2023-10-01-preview' = {
  name: 'backend'
  properties: {
    application: tradingApp.id
    container: {
      image: '${imageRegistry}/backend:${imageTag}'
      ports: {
        http: {
          containerPort: 8080
        }
      }
      readinessProbe: {
        kind: 'httpGet'
        path: '/api/accounts'
        containerPort: 8080
      }
      env: {
        ASPNETCORE_URLS: {
          value: 'http://+:8080'
        }
        CONNECTION_DB_SECRETS_PASSWORD: {
          value: tradingDb.properties.secrets.password
        }
        AZURE_CLIENT_ID: {
          value: backendIdentity.properties.clientId
        }
        AZURE_TENANT_ID: {
          value: workloadIdentityTenantId
        }
        MQTT_AUTH_METHOD: {
          value: backendIdentity.properties.authMethod
        }
        MQTT_TOKEN_AUDIENCE: {
          value: backendIdentity.properties.tokenAudience
        }
        MQTT_TOPIC: {
          value: 'orders/new'
        }
      }
    }
    extensions: kubernetesMetadataExtension
    connections: {
      db: {
        source: tradingDb.id
      }
      mqtt: {
        source: tradingMqtt.id
      }
      identity: {
        source: backendIdentity.id
      }
    }
  }
}

resource frontend 'Applications.Core/containers@2023-10-01-preview' = {
  name: 'frontend'
  properties: {
    application: tradingApp.id
    container: {
      image: '${imageRegistry}/frontend:${imageTag}'
      ports: {
        http: {
          containerPort: 3000
        }
      }
      env: {
        PORT: {
          value: '3000'
        }
        BACKEND_URL: {
          value: 'http://backend:8080'
        }
        AI_AGENT_URL: {
          value: 'http://ai-agent:7000'
        }
        MQTT_WS_URL: {
          value: '${tradingMqtt.properties.wsPort == 443 ? 'wss' : 'ws'}://${tradingMqtt.properties.host}:${tradingMqtt.properties.wsPort}'
        }
        AZURE_CLIENT_ID: {
          value: frontendIdentity.properties.clientId
        }
        AZURE_TENANT_ID: {
          value: workloadIdentityTenantId
        }
        MQTT_AUTH_METHOD: {
          value: frontendIdentity.properties.authMethod
        }
        MQTT_TOKEN_AUDIENCE: {
          value: frontendIdentity.properties.tokenAudience
        }
        AUTH_USERNAME: {
          value: authUsername
        }
        AUTH_PASSWORD: {
          value: authPassword
        }
        SESSION_SECRET: {
          value: sessionSecret
        }
        OIDC_CLIENT_ID: {
          value: oidcClientId
        }
        OIDC_CLIENT_SECRET: {
          value: oidcClientSecret
        }
        OIDC_ISSUER: {
          value: oidcIssuer
        }
        OIDC_AUTH_ENDPOINT: {
          value: oidcAuthEndpoint
        }
        OIDC_BROWSER_AUTH_ENDPOINT: {
          value: oidcBrowserAuthEndpoint
        }
        OIDC_TOKEN_ENDPOINT: {
          value: oidcTokenEndpoint
        }
        OIDC_USERINFO_ENDPOINT: {
          value: oidcUserInfoEndpoint
        }
        APP_BASE_URL: {
          value: appBaseUrl
        }
      }
    }
    extensions: kubernetesMetadataExtension
    connections: {
      backend: {
        source: backend.id
      }
      mqtt: {
        source: tradingMqtt.id
      }
      identity: {
        source: frontendIdentity.id
      }
    }
  }
}
