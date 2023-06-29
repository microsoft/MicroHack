targetScope = 'subscription'

@description('Object ID of the current user (az ad signed-in-user show --query id)')
param currentUserObjectId string

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
resource sourceRg 'Microsoft.Resources/resourceGroups@2021-01-01' = {
  name: 'source-rg'
  location: location
}

module source 'source.bicep' = {
  name: 'sourceModule'
  scope: sourceRg
  params: {
    location: location
    currentUserObjectId: currentUserObjectId
  }
}

/*
* Destination Module
*/
resource destinationRg 'Microsoft.Resources/resourceGroups@2021-01-01' = {
  name: 'destination-rg'
  location: location
}

module destination 'destination.bicep' = {
  name: 'destinationModule'
  scope: destinationRg
  params: {
    location: location
  }
}
