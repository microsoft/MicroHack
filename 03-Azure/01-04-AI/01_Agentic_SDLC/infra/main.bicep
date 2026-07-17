// =============================================================================
// main.bicep — Challenge 5 starter scaffold (OPTIONAL, SKELETON — not an answer key)
// -----------------------------------------------------------------------------
// Target architecture expressed here (Azure Container Apps):
//
//   ACR ──images──> ┌─────────────── Container Apps Environment ───────────────┐
//                   │  frontend (nginx, :80, external)  ──proxy──>  api (:3000) │
//                   └───────────────────────────────────────────────────────────┘
//                                    │ logs
//                            Log Analytics workspace
//
// The frontend's nginx proxies /api to the api app using API_HOST / API_PORT
// (see src/frontend/entrypoint.sh + nginx.conf). Within one Container Apps
// environment, apps can address each other by app name, which is what makes
// that service discovery work.
//
// WHAT'S PROVIDED: the wiring, parameters, module structure, outputs.
// WHAT'S LEFT TO YOU (look for // TODO): SKUs, ingress visibility for the api,
// exact env/secrets, scaling rules, and the database/storage strategy.
//
// Deploy manually:
//   az group create -n <rg> -l <location>
//   az deployment group create -g <rg> -f infra/main.bicep -p infra/main.parameters.json
// =============================================================================

targetScope = 'resourceGroup'

@description('Azure region for all resources. Defaults to the resource group location.')
param location string = resourceGroup().location

@description('Short prefix used to derive resource names (lowercase letters/numbers).')
@minLength(2)
@maxLength(12)
param namePrefix string = 'octocat'

@description('Environment name / suffix (e.g. dev, test, hack). Keeps names unique per env.')
param environmentName string = 'dev'

@description('Container image reference for the API (e.g. <acr>.azurecr.io/api:<tag>).')
param apiImage string

@description('Container image reference for the frontend (e.g. <acr>.azurecr.io/frontend:<tag>).')
param frontendImage string

@description('Minimum replicas for each app.')
@minValue(0)
param minReplicas int = 1

@description('Maximum replicas for each app.')
@minValue(1)
param maxReplicas int = 3

// TODO: The scaffold passes ACR admin credentials into the frontend/api modules
//       for a quick first deploy. Prefer a user-assigned managed identity with
//       AcrPull and remove these entirely. Left as params so nothing is baked in.
@description('ACR admin username (leave empty to switch modules to managed identity).')
param registryUsername string = ''

@description('ACR admin password (leave empty to switch modules to managed identity).')
@secure()
param registryPassword string = ''

// -----------------------------------------------------------------------------
// Derived names. Registry names must be globally unique and alphanumeric only.
// -----------------------------------------------------------------------------
var baseName = '${namePrefix}-${environmentName}'
var registryName = toLower(replace('${namePrefix}${environmentName}acr', '-', ''))
var logAnalyticsName = '${baseName}-logs'
var environmentResourceName = '${baseName}-env'
var apiAppName = '${baseName}-api'
var frontendAppName = '${baseName}-frontend'

var commonTags = {
  project: 'octocat-supply'
  challenge: 'challenge-4-azure-deploy'
  managedBy: 'bicep'
  environment: environmentName
}

// -----------------------------------------------------------------------------
// Container Registry
// -----------------------------------------------------------------------------
module registry 'modules/registry.bicep' = {
  name: 'registry'
  params: {
    location: location
    registryName: registryName
    tags: commonTags
  }
}

// -----------------------------------------------------------------------------
// Log Analytics (dependency of the Container Apps environment)
// -----------------------------------------------------------------------------
module logAnalytics 'modules/loganalytics.bicep' = {
  name: 'loganalytics'
  params: {
    location: location
    workspaceName: logAnalyticsName
    tags: commonTags
  }
}

// -----------------------------------------------------------------------------
// Container Apps managed environment
// -----------------------------------------------------------------------------
module environment 'modules/containerapp-env.bicep' = {
  name: 'containerapp-env'
  params: {
    location: location
    environmentName: environmentResourceName
    logAnalyticsWorkspaceId: logAnalytics.outputs.workspaceId
    tags: commonTags
  }
}

// -----------------------------------------------------------------------------
// API container app — listens on 3000.
// -----------------------------------------------------------------------------
// TODO: Ingress visibility decision. `externalIngress: true` gives the api its
//       own public URL (handy for debugging/tests). Set it to false to make the
//       api internal-only and reachable solely by the frontend inside the env —
//       usually the more correct production choice. Pick one deliberately.
module apiApp 'modules/containerapp.bicep' = {
  name: 'api-app'
  params: {
    location: location
    appName: apiAppName
    environmentId: environment.outputs.environmentId
    image: apiImage
    targetPort: 3000
    externalIngress: true
    registryLoginServer: registry.outputs.loginServer
    registryUsername: registryUsername
    registryPassword: registryPassword
    minReplicas: minReplicas
    maxReplicas: maxReplicas
    tags: commonTags
    // TODO: Add the api's runtime env vars / secrets here (e.g. DB connection
    //       string once you pick a database strategy).
    env: []
  }
}

// -----------------------------------------------------------------------------
// Frontend container app — nginx on 80, external, proxying to the api.
// -----------------------------------------------------------------------------
// The API_HOST/API_PORT env vars tell nginx where the api lives. Using the api
// app name resolves inside the environment for service discovery.
module frontendApp 'modules/containerapp.bicep' = {
  name: 'frontend-app'
  params: {
    location: location
    appName: frontendAppName
    environmentId: environment.outputs.environmentId
    image: frontendImage
    targetPort: 80
    externalIngress: true
    registryLoginServer: registry.outputs.loginServer
    registryUsername: registryUsername
    registryPassword: registryPassword
    minReplicas: minReplicas
    maxReplicas: maxReplicas
    tags: commonTags
    env: [
      {
        name: 'API_HOST'
        value: apiAppName
      }
      {
        name: 'API_PORT'
        // TODO: If you make the api internal-only, confirm the frontend still
        //       reaches it on 3000 within the environment (it should). If you
        //       front the api on 443/https externally, adjust API_PORT/PROTOCOL.
        value: '3000'
      }
      // TODO: The entrypoint also honours API_PROTOCOL (default https). Add it
      //       here if your ingress/scheme requires it.
    ]
  }
}

// -----------------------------------------------------------------------------
// Outputs
// -----------------------------------------------------------------------------
@description('ACR login server — push images here and reference them in the apps.')
output acrLoginServer string = registry.outputs.loginServer

@description('Public URL of the frontend app.')
output frontendUrl string = 'https://${frontendApp.outputs.fqdn}'

@description('FQDN of the api app (public only while externalIngress is true).')
output apiFqdn string = apiApp.outputs.fqdn
