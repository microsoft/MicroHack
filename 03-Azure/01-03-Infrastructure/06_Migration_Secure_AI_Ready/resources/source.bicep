@description('Object ID of the current user')
// https://github.com/Azure/bicep/discussions/9969
// "There's no function to get the principal ID of the user executing the deployment (though it is planned)."
param currentUserObjectId string

// Module Paramaters
@description('Location to deploy all resources')
param location string

@description('Prefix used in the Naming for multiple Deployments in the same Subscription')
param prefix string

@description('Number of the deployment used for multiple Deployments in the same Subscription')
param deployment int

@description('Permission Array to be used with Keyvault')
param secretsPermissions array = [
  'all'
]

@secure()
@description('Admin Password')
param adminPassword string

@description('Deployment Script URL for Windows Machines.')
var deploymentScriptUrl = 'https://raw.githubusercontent.com/microsoft/MicroHack/main/03-Azure/01-03-Infrastructure/06_Migration_Datacenter_Modernization/resources/deploy.ps1'

@description('Cloud Init Data for Linux Machines.')
var customData = loadTextContent('cloud.cfg')  

@description('Admin user variable')
var adminUsername = '${prefix}${deployment}-${userName}'

@description('Create Name for VM1')
var vm1Name = '${prefix}${deployment}-${userName}-Win-fe1'

@description('Create Name for VM2')
var vm2Name = '${prefix}${deployment}-${userName}-Lx-fe2'

@description('Tenant ID used by Keyvault')
var tenantId  = subscription().tenantId

@description('User Name for the Tags')
param userName string 

// Resources
// https://learn.microsoft.com/en-us/azure/templates/microsoft.keyvault/vaults?pivots=deployment-language-bicep
@description('Source Keyvault')
resource sourceKeyvault 'Microsoft.KeyVault/vaults@2021-11-01-preview' = {
  name: substring('${prefix}${deployment}${userName}sourcekv${uniqueString(resourceGroup().id)}', 0, 22)
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
  name: '${prefix}${deployment}-${userName}-source-vnet-nsg'
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
  name: '${prefix}${deployment}-${userName}-source-vnet'
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
  name: '${prefix}${deployment}-${userName}-source-bastion-pip'
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
  name: '${prefix}${deployment}-${userName}-source-bastion'
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
          privateIPAllocationMethod: 'Static'
          privateIPAddress: '10.1.1.5'
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
      vmSize: 'Standard_D2as_v5'
    }
    osProfile: {
      computerName: 'Winfe1'
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
            commandToExecute: 'powershell -ExecutionPolicy Unrestricted Add-WindowsFeature Web-Server -IncludeManagementTools; powershell -ExecutionPolicy Unrestricted -File deploy.ps1'
            fileUris: [deploymentScriptUrl]
    }
    protectedSettings: {
          }
  }
} 


// https://learn.microsoft.com/en-us/azure/templates/microsoft.network/networkinterfaces?pivots=deployment-language-bicep
@description('Linux VM NIC')
resource vm2Nic 'Microsoft.Network/networkInterfaces@2022-05-01' = {
  name: '${vm2Name}-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Static'
          privateIPAddress: '10.1.1.4'
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
@description('Linux Virtual Machine')
resource vm2 'Microsoft.Compute/virtualMachines@2022-03-01' = {
  name: vm2Name
  location: location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_D2as_v5'
    }
    osProfile: {
      computerName: 'Lxfe2'
      adminUsername: adminUsername
      adminPassword: adminPassword
      customData: !empty(customData) ? base64(customData) : null      
      linuxConfiguration: {
        disablePasswordAuthentication: false
      }      
    }        
    storageProfile: {
      imageReference: {
        publisher: 'RedHat'
        offer: 'RHEL'
        sku: '86-gen2'
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
        enabled: true
      }
    }
  }
}

// https://learn.microsoft.com/en-us/azure/templates/microsoft.compute/virtualmachines/extensions?pivots=deployment-language-bicep
@description('Linux VM Extension')
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
     commandToExecute: 'sudo firewall-cmd --zone=public --add-port=80/tcp --permanent && firewall-cmd --reload'
  }
 }
} 



// https://learn.microsoft.com/en-us/azure/templates/microsoft.network/loadbalancers?pivots=deployment-language-bicep
@description('Loadbalancer for VMs')
resource lb 'Microsoft.Network/loadBalancers@2021-08-01' = {
  name: '${prefix}${deployment}-${userName}-plb-frontend'
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
            id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', '${prefix}${deployment}-${userName}-plb-frontend', 'LoadBalancerFrontEnd')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', '${prefix}${deployment}-${userName}-plb-frontend', 'LoadBalancerBackEndPool')
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
            id: resourceId('Microsoft.Network/loadBalancers/probes', '${prefix}${deployment}-${userName}-plb-frontend', 'loadBalancerHealthProbe')
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
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', '${prefix}${deployment}-${userName}-plb-frontend', 'LoadBalancerBackEndPoolOutbound')
          }
          frontendIPConfigurations: [
            {
              id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', '${prefix}${deployment}-${userName}-plb-frontend', 'LoadBalancerFrontEndOutbound')
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
  name: '${prefix}${deployment}-${userName}-lbPublicIP'
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
  name: '${prefix}${deployment}-${userName}-lbPublicIPOutbound'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Static'
  }
}
