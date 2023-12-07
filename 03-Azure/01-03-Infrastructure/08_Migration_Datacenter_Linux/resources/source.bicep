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

@description('Admin user variable')
param adminUsername string

@secure()
@description('Admin password variable')
param adminPassword string

param customData string 


// @description('Permission Array to be used with Keyvault')
// param secretsPermissions array = [
//   'all'
// ]

// @secure()
// @description('GUID to be used in Password creation')
// param guidValue string = newGuid()

// Variables
@description('Create Name for VM1')
var vm1Name = '${prefix}${deployment}${suffix}1'

@description('Create Name for VM2')
var vm2Name = '${prefix}${deployment}${suffix}2'

// @description('Tenant ID used by Keyvault')
// var tenantId  = subscription().tenantId

@description('Virtual Network Name')
var vnetName = '${prefix}${deployment}${suffix}-source-vnet'

@description('Virtual Network Subnet Name')
var subnetName = 'source-subnet'

@description('Public Loadbalancer Name')
var lbName = '${prefix}${deployment}${suffix}-source-plb-frontend'
var lbPublicIPName = '${prefix}${deployment}${suffix}-source-lbPublicIP'
var lbPublicIPOutboundName = '${prefix}${deployment}${suffix}-source-lbPublicIPOutbound'

@description('Image Reference')
param imageReference object

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
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.1.0.0/16'
      ]
    }
    subnets: [
      {
        name: subnetName
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
resource sourceBastion 'Microsoft.Network/bastionHosts@2023-05-01' = {
  name: '${prefix}${deployment}${suffix}-source-bastion'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    enableTunneling: true
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

module vm1 'vm.bicep' = {
  name: vm1Name
  params: {
    location: location
    vmName: vm1Name
    adminUsername: adminUsername
    adminPassword: adminPassword
    vnetName: vnetName
    subnetName: subnetName
    imageReference: imageReference
    // imagePlan: imagePlan
    lbName: lbName
    userObjectId: currentUserObjectId
    privateip: '10.1.1.4'
    customData: customData
  }
  dependsOn: [
    lb
  ]
}

module vm2 'vm.bicep' = {
  name: vm2Name
  params: {
    location: location
    vmName: vm2Name
    adminUsername: adminUsername
    adminPassword: adminPassword
    vnetName: vnetName
    subnetName: subnetName
    imageReference: imageReference
    // imagePlan: imagePlan
    lbName: lbName
    userObjectId: currentUserObjectId
    privateip: '10.1.1.5'
    customData: customData
  }
  dependsOn: [
    lb
  ]
}

module lb 'loadbalancer.bicep' = {
  name: lbName
  params: {
    location: location
    lbName: lbName
    lbPublicIPName: lbPublicIPName
    lbPublicIPOutboundName: lbPublicIPOutboundName
  }
  dependsOn: [
    sourceVnet
  ]
}


output publicip string = lb.outputs.publicip
output vm1id string = vm1.outputs.vmId
output vm2id string = vm2.outputs.vmId

