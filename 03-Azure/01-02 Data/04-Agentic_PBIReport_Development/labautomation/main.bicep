param location string
param suffix string
param tags object
param adminUsername string
@secure()
param adminPassword string
param vmSize string
@description('Windows image resolved to an exact version by the shared hook.')
param image object
@minValue(128)
param osDiskSizeGB int
param subnetId string
@description('Rerun the same idempotent bootstrap on an explicit hook retry, including after Run Command failure.')
param bootstrapRunId string
@secure()
param bootstrapConfigurationBase64 string

resource nsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: 'nsg-${suffix}'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'BastionRdpOnly'
        properties: {
          priority: 100
          access: 'Allow'
          direction: 'Inbound'
          protocol: 'Tcp'
          sourceAddressPrefix: '10.90.0.0/26'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '3389'
        }
      }
      {
        name: 'DenyOtherInbound'
        properties: {
          priority: 110
          access: 'Deny'
          direction: 'Inbound'
          protocol: '*'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
    ]
  }
}

resource nic 'Microsoft.Network/networkInterfaces@2024-05-01' = {
  name: 'nic-${suffix}'
  location: location
  tags: tags
  properties: {
    networkSecurityGroup: { id: nsg.id }
    ipConfigurations: [
      {
        name: 'primary'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: { id: subnetId }
        }
      }
    ]
  }
}
resource vm 'Microsoft.Compute/virtualMachines@2024-07-01' = {
  name: 'vm-${suffix}'
  location: location
  tags: tags
  properties: {
    hardwareProfile: { vmSize: vmSize }
    storageProfile: {
      imageReference: image
      osDisk: {
        createOption: 'FromImage'
        diskSizeGB: osDiskSizeGB
        managedDisk: { storageAccountType: 'StandardSSD_LRS' }
        deleteOption: 'Delete'
      }
    }
    osProfile: {
      computerName: 'lab${suffix}'
      adminUsername: adminUsername
      adminPassword: adminPassword
      windowsConfiguration: {
        provisionVMAgent: true
        enableAutomaticUpdates: true
      }
    }
    networkProfile: { networkInterfaces: [{ id: nic.id, properties: { deleteOption: 'Delete' } }] }
    diagnosticsProfile: { bootDiagnostics: { enabled: true } }
  }
}
resource bootstrap 'Microsoft.Compute/virtualMachines/runCommands@2024-07-01' = {
  parent: vm
  name: 'bootstrap'
  location: location
  tags: tags
  properties: {
    source: { script: loadTextContent('bootstrap.ps1') }
    timeoutInSeconds: 5400
    asyncExecution: false
    treatFailureAsDeploymentFailure: true
    parameters: [{ name: 'RunId', value: bootstrapRunId }]
    protectedParameters: [{ name: 'ConfigurationBase64', value: bootstrapConfigurationBase64 }]
  }
}

output vmName string = vm.name
