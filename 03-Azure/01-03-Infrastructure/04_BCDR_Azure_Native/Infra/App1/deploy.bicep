// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.
/*
SUMMARY: Bicep template to create the resources for a demo of Azure Site Recovery (ASR) for VMs.
DESCRIPTION: This Bicep file is used to deploy a VM in a source region and configure ASR to replicate the VM to a target region.
AUTHOR/S: David Smith (CSA FSI)
*/

// Scope
targetScope = 'subscription'

// Parameters & variables (see deployparam.yaml file)
@description('Deployment Prefix')
param parDeploymentPrefix string
@description('Source VM Region')
param sourceLocation string
@description('Target VM Region')
param targetLocation string
@secure()
param vmAdminPassword string
@description('VNet configurations for hub')
param hubVnetConfig object
@description('VNet configurations for source')
param sourceVnetConfig object
@description('VNet configurations for target')
param targetVnetConfig object
@description('Vnet configuration for test failovers')
param testVnetConfig object
param vmConfigs array
// @description('Notification Email Address')
// param userPrincipalId string

// param monitorConfigs object

// Resources
@description('Resource Groups for source and target')
resource sourceRG 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: '${parDeploymentPrefix}-source-${sourceLocation}-rg'
  location: sourceLocation
}
@description('Resource Groups for source and target')
resource targetRG 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: '${parDeploymentPrefix}-target-${targetLocation}-rg'
  location: targetLocation
}

@description('Log Analytics Account in Source Region')
module logAnalytics './MODULES/MONITORING/monitor.bicep' = {
  name: 'loganalytics'
  scope: sourceRG
  params: {
    namePrefix: parDeploymentPrefix
    // emailAddress: monitorConfigs.emailAddress
    // queries: monitorConfigs.asrqueries
    // alerts: monitorConfigs.asralerts
  }
}

@description('ASR Vault in the target region')
module asrvault './MODULES/SITERECOVERY/asrvault.bicep' = {
  name: 'asrvault'
  scope: targetRG
  params: {
    namePrefix: parDeploymentPrefix
    // logAnalyticsWorkspaceId: logAnalytics.outputs.logAnalyticsWorkspaceId
  }
  dependsOn: [
    logAnalytics
  ]
}

@description('Backup Vault in the source region')
module backupvault './MODULES/SITERECOVERY/asrvault.bicep' = {
  name: 'backupvault'
  scope: sourceRG
  params: {
    namePrefix: parDeploymentPrefix
    // logAnalyticsWorkspaceId: logAnalytics.outputs.logAnalyticsWorkspaceId
  }
  dependsOn: [
    logAnalytics
  ]
}

@description('Automation Account for ASR')
module automationacct './MODULES/SITERECOVERY/automation.bicep' = {
  name: 'asr-automationaccount'
  scope: targetRG
  params: {
    namePrefix: parDeploymentPrefix
    // logAnalyticsWorkspaceId: logAnalytics.outputs.logAnalyticsWorkspaceId
  }
}

@description('Storage account for ASR cache')
module storageacct './MODULES/STORAGE/storage.bicep' = {
  name: 'storageacct-${sourceLocation}'
  scope: sourceRG
  params: {
    namePrefix: parDeploymentPrefix
    // logAnalyticsWorkspaceId: logAnalytics.outputs.logAnalyticsWorkspaceId
  }
}

