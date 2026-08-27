param location string
param vmName string
param storageAccountName string
param managedInstanceServer string
param repoBaseURL string

param adminUsername string
@secure()
param adminPassword string

param sqlMiAdminUsername string
@secure()
param sqlMiAdminPassword string

var ConfigureSQLMachineCommand = 'powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "bootstrap-legacy.ps1" -BackupBaseUri "${repoBaseURL}/Databases" -adminUsername ${adminUsername} -adminPassword ${adminPassword} -sqlMiAdminUsername ${sqlMiAdminUsername} -sqlMiAdminPassword ${sqlMiAdminPassword} -StorageAccountName ${storageAccountName} -ManagedInstanceServer ${managedInstanceServer}'

resource virtualMachine 'Microsoft.Compute/virtualMachines@2024-11-01' existing = {
  name: vmName
}

resource sqlVirtualMachine 'Microsoft.SqlVirtualMachine/sqlVirtualMachines@2023-10-01' existing = {
  name: vmName
}

resource ConfigureSQLMachine 'Microsoft.Compute/virtualMachines/extensions@2024-11-01' = {
  parent: virtualMachine
  name: 'ConfigureSQLMachine'
  location: location

  dependsOn: [
    sqlVirtualMachine
  ]  

  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true

    settings: {
      fileUris: [
        '${repoBaseURL}/scripts/Set-FW-ForAllInstances.ps1'
        //'${repoBaseURL}/scripts/Restore-TeamDatabases.ps1'
        '${repoBaseURL}/scripts/Download-TeamDatabases.ps1'
        '${repoBaseURL}/scripts/bootstrap-legacy.ps1'
        '${repoBaseURL}/scripts/Restore-TeamDatabasesMI.ps1'
        '${repoBaseURL}/scripts/Install-AzureCLI.ps1'
        '${repoBaseURL}/scripts/Configure-SQLMI.ps1'
        '${repoBaseURL}/scripts/Configure-legacySQL.ps1'
      ]
    }

    protectedSettings: {
      commandToExecute: ConfigureSQLMachineCommand
    }
  }
}
