targetScope = 'resourceGroup'

@description('Must match the participant resource group: the PostgreSQL recipe uses resourceGroup().location.')
param location string = resourceGroup().location

@secure()
param adminPassword string

param adminUsername string = 'azureuser'

var tags = {
  workload: 'adaptive-apps'
  SecurityControl: 'Ignore'
  CostControl: 'Ignore'
}
var acrName = 'acad${uniqueString(subscription().subscriptionId, resourceGroup().id)}'

resource registry 'Microsoft.ContainerRegistry/registries@2025-11-01' = {
  name: acrName
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    adminUserEnabled: false
    anonymousPullEnabled: true
    publicNetworkAccess: 'Enabled'
  }
}

resource cluster 'Microsoft.ContainerService/managedClusters@2025-05-01' = {
  name: 'aks-adaptive-apps'
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  sku: {
    name: 'Base'
    tier: 'Free'
  }
  properties: {
    dnsPrefix: 'adaptive-${uniqueString(resourceGroup().id)}'
    enableRBAC: true
    nodeResourceGroup: 'MC_${resourceGroup().name}_aks-adaptive-apps_${location}'
    agentPoolProfiles: [
      {
        name: 'system'
        mode: 'System'
        count: 2
        vmSize: 'Standard_D4s_v5'
        osType: 'Linux'
        osSKU: 'Ubuntu'
        osDiskType: 'Managed'
        osDiskSizeGB: 128
        type: 'VirtualMachineScaleSets'
        enableAutoScaling: false
        upgradeSettings: {
          maxSurge: '1'
        }
      }
    ]
    networkProfile: {
      networkPlugin: 'azure'
      networkPluginMode: 'overlay'
      podCidr: '10.244.0.0/16'
      serviceCidr: '10.0.0.0/16'
      dnsServiceIP: '10.0.0.10'
      loadBalancerSku: 'standard'
      outboundType: 'loadBalancer'
      loadBalancerProfile: {
        managedOutboundIPs: {
          count: 1
        }
      }
    }
    oidcIssuerProfile: {
      enabled: true
    }
    securityProfile: {
      workloadIdentity: {
        enabled: true
      }
    }
    serviceMeshProfile: {
      mode: 'Istio'
    }
  }
}

resource natIp 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: 'pip-adaptive-apps-nat'
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}

resource nat 'Microsoft.Network/natGateways@2024-05-01' = {
  name: 'natgw-adaptive-apps'
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIpAddresses: [
      {
        id: natIp.id
      }
    ]
    idleTimeoutInMinutes: 10
  }
}

resource nsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: 'nsg-adaptive-apps-k3s'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'BastionToK3s'
        properties: {
          priority: 100
          access: 'Allow'
          direction: 'Inbound'
          protocol: 'Tcp'
          sourceAddressPrefix: '10.42.1.0/26'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRanges: [
            '22'
            '6443'
          ]
        }
      }
      {
        name: 'DenyOtherInbound'
        properties: {
          priority: 200
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

resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: 'vnet-adaptive-apps'
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.42.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'snet-k3s'
        properties: {
          addressPrefix: '10.42.0.0/24'
          defaultOutboundAccess: false
          networkSecurityGroup: {
            id: nsg.id
          }
          natGateway: {
            id: nat.id
          }
        }
      }
      {
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: '10.42.1.0/26'
        }
      }
    ]
  }
}

resource nic 'Microsoft.Network/networkInterfaces@2024-05-01' = {
  name: 'nic-adaptive-apps-k3s'
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'private'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: '${vnet.id}/subnets/snet-k3s'
          }
        }
      }
    ]
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2024-07-01' = {
  name: 'vm-adaptive-apps-k3s'
  location: location
  tags: tags
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_D4s_v5'
    }
    osProfile: {
      computerName: 'adaptive-k3s'
      adminUsername: adminUsername
      adminPassword: adminPassword
      linuxConfiguration: {
        disablePasswordAuthentication: false
        provisionVMAgent: true
      }
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
        diskSizeGB: 64
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
        }
      ]
    }
  }
}

resource bastionIp 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: 'pip-adaptive-apps-bastion'
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}

resource bastion 'Microsoft.Network/bastionHosts@2024-05-01' = {
  name: 'bas-adaptive-apps'
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    enableTunneling: true
    scaleUnits: 2
    ipConfigurations: [
      {
        name: 'bastion'
        properties: {
          subnet: {
            id: '${vnet.id}/subnets/AzureBastionSubnet'
          }
          publicIPAddress: {
            id: bastionIp.id
          }
        }
      }
    ]
  }
}

output acrName string = registry.name
output nodeResourceGroup string = cluster.properties.nodeResourceGroup
output k3sVmName string = vm.name
output bastionName string = bastion.name
