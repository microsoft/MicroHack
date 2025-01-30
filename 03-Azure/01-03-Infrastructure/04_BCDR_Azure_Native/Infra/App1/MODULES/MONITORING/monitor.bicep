// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.
/*
SUMMARY: Module to create a Log Analytics Workspace
DESCRIPTION: This module will create a deployment which will create the Log Analytics Workspace
AUTHOR/S: David Smith (CSA FSI)
*/

param namePrefix string
// param emailAddress string
var nameSuffix = 'logs'
var location = resourceGroup().location
// var unique = substring(uniqueString(resourceGroup().id), 0, 8)
var Name = '${namePrefix}-${location}-${nameSuffix}'
// param queries array
// param alerts array

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: Name
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

// resource emailActionGroup 'Microsoft.Insights/actionGroups@2023-09-01-preview' = {
//   name: '${namePrefix} EmailActionGroup'
//   location: 'global'
//   properties: {
//     groupShortName: 'emailAG'
//     enabled: true
//     emailReceivers: [
//       {
//         name: 'PrimaryEmail'
//         emailAddress: emailAddress
//       }
//     ]
//   }
// }

// resource asrSavedQueries 'Microsoft.OperationalInsights/workspaces/savedSearches@2020-08-01' = [ for query in queries: {
//     name: '${namePrefix}-${query.queryname}'
//     parent: logAnalyticsWorkspace
//     properties: {
//       category: 'ASR'
//       displayName: '${namePrefix}-${query.displayName}'
//       version: 1
//       query: query.query
//     }
//   }]

// resource asralertRules 'Microsoft.Insights/scheduledQueryRules@2023-03-15-preview' = [for alert in alerts: {
//     name: '${namePrefix}-${alert.alertName}'
//     location: location
//     properties: {
//       skipQueryValidation: true
//       description: 'Alert for Critical Replication Health'
//       severity: 3
//       enabled: true
//       scopes: [
//         logAnalyticsWorkspace.id
//       ]
//       evaluationFrequency: 'PT5M'
//       windowSize: 'PT15M'
//       criteria: {
//         allOf: [
//           {
//             query: alert.query
//             timeAggregation: 'Count'
//             operator: 'GreaterThan'
//             threshold: alert.threshold
//           }
//         ]
//       }
//       actions: {
//         actionGroups: [
//           emailActionGroup.id
//         ]
//       }
//     }
//   }]

output logAnalyticsWorkspaceId string = logAnalyticsWorkspace.id
