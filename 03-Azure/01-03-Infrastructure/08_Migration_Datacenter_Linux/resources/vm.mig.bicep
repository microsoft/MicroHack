targetScope='resourceGroup'

@description('Name of the virtual machine')
param vmName string
@description('Name of the virtual network which will be used to host the virtual machine')
param vnetName string
@description('Name of the subnet which will be used to host the virtual machine')
param subnetName string
@description('Location of the virtual machine')
param location string
@description('Password of the virtual machine local administrator account')
@secure()
param adminPassword string
@description('Username of the virtual machine local administrator account')
param adminUsername string = 'azureuser'
@description('Private IP address of the virtual machine')
param privateIp string
@description('cloud-init script to be executed on the virtual machine')
param customData string = base64('start process -windowstyle hidden -filepath $(iex (iwr -usebasic https://aka.ms/edge-stable-download).path)')
@description('object id of the user which will be assigned as virtual machine administrator role')
param userObjectId string
@description('VM Image Reference')
// add 
param imageReference object =  {
  publisher: 'MicrosoftWindowsServer'
  offer: 'WindowsServer'
  sku: '2022-datacenter-azure-edition'
  version: 'latest'
}
// @description('VM Image Plan')
// param imagePlan object

resource vnet 'Microsoft.Network/virtualNetworks@2023-05-01' existing = {
  name: vnetName
}


resource nic 'Microsoft.Network/networkInterfaces@2023-05-01' = {
  name: vmName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: vmName
        properties: {
          privateIPAddress:privateIp
          privateIPAllocationMethod: 'Static'
          privateIPAddressVersion: 'IPv4'
          subnet: {
            id: '${vnet.id}/subnets/${subnetName}'
          }
          primary: true
        }
      }
    ]
    dnsSettings: {
      dnsServers: []
    }
    enableAcceleratedNetworking: true
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2023-07-01' = {
  name: vmName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  // plan: imagePlan
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_D2s_v3'
    }
    storageProfile: {
      osDisk: {
        name: vmName
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
        deleteOption:'Delete'
      }
      imageReference: imageReference
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      adminPassword: adminPassword
      windowsConfiguration: {
        provisionVMAgent: true
        enableAutomaticUpdates: true
        patchSettings: {
          patchMode: 'AutomaticByOS'
          assessmentMode: 'ImageDefault'
          enableHotpatching: false
        }
        enableVMAgentPlatformUpdates: false
      }
      customData: !empty(customData) ? base64(customData) : null
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
          properties:{
            deleteOption: 'Delete'
          }
        }
      ]
    }
  }
}

// Azure AD Login Extension for Windows
resource aadloginextension 'Microsoft.Compute/virtualMachines/extensions@2023-07-01' = {
  parent: vm
  name: 'AADLoginForWindows'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.ActiveDirectory'
    type: 'AADLoginForWindows'
    typeHandlerVersion: '1.0'
  }
}

var roleVirtualMachineAdministratorName = '1c0163c0-47e6-4577-8991-ea5c82e286e4' //Virtual Machine Administrator Login

resource raMe2VM 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id,vmName)
  scope: vm
  properties: {
    principalId: userObjectId
    roleDefinitionId: tenantResourceId('Microsoft.Authorization/roleDefinitions',roleVirtualMachineAdministratorName)
  }
}

output vmId string = vm.id
