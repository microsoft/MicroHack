param name string
param topicSpaceName string
param topicTemplates string[]

@description('Name of the Event Grid namespace topic for pull delivery.')
param topicName string

@description('Name of the queue subscription on the namespace topic.')
param eventSubscriptionName string

resource eventGridNamespace 'Microsoft.EventGrid/namespaces@2023-12-15-preview' = {
  name: name
  location: resourceGroup().location
  sku: {
    name: 'Standard'
    capacity: 1
  }
  properties: {
    publicNetworkAccess: 'Enabled'
    topicSpacesConfiguration: {
      state: 'Enabled'
    }
  }
}

resource topicSpace 'Microsoft.EventGrid/namespaces/topicSpaces@2023-12-15-preview' = {
  parent: eventGridNamespace
  name: topicSpaceName
  properties: {
    topicTemplates: topicTemplates
  }
}

// Native pull delivery is separate from the application's MQTT topic space.
resource topic 'Microsoft.EventGrid/namespaces/topics@2023-12-15-preview' = {
  parent: eventGridNamespace
  name: topicName
  properties: {
    inputSchema: 'CloudEventSchemaV1_0'
    publisherType: 'Custom'
  }
}

resource queue 'Microsoft.EventGrid/namespaces/topics/eventSubscriptions@2023-12-15-preview' = {
  parent: topic
  name: eventSubscriptionName
  properties: {
    eventDeliverySchema: 'CloudEventSchemaV1_0'
    deliveryConfiguration: {
      deliveryMode: 'Queue'
      queue: {}
    }
  }
}

output host string = eventGridNamespace.properties.topicSpacesConfiguration.hostname
output resourceId string = eventGridNamespace.id
output resourceIds string[] = [
  eventGridNamespace.id
  topicSpace.id
  topic.id
  queue.id
]
