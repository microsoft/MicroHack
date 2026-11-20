@description('Unique managed identity name.')
@minLength(3)
param name string

@description('Existing AKS OIDC issuer URL.')
param oidcIssuer string

@description('Existing application namespace.')
param namespace string

@description('Existing application service account.')
param serviceAccountName string

@description('Existing Event Grid namespace containing the topic space.')
param eventGridNamespaceName string

@description('Topic space the workload is allowed to access.')
param topicSpaceName string

@description('Topic space permissions and matching Azure RBAC role IDs for this workload.')
param grants {
  bindingSuffix: string
  permission: 'Publisher' | 'Subscriber'
  roleId: string
}[]

resource identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: name
  location: resourceGroup().location
}

resource federation 'Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials@2023-01-31' = {
  parent: identity
  name: 'aks'
  properties: {
    issuer: oidcIssuer
    subject: 'system:serviceaccount:${namespace}:${serviceAccountName}'
    audiences: [
      'api://AzureADTokenExchange'
    ]
  }
}

resource eventGrid 'Microsoft.EventGrid/namespaces@2023-12-15-preview' existing = {
  name: eventGridNamespaceName
}

resource topicSpace 'Microsoft.EventGrid/namespaces/topicSpaces@2023-12-15-preview' existing = {
  parent: eventGrid
  name: topicSpaceName
}

resource clientGroup 'Microsoft.EventGrid/namespaces/clientGroups@2023-12-15-preview' = {
  parent: eventGrid
  name: name
  properties: {
    query: 'authenticationName IN [\'${identity.properties.principalId}\']'
  }
}

resource bindings 'Microsoft.EventGrid/namespaces/permissionBindings@2023-12-15-preview' = [for grant in grants: {
  parent: eventGrid
  name: '${name}-${grant.bindingSuffix}'
  properties: {
    clientGroupName: clientGroup.name
    topicSpaceName: topicSpace.name
    permission: grant.permission
  }
}]

// Entra JWT clients are authorized by these RBAC roles, not by client-group bindings.
resource roleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for grant in grants: {
  scope: topicSpace
  name: guid(topicSpace.id, identity.id, toLower(grant.permission))
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', grant.roleId)
    principalId: identity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}]

var bindingIds = [for (_, i) in grants: bindings[i].id]
var roleAssignmentIds = [for (_, i) in grants: roleAssignments[i].id]

output clientId string = identity.properties.clientId
output principalId string = identity.properties.principalId
output tenantId string = identity.properties.tenantId
output resourceIds array = concat([
  identity.id
  federation.id
  clientGroup.id
], bindingIds, roleAssignmentIds)
