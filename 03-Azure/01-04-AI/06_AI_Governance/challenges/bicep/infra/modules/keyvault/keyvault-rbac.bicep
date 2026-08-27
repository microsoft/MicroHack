@description('Key Vault resource ID to assign roles on')
param keyVaultName string

@description('Principal IDs for AI Foundry resources to grant Key Vault access')
param aiFoundryPrincipalIds array = []

// Key Vault built-in roles
var keyVaultSecretsUserRoleId = '4633458b-17de-408a-b874-0445c86b69e6'
var keyVaultCertificatesOfficerRoleId = 'a4417e6f-fecd-4de8-b567-7b0420556985'

// Reference existing Key Vault
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: keyVaultName
}

// RBAC: Grant AI Foundry resources Key Vault Secrets User role
resource aiFoundrySecretsUserRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for (principalId, i) in aiFoundryPrincipalIds: if (!empty(principalId)) {
  scope: keyVault
  name: guid(subscription().id, resourceGroup().id, keyVault.name, keyVaultSecretsUserRoleId, principalId)
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', keyVaultSecretsUserRoleId)
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}]

// RBAC: Grant AI Foundry resources Key Vault Certificates Officer role
resource aiFoundryCertificatesOfficerRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for (principalId, i) in aiFoundryPrincipalIds: if (!empty(principalId)) {
  scope: keyVault
  name: guid(subscription().id, resourceGroup().id, keyVault.name, keyVaultCertificatesOfficerRoleId, principalId)
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', keyVaultCertificatesOfficerRoleId)
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}]
