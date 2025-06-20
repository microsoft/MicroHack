targetScope = 'resourceGroup'

param prefix string = 'zdm2'
param location string = 'swedencentral'

resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' existing = {
  name: 'vnet1'
}

resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: 'rgmhoracle1perfdiag908'
}

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(virtualMachine.id, 'ba92f5b4-2d11-453d-a403-e96b0029c9fe') // Blog Contributor role ID
  properties: {
    principalId: virtualMachine.identity.principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe') // Blog Contributor role ID
  }
}

resource virtualMachine 'Microsoft.Compute/virtualMachines@2024-07-01' = {
  name: prefix
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    hardwareProfile: {
      // vmSize: 'Standard_D2s_v3'
      vmSize: 'Standard_B4ms'
    }
    additionalCapabilities: {
      hibernationEnabled: false
    }
    storageProfile: {
      imageReference: {
        publisher: 'Oracle'
        offer: 'Oracle-Linux'
        sku: 'ol810-lvm-gen2'
        version: 'latest'
      }
      osDisk: {
        osType: 'Linux'
        name: '${prefix}osdisk'
        createOption: 'FromImage'
        caching: 'ReadWrite'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
                }
        deleteOption: 'Delete'
        diskSizeGB: 30
      }
      dataDisks: [
        {
          lun: 0
          name: '${prefix}datadisk'
          createOption: 'Attach'
          caching: 'ReadOnly'
          writeAcceleratorEnabled: false
          managedDisk: {
            storageAccountType: 'Premium_LRS'
            id: disk.id
          }
          deleteOption: 'Delete'
          // diskSizeGB: 1024
          toBeDetached: false
        }
      ]
      diskControllerType: 'SCSI'
    }
    osProfile: {
      customData: loadFileAsBase64('vm.yaml')
      computerName: prefix
      adminUsername: 'chpinoto'
      adminPassword: 'demo!pass123'
      linuxConfiguration: {
        disablePasswordAuthentication: false
        provisionVMAgent: true
        patchSettings: {
          patchMode: 'ImageDefault'
          assessmentMode: 'ImageDefault'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
          properties: {
            deleteOption: 'Delete'
          }
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
  }
}

resource nic 'Microsoft.Network/networkInterfaces@2024-05-01' = {
  name: prefix
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        type: 'Microsoft.Network/networkInterfaces/ipConfigurations'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: '${vnet.id}/subnets/zdm'
          }
          primary: true
          privateIPAddressVersion: 'IPv4'
        }
      }
    ]
    dnsSettings: {
      dnsServers: []
    }
    // enableAcceleratedNetworking: true
    enableIPForwarding: false
    disableTcpStateTracking: false
    nicType: 'Standard'
    auxiliaryMode: 'None'
    auxiliarySku: 'None'
  }
}

resource disk 'Microsoft.Compute/disks@2024-03-02' = {
  name: '${prefix}datadisk'
  location: location
  sku: {
    name: 'Premium_LRS'
  }
  properties: {
    creationData: {
      createOption: 'Empty'
    }
    diskSizeGB: 2048
    // diskIOPSReadWrite: 5000
    // diskMBpsReadWrite: 200
    // encryption: {
    //   type: 'EncryptionAtRestWithPlatformKey'
    // }
    networkAccessPolicy: 'AllowAll'
    publicNetworkAccess: 'Enabled'
    tier: 'P40'
  }
}
