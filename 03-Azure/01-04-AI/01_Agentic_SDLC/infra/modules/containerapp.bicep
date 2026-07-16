// =============================================================================
// Module: containerapp.bicep  (generic Container App — reused for api + frontend)
// -----------------------------------------------------------------------------
// One reusable module for BOTH workloads:
//   - api:      target port 3000, ingress (internal or external — a TODO decision)
//   - frontend: target port 80, external ingress, with API_HOST/API_PORT env
//               vars pointing at the api app so nginx can proxy /api.
//
// STARTER SKELETON — compiles as-is; decisions left as // TODO.
// =============================================================================

@description('Azure region for the app.')
param location string

@description('Name of the container app (also its DNS label within the environment).')
param appName string

@description('Resource ID of the Container Apps managed environment.')
param environmentId string

@description('Fully-qualified image reference, e.g. myregistry.azurecr.io/api:latest.')
param image string

@description('The port the container listens on (api=3000, frontend=80).')
param targetPort int

@description('Whether ingress is exposed externally (public). Set false for internal-only.')
param externalIngress bool = true

@description('Login server of the ACR the image is pulled from.')
param registryLoginServer string

@description('Environment variables for the container. Array of { name, value } objects.')
param env array = []

@description('Tags applied to the app.')
param tags object = {}

// TODO: Scaling. These defaults keep at least one replica warm. For a scale-to-
//       zero API set minReplicas: 0, and add custom scale rules (HTTP
//       concurrency, CPU, queue length, ...) rather than relying on replica
//       counts alone.
@minValue(0)
param minReplicas int = 1

@minValue(1)
param maxReplicas int = 3

// TODO: Right-size CPU/memory. 0.5 vCPU / 1Gi is a reasonable starting point;
//       valid combinations are constrained (see Container Apps docs).
param cpu string = '0.5'
param memory string = '1.0Gi'

// -----------------------------------------------------------------------------
// Registry authentication
// -----------------------------------------------------------------------------
// TODO: This scaffold authenticates to ACR with the admin username/password
//       passed in as a secret (simplest path to a first deploy). The PREFERRED
//       approach is a user-assigned managed identity with the AcrPull role and
//       `identity: '<managed-identity-resource-id>'` on the registry entry — no
//       secrets at all. Swap this out once you wire up the identity + role.
@description('ACR admin username (leave empty when using managed identity).')
param registryUsername string = ''

@description('ACR admin password (leave empty when using managed identity).')
@secure()
param registryPassword string = ''

var useAdminCreds = !empty(registryUsername)

resource containerApp 'Microsoft.App/containerApps@2024-03-01' = {
  name: appName
  location: location
  tags: tags
  properties: {
    managedEnvironmentId: environmentId
    configuration: {
      ingress: {
        external: externalIngress
        targetPort: targetPort
        // TODO: For the api you may want `transport: 'http'` and to restrict
        //       traffic; for the frontend the defaults are usually fine.
        traffic: [
          {
            weight: 100
            latestRevision: true
          }
        ]
      }
      // Only attach registry credentials when using admin creds. With a managed
      // identity you would set `identity` here and omit the secret.
      registries: useAdminCreds ? [
        {
          server: registryLoginServer
          username: registryUsername
          passwordSecretRef: 'registry-password'
        }
      ] : []
      secrets: useAdminCreds ? [
        {
          name: 'registry-password'
          value: registryPassword
        }
      ] : []
      // TODO: Add application secrets here (DB connection strings, API keys, ...)
      //       and reference them from env via secretRef instead of value.
    }
    template: {
      containers: [
        {
          name: appName
          image: image
          resources: {
            cpu: json(cpu)
            memory: memory
          }
          env: env
          // TODO: Add liveness/readiness probes so revisions only take traffic
          //       once healthy (e.g. GET / on the frontend, a health route on
          //       the api). Container Apps supports `probes: [...]` here.
        }
      ]
      scale: {
        minReplicas: minReplicas
        maxReplicas: maxReplicas
        // TODO: Add `rules: [...]` for real autoscaling triggers.
      }
      // TODO: Database/storage decision. If you keep the api's SQLite DB inside
      //       the container it is EPHEMERAL — it resets on every revision/scale
      //       event. To persist, either mount an Azure Files volume here
      //       (`volumes` + `volumeMounts`) or move to a managed DB (Azure SQL /
      //       Postgres) and inject a connection string. This is a team decision.
    }
  }
}

@description('The fully-qualified domain name of the app (empty when ingress is disabled).')
output fqdn string = containerApp.properties.configuration.ingress.fqdn

@description('The name of the container app.')
output appName string = containerApp.name
