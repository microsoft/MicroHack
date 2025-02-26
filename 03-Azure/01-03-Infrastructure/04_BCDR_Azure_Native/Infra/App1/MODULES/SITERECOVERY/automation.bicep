// Parameters & variables
@description('Automation Account Name & Location')
param namePrefix string
var nameSuffix = 'automation'
var location = resourceGroup().location
var Name = '${namePrefix}-${location}-${nameSuffix}'

// Resources
@description('Automation Account')
resource automationAccount 'Microsoft.Automation/automationAccounts@2023-11-01' = {
  name: Name
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    sku: {
      name: 'Basic'
    }
  }
}

// Output
@description('Output the automation account ID')
output automationAccountId string = automationAccount.id
