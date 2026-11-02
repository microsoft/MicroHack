@description('Username for the Virtual Machine')
param windowsAdminUsername string = 'HVAdmin'

@description('Enable automatic logon into ArcBox Virtual Machine')
param vmAutologon bool = true

@description('Override default RDP port using this parameter. Default is 3389. No changes will be made to the client VM.')
param rdpPort string = '3389'

@description('Password for Windows account. Password must have 3 of the following: 1 lower case character, 1 upper case character, 1 number, and 1 special character. The value must be between 12 and 123 characters long')
@minLength(12)
@maxLength(123)
@secure()
param windowsAdminPassword string

@description('The Windows version for the VM. This will pick a fully patched image of this given Windows version')
param windowsOSVersion string = '2022-datacenter-g2'

@description('Location for all resources')
param location string = resourceGroup().location

@description('Resource Id of the subnet in the virtual network')
param subnetId string

param labSuffix string
param keyVaultName string
param participantObjectIds array
param tags object = {}

param spnAuthority string = environment().authentication.loginEndpoint

@description('Your Microsoft Entra tenant Id')
param tenantId string

param acceptEula string = 'yes'
param registryUsername string = 'registryUser'

@description('The base URL used for accessing artifacts and automation artifacts.')
param templateBaseUrl string

@maxLength(7)
@description('The naming prefix for the nested virtual machines. Example: ArcBox-Win2k19')
param Prefix string = 'MHBox'

@description('The flavor of ArcBox you want to deploy. Valid values are: \'ITPro\', \'DevOps\', \'DataOps\'')
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

@description('Choice to deploy Bastion to connect to the client VM')
param deployBastion bool = false

@description('User github account where they have forked https://github.com/Azure/jumpstart-apps')
param githubUser string

@description('Git branch to use from the forked repo https://github.com/Azure/jumpstart-apps')
param githubBranch string

@description('The SKU of the VMs disk')
param vmsDiskSku string = 'PremiumV2_LRS'

@description('Use this parameter to enable or disable debug mode for the automation scripts on the client VM, effectively configuring PowerShell ErrorActionPreference to Break. Default is false.')
param debugEnabled bool = false

param autoShutdownEnabled bool = true
param autoShutdownTime string = '2000' // The time for auto-shutdown in HHmm format (24-hour clock)
param autoShutdownTimezone string = 'Central Europe Standard Time' // Timezone for the auto-shutdown
param autoShutdownEmailRecipient string = ''

@description('The availability zone for the Virtual Machine, public IP, and data disk for the ArcBox client VM')
@allowed([
  '1'
  '2'
  '3'
])
param zones string = '1'

@description('Option to enable spot pricing for the ArcBox Client VM')
param enableAzureSpotPricing bool = false

var namingPrefix = 'mh-${labSuffix}'

@description('The name of your Virtual Machine')
var hostName string = '${namingPrefix}-hv'

var bastionName = '${namingPrefix}-Bastion'
var publicIpAddressName = deployBastion == false ? '${hostName}-PIP' : '${bastionName}-PIP'
var networkInterfaceName = '${hostName}-NIC'
var osDiskType = 'Premium_LRS'
var PublicIPNoBastion = {
  id: publicIpAddress.id
}
resource networkInterface 'Microsoft.Network/networkInterfaces@2024-05-01' = {
  name: networkInterfaceName
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: subnetId
          }
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: deployBastion == false ? PublicIPNoBastion : null
        }
      }
    ]
  }
}

resource publicIpAddress 'Microsoft.Network/publicIPAddresses@2024-05-01' = if (deployBastion == false) {
  name: publicIpAddressName
  location: location
  tags: tags
  zones: [zones]
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
    idleTimeoutInMinutes: 4
  }
  sku: {
    name: 'Standard'
  }
}

