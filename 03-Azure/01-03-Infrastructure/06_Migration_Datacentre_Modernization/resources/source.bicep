@description('Object ID of the current user')
// https://github.com/Azure/bicep/discussions/9969
// "There's no function to get the principal ID of the user executing the deployment (though it is planned)."
param currentUserObjectId string

// Locals
param vm1Name string = 'frontend'
param vm2Name string = 'backend'
param adminUsername string = 'microhackadmin'
param location string = resourceGroup().location
param tenantId string = subscription().tenantId
param secretsPermissions array = [
  'all'
]
@secure()
param adminPassword string = newGuid()
param cloudInit string = '''
#cloud-config
package_upgrade: true
packages:
  - nginx
'''

/*
* Secrets
*/
resource sourceKeyvault 'Microsoft.KeyVault/vaults@2021-11-01-preview' = {
  name: substring('source-kv-${uniqueString(resourceGroup().id)}', 0, 16)
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

resource adminPasswordSecret 'Microsoft.KeyVault/vaults/secrets@2021-11-01-preview' = {
  parent: sourceKeyvault
  name: 'adminPassword'
  properties: {
    value: adminPassword
  }
}

resource adminUsernameSecret 'Microsoft.KeyVault/vaults/secrets@2021-11-01-preview' = {
  parent: sourceKeyvault
  name: 'adminUsername'
  properties: {
    value: adminUsername
  }
}

/*
* Network
*/
resource sourceVnetNsg 'Microsoft.Network/networkSecurityGroups@2022-05-01' = {
  name: 'source-vnet-nsg'
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

resource sourceVnet 'Microsoft.Network/virtualNetworks@2022-05-01' = {
  name: 'source-vnet'
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

resource sourceBastionPip 'Microsoft.Network/publicIPAddresses@2022-05-01' = {
  name: 'source-bastion-pip'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource sourceBastion 'Microsoft.Network/bastionHosts@2022-07-01' = {
  name: 'source-bastion'
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

/*
* VM1 (Windows)
*/

/*
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
*/

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


//Custom Script Extension (might be useful for later to generate load on VM)
//TODO: To be tested

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
            commandToExecute: 'powershell -ExecutionPolicy Unrestricted Add-WindowsFeature Web-Server; powershell -ExecutionPolicy Unrestricted Add-Content -Path "C:\\inetpub\\wwwroot\\Default.htm" -Value $($env:computername)'
    }
    protectedSettings: {
          }
  }
} 

/*
* VM2 (Linux)
*/
/*
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
*/

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
      customData: base64(cloudInit)
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
Custom Script Extension (might be useful for later to generate load on VM)
TODO: To be tested
*/

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
      commandToExecute: 'apt-get -y update && apt-get install net-tools'
    }
    protectedSettings: {
    }
  }
} 


//Public Load Balancer for Frontend VM
resource lb 'Microsoft.Network/loadBalancers@2021-08-01' = {
  name: 'plb-frontend'
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
            id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', 'plb-frontend', 'LoadBalancerFrontEnd')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', 'plb-frontend', 'LoadBalancerBackEndPool')
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
            id: resourceId('Microsoft.Network/loadBalancers/probes', 'plb-frontend', 'loadBalancerHealthProbe')
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
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', 'plb-frontend', 'LoadBalancerBackEndPoolOutbound')
          }
          frontendIPConfigurations: [
            {
              id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', 'plb-frontend', 'LoadBalancerFrontEndOutbound')
            }
          ]
        }
      }
    ]
  }
}

resource lbPublicIPAddress 'Microsoft.Network/publicIPAddresses@2021-08-01' = {
  name: 'lbPublicIP'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Static'
  }
}

resource lbPublicIPAddressOutbound 'Microsoft.Network/publicIPAddresses@2021-08-01' = {
  name: 'lbPublicIPOutbound'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Static'
  }
}
