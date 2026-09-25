# ch01-A Java Bicep

Deploy the resources in the same order as the [Java walkthrough](../../java.md).
Run these Bash commands from the repository root, in a Codespace or a terminal with
Azure CLI and Bicep. Use an existing participant resource group. Deployment is
**incremental**; never use complete mode against a group containing the workshop VMs.

`main.bicep` coordinates small modules for PostgreSQL, ACR/identity, Azure Files and
the Container Apps environment, and the application. Java-specific names, suffixed
with `uniqueString(resourceGroup().id)`, allow both solution stacks to coexist.
The location defaults to the resource group's location.

## Configuration

```bash
export AZURE_CONFIG_DIR="$HOME/.azure-365"  # Omit for the normal CLI profile.
export RG=rg-user001
export BICEP=walkthrough/ch01-A/java/bicep
az account show --query '{subscription:id,name:name}' -o table
az group show -n "$RG" --query '{name:name,location:location}' -o table

export CATALOG_CLIENT_IP="$(curl -fsS https://api.ipify.org)"
export OTEL_SERVICE_VERSION="ch01-java-$(git rev-parse --short HEAD)"
read -rsp 'PostgreSQL administrator password: ' POSTGRES_ADMIN_PASSWORD; echo
read -rsp 'Performance endpoint API key: ' PERFTEST_API_KEY; echo
export POSTGRES_ADMIN_PASSWORD PERFTEST_API_KEY
export DEPLOYMENT_STAGE=2 DEPLOY_APPLICATION=false
```

The example `main.bicepparam` reads secrets from the environment, never from committed
values. Keep the same password and API key for every stage. Do not print the environment
or write compiled parameter JSON into the repository. The default administrator is
`catalogadmin`, the database is `catalog`, and PostgreSQL is version 16 on **B1ms**.

## Step 2 - database, then local import

```bash
az bicep build --file "$BICEP/main.bicep" --stdout >/dev/null
az deployment group validate -g "$RG" -n ch01-java-step2 \
  --template-file "$BICEP/main.bicep" --parameters "$BICEP/main.bicepparam" \
  --query properties.provisioningState -o tsv
az deployment group what-if -g "$RG" -n ch01-java-step2 \
  --template-file "$BICEP/main.bicep" --parameters "$BICEP/main.bicepparam"
az deployment group create -g "$RG" -n ch01-java-step2 --mode Incremental \
  --template-file "$BICEP/main.bicep" --parameters "$BICEP/main.bicepparam" \
  --query properties.provisioningState -o tsv

export CATALOG_DATABASE_HOST="$(az deployment group show -g "$RG" -n ch01-java-step2 \
  --query properties.outputs.postgresServerFqdn.value -o tsv)"
export CATALOG_DATABASE_PORT=5432 CATALOG_DATABASE_NAME=catalog
export CATALOG_DATABASE_USERNAME=catalogadmin
export CATALOG_DATABASE_PASSWORD="$POSTGRES_ADMIN_PASSWORD"
export CATALOG_DATABASE_SSL_MODE=require CATALOG_STARTUP_IMPORT_ENABLED=true
```

Use the upgraded application from [the app instructions](../README.md), with the
repository's seed JSON and images. Start it locally before continuing. Flyway creates
the schema and the startup importer loads **198 figures in 20 categories**. Confirm
`/readyz` and the catalog; this step deliberately imports from the seed rather than
modifying or exporting the ch00 VM.

Only the client IP is admitted at this stage. If a VPN changes the database-visible IP,
correct `CATALOG_CLIENT_IP` and redeploy. PostgreSQL requires TLS; never work around a
connection error with `sslmode=disable` against Azure.

## Steps 3 and 4 - local container, then ACR build

First complete the local Docker build/run in [the app instructions](../README.md).
Then extend the deployed resources with the registry and its image-pull identity:

```bash
export DEPLOYMENT_STAGE=4
az deployment group validate -g "$RG" -n ch01-java-step4 \
  --template-file "$BICEP/main.bicep" --parameters "$BICEP/main.bicepparam" \
  --query properties.provisioningState -o tsv
az deployment group create -g "$RG" -n ch01-java-step4 --mode Incremental \
  --template-file "$BICEP/main.bicep" --parameters "$BICEP/main.bicepparam" \
  --query properties.provisioningState -o tsv
export REGISTRY="$(az deployment group show -g "$RG" -n ch01-java-step4 \
  --query properties.outputs.containerRegistryName.value -o tsv)"
az acr build --registry "$REGISTRY" --image lego-catalog/app:latest "$WORKSHOP/java"
```

The `$WORKSHOP/java` build context must have the solution's `app/` overlay applied. The registry
is **Basic**, with admin credentials disabled. ACR builds for Linux independently of
your workstation architecture. Do not substitute an ARM-only local image for this step.

## Step 5 - temporary Azure-services database access

