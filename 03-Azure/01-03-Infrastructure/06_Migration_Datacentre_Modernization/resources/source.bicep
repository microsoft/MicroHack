@description('Location for all resources')
param location string

@description('Name for VM1')
param vm1Name string = 'vm1'

@description('Name for VM2')
param vm2Name string = 'vm2'

@description('Admin username for all VMs')
param adminUsername string

@secure()
@description('Admin password for all VMs')
param adminPassword string

// Network

resource sourceVnetNsg 'Microsoft.Network/networkSecurityGroups@2022-05-01' = {
  name: 'source-vnet-nsg'
  location: location
  properties: {
    securityRules: [
      {
        name: 'default-allow-3389'
        properties: {
          priority: 1000
          access: 'Allow'
          direction: 'Inbound'
          destinationPortRange: '3389'
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'default-allow-22'
        properties: {
          priority: 2000
          access: 'Allow'
          direction: 'Inbound'
          destinationPortRange: '22'
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

resource sourceVnet 'Microsoft.Network/virtualNetworks@2022-05-01' = {
  name: 'source-vnet'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.1.1.0/24'
      ]
    }
    subnets: [
      {
        name: 'source-subnet'
        properties: {
          addressPrefix: '10.1.1.0/24'
          networkSecurityGroup: {
            id: sourceVnetNsg.id
          }
        }
      }
    ]
  }
}

// VM1 (Windows)

resource vm1Pip 'Microsoft.Network/publicIPAddresses@2022-05-01' = {
  name: '${vm1Name}-pip'
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    publicIPAllocationMethod: 'Dynamic'
  }
}

resource vm1Nic 'Microsoft.Network/networkInterfaces@2022-05-01' = {
  name: '${vm1Name}-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: vm1Pip.id
          }
          subnet: {
            id: sourceVnet.properties.subnets[0].id
          }
        }
      }
    ]
  }
}

resource vm1 'Microsoft.Compute/virtualMachines@2022-03-01' = {
  name: vm1Name
  location: location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_D2s_v5'
    }
    osProfile: {
      computerName: vm1Name
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2022-datacenter-smalldisk-g2'
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
          id: vm1Nic.id
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: false
      }
    }
  }
}

/*
* Custom Script Extension (might be useful for later to generate load on VM)
* TODO: To be tested
*
resource vm1Extension 'Microsoft.Compute/virtualMachines/extensions@2022-03-01' = {
  parent: vm1
  name: '${vm1Name}-customScriptExtension'
  location: location
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    settings: {
      timestamp: 123456789
    }
    protectedSettings: {
      commandToExecute: 'myExecutionCommand'
      storageAccountName: 'myStorageAccountName'
      storageAccountKey: 'myStorageAccountKey'
      managedIdentity: {}
      fileUris: [
        'script location'
      ]
    }
  }
} */

// VM2 (Linux)

resource vm2Pip 'Microsoft.Network/publicIPAddresses@2022-05-01' = {
  name: '${vm2Name}-pip'
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    publicIPAllocationMethod: 'Dynamic'
  }
}

resource vm2Nic 'Microsoft.Network/networkInterfaces@2022-05-01' = {
  name: '${vm2Name}-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: vm2Pip.id
          }
          subnet: {
            id: sourceVnet.properties.subnets[0].id
          }
        }
      }
    ]
  }
}

resource vm2 'Microsoft.Compute/virtualMachines@2022-03-01' = {
  name: vm2Name
  location: location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_D2s_v5'
    }
    osProfile: {
      computerName: vm2Name
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-jammy'
        sku: '22_04-lts-gen2'
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
          id: vm2Nic.id
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: false
      }
    }
  }
}

/*
* Custom Script Extension (might be useful for later to generate load on VM)
* TODO: To be tested
*
resource vm2Extension 'Microsoft.Compute/virtualMachines/extensions@2022-03-01' = {
  parent: vm2
  name: '${vm2Name}-customScriptExtension'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.Extensions'
    type: 'CustomScript'
    typeHandlerVersion: '2.1'
    autoUpgradeMinorVersion: true
    settings: {
      skipDos2Unix: false
      timestamp: 123456789
    }
    protectedSettings: {
      commandToExecute: 'xxx'
      script: 'xxx'
      storageAccountName: 'xxx'
      storageAccountKey: 'xxx'
      fileUris: [ 'xxx' ]
      managedIdentity: 'xxx'
    }
  }
} */
