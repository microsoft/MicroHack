using './main.bicep'

param sqlAdministratorLogin = 'catalogadmin'

// Supplied from the environment so the secret never lands in source control:
//   export SQL_ADMIN_PASSWORD='<your-strong-password>'
param sqlAdministratorPassword = readEnvironmentVariable('SQL_ADMIN_PASSWORD')

// Your public IP, so you can reach the database from your workstation or Codespace:
//   export CLIENT_IP_ADDRESS="$(curl -s https://api.ipify.org)"
param clientIpAddress = readEnvironmentVariable('CLIENT_IP_ADDRESS')

param databaseName = 'LegoCatalog'
param databaseMinCapacity = '0.5'
param databaseMaxCapacity = 2
param databaseAutoPauseDelayMinutes = 60

param containerRegistrySku = 'Basic'
param containerImageName = 'lego-catalog/app:latest'
param maxReplicas = 3

// Also supplied from the environment, so no secret is committed:
//   export PERFTEST_API_KEY='<pick-a-key>'
param performanceApiKey = readEnvironmentVariable('PERFTEST_API_KEY')

//   export SERVICE_VERSION="$(git rev-parse HEAD)"
param serviceVersion = readEnvironmentVariable('SERVICE_VERSION')
