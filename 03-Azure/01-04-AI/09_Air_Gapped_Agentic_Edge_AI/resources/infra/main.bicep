// ============================================================================
// Air-Gapped Agentic AI: Orchestrating Local SLMs and IoT on Edge Kubernetes
// Provisions the Fast K3s Edge Host Environment:
//   - Standard_D16s_v5 Ubuntu 24.04 VM with single-node K3s (~10 min)
//   - Virtual Network, Subnet, NSG, and optional Azure Bastion
//   - Storage Account (HNS enabled) for Azure IoT Operations Schema Registry
//   - Key Vault for Edge Secrets & Certificates
//   - User-Assigned Managed Identity for Arc & AIO onboarding
// ============================================================================

targetScope = 'resourceGroup'

@description('Azure region for all resources.')
param location string = resourceGroup().location

@description('Short unique prefix/suffix for resource names.')
@minLength(3)
@maxLength(12)
param environmentPrefix string = 'edgeai'

@description('Edge simulation topology profile.')
@allowed([
  'fast-k3s'
])
param edgeProfile string = 'fast-k3s'

@description('VM size for the Ubuntu K3s edge host.')
param vmSize string = 'Standard_D16s_v5'

@description('Administrator username for the Edge Host VM.')
param adminUsername string = 'edgeadmin'

@description('Administrator password or SSH public key for the Edge Host VM.')
@secure()
param adminPasswordOrKey string

@description('Authentication type for the Linux fast-k3s VM.')
@allowed([
  'password'
  'sshPublicKey'
])
param authType string = 'password'

@description('Whether to deploy Azure Bastion for browser-based SSH/RDP access.')
param deployBastion bool = true

@description('Optional Entra Object ID of the lab participant to grant RBAC roles.')
param participantObjectId string = ''

var uniqueSuffix = substring(uniqueString(resourceGroup().id, environmentPrefix), 0, 6)
var vmName = '${environmentPrefix}-host-${uniqueSuffix}'
var arcClusterName = '${environmentPrefix}-arck8s-${uniqueSuffix}'
var vnetName = '${environmentPrefix}-vnet-${uniqueSuffix}'
var nsgName = '${environmentPrefix}-nsg-${uniqueSuffix}'
var natGwName = '${environmentPrefix}-natgw-${uniqueSuffix}'
var natPipName = '${environmentPrefix}-natpip-${uniqueSuffix}'
var bastionName = '${environmentPrefix}-bastion-${uniqueSuffix}'
var bastionPipName = '${environmentPrefix}-bastion-pip-${uniqueSuffix}'
var storageAccountName = take('st${replace(environmentPrefix, '-', '')}${uniqueSuffix}', 24)
var keyVaultName = take('${environmentPrefix}-kv-${uniqueSuffix}', 24)
var identityName = '${environmentPrefix}-id-${uniqueSuffix}'

var linuxConfiguration = {
  disablePasswordAuthentication: true
  ssh: {
    publicKeys: [
      {
        path: '/home/${adminUsername}/.ssh/authorized_keys'
        keyData: adminPasswordOrKey
      }
    ]
  }
}

// Cloud-init script for the fast-k3s Ubuntu 24.04 edge host
var cloudInitScript = loadFileAsBase64('cloud-init-k3s.yaml')

// ----------------------------------------------------------------------------
// 1. User-Assigned Managed Identity for Edge Onboarding
// ----------------------------------------------------------------------------
resource edgeIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: identityName
  location: location
}

// ----------------------------------------------------------------------------
// 2. Networking (VNet, Subnets, NSG, Optional Azure Bastion)
// ----------------------------------------------------------------------------
resource nsg 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: nsgName
  location: location
  properties: {
    securityRules: [
      {
        name: 'Allow-Internal-VNet'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          sourcePortRange: '*'
          destinationAddressPrefix: 'VirtualNetwork'
          destinationPortRange: '*'
        }
      }
    ]
  }
}

resource natPip 'Microsoft.Network/publicIPAddresses@2023-11-01' = {
  name: natPipName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource natGateway 'Microsoft.Network/natGateways@2023-11-01' = {
  name: natGwName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    idleTimeoutInMinutes: 10
    publicIpAddresses: [
      {
        id: natPip.id
      }
    ]
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.42.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'snet-edge-host'
        properties: {
          addressPrefix: '10.42.1.0/24'
          networkSecurityGroup: {
            id: nsg.id
          }
          natGateway: {
            id: natGateway.id
          }
        }
      }
      {
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: '10.42.2.0/26'
        }
      }
    ]
  }
}

resource bastionPip 'Microsoft.Network/publicIPAddresses@2023-11-01' = if (deployBastion) {
  name: bastionPipName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource bastion 'Microsoft.Network/bastionHosts@2023-11-01' = if (deployBastion) {
  name: bastionName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    enableTunneling: true
    ipConfigurations: [
      {
        name: 'IpConf'
        properties: {
          subnet: {
            id: vnet.properties.subnets[1].id
          }
          publicIPAddress: {
            id: bastionPip.id
          }
        }
      }
    ]
  }
}

