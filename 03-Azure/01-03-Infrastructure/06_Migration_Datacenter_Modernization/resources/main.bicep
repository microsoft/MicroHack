targetScope = 'subscription'

@description('Object ID of the current user (az ad signed-in-user show --query id)')
param currentUserObjectId string

@description('The Number of deployments per subscription')
param deploymentCount int = 1

@description('Azure region for the deployment')
@allowed([
  'West Europe'
  'East US'
  'East US 2'
  'South Central US'
  'West US 2'
  'West US 3'
  'Australia East'
  'Southeast Asia'
  'North Europe'
  'Sweden Central'
  'UK South'
  'Central US'
  'South Africa North'
  'Central India'
  'East Asia'
  'Japan East'
  'Korea Central'
  'Canada Central'
  'France Central'
  'Germany West Central'
  'Norway East'
  'Poland Central'
  'Switzerland North'
  'UAE North'
  'Brazil South'
  'Central US EUAP'
  'East US 2 EUAP'
  'Qatar Central'
  'Central US (Stage)'
  'East US (Stage)'
  'East US 2 (Stage)'
  'North Central US (Stage)'
  'South Central US (Stage)'
  'West US (Stage)'
  'West US 2 (Stage)'
  'Asia'
  'Asia Pacific'
  'Australia'
  'Brazil'
  'Canada'
  'Europe'
  'France'
  'Germany'
  'Global'
  'India'
  'Japan'
  'Korea'
  'Norway'
  'Singapore'
  'South Africa'
  'Switzerland'
  'United Arab Emirates'
  'United Kingdom'
  'United States'
  'United States EUAP'
  'East Asia (Stage)'
  'Southeast Asia (Stage)'
  'Brazil US'
  'East US STG'
  'North Central US'
  'West US'
  'Jio India West'
  'South Central US STG'
  'West Central US'
  'South Africa West'
  'Australia Central'
  'Australia Central 2'
  'Australia Southeast'
  'Japan West'
  'Jio India Central'
  'Korea South'
  'South India'
  'West India'
  'Canada East'
  'France South'
  'Germany North'
  'Norway West'
  'Switzerland West'
  'UK West'
  'UAE Central'
  'Brazil Southeast'
])
param location string

/*
* Source Module
*/
resource sourceRg 'Microsoft.Resources/resourceGroups@2021-01-01' = [for i in range(0, deploymentCount): {
  name: 'source-rg-${(i+1)}'
  location: location
}]

module source 'source.bicep' = [for i in range(0, deploymentCount):  {
  name: 'sourceModule${(i+1)}'
  scope: sourceRg[i]
  params: {
    location: location
    currentUserObjectId: currentUserObjectId
    vm1Name: 'frontend-${(i+1)}-1'
    vm2Name: 'frontend-${(i+1)}-2'
    adminUsername: 'microhackadmin${(i+1)}'
    deployment: (i+1)
  }
}]

/*
* Destination Module
*/
resource destinationRg 'Microsoft.Resources/resourceGroups@2021-01-01' = [for i in range(0, deploymentCount): {
  name: 'destination-rg-${(i+1)}'
  location: location
}]

module destination 'destination.bicep' = [for i in range(0, deploymentCount): {
  name: 'destinationModule${(i+1)}'
  scope: destinationRg[i]
  params: {
    location: location
    deployment: (i+1)
  }
}]
