targetScope = 'resourceGroup'

param environmentName string

param location string

param vmName string
param TeamName string = 'TEAM01'
param legacySQLName string

@description('Name of the shared resource group for accessing shared resources')
param sharedResourceGroupName string = ''

param repoBaseURL string = 'https://raw.githubusercontent.com/microsoft/MicroHack/main/03-Azure/01-02%20Data/02-SQL_Modernization/labautomation'

param storageAccountName string
//param managedInstanceName string
param managedInstanceFQDN string

param adminUsername string
@secure()
param adminPassword string

param teamVmSize string = 'Standard_D2s_v5'

param tags object = {
  workload: 'SQL Modernization MicroHack'
  environment: environmentName
  managedBy: 'azd-bicep'
}

//var resourceGroupName = 'rg-${environmentName}'
var vnetName = 'SQLHACK-SHARED-VNET'

resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' existing = {
  name: vnetName
  scope: resourceGroup(sharedResourceGroupName)
}

module teamVms 'modules/team-vm.bicep' = {
  name: 'team-vms'
  //scope: resourceGroup
  params: {
    location: location
    subnetId: vnet.properties.subnets[2].id
    vmSize: teamVmSize
    vmName: vmName
    adminUsername: adminUsername
    adminPassword: adminPassword
    tags: tags
  }
}

module teamVms_cse 'modules/team-vm-cse.bicep' = {
  name: 'team-vms_cse'
  //scope: resourceGroup
  dependsOn: [
    teamVms
  ]
  params: {
    location: location
    vmName: vmName
    repoBaseURL: repoBaseURL
    managedInstanceServer: managedInstanceFQDN
    storageAccountName: storageAccountName
    TeamName: TeamName
    legacySQLName: legacySQLName
    adminUsername: adminUsername
    adminPassword: adminPassword
  }
}

//output AZURE_RESOURCE_GROUP string = resourceGroup.name
output AZURE_LOCATION string = location

//output AZURE_STORAGE_ACCOUNT_NAME string = storage.outputs.storageAccountName

//output SQL_MI_NAME string = managedInstance.outputs.managedInstanceName

//output SQL_MI_FQDN string = managedInstance.outputs.fullyQualifiedDomainName

//output LEGACY_SQL_VM_NAME string = legacySqlVm.outputs.vmName

//output TEAM_VM_NAMES array = teamVms.outputs.vmNames

//output BASTION_NAME string = bastion.outputs.bastionName
