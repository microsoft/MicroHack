param namePrefix string
var nameSuffix = 'bastion'
var location = resourceGroup().location
var Name = '${namePrefix}-${location}-${nameSuffix}'
param bastionSubnetId string
//param logAnalyticsWorkspaceId string

module bastionpublicIp '../NETWORK/pip.bicep' = {
  name: '${Name}-pip'
  scope: resourceGroup()
  params: {
    Name: Name
    //logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    skuName: 'Standard'
  }
}



resource bastion 'Microsoft.Network/bastionHosts@2024-05-01' = {
  name: Name
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'bastionIpConfig'
        properties: {
          subnet: {
            id: bastionSubnetId
          }
          publicIPAddress: {
            id: bastionpublicIp.outputs.pipId
          }
        }
      }
    ]
  }
  dependsOn: [
    bastionpublicIp
  ]
}
