targetScope='resourceGroup'

@description('Name of the virtual machine')
param vmName string
@description('Name of the load balancer which will be used to loadbalance the virtual machine')
param lbName string
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
param adminUsername string
@description('Private IP address of the virtual machine')
param privateip string
@description('cloud-init script to be executed on the virtual machine')
param customData string = ''
@description('object id of the user which will be assigned as virtual machine administrator role')
param userObjectId string
@description('VM Image Reference')
param imageReference object
// @description('VM Image Plan')
// param imagePlan object

resource vnet 'Microsoft.Network/virtualNetworks@2023-05-01' existing = {
  name: vnetName
}

resource lb 'Microsoft.Network/loadBalancers@2023-05-01' existing = {
  name: lbName
}

resource nic 'Microsoft.Network/networkInterfaces@2023-05-01' = {
  name: vmName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: vmName
        properties: {
          privateIPAddress:privateip
          privateIPAllocationMethod: 'Static'
          subnet: {
            id: '${vnet.id}/subnets/${subnetName}'
          }
          loadBalancerBackendAddressPools: [
            {
              id: lb.properties.backendAddressPools[0].id
              name: 'LoadBalancerBackEndPool'
            }
            {
              id: lb.properties.backendAddressPools[1].id
              name: 'LoadBalancerBackEndPoolOutbound'
            }
          ] 
          primary: true
          privateIPAddressVersion: 'IPv4'
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
      vmSize: 'Standard_D2s_v5'
    }
    storageProfile: {
      osDisk: {
        name: vmName
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
        deleteOption:'Delete'
      }
      imageReference: imageReference
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      adminPassword: adminPassword
      customData: !empty(customData) ? base64(customData) : null
      linuxConfiguration: {
        disablePasswordAuthentication: false
      }
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

resource vm_extension 'Microsoft.Compute/virtualMachines/extensions@2021-04-01' = {
  name: 'CustomScript'
  parent: vm
  location: location
  properties: {
    publisher: 'Microsoft.Azure.Extensions'
    type: 'CustomScript'
    typeHandlerVersion: '2.1'
    autoUpgradeMinorVersion: true
    settings: {
      commandToExecute: 'sudo systemctl stop firewalld && sudo systemctl disable firewalld'
    }
  }
}

// resource vmaadextension 'Microsoft.Compute/virtualMachines/extensions@2023-07-01' = {
//   parent: vm
//   name: 'AADSSHLoginForLinux'
//   location: location
//   properties: {
//     publisher: 'Microsoft.Azure.ActiveDirectory'
//     type: 'AADSSHLoginForLinux'
//     typeHandlerVersion: '1.0'
//   }
// }

// resource nwagentextension 'Microsoft.Compute/virtualMachines/extensions@2023-07-01' = {
//   parent: vm
//   name: 'NetworkWatcherAgentLinux'
//   location: location
//   properties: {
//     publisher: 'Microsoft.Azure.NetworkWatcher'
//     type: 'NetworkWatcherAgentLinux'
//     typeHandlerVersion: '1.4'
//   }
// }

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
