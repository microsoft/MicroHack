targetScope = 'resourceGroup'

param prefix string = 'odaa'
param location string = 'germanywestcentral'
param lawName string = 'odaa'
param postfix string = ''
param subnetAksName string = 'aks'
// param vnetODAAName string = 'ODAAvnet'
// param subnetODAAName string = 'odaasubnet'
param aksVmSize string = 'Standard_D8ds_v5'
param vnetCIDR string = '10.10.0.0'

var subnetAksNamePostfix = '${subnetAksName}${postfix}'

resource law 'Microsoft.OperationalInsights/workspaces@2021-06-01' = {
  name: '${lawName}${postfix}'
  location: 'germanywestcentral'
}

// resource vnetODAA 'Microsoft.Network/virtualNetworks@2021-05-01' existing = {
//   // name: '${vnetODAAName}${postfix}'
//   name: vnetODAAName
// }

resource vnetAks 'Microsoft.Network/virtualNetworks@2021-05-01' = {
  name: '${prefix}${postfix}'
  location: 'germanywestcentral'
  properties: {
    addressSpace: {
      addressPrefixes: [
        '${vnetCIDR}/16'
      ]
    }
    subnets: [
      {
        name: '${subnetAksName}${postfix}'
        properties: {
          addressPrefix: '${vnetCIDR}/23'
        }
      }
    ]
  }
}

resource aks 'Microsoft.ContainerService/managedClusters@2025-05-01' = {
  name: '${prefix}${postfix}'
  location: 'germanywestcentral'
  sku: {
    name: 'Base'
    tier: 'Free'
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    kubernetesVersion: '1.32.6'
    dnsPrefix: '${prefix}${postfix}'
    apiServerAccessProfile: {
      enablePrivateCluster: false // force public API endpoint
      // authorizedIPRanges: length(authorizedIPRanges) == 0 ? [] : authorizedIPRanges
    }
    agentPoolProfiles: [
      {
        name: 'agentpool'
        count: 2
        vmSize: aksVmSize
        osDiskSizeGB: 300
        osDiskType: 'Ephemeral'
        kubeletDiskType: 'OS'
        vnetSubnetID: '${vnetAks.id}/subnets/${subnetAksNamePostfix}'
        maxPods: 30
        type: 'VirtualMachineScaleSets'
        // availabilityZones: [
        //   '2'
        // ]
        maxCount: 2 // reduced from 5
        minCount: 1
        enableAutoScaling: true
        scaleDownMode: 'Delete'
        powerState: {
          code: 'Running'
        }
        orchestratorVersion: '1.32.6'
        enableNodePublicIP: false
        nodeTaints: [
          'CriticalAddonsOnly=true:NoSchedule'
        ]
        mode: 'System'
        osType: 'Linux'
        osSKU: 'Ubuntu'
        upgradeSettings: {
          maxSurge: '1' // reduced from 10% to minimize temporary surge IP usage
          undrainableNodeBehavior: 'Cordon'
          maxUnavailable: '0'
        }
        enableFIPS: false
        securityProfile: {
          enableVTPM: false
          enableSecureBoot: false
        }
      }
      {
        name: 'userpool'
        count: 2
        vmSize: aksVmSize
        osDiskSizeGB: 300
        osDiskType: 'Ephemeral'
        kubeletDiskType: 'OS'
     // vnetSubnetID: '${virtualNetworks_ODAAvnet_externalid}/subnets/${managedClusters_odaa_name}'
        vnetSubnetID: '${vnetAks.id}/subnets/${subnetAksNamePostfix}'
        maxPods: 30
        type: 'VirtualMachineScaleSets'
        // availabilityZones: [
        //   '2'
        // ]
        maxCount: 2 // reduced from 10
        minCount: 1
        enableAutoScaling: true
        scaleDownMode: 'Delete'
        powerState: {
          code: 'Running'
        }
        orchestratorVersion: '1.32.6'
        enableNodePublicIP: false
        mode: 'User'
        osType: 'Linux'
        osSKU: 'Ubuntu'
        upgradeSettings: {
          maxSurge: '10%' // reduced from 10%
          undrainableNodeBehavior: 'Cordon'
          maxUnavailable: '0'
        }
        enableFIPS: false
        securityProfile: {
          enableVTPM: false
          enableSecureBoot: false
        }
      }
    ]
    servicePrincipalProfile: {
      clientId: 'msi'
    }
    addonProfiles: {
      azureKeyvaultSecretsProvider: {
        enabled: false
      }
      azurepolicy: {
        enabled: true
      }
      omsAgent: {
        enabled: true
        config: {
          logAnalyticsWorkspaceResourceID: law.id
          useAADAuth: 'true'
        }
      }
    }
    nodeResourceGroup: 'MC_${prefix}${postfix}_${location}'
    enableRBAC: true
    supportPlan: 'KubernetesOfficial'
    networkProfile: {
      networkPlugin: 'azure'
      networkPolicy: 'none'
      networkDataplane: 'azure'
      loadBalancerSku: 'Standard'
      loadBalancerProfile: {
        managedOutboundIPs: {
          count: 1
        }
        backendPoolType: 'nodeIPConfiguration'
      }
      serviceCidr: '10.72.0.0/16'
      dnsServiceIP: '10.72.0.10'
      outboundType: 'loadBalancer'
      serviceCidrs: [
        '10.72.0.0/16'
      ]
      ipFamilies: [
        'IPv4'
      ]
    }
    autoScalerProfile: {
      'balance-similar-node-groups': 'false'
      'daemonset-eviction-for-empty-nodes': false
      'daemonset-eviction-for-occupied-nodes': true
      expander: 'random'
      'ignore-daemonsets-utilization': false
      'max-empty-bulk-delete': '10'
      'max-graceful-termination-sec': '600'
      'max-node-provision-time': '15m'
      'max-total-unready-percentage': '45'
      'new-pod-scale-up-delay': '0s'
      'ok-total-unready-count': '3'
      'scale-down-delay-after-add': '10m'
      'scale-down-delay-after-delete': '10s'
      'scale-down-delay-after-failure': '3m'
      'scale-down-unneeded-time': '10m'
      'scale-down-unready-time': '20m'
      'scale-down-utilization-threshold': '0.5'
      'scan-interval': '10s'
      'skip-nodes-with-local-storage': 'false'
      'skip-nodes-with-system-pods': 'true'
    }
    autoUpgradeProfile: {
      upgradeChannel: 'patch'
      nodeOSUpgradeChannel: 'NodeImage'
    }
    disableLocalAccounts: false
    securityProfile: {
      imageCleaner: {
        enabled: true
        intervalHours: 168
      }
      workloadIdentity: {
        enabled: true
      }
    }
    storageProfile: {
      diskCSIDriver: {
        enabled: true
      }
      fileCSIDriver: {
        enabled: true
      }
      snapshotController: {
        enabled: true
      }
    }
    oidcIssuerProfile: {
      enabled: true
    }
    workloadAutoScalerProfile: {}
    azureMonitorProfile: {
      metrics: {
        enabled: true
        kubeStateMetrics: {}
      }
    }
    metricsProfile: {
      costAnalysis: {
        enabled: false
      }
    }
    nodeProvisioningProfile: {
      mode: 'Manual'
      defaultNodePools: 'Auto'
    }
    bootstrapProfile: {
      artifactSource: 'Direct'
    }
  }
}
