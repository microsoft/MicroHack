@description('Radius-provided recipe context.')
param context object

@description('Existing AKS OIDC issuer URL.')
param oidcIssuer string

@description('Existing Event Grid namespace containing the orders topic space.')
param eventGridNamespaceName string

@description('Actual pod service accounts by Radius identity name. Example: {"backend-identity":"backend"}.')
param serviceAccountOverrides object = {}

var namespace = context.runtime.kubernetes.namespace
var serviceAccountName = serviceAccountOverrides[?context.resource.name] ?? context.resource.properties.?serviceAccountName ?? 'default'

module identity '../platform/workload-identity-azure.bicep' = {
  name: 'wi-${uniqueString(context.resource.id)}'
  params: {
    name: 'wi-${uniqueString(resourceGroup().id, context.resource.id)}'
    oidcIssuer: oidcIssuer
    namespace: namespace
    serviceAccountName: serviceAccountName
    eventGridNamespaceName: eventGridNamespaceName
    topicSpaceName: 'orders'
    grants: [
      {
        bindingSuffix: 'publish'
        permission: 'Publisher'
        roleId: 'a12b0b94-b317-4dcd-84a8-502ce99884c6'
      }
      {
        bindingSuffix: 'subscribe'
        permission: 'Subscriber'
        roleId: '4b0f2fd7-60b4-4eca-896f-4435034f8bf5'
      }
    ]
  }
}

// Typed output keeps module references symbolic on the pinned Radius version.
output result {
  resources: string[]
  values: object
} = {
  resources: identity.outputs.resourceIds
  values: {
    clientId: identity.outputs.clientId
    principalId: identity.outputs.principalId
    tenantId: identity.outputs.tenantId
    serviceAccountNamespace: namespace
    boundServiceAccountName: serviceAccountName
    authMethod: 'OAUTH2-JWT'
    tokenAudience: 'https://eventgrid.azure.net/'
  }
}
