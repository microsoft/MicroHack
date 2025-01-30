using 'br/public:avm/res/compute/virtual-machine:0.12.0'

// Required parameters
param adminUsername = 'vmAdminUser'
param imageReference = {
  offer: 'dsvm-win-2022'
  publisher: 'microsoft-dsvm'
  sku: 'winserver-2022'
  version: 'latest'
}
param  name = 'app3vm_datascience'

param nicConfigurations = [
  {
    ipConfigurations: [
      {
        name: 'ipconfig01'
        subnetResourceId: '<subnetResourceId>'
      }
    ]
    nicSuffix: '-nic-01'
  }
]
param osDisk = {
  caching: 'ReadWrite'
  diskSizeGB: 128
  managedDisk: {
    storageAccountType: 'Premium_LRS'
  }
}
param osType = 'Windows'
param vmSize = 'Standard_D2s_v3'
param zone = 1
// Non-required parameters
param adminPassword = '<adminPassword>'
param location = '<location>'
