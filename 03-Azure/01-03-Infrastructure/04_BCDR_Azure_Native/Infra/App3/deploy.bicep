@secure()
param adminPassword string

module virtualNetwork 'br/public:avm/res/network/virtual-network:0.5.2' = {
  name: 'virtualNetworkDeployment'
  params: {
    // Required parameters
    addressPrefixes: [
      '10.0.0.0/21'
    ]
    name: 'nvnipv6001'
    // Non-required parameters
    location: resourceGroup().location
    subnets: [
      {
        addressPrefixes: [
          '10.0.0.0/24'
        ]
        name: 'snet-vm'
      }
    ]
  }
}


module virtualMachine 'br/public:avm/res/compute/virtual-machine:0.12.0' = {
  name: 'virtualMachineDeployment'
  params: {
    // Required parameters
    adminUsername: 'localAdminUser'
    imageReference: {
      offer: 'dsvm-win-2022'
      publisher: 'microsoft-dsvm'
      sku: 'winserver-2022'
      version: 'latest'
    }
    name: 'app3vm_datascience'
    nicConfigurations: [
      {
        ipConfigurations: [
          {
            name: 'ipconfig01'
            subnetResourceId: virtualNetwork.outputs.subnetResourceIds[0]
          }
        ]
        nicSuffix: '-nic-01'
      }
    ]
    osDisk: {
      caching: 'ReadWrite'
      diskSizeGB: 128
      managedDisk: {
        storageAccountType: 'Premium_LRS'
      }
    }
    osType: 'Windows'
    vmSize: 'Standard_D2s_v3'
    zone: 0
    // Non-required parameters
    adminPassword: adminPassword
    location: resourceGroup().location
  }
  dependsOn: [
    virtualNetwork
  ]
}
