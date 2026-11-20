@description('Radius-provided recipe context.')
param context object

@description('Namespace name supplied by the environment so workload identities target the same broker.')
param namespaceName string = 'egns-${uniqueString(resourceGroup().id, context.resource.id)}'

module eventGrid '../platform/event-grid-mqtt-azure.bicep' = {
  name: namespaceName
  params: {
    name: namespaceName
    topicSpaceName: 'orders'
    topicTemplates: [
      'orders/#'
    ]
    topicName: 'orders'
    eventSubscriptionName: 'orders-queue'
  }
}

output result {
  resources: string[]
  values: object
} = {
  resources: eventGrid.outputs.resourceIds
  values: {
    host: eventGrid.outputs.host
    port: 8883
    protocol: 'mqtts'
    wsPort: 443
    wsProtocol: 'wss'
    authMethod: 'OAUTH2-JWT'
    tokenAudience: 'https://eventgrid.azure.net/'
    resourceId: eventGrid.outputs.resourceId
  }
}