```bash
export DEPLOYMENT_STAGE=5
az deployment group create -g "$RG" -n ch01-java-step5 --mode Incremental \
  --template-file "$BICEP/main.bicep" --parameters "$BICEP/main.bicepparam" \
  --query properties.provisioningState -o tsv
```

The `0.0.0.0` to `0.0.0.0` PostgreSQL firewall rule allows Azure services, **including
other subscriptions**, not just this app. It is the walkthrough's temporary lab setting.
Replace public access with private networking in ch07-enterprise.

## Step 6 - storage/environment first, then the application

Create the environment and empty shares without prematurely starting the catalog:

```bash
export DEPLOYMENT_STAGE=6 DEPLOY_APPLICATION=false
az deployment group validate -g "$RG" -n ch01-java-step6 \
  --template-file "$BICEP/main.bicep" --parameters "$BICEP/main.bicepparam" \
  --query properties.provisioningState -o tsv
az deployment group what-if -g "$RG" -n ch01-java-step6 \
  --template-file "$BICEP/main.bicep" --parameters "$BICEP/main.bicepparam"
az deployment group create -g "$RG" -n ch01-java-step6 --mode Incremental \
  --template-file "$BICEP/main.bicep" --parameters "$BICEP/main.bicepparam" \
  --query properties.provisioningState -o tsv

export AZURE_STORAGE_ACCOUNT="$(az deployment group show -g "$RG" -n ch01-java-step6 \
  --query properties.outputs.storageAccountName.value -o tsv)"
export AZURE_STORAGE_KEY="$(az storage account keys list -g "$RG" \
  -n "$AZURE_STORAGE_ACCOUNT" --query '[0].value' -o tsv)"
az storage file upload --share-name catalog-seed --source data/catalog.json \
  --path catalog.json --no-progress --only-show-errors -o none
az storage file upload-batch --destination catalog-images --source data/images \
  --no-progress --only-show-errors -o none
unset AZURE_STORAGE_KEY
```

Before deploying the app, confirm the user-assigned identity's role is visible and
the registry permits ARM audience tokens:

```bash
IDENTITY_PRINCIPAL="$(az deployment group show -g "$RG" -n ch01-java-step6 \
  --query properties.outputs.appIdentityPrincipalId.value -o tsv)"
REGISTRY_ID="$(az acr show -n "$REGISTRY" --query id -o tsv)"
az role assignment list --scope "$REGISTRY_ID" \
  --assignee-object-id "$IDENTITY_PRINCIPAL" \
  --query "[?roleDefinitionName=='AcrPull'].roleDefinitionName" -o tsv
az acr config authentication-as-arm show -r "$REGISTRY" --query status -o tsv
```

Proceed only when these return `AcrPull` and `enabled`; role propagation may take a
few minutes. No registry password is needed.

```bash
export DEPLOY_APPLICATION=true
az deployment group validate -g "$RG" -n ch01-java-step6 \
  --template-file "$BICEP/main.bicep" --parameters "$BICEP/main.bicepparam" \
  --query properties.provisioningState -o tsv
az deployment group create -g "$RG" -n ch01-java-step6 --mode Incremental \
  --template-file "$BICEP/main.bicep" --parameters "$BICEP/main.bicepparam" \
  --query properties.provisioningState -o tsv
URL="$(az deployment group show -g "$RG" -n ch01-java-step6 \
  --query properties.outputs.applicationUrl.value -o tsv)"
printf '%s\n' "$URL"
curl --fail-with-body "$URL/healthz"
curl --fail-with-body "$URL/readyz"
```

The app uses **1 CPU / 2 GiB**, HTTPS ingress on port 8080, a workload-profiles
Consumption environment, and HTTP scaling **0-3** at 50 concurrent requests.
Seed and images are separate read-only Azure Files mounts. The database password and
performance key use Container Apps secrets. `CONTAINER_APP_REVISION` is injected by
Azure; telemetry export is deliberately disabled until ch04.
The local OTLP placeholder satisfies the application's configuration validation; with
`OTEL_SDK_DISABLED=true` no telemetry is sent to it.

## Exit criteria

Browse `/`, search by figure name, select a category, open `/figure/{id}`, and load
its `/images/{filename}` photograph. Confirm 198 figures and 20 categories, healthy
`/healthz`, and database/import readiness from `/readyz`.

Close browser tabs and stop all HTTP polling before waiting for scale-to-zero.
Observe through the management API instead, which does not wake the application:

```bash
REVISION="$(az containerapp show -g "$RG" -n ca-legocatalog-java \
  --query properties.latestReadyRevisionName -o tsv)"
az containerapp replica list -g "$RG" -n ca-legocatalog-java \
  --revision "$REVISION" --query 'length(@)' -o tsv
# Wait for zero (the default cooldown is about five minutes), then:
curl --fail-with-body --max-time 180 "$URL/readyz"
```

Keep the deployed Azure resources for ch02. Never delete the participant resource
group as cleanup; it contains the original VMs and may contain the other stack.
