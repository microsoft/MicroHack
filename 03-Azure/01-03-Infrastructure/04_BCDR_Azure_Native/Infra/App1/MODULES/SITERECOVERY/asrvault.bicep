// Parameters & variables
@description('ASR Vault Name, Location and SKU')
param namePrefix string
var nameSuffix = 'asrvault'
var location = resourceGroup().location
var Name = '${namePrefix}-${location}-${nameSuffix}'

// Resources
@description('ASR Vault configuration in the target region')
resource recoveryServicesVault 'Microsoft.RecoveryServices/vaults@2024-04-01' = {
  name: Name
  location: location
  properties: {
    publicNetworkAccess: 'Enabled'
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
      crossRegionRestore: 'Enabled'
      standardTierStorageRedundancy: 'GeoRedundant'
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
        type: 'GeoRedundant'
        
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

// Output
@description('Output the vault name')
output vaultName string = recoveryServicesVault.name
