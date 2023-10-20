@description('Object ID of the current user')
// https://github.com/Azure/bicep/discussions/9969
// "There's no function to get the principal ID of the user executing the deployment (though it is planned)."
param currentUserObjectId string

// Module Paramaters
@description('Location to deploy all resources')
param location string

@description('Prefix used in the Naming for multiple Deployments in the same Subscription')
param prefix string

@description('Suffix used in the Naming for multiple Deployments in the same Subscription')
param suffix string

@description('Number of the deployment used for multiple Deployments in the same Subscription')
param deployment int

@description('Permission Array to be used with Keyvault')
param secretsPermissions array = [
  'all'
]

@secure()
@description('GUID to be used in Password creation')
param guidValue string = newGuid()

// Variables
@description('Admin user variable')
var adminUsername = '${prefix}${deployment}-microhackadmin'

@description('Admin password variable')
var adminPassword = '${toUpper(uniqueString(resourceGroup().id))}-${guidValue}'

@description('Create Name for VM1')
var vm1Name = '${prefix}${deployment}${suffix}-fe-1'

@description('Create Name for VM2')
var vm2Name = '${prefix}${deployment}${suffix}-fe-2'

@description('Tenant ID used by Keyvault')
var tenantId  = subscription().tenantId

// Resources
// https://learn.microsoft.com/en-us/azure/templates/microsoft.keyvault/vaults?pivots=deployment-language-bicep
@description('Source Keyvault')
resource sourceKeyvault 'Microsoft.KeyVault/vaults@2021-11-01-preview' = {
  name: substring('${prefix}${deployment}${suffix}-source-kv-${uniqueString(resourceGroup().id)}', 0, 22)
  location: location
  properties: {
    enabledForDeployment: false
    enabledForDiskEncryption: false
    enabledForTemplateDeployment: true
    tenantId: tenantId
    enableSoftDelete: true
    softDeleteRetentionInDays: 90
    sku: {
      name: 'standard'
      family: 'A'
    }
    accessPolicies: [
      {
        objectId: currentUserObjectId
        tenantId: tenantId
        permissions: {
          secrets: secretsPermissions
        }
      }
    ]
  }
}

// https://learn.microsoft.com/en-us/azure/templates/microsoft.keyvault/vaults/secrets?pivots=deployment-language-bicep
@description('Secret to store Admin Password')
resource adminPasswordSecret 'Microsoft.KeyVault/vaults/secrets@2021-11-01-preview' = {
  parent: sourceKeyvault
  name: 'adminPassword'
  properties: {
    value: adminPassword
  }
}

// https://learn.microsoft.com/en-us/azure/templates/microsoft.keyvault/vaults/secrets?pivots=deployment-language-bicep
@description('Secret to store Admin Username')
resource adminUsernameSecret 'Microsoft.KeyVault/vaults/secrets@2021-11-01-preview' = {
  parent: sourceKeyvault
  name: 'adminUsername'
  properties: {
    value: adminUsername
  }
}

// https://learn.microsoft.com/en-us/azure/templates/microsoft.network/networksecuritygroups?pivots=deployment-language-bicep
@description('Network security group in source network')
resource sourceVnetNsg 'Microsoft.Network/networkSecurityGroups@2022-05-01' = {
  name: '${prefix}${deployment}${suffix}-source-vnet-nsg'
  location: location
  properties: {
    securityRules: [
      {
        name: 'default-allow-80'
        properties: {
          priority: 1000
          access: 'Allow'
          direction: 'Inbound'
          destinationPortRange: '80'
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

// https://learn.microsoft.com/en-us/azure/templates/Microsoft.Network/virtualNetworks?pivots=deployment-language-bicep
@description('Virtual network for the source resources')
resource sourceVnet 'Microsoft.Network/virtualNetworks@2022-05-01' = {
  name: '${prefix}${deployment}${suffix}-source-vnet'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.1.0.0/16'
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
      {
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: '10.1.2.0/24'
        }
      }
    ]
  }
}

// https://learn.microsoft.com/en-us/azure/templates/microsoft.network/publicipaddresses?pivots=deployment-language-bicep
@description('Source Bastion Public IP')
resource sourceBastionPip 'Microsoft.Network/publicIPAddresses@2022-05-01' = {
  name: '${prefix}${deployment}${suffix}-source-bastion-pip'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

// https://learn.microsoft.com/en-us/azure/templates/microsoft.network/bastionhosts?pivots=deployment-language-bicep
@description('Source Network Bastion to access the source Servers')
resource sourceBastion 'Microsoft.Network/bastionHosts@2022-07-01' = {
  name: '${prefix}${deployment}${suffix}-source-bastion'
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          publicIPAddress: {
            id: sourceBastionPip.id
          }
          subnet: {
            id: sourceVnet.properties.subnets[1].id
          }
        }
      }
    ]
  }
}

// https://learn.microsoft.com/en-us/azure/templates/microsoft.network/networkinterfaces?pivots=deployment-language-bicep
@description('Windows VM NIC')
resource vm1Nic 'Microsoft.Network/networkInterfaces@2022-05-01' = {
  name: '${vm1Name}-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          //publicIPAddress: {
          // id: vm1Pip.id
          //}
          subnet: {
            id: sourceVnet.properties.subnets[0].id
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
        }
      }
    ]
  }
}

