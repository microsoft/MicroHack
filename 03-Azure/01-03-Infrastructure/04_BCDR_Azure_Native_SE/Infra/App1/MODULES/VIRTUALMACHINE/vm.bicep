param namePrefix string
param nameSuffix string
var location = resourceGroup().location
var Name = '${namePrefix}-${nameSuffix}'
param purpose string
param vmSize string
param osDiskSize int
param dataDiskSize int
param osType string
param adminUsername string
@secure()
param adminPassword string
param imagePublisher string
param imageOffer string
param imageSku string
param imageVersion string
param publicIp bool
param subnetId string
param backendAddressPools array
param avset string

// Resources
@description('Network interface')
resource networkInterface 'Microsoft.Network/networkInterfaces@2024-01-01' = {
  name: '${Name}-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: subnetId
          }
          loadBalancerBackendAddressPools: (purpose == 'web') ? [
                {
                  id: backendAddressPools[0].id
                }
              ] : []
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: publicIp ? {
                id: vmPip.outputs.pipId
              } : null
        }
      }
    ]
  }
}

@description('Public IP configurations for source and target')
module vmPip '../NETWORK/pip.bicep' = if (publicIp) {
  name: '${Name}-pip'
  scope: resourceGroup()
  params: {
    Name: Name
    skuName: 'Basic'
  }
}

@description('Virtual machine')
resource virtualMachine 'Microsoft.Compute/virtualMachines@2024-03-01' = {
  name: Name
  location: location
  tags: {
    purpose: purpose
  }
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: Name
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: imagePublisher
        offer: imageOffer
        sku: imageSku
        version: imageVersion
      }
      osDisk: {
        createOption: 'FromImage'
        diskSizeGB: osDiskSize
        osType: osType
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
      }
      dataDisks: dataDiskSize != 0 ? [
            {
              createOption: 'Empty'
              diskSizeGB: dataDiskSize
              lun: 0
              managedDisk: {
                storageAccountType: 'Standard_LRS'
              }
            }
          ] : []
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: networkInterface.id
        }
      ]
    }
    availabilitySet: purpose == 'web' ? {
          id: avset
        } : null
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
  }
  identity: {
    type: 'SystemAssigned'
  }
}

@description('Custom script extension to deploy IIS')
resource iisExtension 'Microsoft.Compute/virtualMachines/extensions@2024-03-01' = if (purpose == 'web') {
  parent: virtualMachine
  name: 'iisExtension'
  location: location
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    settings: {
      fileUris: [
        'https://raw.githubusercontent.com/dsmithcloud/ASR-Lab/refs/heads/main/MODULES/VIRTUALMACHINE/VMEXTENSIONS/DeployIIS.ps1'
      ]
      commandToExecute: 'powershell -ExecutionPolicy Unrestricted -File DeployIIS.ps1'
    }
  }
}

// Resource: SQL Virtual Machine
resource sqlVm 'Microsoft.SqlVirtualMachine/sqlVirtualMachines@2023-10-01' = if (purpose == 'sql') {
  name: Name
  location: location
  properties: {
    virtualMachineResourceId: virtualMachine.id
    sqlServerLicenseType: 'PAYG'
  }
}

@description('Custom script extension to deploy AdventureWorks database to SQL Server')
resource AdventureWorks 'Microsoft.Compute/virtualMachines/extensions@2024-07-01' = if (purpose == 'sql') {
  parent: virtualMachine
  name: 'SQL-with-AdventureWorks'
  location: location
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    protectedSettings: {
      script: 'DeploySQLDB.ps1'
      commandToExecute: 'powershell -ExecutionPolicy Unrestricted -File DeploySQLDB.ps1 -AdminUsername "${adminUsername}" -AdminPassword "${adminPassword}"'
    }
    settings: {
      fileUris: [
        'https://raw.githubusercontent.com/Azure/USFSI-ASR-Lab/main/MODULES/VIRTUALMACHINE/VMEXTENSIONS/DeploySQLDB.ps1'
      ]
    }
  }
}

// Output
@description('Output the VM ID and NIC ID')
output vmId string = virtualMachine.id
output vmNicId string = networkInterface.id
output vmName string = virtualMachine.name
output vmMI string = virtualMachine.identity.principalId
