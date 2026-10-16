using './main.bicep'

param postgresAdministratorLogin = 'catalogadmin'
param postgresAdministratorPassword = readEnvironmentVariable('POSTGRES_ADMIN_PASSWORD')
param performanceApiKey = readEnvironmentVariable('PERFTEST_API_KEY')
param clientIpAddress = readEnvironmentVariable('CATALOG_CLIENT_IP')
param serviceVersion = readEnvironmentVariable('OTEL_SERVICE_VERSION')
param deploymentStage = int(readEnvironmentVariable('DEPLOYMENT_STAGE', '2'))
param deployApplication = bool(readEnvironmentVariable('DEPLOY_APPLICATION', 'false'))
