@description('Stable, per-lab suffix derived from the platform-provided resource group name.')
@minLength(12)
@maxLength(12)
param labSuffix string

@description('Local Windows administrator name on both legacy VMs.')
param adminUsername string = 'azureuser'

@secure()
param adminPassword string

@secure()
param dotnetCustomData string

@secure()
param javaCustomData string

@description('Secret-free, UTF-16LE encoded bootstrap commands for the VM extensions.')
param dotnetBootstrapCommand string
param javaBootstrapCommand string

@description('Changes the extension force-update tag when either provisioning script changes.')
param provisionerVersion string

@description('Full immutable commit used for the source archive.')
param sourceCommit string

param vmSize string = 'Standard_D2as_v5'
@minValue(127)
param osDiskSizeGiB int = 127

@description('Concrete source CIDRs for RDP, or an empty array to leave inbound RDP closed.')
param rdpSourceAddressPrefixes array = []

@description('The participant identities granted Security Reader on this resource group.')
param allowedEntraUserIds array = []

var location = resourceGroup().location
var stacks = [
  {
    name: 'dotnet'
    computerName: 'd-${labSuffix}'
    customData: dotnetCustomData
    bootstrapCommand: dotnetBootstrapCommand
  }
  {
    name: 'java'
    computerName: 'j-${labSuffix}'
    customData: javaCustomData
    bootstrapCommand: javaBootstrapCommand
  }
]
var ownerRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '8e3af657-a8ff-443c-a75c-2fe8c4bcb635')
var securityReaderRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '39bc4728-0917-49c7-9d2c-d95423bc2eb4')

resource nsg 'Microsoft.Network/networkSecurityGroups@2023-04-01' = {
  name: 'nsg-${labSuffix}'
  location: location
  properties: empty(rdpSourceAddressPrefixes) ? {} : {
    securityRules: [
      {
        name: 'rdp'
        properties: {
          priority: 300
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefixes: rdpSourceAddressPrefixes
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '3389'
        }
      }
    ]
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2023-04-01' = {
  name: 'vnet-${labSuffix}'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: ['10.1.0.0/22']
    }
    subnets: [
      {
        name: 'vms'
        properties: {
          addressPrefix: '10.1.0.0/24'
          networkSecurityGroup: {
            id: nsg.id
          }
        }
      }
    ]
  }
}

resource publicIps 'Microsoft.Network/publicIPAddresses@2023-04-01' = [for stack in stacks: {
  name: 'pip-${stack.name}-${labSuffix}'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}]

resource nics 'Microsoft.Network/networkInterfaces@2023-04-01' = [for (stack, i) in stacks: {
  name: 'nic-${stack.name}-${labSuffix}'
  location: location
  properties: {
    enableAcceleratedNetworking: false
    networkSecurityGroup: {
      id: nsg.id
    }
    ipConfigurations: [
      {
        name: 'ipconfig'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: '${vnet.id}/subnets/vms'
          }
          publicIPAddress: {
            id: publicIps[i].id
          }
        }
      }
    ]
  }
}]

resource vms 'Microsoft.Compute/virtualMachines@2024-11-01' = [for (stack, i) in stacks: {
  name: 'vm-${stack.name}-${labSuffix}'
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    storageProfile: {
      osDisk: {
        createOption: 'FromImage'
        deleteOption: 'Delete'
        diskSizeGB: osDiskSizeGiB
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
      }
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2025-datacenter-g2'
        version: 'latest'
      }
    }
    osProfile: {
      computerName: stack.computerName
      adminUsername: adminUsername
      adminPassword: adminPassword
      customData: stack.customData
      windowsConfiguration: {
        enableAutomaticUpdates: false
        patchSettings: {
          patchMode: 'Manual'
        }
      }
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nics[i].id
          properties: {
            primary: true
          }
        }
      ]
    }
  }
}]

resource vmOwners 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for (stack, i) in stacks: {
  name: guid(resourceGroup().id, vms[i].name, ownerRoleId)
  properties: {
    roleDefinitionId: ownerRoleId
    principalId: vms[i].identity.principalId
    principalType: 'ServicePrincipal'
  }
}]

resource securityReaders 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for userId in allowedEntraUserIds: {
  name: guid(resourceGroup().id, userId, securityReaderRoleId)
  properties: {
    roleDefinitionId: securityReaderRoleId
    principalId: userId
    principalType: 'User'
  }
}]

resource vmSetup 'Microsoft.Compute/virtualMachines/extensions@2024-11-01' = [for (stack, i) in stacks: {
  parent: vms[i]
  name: 'provision-${stack.name}'
  location: location
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: false
    forceUpdateTag: uniqueString(provisionerVersion, sourceCommit)
    settings: {
      commandToExecute: stack.bootstrapCommand
    }
  }
  dependsOn: [vmOwners]
}]

output vmNames object = {
  dotnet: vms[0].name
  java: vms[1].name
}
output publicIpAddresses object = {
  dotnet: publicIps[0].properties.ipAddress
  java: publicIps[1].properties.ipAddress
}
output privateIpAddresses object = {
  dotnet: nics[0].properties.ipConfigurations[0].properties.privateIPAddress
  java: nics[1].properties.ipConfigurations[0].properties.privateIPAddress
}
output vnetName string = vnet.name
