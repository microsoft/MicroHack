// Azure Copilot Workshop — Main deployment orchestration
// Subscription-level deployment: creates resource groups and deploys challenge modules
targetScope = 'subscription'

@description('Azure region for all resources')
param location string = 'francecentral'

@description('Random suffix for globally unique resource names')
param suffix string

@description('SSH public key for VM authentication')
param sshPublicKey string

// ── Resource Groups ──

resource rgCh00 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: 'rg-copilot-${suffix}-ch00'
  location: location
}

resource rgCh02 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: 'rg-copilot-${suffix}-ch02'
  location: location
}

resource rgCh03 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: 'rg-copilot-${suffix}-ch03'
  location: location
}

resource rgCh04 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: 'rg-copilot-${suffix}-ch04'
  location: location
}

resource rgCh05 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: 'rg-copilot-${suffix}-ch05'
  location: location
}

// ── Challenge Deployments ──

module ch00 'modules/ch00-basics.bicep' = {
  scope: rgCh00
  name: 'ch00-basics'
  params: {
    location: location
    suffix: suffix
  }
}

module ch02 'modules/ch02-observability.bicep' = {
  scope: rgCh02
  name: 'ch02-observability'
  params: {
    location: location
    suffix: suffix
  }
}

module ch03 'modules/ch03-optimization.bicep' = {
  scope: rgCh03
  name: 'ch03-optimization'
  params: {
    location: location
    sshPublicKey: sshPublicKey
  }
}

module ch04 'modules/ch04-resiliency.bicep' = {
  scope: rgCh04
  name: 'ch04-resiliency'
  params: {
    location: location
    sshPublicKey: sshPublicKey
  }
}

module ch05 'modules/ch05-troubleshooting.bicep' = {
  scope: rgCh05
  name: 'ch05-troubleshooting'
  params: {
    location: location
    suffix: suffix
    sshPublicKey: sshPublicKey
  }
}

// ── Outputs ──

output rgCh00Name string = rgCh00.name
output rgCh02Name string = rgCh02.name
output rgCh03Name string = rgCh03.name
output rgCh04Name string = rgCh04.name
output rgCh05Name string = rgCh05.name
output webAppName string = ch02.outputs.webAppName
output webAppDefaultHostName string = ch02.outputs.webAppDefaultHostName
