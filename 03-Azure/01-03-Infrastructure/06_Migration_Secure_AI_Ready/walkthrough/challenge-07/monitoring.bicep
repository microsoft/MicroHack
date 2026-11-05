targetScope = 'resourceGroup'

@description('Use the region of the migrated VMs, not the resource group metadata location.')
param location string

@description('Existing migrated Windows web VM in this resource group.')
@minLength(1)
param windowsVmName string

@description('An email inbox the learner can actually read.')
@minLength(3)
param notificationEmail string

var labTags = {
  microhackChallenge: '07'
}
var monitoringReaderRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '43d0d8ad-25c7-4714-9337-8ba259a9fe05')

resource metricsWorkspace 'Microsoft.Monitor/accounts@2025-10-03' = {
  name: 'amw-mh-${uniqueString(resourceGroup().id)}'
  location: location
  tags: labTags
  properties: {
    metrics: {
      enableAccessUsingResourcePermissions: true
    }
  }
}

resource logsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: 'law-mh-monitoring'
  location: location
  tags: labTags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

resource alertIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'id-mh-monitor-alerts'
  location: location
  tags: labTags
}

resource alertReader 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, alertIdentity.id, monitoringReaderRoleId)
  properties: {
    principalId: alertIdentity.properties.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: monitoringReaderRoleId
  }
}

resource operators 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: 'ag-mh-operators'
  location: 'global'
  tags: labTags
  properties: {
    groupShortName: 'MHOperators'
    enabled: true
    emailReceivers: [
      {
        name: 'LabOperator'
        emailAddress: notificationEmail
        useCommonAlertSchema: true
      }
    ]
  }
}

resource serviceEvents 'Microsoft.Insights/dataCollectionRules@2023-03-11' = {
  name: 'dcr-iis-service-events'
  location: location
  kind: 'Windows'
  tags: labTags
  properties: {
    dataSources: {
      windowsEventLogs: [
        {
          name: 'serviceStateChanges'
          streams: [
            'Microsoft-Event'
          ]
          xPathQueries: [
            'System!*[System[(EventID=7036)]]'
          ]
        }
      ]
    }
    destinations: {
      logAnalytics: [
        {
          name: 'labLogs'
          workspaceResourceId: logsWorkspace.id
        }
      ]
    }
    dataFlows: [
      {
        streams: [
          'Microsoft-Event'
        ]
        destinations: [
          'labLogs'
        ]
      }
    ]
  }
}

resource windowsVm 'Microsoft.Compute/virtualMachines@2024-11-01' existing = {
  name: windowsVmName
}

resource serviceEventsAssociation 'Microsoft.Insights/dataCollectionRuleAssociations@2023-03-11' = {
  name: 'mh-iis-service-events'
  scope: windowsVm
  properties: {
    dataCollectionRuleId: serviceEvents.id
  }
}

output azureMonitorWorkspaceId string = metricsWorkspace.id
output logAnalyticsWorkspaceId string = logsWorkspace.id
output alertIdentityId string = alertIdentity.id
output actionGroupId string = operators.id
output windowsEventDcrId string = serviceEvents.id
output windowsEventAssociationId string = serviceEventsAssociation.id
output monitoringReaderAssignmentId string = alertReader.id
