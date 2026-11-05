targetScope = 'resourceGroup'

@minLength(8)
@maxLength(8)
@description('Stable, lowercase hexadecimal lab identity derived from the subscription and lab resource group.')
param labSuffix string

@minLength(1)
@maxLength(9)
@description('Resource-name suffix: the learner number for new hosted labs, or the stable lab identity for legacy labs.')
param resourceNameSuffix string = labSuffix

@minLength(1)
@description('Entra user object IDs that need to read the host login secrets.')
param participantObjectIds array

@description('Your Microsoft Entra tenant Id')
param tenantId string = tenant().tenantId

@description('Username for Windows account')
param windowsAdminUsername string = 'HVAdmin'

@description('Password for Windows account. Password must have 3 of the following: 1 lower case character, 1 upper case character, 1 number, and 1 special character. The value must be between 12 and 123 characters long')
@minLength(12)
@maxLength(123)
@secure()
param windowsAdminPassword string

@description('Enable automatic logon into ArcBox Virtual Machine')
param vmAutologon bool = true

@description('Override default RDP port using this parameter. Default is 3389. No changes will be made to the client VM.')
param rdpPort string = '3389'

@description('The flavor of ArcBox you want to deploy. Valid values are: \'Full\', \'ITPro\', \'DevOps\', \'DataOps\'')
@allowed([
  'ITPro'
])
param flavor string = 'ITPro'

@description('SQL Server edition to deploy. Valid values are: \'Developer\', \'Standard\', \'Enterprise\'')
@allowed([
  'Developer'
  'Standard'
  'Enterprise'
])
param sqlServerEdition string = 'Standard'

@description('Target GitHub account')
param githubAccount string = 'microsoft'

@description('Target GitHub branch')
param githubBranch string = 'main'

@description('Choice to deploy Bastion to connect to the client VM')
param deployBastion bool = true

@description('Bastion host SKU. Basic provides dedicated portal-based RDP and SSH access by default.')
@allowed([
  'Basic'
  'Standard'
  'Developer'
])
param bastionSku string = 'Basic'

@description('User github account where they have forked https://github.com/Azure/jumpstart-apps')
param githubUser string = 'Azure'

@description('Azure location to deploy all resources')
param location string = resourceGroup().location

@description('Use this parameter to enable or disable debug mode for the automation scripts on the client VM, effectively configuring PowerShell ErrorActionPreference to Break. Intended for use when troubleshooting automation scripts. Default is false.')
param debugEnabled bool = false


@maxLength(7)
@description('The naming prefix for the nested virtual machines. The maximum length is 7 characters, example: `MHBox-Win2K22`.')
param Prefix string = 'MHBox'


param autoShutdownEnabled bool = true
param autoShutdownTime string = '2000' // The time for auto-shutdown in HHmm format (24-hour clock)
param autoShutdownTimezone string = 'Central Europe Standard Time' // Timezone for the auto-shutdown
param autoShutdownEmailRecipient string = ''

@description('Option to enable spot pricing for the ArcBox Client VM')
param enableAzureSpotPricing bool = false

@description('The availability zone for the Virtual Machine, public IP, and data disk for the ArcBox client VM')
@allowed([
  '1'
  '2'
  '3'
])
param zones string = '1'

var templateBaseUrl = 'https://raw.githubusercontent.com/${githubAccount}/MicroHack/${githubBranch}/03-Azure/01-03-Infrastructure/06_Migration_Secure_AI_Ready/resources/'

var namingPrefix = 'mh-${resourceNameSuffix}'

@description('Tags to assign for all MH resources')
var resourceTags object = {
  Microhack: '06_Migration_Secure_AI_Ready'
  LabId: labSuffix
}

