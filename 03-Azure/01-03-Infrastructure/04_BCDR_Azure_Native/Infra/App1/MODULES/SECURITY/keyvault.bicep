// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.
/*
SUMMARY: Module to create a Key Vault
DESCRIPTION: This module will create a deployment which will create the Key Vault
AUTHOR/S: David Smith (CSA FSI)
*/

param namePrefix string
var location = resourceGroup().location
var nameSuffix = 'kv'
var unique = uniqueString(resourceGroup().id)
var subName = '${namePrefix}${location}${nameSuffix}${unique}' // must be between 3-24 alphanumeric characters
var Name = length(subName) >= 24 ? substring(subName, 0, 24) : subName // Key Vault name must be between 3 and 24 characters in length and use numbers and lower-case letters only
param secretName string
@secure()
param vmAdminPassword string
// param userPrincipalId string
// param logAnalyticsWorkspaceId string

resource keyVault 'Microsoft.KeyVault/vaults@2024-04-01-preview' = {
  name: Name
  location: location
  properties: {
    enabledForTemplateDeployment: true
    enableRbacAuthorization: true
    enableSoftDelete: false
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    accessPolicies: []
  }
}

resource secret 'Microsoft.KeyVault/vaults/secrets@2024-04-01-preview' = {
  name: secretName
  parent: keyVault
  properties: {
    value: vmAdminPassword
  }
}

// resource roleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
//   name: guid(keyVault.id, 'Key Vault Secrets User', userPrincipalId)
//   scope: keyVault
//   properties: {
//     roleDefinitionId: subscriptionResourceId(
//       'Microsoft.Authorization/roleDefinitions',
//       '4633458b-17de-408a-b874-0445c86b69e6'
//     ) // Key Vault Secrets User role
//     principalId: userPrincipalId
//   }
// }



// resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
//   name: '${keyVault.name}-diag'
//   scope: keyVault
//   properties: {
//     workspaceId: logAnalyticsWorkspaceId
//     logs: [
//       {
//         category: 'AuditEvent'
//         enabled: true
//       }
//     ]
//     metrics: [
//       {
//         category: 'AllMetrics'
//         enabled: true
//       }
//     ]
//   }
// }

output keyVaultUri string = keyVault.properties.vaultUri
output kvName string = keyVault.name
output secret string = secret.name
