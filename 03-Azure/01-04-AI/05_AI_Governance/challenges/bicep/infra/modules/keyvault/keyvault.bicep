@description('Name of the Key Vault')
param keyVaultName string

@description('Location for the Key Vault')
param location string = resourceGroup().location

@description('Tags to be applied to the Key Vault')
param tags object = {}

@description('SKU for the Key Vault')
@allowed(['standard', 'premium'])
param skuName string = 'standard'

@description('SKU family for the Key Vault')
param skuFamily string = 'A'

@description('Enable soft delete for the Key Vault')
param enableSoftDelete bool = true

@description('Soft delete retention in days')
@minValue(7)
@maxValue(90)
param softDeleteRetentionInDays int = 90

@description('Enable purge protection for the Key Vault')
param enablePurgeProtection bool = true

@description('Enable RBAC authorization for the Key Vault')
param enableRbacAuthorization bool = true

@description('Public network access for the Key Vault')
@allowed(['Enabled', 'Disabled'])
param publicNetworkAccess string = 'Disabled'

@description('Enable vault for deployment')
param enabledForDeployment bool = false

@description('Enable vault for disk encryption')
param enabledForDiskEncryption bool = false

@description('Enable vault for template deployment')
param enabledForTemplateDeployment bool = true

// Networking parameters
@description('Name of the Virtual Network')
param vNetName string

@description('Name of the private endpoint subnet')
param privateEndpointSubnetName string

@description('Resource group containing the Virtual Network')
param vNetRG string

@description('Name of the Key Vault private endpoint')
param keyVaultPrivateEndpointName string

@description('DNS zone name for Key Vault private endpoint')
param keyVaultDnsZoneName string = 'privatelink.vaultcore.azure.net'

// DNS Zone parameters (legacy approach - used when dnsZoneResourceId is not provided)
@description('Resource group containing the DNS zones')
param dnsZoneRG string = ''

@description('Subscription ID containing the DNS zones')
param dnsSubscriptionId string = ''

// New parameter: Direct DNS zone resource ID (preferred over dnsZoneRG/dnsSubscriptionId)
@description('Direct DNS zone resource ID for Key Vault (preferred over dnsZoneRG/dnsSubscriptionId)')
param dnsZoneResourceId string = ''

// RBAC assignments
@description('Principal ID of the APIM managed identity for RBAC assignments')
param apimPrincipalId string = ''

// Key Vault built-in roles
var keyVaultSecretsUserRoleId = '4633458b-17de-408a-b874-0445c86b69e6'

// Get existing VNet and subnet for private endpoint
resource vnet 'Microsoft.Network/virtualNetworks@2022-01-01' existing = {
  name: vNetName
  scope: resourceGroup(vNetRG)
}

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2022-01-01' existing = {
  name: privateEndpointSubnetName
  parent: vnet
}

// Key Vault resource
resource keyVault 'Microsoft.KeyVault/vaults@2025-05-01' = {
  name: keyVaultName
  location: location
  tags: union(tags, { 'azd-service-name': keyVaultName })
  properties: {
    tenantId: subscription().tenantId
    sku: {
      family: skuFamily
      name: skuName
    }
    enableSoftDelete: enableSoftDelete
    softDeleteRetentionInDays: softDeleteRetentionInDays
    enablePurgeProtection: enablePurgeProtection ? true : null
    enableRbacAuthorization: enableRbacAuthorization
    enabledForDeployment: enabledForDeployment
    enabledForDiskEncryption: enabledForDiskEncryption
    enabledForTemplateDeployment: enabledForTemplateDeployment
    publicNetworkAccess: publicNetworkAccess
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'AzureServices'
      ipRules: []
      virtualNetworkRules: []
    }
  }
}

// Private endpoint for Key Vault
module privateEndpoint '../networking/private-endpoint.bicep' = {
  name: '${keyVaultName}-pe'
  params: {
    groupIds: [
      'vault'
    ]
    dnsZoneName: keyVaultDnsZoneName
    name: keyVaultPrivateEndpointName
    privateLinkServiceId: keyVault.id
    location: location
    dnsZoneRG: dnsZoneRG
    privateEndpointSubnetId: subnet.id
    dnsSubId: dnsSubscriptionId
    dnsZoneResourceId: dnsZoneResourceId
    tags: tags
  }
}

// RBAC: Grant APIM managed identity Key Vault Secrets User role
resource apimSecretsUserRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(apimPrincipalId)) {
  scope: keyVault
  name: guid(subscription().id, resourceGroup().id, keyVault.name, keyVaultSecretsUserRoleId, apimPrincipalId)
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', keyVaultSecretsUserRoleId)
    principalId: apimPrincipalId
    principalType: 'ServicePrincipal'
  }
}

// Outputs
output keyVaultName string = keyVault.name
output keyVaultId string = keyVault.id
output keyVaultUri string = keyVault.properties.vaultUri
output location string = location
