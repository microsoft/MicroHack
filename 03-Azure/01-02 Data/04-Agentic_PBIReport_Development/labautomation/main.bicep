param location string
param suffix string
param tags object
param adminUsername string
@secure()
param adminPassword string
param vmSize string
@description('Explicit approved Windows publisher/offer/sku/version; no default or latest.')
param image object
@allowed(['None', 'Windows_Client', 'Windows_Server'])
param licenseType string
@minValue(128)
param osDiskSizeGB int
@allowed(['RestrictedPublicRdp', 'PrivateRdp'])
param accessMode string
param sourceAddressPrefix string
param bootstrapUri string
param bootstrapSha256 string
@description('Rerun the same idempotent bootstrap on an explicit hook retry, including after extension failure.')
param bootstrapRunId string
@secure()
param bootstrapConfigurationBase64 string

resource nsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: 'nsg-${suffix}'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'ApprovedRdpSource'
        properties: {
          priority: 100
          access: 'Allow'
          direction: 'Inbound'
          protocol: 'Tcp'
          sourceAddressPrefix: sourceAddressPrefix
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '3389'
        }
      }
      {
        name: 'DenyOtherInbound'
        properties: {
          priority: 110
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
  name: 'vnet-${suffix}'
  location: location
  tags: tags
  properties: {
    addressSpace: { addressPrefixes: ['10.90.0.0/24'] }
    subnets: [
      {
        name: 'desktop'
        properties: {
          addressPrefix: '10.90.0.0/26'
          networkSecurityGroup: { id: nsg.id }
          defaultOutboundAccess: false
          natGateway: { id: nat.id }
        }
      }
    ]
  }
}

// Explicit outbound access is needed on private subnets; never rely on default outbound.
resource outboundIp 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: 'egress-${suffix}'
  location: location
  tags: tags
  sku: { name: 'Standard' }
  properties: { publicIPAllocationMethod: 'Static' }
}
resource nat 'Microsoft.Network/natGateways@2024-05-01' = {
  name: 'nat-${suffix}'
  location: location
  tags: tags
  sku: { name: 'Standard' }
  properties: {
    publicIpAddresses: [{ id: outboundIp.id }]
    idleTimeoutInMinutes: 4
  }
}
resource publicIp 'Microsoft.Network/publicIPAddresses@2024-05-01' = if (accessMode == 'RestrictedPublicRdp') {
  name: 'rdp-${suffix}'
  location: location
  tags: tags
  sku: { name: 'Standard' }
  properties: { publicIPAllocationMethod: 'Static' }
}
resource nic 'Microsoft.Network/networkInterfaces@2024-05-01' = {
  name: 'nic-${suffix}'
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'primary'
        properties: union({
          privateIPAllocationMethod: 'Dynamic'
          subnet: { id: '${vnet.id}/subnets/desktop' }
        }, accessMode == 'RestrictedPublicRdp' ? { publicIPAddress: { id: publicIp!.id } } : {})
      }
    ]
  }
}
resource vm 'Microsoft.Compute/virtualMachines@2024-07-01' = {
  name: 'vm-${suffix}'
  location: location
  tags: tags
  properties: union({
    hardwareProfile: { vmSize: vmSize }
    storageProfile: {
      imageReference: image
      osDisk: {
        createOption: 'FromImage'
        diskSizeGB: osDiskSizeGB
        managedDisk: { storageAccountType: 'StandardSSD_LRS' }
        deleteOption: 'Delete'
      }
    }
    osProfile: {
      computerName: 'lab${suffix}'
      adminUsername: adminUsername
      adminPassword: adminPassword
      windowsConfiguration: {
        provisionVMAgent: true
        enableAutomaticUpdates: true
      }
    }
    networkProfile: { networkInterfaces: [{ id: nic.id, properties: { deleteOption: 'Delete' } }] }
    diagnosticsProfile: { bootDiagnostics: { enabled: true } }
  }, licenseType == 'None' ? {} : { licenseType: licenseType })
}
resource bootstrap 'Microsoft.Compute/virtualMachines/extensions@2024-07-01' = {
  parent: vm
  name: 'bootstrap'
  location: location
  tags: tags
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: false
    forceUpdateTag: bootstrapRunId
    protectedSettings: {
      fileUris: [bootstrapUri]
      commandToExecute: 'powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "$ErrorActionPreference = \'Stop\'; if ((Get-FileHash -LiteralPath \'.\\bootstrap.ps1\' -Algorithm SHA256).Hash -ne \'${bootstrapSha256}\') { throw \'Bootstrap checksum mismatch\' }; & \'.\\bootstrap.ps1\' -ConfigurationBase64 \'${bootstrapConfigurationBase64}\'"'
    }
  }
}

output vmName string = vm.name
