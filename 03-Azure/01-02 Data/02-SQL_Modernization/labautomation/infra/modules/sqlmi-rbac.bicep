param managedInstanceName string
param vmPrincipalId string

// SQL Managed Instance Contributor, scoped to the managed instance only
var sqlManagedInstanceContributorRoleId = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  '4939a1f6-9ae0-4e48-a1e0-f2cbe897382d'
)

resource managedInstance 'Microsoft.Sql/managedInstances@2025-02-01-preview' existing = {
  name: managedInstanceName
}

resource vmSqlMiContributorRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(
    managedInstance.id,
    vmPrincipalId,
    sqlManagedInstanceContributorRoleId
  )

  scope: managedInstance

  properties: {
    roleDefinitionId: sqlManagedInstanceContributorRoleId
    principalId: vmPrincipalId
    principalType: 'ServicePrincipal'
  }
}
