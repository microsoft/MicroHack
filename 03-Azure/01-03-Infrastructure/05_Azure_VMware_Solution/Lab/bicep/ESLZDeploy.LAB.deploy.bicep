targetScope = 'subscription'

@description('Number of AVS SDDCs')
param NumberOfAVSInstances int = 1

@description('Number Nested Labs inside of each AVS SDDC')
param NumberOfNestedLabsInAVS int = 6

@description('The prefix to use on resources inside this template')
@minLength(1)
@maxLength(20)
param Prefix string = 'AVS-Microhack'

@description('Optional: The location the private cloud should be deployed to, by default this will be the location of the deployment')
param Location string = deployment().location

@description('Email addresses to be added to the alerting action group. Use the format ["name1@domain.com","name2@domain.com"].')
param AlertEmails array = []

@description('The sku to use for the Jumpbox VM, must have quota for this within the target region')
@allowed([
  'Standard_D2ds_v5'
  'Standard_D2as_v4'
  'Standard_D2s_v3'
  'Standard_B2ms'
])
param JumpboxSku string = 'Standard_B2ms'

@description('AVS Jumpbox User account name')
param JumpboxUser string = 'avsjump'

@description('Password Prefix for the Jumpbox VM')
@secure()
param JumpboxPasswordPrefix string = 'AVS-Group'

@description('Decision to bootstrap the Jumpbox or not')
param Bootstrap bool = false

@description('Path for Jumpbox VM bootstrap script')
param BootstrapPath string = 'https://raw.githubusercontent.com/Azure/Enterprise-Scale-for-AVS/main/AVS-Landing-Zone/GreenField/Scripts/bootstrap.ps1'

@description('Path to AVS ESLZ Template')
param ESLZTemplate string = 'https://raw.githubusercontent.com/Azure/Enterprise-Scale-for-AVS/main/AVS-Landing-Zone/GreenField/ARM/ESLZDeploy.deploy.json'

@description('Decision to deploy HCX or not')
param DeployHCX bool = false

@description('Decision to deploy SRM or not')
param DeploySRM bool = false

@description('Nested Deployment')
resource MultipleSDDCDeployment 'Microsoft.Resources/deployments@2021-04-01' = [for i in range(1, NumberOfAVSInstances): {
  name: '${Prefix}-${i}-LAB-Deployment-${uniqueString(Prefix, BootstrapPath)}'
  location: Location
  properties: {
    mode: 'Incremental'
    expressionEvaluationOptions: {
      scope: 'Outer'
    }
    templateLink: {
      uri: ESLZTemplate
    }
    parameters: {
      Prefix: { value: '${Prefix}${i}' }
      PrivateCloudAddressSpace: { value: '10.1${padLeft(i, 2, '0')}.0.0/22' }
      VNetAddressSpace: { value: '10.2${padLeft(i, 2, '0')}.0.0/16' }
      VNetGatewaySubnet: { value: '10.2${padLeft(i, 2, '0')}.10.0/24' }
      AlertEmails: { value: AlertEmails }
      DeployJumpbox: { value: true }
      AssignJumpboxAsAVSContributor: { value: true }
      BootstrapJumpboxVM: { value: Bootstrap }
      BootstrapPath: { value: BootstrapPath }
      BootstrapCommand: { value: 'powershell.exe -ExecutionPolicy Unrestricted -File bootstrap.ps1 -GroupNumber ${i} -NumberOfNestedLabs ${NumberOfNestedLabsInAVS}' }
      JumpboxUsername: { value: JumpboxUser }
      JumpboxPassword: { value: '${JumpboxPasswordPrefix}${i}!' }
      JumpboxSku: { value: JumpboxSku }
      OSVersion: { value: '2022-datacenter-azure-edition'}
      JumpboxSubnet: { value: '10.2${padLeft(i, 2, '0')}.20.192/26' }
      BastionSubnet: { value: '10.2${padLeft(i, 2, '0')}.30.192/26' }
      VNetExists: { value: false }
      DeployHCX: { value: DeployHCX }
      DeploySRM: { value: DeploySRM }
      VRServerCount: { value: 1 }
    }
  }
}]
