targetScope = 'subscription'

@description('Your Microsoft Entra tenant Id')
param tenantId string = tenant().tenantId

@description('Username for Windows account')
param windowsAdminUsername string = 'HVAdmin'

@description('Password for Windows account. Password must have 3 of the following: 1 lower case character, 1 upper case character, 1 number, and 1 special character. The value must be between 12 and 123 characters long')
@minLength(12)
@maxLength(123)
@secure()
param windowsAdminPassword string  = newGuid()

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
param sqlServerEdition string = 'Developer'

@description('Target GitHub account')
param githubAccount string = 'microsoft'

@description('Target GitHub branch')
param githubBranch string = 'main'

@description('Choice to deploy Bastion to connect to the client VM')
param deployBastion bool = true

@description('Bastion host Sku name. The Developer SKU is currently supported in a limited number of regions: https://learn.microsoft.com/azure/bastion/quickstart-developer-sku')
@allowed([
  'Basic'
  'Standard'
  'Developer'
])
param bastionSku string = 'Developer'

@description('User github account where they have forked https://github.com/Azure/jumpstart-apps')
param githubUser string = 'Azure'

@description('Azure location to deploy all resources')
param location string = deployment().location

@description('Use this parameter to enable or disable debug mode for the automation scripts on the client VM, effectively configuring PowerShell ErrorActionPreference to Break. Intended for use when troubleshooting automation scripts. Default is false.')
param debugEnabled bool = false


@maxLength(7)
@description('The naming prefix for the nested virtual machines and all Azure resources deployed. The maximum length for the naming prefix is 7 characters,example: `ArcBox-Win2k19`')
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

var templateBaseUrl = 'https://raw.githubusercontent.com/${githubAccount}/microhack/${githubBranch}/03-Azure/01-03-Infrastructure/06_Migration_Secure_AI_Ready/resources/'

var userName = contains(deployer().userPrincipalName, '@') ? substring(deployer().userPrincipalName, 0, indexOf(deployer().userPrincipalName, '@')) : deployer().userPrincipalName

var namingPrefix = '${Prefix}-${userName}'

@description('Tags to assign for all MH resources')
var resourceTags object = {
  Microhack: '06_Migration_Secure_AI_Ready'
  User: userName
}

@description('Source Resouce Group')
resource sourceRg 'Microsoft.Resources/resourceGroups@2021-01-01'={
  name: '${namingPrefix}-source-rg'
  location: location
  tags: resourceTags
}

@description('Destination Resouce Group')
resource destinationRg 'Microsoft.Resources/resourceGroups@2021-01-01'={
  name: '${namingPrefix}-destination-rg'
  location: location
  tags: resourceTags
}

module clientVmDeployment 'clientVm/clientVm.bicep' = {
  name: '${namingPrefix}-clientVmDeployment'
  scope: sourceRg
  params: {
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
  scope: sourceRg
  params: {
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
  scope: destinationRg
  params: {
    flavor: flavor
    deployBastion: deployBastion
    bastionSku: bastionSku
    location: location
  }
}


output clientVmLogonUserName string = windowsAdminUsername
