// Microsoft Fabric capacity. Faithful Bicep port of the ARM-deployable part of
// infra/modules/fabric_platform. NOTE: the Fabric VNet gateway, per-user
// workspaces and workspace/gateway role assignments are Fabric control-plane
// objects (not ARM) and are handled by orchestration (Phase 2).

@description('Azure region.')
param location string

@description('Lab/environment name (used for the generated capacity name).')
param envName string

@description('Fabric capacity SKU name (e.g. F2, F32).')
param skuName string = 'F2'

@description('Fabric capacity administrator identities (UPNs or object IDs).')
param administrationMembers array

@description('Tags to apply to all resources.')
param tags object = {}

var normalizedEnv = toLower(replace(envName, '-', ''))
var capacityName = substring('fab${normalizedEnv}', 0, min(length('fab${normalizedEnv}'), 63))

resource capacity 'Microsoft.Fabric/capacities@2023-11-01' = {
  name: capacityName
  location: location
  tags: tags
  sku: {
    name: skuName
    tier: 'Fabric'
  }
  properties: {
    administration: {
      members: administrationMembers
    }
  }
}

output capacityId string = capacity.id
output capacityName string = capacity.name
