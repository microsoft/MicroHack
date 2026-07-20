// =============================================================================
// Module: registry.bicep  (Azure Container Registry)
// -----------------------------------------------------------------------------
// Holds the two application images (api, frontend) that the Container Apps pull.
//
// This is a STARTER SKELETON. The core resource + key params are wired so the
// template compiles, but the meaningful decisions are left as // TODO for you.
// =============================================================================

@description('Azure region for the registry.')
param location string

@description('Globally-unique name for the container registry (alphanumeric, 5-50 chars).')
param registryName string

@description('Tags applied to the registry.')
param tags object = {}

// TODO: Decide the SKU. Basic is cheapest and fine for a hackathon; Standard/
//       Premium add throughput, geo-replication, private endpoints, etc.
//       Ask Copilot for Well-Architected guidance if unsure.
@allowed([
  'Basic'
  'Standard'
  'Premium'
])
param sku string = 'Basic'

// TODO: For OIDC/managed-identity pulls you can (and ideally should) keep the
//       admin user DISABLED and grant the Container Apps' identity AcrPull
//       instead. The scaffold defaults to enabled to keep first-run simple —
//       flip this to false once you wire up role assignments.
param adminUserEnabled bool = true

resource registry 'Microsoft.ContainerRegistry/registries@2023-11-01-preview' = {
  name: registryName
  location: location
  tags: tags
  sku: {
    name: sku
  }
  properties: {
    adminUserEnabled: adminUserEnabled
    // TODO: Consider `publicNetworkAccess: 'Disabled'` + private endpoints for
    //       a hardened setup, and `anonymousPullEnabled: false`.
  }
}

@description('The login server host name of the registry (e.g. myregistry.azurecr.io).')
output loginServer string = registry.properties.loginServer

@description('The resource ID of the registry (useful for role assignments).')
output registryId string = registry.id

@description('The name of the registry.')
output registryName string = registry.name
