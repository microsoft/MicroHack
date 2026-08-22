targetScope = 'resourceGroup'

@description('Azure region for all Adaptive Apps lab resources.')
param location string = resourceGroup().location

@description('Stable suffix used to keep resource names unique per participant.')
@minLength(6)
@maxLength(12)
param nameSuffix string

@description('Local administrator name for the private K3s VM.')
param adminUsername string = 'azureuser'

@description('Local administrator password for the private K3s VM.')
@secure()
param adminPassword string

@description('AKS system-pool VM size. The deployment wrapper retries in the next preferred region on capacity or quota failures.')
param aksNodeVmSize string = 'Standard_D4s_v5'

@description('Private K3s VM size. The deployment wrapper retries in the next preferred region on capacity or quota failures.')
param k3sVmSize string = 'Standard_D4s_v5'

var aksName = 'aks-adaptive-${nameSuffix}'
var vmName = 'vm-k3s-${nameSuffix}'
var vnetName = 'vnet-adaptive-${nameSuffix}'
var nsgName = 'nsg-k3s-${nameSuffix}'
var nicName = 'nic-k3s-${nameSuffix}'
var bastionName = 'bas-adaptive-${nameSuffix}'
var bastionPublicIpName = 'pip-bastion-${nameSuffix}'
var natPublicIpName = 'pip-nat-${nameSuffix}'
var natGatewayName = 'nat-adaptive-${nameSuffix}'
var k3sPrivateIp = '10.42.0.4'

var tags = {
  workload: 'sovereign-adaptive-apps'
  challenge: '7'
}

var k3sInstallScript = '''
#!/usr/bin/env bash
set -euo pipefail

install -d -m 0755 /etc/rancher/k3s
cat >/etc/rancher/k3s/config.yaml <<'EOF'
tls-san:
  - 127.0.0.1
  - ${k3sPrivateIp}
write-kubeconfig-mode: "0600"
disable:
  - traefik
EOF

if command -v k3s >/dev/null 2>&1; then
  systemctl enable --now k3s
  systemctl restart k3s
else
  curl --fail --location --silent --show-error https://get.k3s.io --output /tmp/install-k3s.sh
  sh /tmp/install-k3s.sh
  rm -f /tmp/install-k3s.sh
fi

systemctl is-active --quiet k3s
'''

resource natPublicIp 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: natPublicIpName
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

resource natGateway 'Microsoft.Network/natGateways@2024-05-01' = {
  name: natGatewayName
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    idleTimeoutInMinutes: 10
    publicIpAddresses: [
      {
        id: natPublicIp.id
      }
    ]
  }
}

resource nsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: nsgName
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'AllowBastionSsh'
        properties: {
          priority: 100
          access: 'Allow'
          direction: 'Inbound'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '22'
          sourceAddressPrefix: '10.42.1.0/26'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'AllowBastionK3sApi'
        properties: {
          priority: 110
          access: 'Allow'
          direction: 'Inbound'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '6443'
          sourceAddressPrefix: '10.42.1.0/26'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: vnetName
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
          natGateway: {
            id: natGateway.id
          }
          networkSecurityGroup: {
            id: nsg.id
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

resource k3sSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' existing = {
  name: 'snet-k3s'
  parent: vnet
}

resource bastionSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' existing = {
  name: 'AzureBastionSubnet'
  parent: vnet
}

resource nic 'Microsoft.Network/networkInterfaces@2024-05-01' = {
  name: nicName
  location: location
  tags: tags
  properties: {
    networkSecurityGroup: {
      id: nsg.id
    }
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Static'
          privateIPAddress: k3sPrivateIp
          subnet: {
            id: k3sSubnet.id
          }
        }
      }
    ]
  }
}

resource k3sVm 'Microsoft.Compute/virtualMachines@2024-11-01' = {
  name: vmName
  location: location
  tags: tags
  properties: {
    hardwareProfile: {
      vmSize: k3sVmSize
    }
    osProfile: {
      computerName: vmName
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
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
        diskSizeGB: 64
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

resource k3sExtension 'Microsoft.Compute/virtualMachines/extensions@2024-11-01' = {
  name: 'install-k3s'
  parent: k3sVm
  location: location
  properties: {
    publisher: 'Microsoft.Azure.Extensions'
    type: 'CustomScript'
    typeHandlerVersion: '2.1'
    autoUpgradeMinorVersion: true
    protectedSettings: {
      commandToExecute: 'echo ${base64(k3sInstallScript)} | base64 --decode | bash'
    }
  }
}

resource bastionPublicIp 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: bastionPublicIpName
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
  name: bastionName
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    enableTunneling: true
    ipConfigurations: [
      {
        name: 'bastion-ipconfig'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: bastionPublicIp.id
          }
          subnet: {
            id: bastionSubnet.id
          }
        }
      }
    ]
  }
}

resource aks 'Microsoft.ContainerService/managedClusters@2024-10-01' = {
  name: aksName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    dnsPrefix: aksName
    enableRBAC: true
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
    agentPoolProfiles: [
      {
        name: 'system'
        count: 2
        vmSize: aksNodeVmSize
        osType: 'Linux'
        osSKU: 'Ubuntu'
        mode: 'System'
        type: 'VirtualMachineScaleSets'
        osDiskType: 'Managed'
      }
    ]
    networkProfile: {
      networkPlugin: 'azure'
      networkPluginMode: 'overlay'
      networkPolicy: 'azure'
      loadBalancerSku: 'standard'
      outboundType: 'loadBalancer'
    }
  }
}

output aksClusterName string = aks.name
output bastionName string = bastion.name
output k3sVmName string = k3sVm.name
output k3sVmResourceId string = k3sVm.id
output k3sPrivateIp string = k3sPrivateIp
output natEgressIp string = natPublicIp.properties.ipAddress
output k3sInstallStatusResource string = k3sExtension.id
