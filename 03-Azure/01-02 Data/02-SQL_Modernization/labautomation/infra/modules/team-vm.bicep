param location string

param subnetId string
param vmSize string
param vmName string

param adminUsername string
@secure()
param adminPassword string

param tags object

resource networkInterfaces 'Microsoft.Network/networkInterfaces@2024-05-01' = {
  name: '${vmName}-nic'
  location: location
  tags: tags

  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'

          subnet: {
            id: subnetId
          }
        }
      }
    ]
  }
}

resource virtualMachine 'Microsoft.Compute/virtualMachines@2024-11-01' = {
  name: vmName
  location: location

  tags: tags

  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }

    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      adminPassword: adminPassword

      windowsConfiguration: {
        provisionVMAgent: true
        enableAutomaticUpdates: true
      }
    }

    storageProfile: {
      // imageReference: {
      //   publisher: 'MicrosoftWindowsServer'
      //   offer: 'WindowsServer'
      //   sku: '2022-datacenter-g2'
      //   version: 'latest'
      // }
      imageReference: {
        publisher: 'MicrosoftWindowsDesktop'
        offer: 'windows-11'
        sku: 'win11-23h2-ent'
        version: 'latest'
      }        

      osDisk: {
        createOption: 'FromImage'

        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
      }
    }

    networkProfile: {
      networkInterfaces: [
        {
          id: networkInterfaces.id
        }
      ]
    }
  }
}

/* 
resource autoShutdownConfigs 'Microsoft.DevTestLab/schedules@2018-09-15' = {
  name: 'shutdown-computevm-${vmName}'
  location: location
  properties: {
    status: 'Enabled'
    notificationSettings: {
      status: 'Disabled'
      timeInMinutes: 15
      notificationLocale: 'en'
    }
    dailyRecurrence: {
      time: '1800'
    }
    timeZoneId: 'UTC'
    taskType: 'ComputeVmShutdownTask'
    targetResourceId: virtualMachine.id
  }
}
 */
 
output vmName string = virtualMachine.name