// https://learn.microsoft.com/en-us/azure/templates/microsoft.compute/virtualmachines?pivots=deployment-language-bicep
@description('Windows Virtual Machine')
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

// https://learn.microsoft.com/en-us/azure/templates/microsoft.compute/virtualmachines/extensions?pivots=deployment-language-bicep
@description('Windows VM Extension')
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
            commandToExecute: 'powershell -ExecutionPolicy Unrestricted Add-WindowsFeature Web-Server -IncludeManagementTools; powershell -ExecutionPolicy Unrestricted Add-Content -Path "C:\\inetpub\\wwwroot\\Default.htm" -Value $($env:computername)'
    }
    protectedSettings: {
          }
  }
} 

// https://learn.microsoft.com/en-us/azure/templates/microsoft.network/networkinterfaces?pivots=deployment-language-bicep
@description('2nd Windows VM NIC')
resource vm2Nic 'Microsoft.Network/networkInterfaces@2022-05-01' = {
  name: '${vm2Name}-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          //publicIPAddress: {
            //id: vm2Pip.id
          //}
          subnet: {
            id: sourceVnet.properties.subnets[0].id
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
        }
      }
    ]
  }
}

// https://learn.microsoft.com/en-us/azure/templates/microsoft.compute/virtualmachines?pivots=deployment-language-bicep
@description('2nd Windows Virtual Machine')
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

// https://learn.microsoft.com/en-us/azure/templates/microsoft.compute/virtualmachines/extensions?pivots=deployment-language-bicep
@description('2nd Windows VM Extension')
resource vm2Extension 'Microsoft.Compute/virtualMachines/extensions@2022-03-01' = {
  parent: vm2
  name: '${vm2Name}-customScriptExtension'
  location: location
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    settings: {
            commandToExecute: 'powershell -ExecutionPolicy Unrestricted Add-WindowsFeature Web-Server -IncludeManagementTools; powershell -ExecutionPolicy Unrestricted Add-Content -Path "C:\\inetpub\\wwwroot\\Default.htm" -Value $($env:computername)'
    }
    protectedSettings: {
          }
  }
} 

// https://learn.microsoft.com/en-us/azure/templates/microsoft.network/loadbalancers?pivots=deployment-language-bicep
@description('Loadbalancer for VMs')
resource lb 'Microsoft.Network/loadBalancers@2021-08-01' = {
  name: '${prefix}${deployment}${suffix}-plb-frontend'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    frontendIPConfigurations: [
      {
        name: 'LoadBalancerFrontEnd'
        properties: {
          publicIPAddress: {
            id: lbPublicIPAddress.id
          }
        }
      }
      {
        name: 'LoadBalancerFrontEndOutbound'
        properties: {
          publicIPAddress: {
            id: lbPublicIPAddressOutbound.id
          }
        }
      }
    ]
    backendAddressPools: [
      {
        name: 'LoadBalancerBackEndPool'

      }
      {
        name: 'LoadBalancerBackEndPoolOutbound'
      }
    ]
    loadBalancingRules: [
      {
        name: 'myHTTPRule'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', '${prefix}${deployment}${suffix}-plb-frontend', 'LoadBalancerFrontEnd')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', '${prefix}${deployment}${suffix}-plb-frontend', 'LoadBalancerBackEndPool')
          }
          frontendPort: 80
          backendPort: 80
          enableFloatingIP: false
          idleTimeoutInMinutes: 15
          protocol: 'Tcp'
          enableTcpReset: true
          loadDistribution: 'Default'
          disableOutboundSnat: true
          probe: {
            id: resourceId('Microsoft.Network/loadBalancers/probes', '${prefix}${deployment}${suffix}-plb-frontend', 'loadBalancerHealthProbe')
          }
        }
      }
    ]
    probes: [
      {
        name: 'loadBalancerHealthProbe'
        properties: {
          protocol: 'Tcp'
          port: 80
          intervalInSeconds: 5
          numberOfProbes: 2
        }
      }
    ]
    outboundRules: [
      {
        name: 'myOutboundRule'
        properties: {
          allocatedOutboundPorts: 10000
          protocol: 'All'
          enableTcpReset: false
          idleTimeoutInMinutes: 15
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', '${prefix}${deployment}${suffix}-plb-frontend', 'LoadBalancerBackEndPoolOutbound')
          }
          frontendIPConfigurations: [
            {
              id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', '${prefix}${deployment}${suffix}-plb-frontend', 'LoadBalancerFrontEndOutbound')
            }
          ]
        }
      }
    ]
  }
}

// https://learn.microsoft.com/en-us/azure/templates/microsoft.network/publicipaddresses?pivots=deployment-language-bicep
@description('Load Balancer Public IP')
resource lbPublicIPAddress 'Microsoft.Network/publicIPAddresses@2021-08-01' = {
  name: '${prefix}${deployment}${suffix}-lbPublicIP'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Static'
  }
}

// https://learn.microsoft.com/en-us/azure/templates/microsoft.network/publicipaddresses?pivots=deployment-language-bicep
@description('Load Balancer Outbound Public IP')
resource lbPublicIPAddressOutbound 'Microsoft.Network/publicIPAddresses@2021-08-01' = {
  name: '${prefix}${deployment}${suffix}-lbPublicIPOutbound'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Static'
  }
}