module clientVmDeployment 'clientVm/clientVm.bicep' = {
  name: '${namingPrefix}-clientVmDeployment'
  params: {
    resourceNameSuffix: resourceNameSuffix
    participantObjectIds: participantObjectIds
    keyVaultName: mgmtArtifactsSourceDeployment.outputs.vaultName
    tags: resourceTags
    Prefix: Prefix
    windowsAdminUsername: windowsAdminUsername
    windowsAdminPassword: windowsAdminPassword
    tenantId: tenantId
    templateBaseUrl: templateBaseUrl
    flavor: flavor
    subnetId: mgmtArtifactsSourceDeployment.outputs.subnetId
    deployBastion: deployBastion
    githubBranch: githubBranch
    githubUser: githubUser
    location: location
    vmAutologon: vmAutologon
    rdpPort: rdpPort
    debugEnabled: debugEnabled
    autoShutdownEnabled: autoShutdownEnabled
    autoShutdownTime: autoShutdownTime
    autoShutdownTimezone: autoShutdownTimezone
    autoShutdownEmailRecipient: empty(autoShutdownEmailRecipient) ? null : autoShutdownEmailRecipient
    sqlServerEdition: sqlServerEdition
    zones: zones
    enableAzureSpotPricing: enableAzureSpotPricing
  }
  dependsOn: [
  ]
}

module mgmtArtifactsSourceDeployment 'mgmt/mgmtArtifactsSource.bicep' = {
  name: '${namingPrefix}-mgmtArtifactsSourceDeployment'
  params: {
    resourceNameSuffix: resourceNameSuffix
    tags: resourceTags
    flavor: flavor
    deployBastion: deployBastion
    bastionSku: bastionSku
    location: location
    windowsAdminPassword: windowsAdminPassword
    windowsAdminUserName: windowsAdminUsername
  }
}

module mgmtArtifactsDestinationDeployment 'mgmt/mgmtArtifactsDestination.bicep' = {
  name: '${namingPrefix}-mgmtArtifactsDestinationDeployment'
  params: {
    resourceNameSuffix: resourceNameSuffix
    tags: resourceTags
    flavor: flavor
    deployBastion: deployBastion
    bastionSku: bastionSku
    location: location
  }
}


// Bastion depends on networking, but must not delay host VM startup.
module sourceBastionDeployment 'mgmt/bastion.bicep' = if (deployBastion) {
  name: '${namingPrefix}-sourceBastionDeployment'
  params: {
    bastionName: mgmtArtifactsSourceDeployment.outputs.bastionName
    bastionSku: bastionSku
    location: location
    tags: resourceTags
    virtualNetworkId: mgmtArtifactsSourceDeployment.outputs.vnetId
    bastionSubnetId: mgmtArtifactsSourceDeployment.outputs.bastionSubnetId
    publicIpAddressId: mgmtArtifactsSourceDeployment.outputs.bastionPublicIpId
  }
}

module destinationBastionDeployment 'mgmt/bastion.bicep' = if (deployBastion) {
  name: '${namingPrefix}-destinationBastionDeployment'
  params: {
    bastionName: mgmtArtifactsDestinationDeployment.outputs.bastionName
    bastionSku: bastionSku
    location: location
    tags: resourceTags
    virtualNetworkId: mgmtArtifactsDestinationDeployment.outputs.vnetId
    bastionSubnetId: mgmtArtifactsDestinationDeployment.outputs.bastionSubnetId
    publicIpAddressId: mgmtArtifactsDestinationDeployment.outputs.bastionPublicIpId
  }
}

output clientVmLogonUserName string = windowsAdminUsername
output hostVmName string = clientVmDeployment.outputs.vmName
output keyVaultName string = mgmtArtifactsSourceDeployment.outputs.vaultName
output sourceVnetName string = mgmtArtifactsSourceDeployment.outputs.vnetName
output sourceSubnetId string = mgmtArtifactsSourceDeployment.outputs.subnetId
output destinationVnetName string = mgmtArtifactsDestinationDeployment.outputs.vnetName
output destinationSubnetId string = mgmtArtifactsDestinationDeployment.outputs.subnetId