@description('VNet configurations for hub/spokes')
module hubVnet './MODULES/NETWORK/vnet.bicep' = {
  name: 'hubvnet-${sourceLocation}'
  scope: sourceRG
  params: {
    namePrefix: '${parDeploymentPrefix}-hub'
    vnetConfig: hubVnetConfig
    // logAnalyticsWorkspaceId: logAnalytics.outputs.logAnalyticsWorkspaceId
  }
  dependsOn: [
    logAnalytics
  ]
}
module sourceVnet './MODULES/NETWORK/vnet.bicep' = {
  name: 'sourcevnet-${sourceLocation}'
  scope: sourceRG
  params: {
    namePrefix: '${parDeploymentPrefix}-source'
    vnetConfig: sourceVnetConfig
    // logAnalyticsWorkspaceId: logAnalytics.outputs.logAnalyticsWorkspaceId
  }
  dependsOn: [
    logAnalytics
  ]
}
module targetVnet './MODULES/NETWORK/vnet.bicep' = {
  name: 'targetvnet-${targetLocation}'
  scope: targetRG
  params: {
    namePrefix: '${parDeploymentPrefix}-target'
    vnetConfig: targetVnetConfig
    // logAnalyticsWorkspaceId: logAnalytics.outputs.logAnalyticsWorkspaceId
  }
  dependsOn: [
    logAnalytics
  ]
}
module testVnet './MODULES/NETWORK/vnet.bicep' = {
  name: 'testvnet-${targetLocation}'
  scope: targetRG
  params: {
    namePrefix: '${parDeploymentPrefix}-test'
    vnetConfig: testVnetConfig
    // logAnalyticsWorkspaceId: logAnalytics.outputs.logAnalyticsWorkspaceId
  }
  dependsOn: [
    logAnalytics
  ]
}

module peerSourceToHub './MODULES/NETWORK/vnetpeer.bicep' = {
  name: 'peer-${sourceVnet.name}-${hubVnet.name}'
  scope: sourceRG
  params: {
    parHomeNetworkName: sourceVnet.outputs.name
    parRemoteNetworkId: hubVnet.outputs.id
    parUseRemoteGateways: false
    parAllowGatewayTransit: false
  }
}
module peerHubToSource './MODULES/NETWORK/vnetpeer.bicep' = {
  name: 'peer-${hubVnet.name}-${sourceVnet.name}'
  scope: sourceRG
  params: {
    parHomeNetworkName: hubVnet.outputs.name
    parRemoteNetworkId: sourceVnet.outputs.id
    parUseRemoteGateways: false
    parAllowGatewayTransit: false
  }
}
module peerTargetToHub './MODULES/NETWORK/vnetpeer.bicep' = {
  name: 'peer-${targetVnet.name}-${hubVnet.name}'
  scope: targetRG
  params: {
    parHomeNetworkName: targetVnet.outputs.name
    parRemoteNetworkId: hubVnet.outputs.id
    parUseRemoteGateways: false
    parAllowGatewayTransit: false
  }
}
module peerHubToTarget './MODULES/NETWORK/vnetpeer.bicep' = {
  name: 'peer-${hubVnet.name}-${targetVnet.name}'
  scope: sourceRG
  params: {
    parHomeNetworkName: hubVnet.outputs.name
    parRemoteNetworkId: targetVnet.outputs.id
    parUseRemoteGateways: false
    parAllowGatewayTransit: false
  }
}
module peerTestToHub './MODULES/NETWORK/vnetpeer.bicep' = {
  name: 'peer-${testVnet.name}-${hubVnet.name}'
  scope: targetRG
  params: {
    parHomeNetworkName: testVnet.outputs.name
    parRemoteNetworkId: hubVnet.outputs.id
    parUseRemoteGateways: false
    parAllowGatewayTransit: false
  }
}
module peerHubToTest './MODULES/NETWORK/vnetpeer.bicep' = {
  name: 'peer-${hubVnet.name}-${testVnet.name}'
  scope: sourceRG
  params: {
    parHomeNetworkName: hubVnet.outputs.name
    parRemoteNetworkId: testVnet.outputs.id
    parUseRemoteGateways: false
    parAllowGatewayTransit: false
  }
}

@description('Azure Bastion in the source region')
module bastion './MODULES/BASTION/bastion.bicep' = {
  name: 'bastion'
  scope: sourceRG
  params: {
    namePrefix: parDeploymentPrefix
    bastionSubnetId: resourceId(
      subscription().subscriptionId,
      sourceRG.name,
      'Microsoft.Network/virtualNetworks/subnets',
      hubVnet.outputs.name,
      'AzureBastionSubnet'
    )
    // logAnalyticsWorkspaceId: logAnalytics.outputs.logAnalyticsWorkspaceId
  }
  dependsOn: [
    logAnalytics
    hubVnet
    peerSourceToHub
    peerTargetToHub
    peerTestToHub
  ]
}

