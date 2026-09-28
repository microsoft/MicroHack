# ch01-A · .NET — Bicep templates

Infrastructure for the modernized Lego Catalog: an Azure SQL Database on the serverless
tier, an Azure Container Registry, Azure Files shares for the static content, and the
application itself on Azure Container Apps.

## What gets deployed

| Resource | Notes |
| --- | --- |
| `Microsoft.Sql/servers` | Logical server, public endpoint, TLS 1.2 minimum |
| `Microsoft.Sql/servers/databases` | `GP_S_Gen5` serverless, auto-pause after 60 min, 0.5–2 vCores |
| `Microsoft.Sql/servers/firewallRules` | Your client IP, plus `0.0.0.0` ("Allow access to Azure services") |
| `Microsoft.ContainerRegistry/registries` | `Basic` by default, admin user disabled |
| `Microsoft.Storage/storageAccounts` | Two Azure Files shares: `catalog-seed`, `catalog-images` |
| `Microsoft.ManagedIdentity/userAssignedIdentities` | Pulls from ACR; granted `AcrPull` on the registry |
| `Microsoft.OperationalInsights/workspaces` | Container App logs |
| `Microsoft.App/managedEnvironments` | Workload profiles environment (v2) with a `Consumption` profile |
| `Microsoft.App/containerApps` | 1 vCPU / 2 GiB, external ingress on 8080, HTTP scaling 0–3 |

All names are suffixed with `uniqueString(resourceGroup().id)`, so the same resource group
always produces the same names and two attendees never collide.

## Parameters

| Parameter | Default | Purpose |
| --- | --- | --- |
| `location` | resource group location | Where everything lands |
| `sqlAdministratorLogin` | — | SQL administrator login |
| `sqlAdministratorPassword` | — | `@secure()`; supplied from the environment |
| `clientIpAddress` | — | Your public IP, whitelisted on the SQL server |
| `databaseName` | `LegoCatalog` | Catalog database name |
| `databaseMinCapacity` | `0.5` | Minimum serverless vCores |
| `databaseMaxCapacity` | `2` | Maximum serverless vCores |
| `databaseAutoPauseDelayMinutes` | `60` | Idle minutes before auto-pause; `-1` disables it |
| `containerRegistrySku` | `Basic` | `Basic`, `Standard` or `Premium` |
| `containerImageName` | `lego-catalog/app:latest` | Image to run, as pushed by `az acr build` |
| `performanceApiKey` | — | `@secure()`; guards `GET /perftest/catalog` |
| `serviceVersion` | — | Reported as `OTEL_SERVICE_VERSION` |
| `maxReplicas` | `3` | Upper bound for HTTP scaling |

`main.bicepparam` reads the three secrets and the version from environment variables with
`readEnvironmentVariable()`, so **nothing sensitive is committed**.

## Deploy

```bash
export SQL_ADMIN_PASSWORD='<a-strong-password>'
export PERFTEST_API_KEY='<pick-a-key>'
export CLIENT_IP_ADDRESS='<your-public-ip>'
export SERVICE_VERSION="$(git rev-parse HEAD)"

az deployment group create \
  --resource-group rg-userNNN \
  --template-file main.bicep \
  --parameters main.bicepparam
```

> `CLIENT_IP_ADDRESS` must be the address Azure SQL actually sees. If the startup import
> fails with *"Client with IP address 'x.x.x.x' is not allowed to access the server"*, use
> the address from that message — behind a VPN or proxy it differs from what
> `curl https://api.ipify.org` reports.

The walkthrough builds this template up in stages (SQL first, then ACR, then Container
Apps). Re-running the same command after each edit is safe — the deployment is incremental.

## Build and push the image

```bash
cd ../../../../dotnet
az acr build --registry $(az deployment group show -g rg-userNNN -n <deployment> \
  --query properties.outputs.containerRegistryName.value -o tsv) \
  --image lego-catalog/app:latest .
```

## Upload the static content

The container image carries no seed data or images; both come from Azure Files.

```bash
ACCOUNT=$(az deployment group show -g rg-userNNN -n <deployment> \
  --query properties.outputs.storageAccountName.value -o tsv)
KEY=$(az storage account keys list -g rg-userNNN -n $ACCOUNT --query "[0].value" -o tsv)

az storage file upload --account-name $ACCOUNT --account-key "$KEY" \
  --share-name catalog-seed --source ../../../../data/catalog.json --path catalog.json

az storage file upload-batch --account-name $ACCOUNT --account-key "$KEY" \
  --destination catalog-images --source ../../../../data/images --pattern "*.png"
```

Then open the URL from the `applicationUrl` output.

## Outputs

`sqlServerFqdn`, `sqlServerName`, `databaseName`, `containerRegistryName`,
`containerRegistryLoginServer`, `storageAccountName`, `seedShareName`, `imagesShareName`,
`applicationUrl`.
