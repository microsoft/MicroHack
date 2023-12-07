@description('Specifies a name for creating the migrate project.')
@maxLength(13)
param migrateProjectName string


@description('Specifies the location for all resources.')
@allowed([
  'germanywestcentral'
])
param location string = 'germanywestcentral'

resource migrateProject 'Microsoft.Migrate/MigrateProjects@2020-05-01' = {
  name: migrateProjectName
  location: location
  tags: {
    'Migrate Project': migrateProjectName
  }
  properties: {}
}

resource migrateProjectName_Servers_Assessment_ServerAssessment 'Microsoft.Migrate/MigrateProjects/Solutions@2020-05-01' = {
  parent: migrateProject
  name: 'Servers-Assessment-ServerAssessment'
  properties: {
    tool: 'ServerAssessment'
    purpose: 'Assessment'
    goal: 'Servers'
    status: 'Active'
  }
}

resource migrateProjectName_Servers_Discovery_ServerDiscovery 'Microsoft.Migrate/MigrateProjects/Solutions@2020-05-01' = {
  parent: migrateProject
  name: 'Servers-Discovery-ServerDiscovery'
  properties: {
    tool: 'ServerDiscovery'
    purpose: 'Discovery'
    goal: 'Servers'
    status: 'Inactive'
  }
}

resource migrateProjectName_Servers_Migration_ServerMigration 'Microsoft.Migrate/MigrateProjects/Solutions@2020-05-01' = {
  parent: migrateProject
  name: 'Servers-Migration-ServerMigration'
  properties: {
    tool: 'ServerMigration'
    purpose: 'Migration'
    goal: 'Servers'
    status: 'Active'
  }
}