// ----------------------------------------------------------------------------
// 3. Storage Account (Hierarchical Namespace Enabled for AIO Schema Registry)
// ----------------------------------------------------------------------------
resource schemaStorage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    isHnsEnabled: true
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    supportsHttpsTrafficOnly: true
  }
}

resource blobServices 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  parent: schemaStorage
  name: 'default'
}

resource schemaContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: blobServices
  name: 'schemas'
}

// ----------------------------------------------------------------------------
// 4. Key Vault for Edge Certificates & Secrets
// ----------------------------------------------------------------------------
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 7
  }
}

resource kvEdgeAdminUsernameSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'EdgeHostAdminUsername'
  properties: {
    value: adminUsername
    contentType: 'text/plain'
  }
}

resource kvEdgeAdminPasswordSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'EdgeHostAdminPassword'
  properties: {
    value: adminPasswordOrKey
    contentType: 'password'
  }
}

// ----------------------------------------------------------------------------
// 5. Edge Host NIC & Virtual Machine
// ----------------------------------------------------------------------------
resource nic 'Microsoft.Network/networkInterfaces@2023-11-01' = {
  name: '${vmName}-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: vnet.properties.subnets[0].id
          }
        }
      }
    ]
  }
}

resource edgeVm 'Microsoft.Compute/virtualMachines@2024-03-01' = {
  name: vmName
  location: location
  identity: {
    type: 'SystemAssigned, UserAssigned'
    userAssignedIdentities: {
      '${edgeIdentity.id}': {}
    }
  }
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: take(vmName, 15)
      adminUsername: adminUsername
      adminPassword: adminPasswordOrKey
      customData: edgeProfile == 'fast-k3s' ? cloudInitScript : null
      linuxConfiguration: (edgeProfile == 'fast-k3s' && authType == 'sshPublicKey') ? linuxConfiguration : null
    }
    storageProfile: {
      imageReference: edgeProfile == 'fast-k3s'
        ? {
            publisher: 'Canonical'
            offer: 'ubuntu-24_04-lts'
            sku: 'server'
            version: 'latest'
          }
        : {
            publisher: 'MicrosoftWindowsServer'
            offer: 'WindowsServer'
            sku: '2025-datacenter-azure-edition'
            version: 'latest'
          }
      osDisk: {
        name: '${vmName}-osdisk'
        createOption: 'FromImage'
        diskSizeGB: 256
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
      }
      dataDisks: [
        {
          lun: 0
          name: '${vmName}-modelcache-disk01'
          createOption: 'Empty'
          diskSizeGB: 256
          caching: 'ReadOnly'
          managedDisk: {
            storageAccountType: 'Premium_LRS'
          }
        }
        {
          lun: 1
          name: '${vmName}-iotdata-disk02'
          createOption: 'Empty'
          diskSizeGB: 256
          caching: 'ReadOnly'
          managedDisk: {
            storageAccountType: 'Premium_LRS'
          }
        }
      ]
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
        }
      ]
    }
  }
}

// ----------------------------------------------------------------------------
// 6. RBAC Role Assignments for Edge Managed Identity & Optional Participant
// ----------------------------------------------------------------------------
// Storage Blob Data Contributor on Schema Registry Storage
var storageBlobDataContributorRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe')
// Contributor on Resource Group (allows Edge Identity to onboard Arc, AIO, and Extensions)
var contributorRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b24988ac-6180-42a0-ab88-20f7382dd24c')
// Role Based Access Control Administrator on Resource Group (required by az iot ops create)
var rbacAdminRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'f58310d9-a9f6-439a-9e8d-f62e7b41a168')

resource identityStorageRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(schemaStorage.id, edgeIdentity.id, storageBlobDataContributorRoleId)
  scope: schemaStorage
  properties: {
    principalId: edgeIdentity.properties.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: storageBlobDataContributorRoleId
  }
}

resource identityContributorRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, edgeIdentity.id, contributorRoleId)
  scope: resourceGroup()
  properties: {
    principalId: edgeIdentity.properties.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: contributorRoleId
  }
}

resource identityRbacAdminRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, edgeIdentity.id, rbacAdminRoleId)
  scope: resourceGroup()
  properties: {
    principalId: edgeIdentity.properties.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: rbacAdminRoleId
  }
}

resource participantStorageRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(participantObjectId)) {
  name: guid(schemaStorage.id, participantObjectId, storageBlobDataContributorRoleId)
  scope: schemaStorage
  properties: {
    principalId: participantObjectId
    principalType: 'User'
    roleDefinitionId: storageBlobDataContributorRoleId
  }
}

// ----------------------------------------------------------------------------
// Outputs
// ----------------------------------------------------------------------------
output edgeVmName string = edgeVm.name
output edgeProfileUsed string = edgeProfile
output vmSizeUsed string = vmSize
output arcClusterSuggestedName string = arcClusterName
output schemaStorageAccountName string = schemaStorage.name
output schemaStorageAccountId string = schemaStorage.id
output keyVaultName string = keyVault.name
output userAssignedIdentityId string = edgeIdentity.id
output userAssignedIdentityClientId string = edgeIdentity.properties.clientId
