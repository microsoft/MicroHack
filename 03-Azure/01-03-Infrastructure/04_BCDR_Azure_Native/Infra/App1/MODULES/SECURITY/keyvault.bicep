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

output keyVaultUri string = keyVault.properties.vaultUri
output kvName string = keyVault.name
output secret string = secret.name
