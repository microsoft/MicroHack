targetScope='resourceGroup'

param name string
param sourceLBPublicIP string
param destinationLBPublicIP string

resource trafficManagerProfiles_migtm_name_resource 'Microsoft.Network/trafficManagerProfiles@2022-04-01' = {
  name: name
  location: 'global'
  properties: {
    profileStatus: 'Enabled'
    trafficRoutingMethod: 'Priority'
    dnsConfig: {
      relativeName: name
      ttl: 10
    }
    monitorConfig: {
      profileMonitorStatus: 'Degraded'
      protocol: 'HTTP'
      port: 80
      path: '/'
      intervalInSeconds: 10
      toleratedNumberOfFailures: 3
      timeoutInSeconds: 10
    }
    endpoints: [
      {
        name: 'migsource'
        type: 'Microsoft.Network/trafficManagerProfiles/externalEndpoints'
        properties: {
          endpointStatus: 'Enabled'
          endpointMonitorStatus: 'Degraded'
          target: sourceLBPublicIP
          weight: 1
          priority: 1
          endpointLocation: 'West Europe'
          alwaysServe: 'Disabled'
        }
      }
      {
        name: 'migdest'
        type: 'Microsoft.Network/trafficManagerProfiles/externalEndpoints'
        properties: {
          endpointStatus: 'Enabled'
          endpointMonitorStatus: 'Online'
          target: destinationLBPublicIP
          weight: 1
          priority: 2
          endpointLocation: 'West Europe'
          alwaysServe: 'Disabled'
        }
      }
    ]
    trafficViewEnrollmentStatus: 'Disabled'
  }
}
