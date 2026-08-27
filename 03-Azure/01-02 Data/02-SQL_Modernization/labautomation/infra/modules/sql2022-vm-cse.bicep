param location string
param vmName string
param repoBaseURL string

param adminUsername string
@secure()
param adminPassword string

var ConfigureSQLMachineCommand = 'powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "bootstrap-newsql.ps1" -BackupUri "https://github.com/Microsoft/sql-server-samples/releases/download/wide-world-importers-v1.0/WideWorldImporters-Full.bak" -adminUsername ${adminUsername} -adminPassword ${adminPassword}'

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
        '${repoBaseURL}/scripts/Restore-SampleDatabases.ps1'
        '${repoBaseURL}/scripts/bootstrap-newsql.ps1'
      ]
    }

    protectedSettings: {
      commandToExecute: ConfigureSQLMachineCommand
    }
  }
}