@description('Key Vault in the source region')
module kv './MODULES/SECURITY/keyvault.bicep' = {
  name: 'keyvault'
  scope: sourceRG
  params: {
    namePrefix: parDeploymentPrefix
    secretName: 'vmAdminPassword'
    vmAdminPassword: vmAdminPassword
    // userPrincipalId: userPrincipalId
    // logAnalyticsWorkspaceId: logAnalytics.outputs.logAnalyticsWorkspaceId
  }
  dependsOn: [
    logAnalytics
  ]
}

@description('Load Balancer')
module lbSource './MODULES/NETWORK/loadbalancer.bicep' = {
  name: 'lbSource'
  scope: sourceRG
  params: {
    namePrefix: parDeploymentPrefix
    // logAnalyticsWorkspaceId: logAnalytics.outputs.logAnalyticsWorkspaceId
  }
  dependsOn: [
    logAnalytics
    sourceVnet
  ]
}
module lbTarget './MODULES/NETWORK/loadbalancer.bicep' = {
  name: 'lbTarget'
  scope: targetRG
  params: {
    namePrefix: parDeploymentPrefix
    // logAnalyticsWorkspaceId: logAnalytics.outputs.logAnalyticsWorkspaceId
  }
  dependsOn: [
    logAnalytics
    targetVnet
  ]
}

@description('VM Availability Sets')
module vmAvSetSource './MODULES/VIRTUALMACHINE/avset.bicep' = {
  name: 'avset-web-source'
  scope: sourceRG
  params: {
    namePrefix: parDeploymentPrefix
    nameSuffix: 'web'
  }
}
module vmAvSetTarget './MODULES/VIRTUALMACHINE/avset.bicep' = {
  name: 'avset-web-target'
  scope: targetRG
  params: {
    namePrefix: parDeploymentPrefix
    nameSuffix: 'web'
  }
}

@description('VM deployments')
var vmAdminUsername = 'azadmin'
module vmDeployments './MODULES/VIRTUALMACHINE/vm.bicep' = [ for vmConfig in vmConfigs: if (vmConfig.deploy) {
    name: 'vm-${vmConfig.nameSuffix}'
    scope: sourceRG
    dependsOn: [
      sourceVnet
      lbSource
      lbTarget
    ]
    params: {
      namePrefix: parDeploymentPrefix
      nameSuffix: vmConfig.nameSuffix
      purpose: vmConfig.purpose
      vmSize: vmConfig.vmSize
      osDiskSize: vmConfig.osDiskSize
      dataDiskSize: vmConfig.dataDiskSize
      osType: vmConfig.osType
      adminUsername: vmAdminUsername
      adminPassword: vmAdminPassword
      imagePublisher: vmConfig.imagePublisher
      imageOffer: vmConfig.imageOffer
      imageSku: vmConfig.imageSku
      imageVersion: vmConfig.imageVersion
      publicIp: vmConfig.publicIp
      subnetId: sourceVnet.outputs.subnets[0].id
      backendAddressPools: (vmConfig.purpose == 'web') ? lbSource.outputs.backendAddressPools : [null]
      // logAnalyticsWorkspaceId: logAnalytics.outputs.logAnalyticsWorkspaceId
      avset: vmAvSetSource.outputs.avsetId
    }
  }]

@description('Traffic Manager profile for the web site on the source VM')
module trafficManager './MODULES/NETWORK/trafficmanager.bicep' = {
  scope: sourceRG
  name: 'myTrafficManagerProfile'
  params: {
    namePrefix: parDeploymentPrefix
    endpoint1Target: lbSource.outputs.fqdn
    endpoint2Target: lbTarget.outputs.fqdn
    // logAnalyticsWorkspaceId: logAnalytics.outputs.logAnalyticsWorkspaceId
  }
}

// Output
// output asrqueries array = monitorConfigs.asrqueries
// output asralerts array = monitorConfigs.asralerts
output vmUserName string = vmAdminUsername
output fqdn string = trafficManager.outputs.trafficManagerfqdn
// output vmNames string = vmNames
