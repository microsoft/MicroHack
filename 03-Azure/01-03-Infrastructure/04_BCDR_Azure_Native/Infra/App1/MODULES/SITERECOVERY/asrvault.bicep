// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.
/*
SUMMARY: Module to create a Site Recovery Vault.
DESCRIPTION: This module will create a deployment which will create the Site Recovery Vault in the target region for an ASR Demo
AUTHOR/S: David Smith (CSA FSI)
*/

// Parameters & variables
@description('ASR Vault Name, Location and SKU')
param namePrefix string
var nameSuffix = 'asrvault'
var location = resourceGroup().location
var Name = '${namePrefix}-${location}-${nameSuffix}'
// param logAnalyticsWorkspaceId string

// Resources
@description('ASR Vault configuration in the target region')
resource recoveryServicesVault 'Microsoft.RecoveryServices/vaults@2024-04-01' = {
  name: Name
  location: location
  properties: {
    publicNetworkAccess: 'Enabled'
    redundancySettings: {
      crossRegionRestore: 'Enabled'
      standardTierStorageRedundancy: 'GeoRedundant'
    }
    monitoringSettings: {
      azureMonitorAlertSettings: {
        alertsForAllFailoverIssues: 'Enabled'
        alertsForAllJobFailures: 'Enabled'
        alertsForAllReplicationIssues: 'Enabled'
      }
      classicAlertSettings: {
        alertsForCriticalOperations: 'Disabled'
        emailNotificationsForSiteRecovery: 'Disabled'
      }
    }
  }
  sku: {
    name: 'RS0'
    tier: 'Standard'
  }
}

// Backup Configuration & Policies
resource backupRsvConfig 'Microsoft.RecoveryServices/vaults/BackupConfig@2022-02-01' = {
  parent: recoveryServicesVault
  name: 'vaultconfig'
  properties: {
    enhancedSecurityState: 'Disabled'
    isSoftDeleteFeatureStateEditable: true
    softDeleteFeatureState: 'Disabled'
    redundancySettings: {
      crossRegionRestore: 'Disabled'
      standardTierStorageRedundancy: 'ZoneRedundant'
    }
  }
}

resource backupVlt 'Microsoft.DataProtection/backupVaults@2024-04-01' = {
  name: '${Name}-backupVault'
  location: location
  properties: {
    storageSettings: [
      {
        datastoreType: 'VaultStore'
        type: 'ZoneRedundant'
        
      }
    ]
  }
}

// replicaitonPolicies
resource replicationPolicies 'Microsoft.RecoveryServices/vaults/replicationPolicies@2024-04-01' = {
  name: '24-hour-retention-policy'
  parent: recoveryServicesVault
  properties: {
    providerSpecificInput: {
      instanceType: 'A2A'
      multiVmSyncStatus: 'Disable'
    }
  }
}

// See https://learn.microsoft.com/en-us/azure/backup/backup-azure-diagnostic-events for details on diag settings

// resource diagSettings1 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
//   name: '${recoveryServicesVault.name}-Setting1'
//   scope: recoveryServicesVault
//   properties: {
//     workspaceId: logAnalyticsWorkspaceId
//     logs: [
//       {
//         category: 'AzureBackupReport'
//         enabled: true
//       }
//     ]
//     metrics: []
//     logAnalyticsDestinationType: null // Azure Diagnostics mode
//   }
// }

// resource diagSettings2 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
//   name: '${recoveryServicesVault.name}-Setting2'
//   scope: recoveryServicesVault
//   properties: {
//     workspaceId: logAnalyticsWorkspaceId
//     logs: [
//       {
//         category: 'CoreAzureBackup'
//         enabled: true
//       }
//       {
//         category: 'AddonAzureBackupJobs'
//         enabled: true
//       }
//       {
//         category: 'AddonAzureBackupPolicy'
//         enabled: true
//       }
//       {
//         category: 'AddonAzureBackupStorage'
//         enabled: true
//       }
//       {
//         category: 'AddonAzureBackupProtectedInstance'
//         enabled: true
//       }
//       {
//         category: 'AzureBackupOperations'
//         enabled: true
//       }
//     ]
//     metrics: []
//     logAnalyticsDestinationType: 'Dedicated' // Resource-Specific mode
//   }
// }

// resource diagSettings3 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
//   name: '${recoveryServicesVault.name}-Setting3'
//   scope: recoveryServicesVault
//   properties: {
//     workspaceId: logAnalyticsWorkspaceId
//     logs: [
//       {
//         category: 'AzureBackupReport'
//         enabled: true
//       }
//       {
//         category: 'AzureSiteRecoveryEvents'
//         enabled: true
//       }
//     ]
//     metrics: []
//     logAnalyticsDestinationType: null // Azure Diagnostics mode
//   }
// }

// Output
@description('Output the vault name')
output vaultName string = recoveryServicesVault.name