resource vmDisk 'Microsoft.Compute/disks@2024-03-02' = {
  location: location
  tags: tags
  name: '${hostName}-VMsDisk'
  zones: [zones]
  sku: {
    name: vmsDiskSku
  }
  properties: {
    creationData: {
      createOption: 'Empty'
    }
    diskSizeGB: 256
    burstingEnabled: false
    diskMBpsReadWrite: 200
    diskIOPSReadWrite: 5000
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2024-07-01' = {
  name: hostName
  location: location
  tags: tags
  zones: [zones]
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    hardwareProfile: {
      vmSize: flavor == 'DevOps' ? 'Standard_B4ms' : flavor == 'DataOps' ? 'Standard_D16s_v5' : 'Standard_D16s_v5'
    }
    storageProfile: {
      osDisk: {
        name: '${hostName}-OSDisk'
        caching: 'ReadWrite'
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: osDiskType
        }
        diskSizeGB: 127
      }
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: windowsOSVersion
        version: 'latest'
      }
      dataDisks: [
        {
          createOption: 'Attach'
          lun: 0
          managedDisk: {
            id: vmDisk.id
          }
        }
      ]
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: networkInterface.id
        }
      ]
    }
    osProfile: {
      computerName: hostName
      adminUsername: windowsAdminUsername
      adminPassword: windowsAdminPassword
      windowsConfiguration: {
        provisionVMAgent: true
        enableAutomaticUpdates: true
      }
    }
    priority: enableAzureSpotPricing ? 'Spot' : 'Regular'
    evictionPolicy: enableAzureSpotPricing ? 'Deallocate' : null
    billingProfile: enableAzureSpotPricing ? {
      maxPrice: -1
    } : null
  }
}


 resource vmBootstrap 'Microsoft.Compute/virtualMachines/extensions@2024-07-01' = {
  parent: vm
  name: 'Bootstrap'
  location: location
  tags: {
    displayName: 'config-bootstrap'
  }
  dependsOn: [
    vmVaultReader
    vmResourceReader
    vmTagContributor
    vmDiskContributor
    vmScheduleContributor
  ]
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    protectedSettings: {
      fileUris: [
        uri(templateBaseUrl, 'artifacts/Bootstrap.ps1')
      ]
      commandToExecute: 'powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File Bootstrap.ps1 -adminUsername ${windowsAdminUsername} -tenantId ${tenantId} -spnAuthority ${spnAuthority} -subscriptionId ${subscription().subscriptionId} -resourceGroup "${resourceGroup().name}" -hostVmName "${hostName}" -keyVaultName "${keyVaultName}" -acceptEula ${acceptEula} -registryUsername ${registryUsername} -azureLocation ${location} -templateBaseUrl "${templateBaseUrl}" -flavor ${flavor} -githubUser ${githubUser} -githubBranch "${githubBranch}" -vmAutologon ${vmAutologon} -rdpPort ${rdpPort} -namingPrefix "${Prefix}" -debugEnabled ${debugEnabled} -sqlServerEdition ${sqlServerEdition} -autoShutdownEnabled ${autoShutdownEnabled}'
    }
  }
} 


resource vault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: keyVaultName
}

resource vmVaultReader 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(vault.id, vm.id, 'secrets-reader')
  scope: vault
  properties: {
    principalId: vm.identity.principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6')
    principalType: 'ServicePrincipal'
  }
}

resource participantVaultReaders 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for participantId in participantObjectIds: {
  name: guid(vault.id, participantId, 'secrets-reader')
  scope: vault
  properties: {
    principalId: participantId
    principalType: 'User'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6')
  }
}]

resource vmResourceReader 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, vm.id, 'reader')
  properties: {
    principalId: vm.identity.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'acdd72a7-3385-48ef-bd42-f606fba81ae7')
  }
}

resource vmTagContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, vm.id, 'tag-contributor')
  properties: {
    principalId: vm.identity.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4a9ae827-6dc8-4573-8ac7-8239d42aa03f')
  }
}

resource vmDiskContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(vmDisk.id, vm.id, 'contributor')
  scope: vmDisk
  properties: {
    principalId: vm.identity.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b24988ac-6180-42a0-ab88-20f7382dd24c')
  }
}

resource vmScheduleContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (autoShutdownEnabled) {
  name: guid(autoShutdown.id, vm.id, 'contributor')
  scope: autoShutdown
  properties: {
    principalId: vm.identity.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b24988ac-6180-42a0-ab88-20f7382dd24c')
  }
}

resource autoShutdown 'Microsoft.DevTestLab/schedules@2018-09-15' = if (autoShutdownEnabled) {
  name: 'shutdown-computevm-${vm.name}'
  location: location
  tags: tags
  properties: {
    status: 'Enabled'
    taskType: 'ComputeVmShutdownTask'
    dailyRecurrence: {
      time: autoShutdownTime
    }
    timeZoneId: autoShutdownTimezone
    notificationSettings: {
      status: empty(autoShutdownEmailRecipient) ? 'Disabled' : 'Enabled' // Set status based on whether an email is provided
      timeInMinutes: 30
      webhookUrl: ''
      emailRecipient: autoShutdownEmailRecipient
      notificationLocale: 'en'
    }
    targetResourceId: vm.id
  }
}

output adminUsername string = windowsAdminUsername
output publicIP string = deployBastion == false ? publicIpAddress!.properties.ipAddress : ''
output vmName string = vm.name
