param location string
param repoBaseURL string
param managedInstanceServer string
param storageAccountName string
param vmName string
param TeamName string = 'TEAM01'
param legacySQLName string
param adminUsername string
@secure()
param adminPassword string

//var ConfigureTeamVMCommand = 'powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "bootstrap-teamvm.ps1" -SamplesBaseUri "${repoBaseURL}/TSQL_Scripts" -WallpaperUri "${repoBaseURL}/assets/BaseWallpaper.jpg" -TeamNumber ##teamNumber##'
var ConfigureTeamVMCommand = 'powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "bootstrap-teamvm.ps1" -SamplesBaseUri "${repoBaseURL}/TSQL_Scripts" -WallpaperUri "${repoBaseURL}/assets/BaseWallpaper.jpg" -TeamName ${TeamName} -LabsBaseUri "${repoBaseURL}/LABS" -ManagedInstanceServer "${managedInstanceServer}" -StorageAccountName "${storageAccountName}" -BackupBaseUri "${repoBaseURL}/Databases" -ServerInstance "${legacySQLName}" -adminUsername "${adminUsername}" -adminPassword "${adminPassword}"'
resource virtualMachine 'Microsoft.Compute/virtualMachines@2024-11-01' existing = {
  name: vmName
}

resource ConfigureTeamMachine 'Microsoft.Compute/virtualMachines/extensions@2024-11-01' = {
  parent: virtualMachine
  name: 'ConfigureTeamMachine'
  location: location

  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true

    settings: {
      fileUris: [
        '${repoBaseURL}/scripts/install-team-tools.ps1'
        '${repoBaseURL}/scripts/Download-Samples.ps1'
        '${repoBaseURL}/scripts/bootstrap-teamvm.ps1'
        '${repoBaseURL}/scripts/Configure-Teams-Shortcuts.ps1'
        '${repoBaseURL}/scripts/Restore-TeamDatabases.ps1'
        '${repoBaseURL}/scripts/Configure-legacySQL-DB.ps1'
        '${repoBaseURL}/scripts/Download-Labs.ps1'
        '${repoBaseURL}/scripts/Configure-TeamWallpaper.ps1'
      ]
    }

    protectedSettings: {
      //commandToExecute: replace(ConfigureTeamVMCommand, '##teamNumber##', string(index + 1))
      commandToExecute: ConfigureTeamVMCommand
    }
  }
}
