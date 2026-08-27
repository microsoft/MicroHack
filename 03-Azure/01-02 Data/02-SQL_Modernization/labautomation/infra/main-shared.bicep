targetScope = 'subscription'

@minLength(1)
@maxLength(20)
param environmentName string

param location string

param repoBaseURL string = 'https://raw.githubusercontent.com/microsoft/MicroHack/main/03-Azure/01-02%20Data/02-SQL_Modernization/labautomation'

param adminUsername string
@secure()
param adminPassword string

param sqlMiAdminUsername string
@secure()
param sqlMiAdminPassword string

param vnetAddressPrefix string = '10.0.0.0/16'
param managedInstanceSubnetPrefix string = '10.0.1.0/24'
param managementSubnetPrefix string = '10.0.2.0/24'
param teamSubnetPrefix string = '10.0.3.0/24'
param bastionSubnetPrefix string = '10.0.4.0/24'
param PrivateEndpointsSubnetPrefix string = '10.0.5.0/24'

param legacySQLName string
param arcSQLName string

param legacyVmSize string = 'Standard_D4s_v5'
param sqlarcVmSize string = 'Standard_D2s_v5'

param managedInstanceVCores int = 8
param managedInstanceStorageGB int = 256

param tags object = {
  workload: 'SQL Modernization MicroHack'
  environment: environmentName
  managedBy: 'azd-bicep'
}

var suffix = uniqueString(
  subscription().subscriptionId,
  environmentName,
  location
)

var resourceGroupName = 'rg-${environmentName}-shared'
var vnetName = 'SQLHACK-SHARED-VNET'
var managedInstanceName = 'sqlmi-${environmentName}-${suffix}'

var storageAccountName = take(
  toLower(
    replace(
      'sqlhack${environmentName}${suffix}',
      '-',
      ''
    )
  ),
  24
)

resource resourceGroup 'Microsoft.Resources/resourceGroups@2024-11-01' existing = {
  name: resourceGroupName
}

module network 'modules/network.bicep' = {
  name: 'network'
  scope: resourceGroup
  params: {
    location: location
    vnetName: vnetName
    vnetAddressPrefix: vnetAddressPrefix
    managedInstanceSubnetPrefix: managedInstanceSubnetPrefix
    managementSubnetPrefix: managementSubnetPrefix
    teamSubnetPrefix: teamSubnetPrefix
    bastionSubnetPrefix: bastionSubnetPrefix
    PrivateEndpointsSubnetPrefix: PrivateEndpointsSubnetPrefix
    tags: tags
  }
}

module bastion 'modules/bastion.bicep' = {
  name: 'bastion'
  scope: resourceGroup
  params: {
    location: location
    bastionName: 'bas-${environmentName}'
    bastionSubnetId: network.outputs.bastionSubnetId
    tags: tags
  }
}

module legacySqlVm 'modules/sql2016-vm.bicep' = {
  name: '${legacySQLName}-vm'
  scope: resourceGroup
  params: {
    location: location
    vmName: legacySQLName
    subnetId: network.outputs.managementSubnetId
    privateIPAddress: '10.0.2.5'
    vmSize: legacyVmSize
    adminUsername: adminUsername
    adminPassword: adminPassword
    tags: tags
  }
}

module sqlarcSqlVm 'modules/sql2022-vm.bicep' = {
  name: '${arcSQLName}-vm'
  scope: resourceGroup
  params: {
    location: location
    vmName: arcSQLName
    subnetId: network.outputs.managementSubnetId
    privateIPAddress: '10.0.2.6'
    vmSize: sqlarcVmSize
    adminUsername: adminUsername
    adminPassword: adminPassword
    tags: tags
  }
}

module managedInstance 'modules/managed-instance.bicep' = {
  name: 'managed-instance'
  scope: resourceGroup
  params: {
    location: location
    managedInstanceName: managedInstanceName
    subnetId: network.outputs.managedInstanceSubnetId
    privateEndpointName: '${managedInstanceName}-pe'
    privateEndpointSubnetId: network.outputs.PrivateEndpointsSubnetId
    vnetId: network.outputs.vnetId
    administratorLogin: sqlMiAdminUsername
    administratorLoginPassword: sqlMiAdminPassword
    vCores: managedInstanceVCores
    storageSizeInGB: managedInstanceStorageGB
    tags: tags
  }
}

module storage 'modules/storage.bicep' = {
  name: 'storage'
  scope: resourceGroup
  params: {
    location: location
    storageAccountName: storageAccountName
    privateEndpointName: '${storageAccountName}-pe'
    privateEndpointSubnetId: network.outputs.PrivateEndpointsSubnetId
    vnetId: network.outputs.vnetId
    tags: tags
  }
}

module storage_rbac 'modules/storage-rbac.bicep' = {
  name: 'storage_rbac'
  //dependsOn: [
  //  storage
  //  legacySqlVm
  //  managedInstance
  //]
  scope: resourceGroup
  params: {
    storageAccountName: storage.outputs.storageAccountName
    vmPrincipalId: legacySqlVm.outputs.vmPrincipalId
    sqlmiPrincipalId: managedInstance.outputs.sqlmiPrincipalId
  }
}

module legacySqlVm_cse 'modules/sql2016-vm-cse.bicep' = {
  name: 'legacy-sql-vm_cse'
  scope: resourceGroup
  params: {
    location: location
    vmName: legacySQLName
    adminUsername: adminUsername
    adminPassword: adminPassword
    sqlMiAdminUsername: sqlMiAdminUsername
    sqlMiAdminPassword: sqlMiAdminPassword
    storageAccountName: storageAccountName
    managedInstanceServer: managedInstance.outputs.fullyQualifiedDomainName
    repoBaseURL: repoBaseURL
  }
}

module sqlarcSqlVm_cse 'modules/sql2022-vm-cse.bicep' = {
  name: 'sqlarc-sql-vm_cse'
  scope: resourceGroup
  dependsOn: [
    sqlarcSqlVm
  ]
  params: {
    location: location
    vmName: 'arcSQL2022'
    adminUsername: adminUsername
    adminPassword: adminPassword
    repoBaseURL: repoBaseURL
  }
}

output AZURE_RESOURCE_GROUP string = resourceGroup.name
output AZURE_LOCATION string = location

output AZURE_STORAGE_ACCOUNT_NAME string = storage.outputs.storageAccountName

output SQL_MI_NAME string = managedInstance.outputs.managedInstanceName

output SQL_MI_FQDN string = managedInstance.outputs.fullyQualifiedDomainName

output LEGACY_SQL_VM_NAME string = legacySqlVm.outputs.vmName

output BASTION_NAME string = bastion.outputs.bastionName
