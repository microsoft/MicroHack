@description('Name of the existing Key Vault')
param keyVaultName string

@description('Name of the secret to create or update')
param secretName string

@secure()
@description('Value of the secret')
param secretValue string

resource kv 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: keyVaultName
}

resource secret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  name: secretName
  parent: kv
  properties: {
    value: secretValue
    contentType: 'string'
  }
}

output secretUri string = secret.properties.secretUri
output secretName string = secret.name
