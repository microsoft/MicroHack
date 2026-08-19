# Walkthrough Challenge 04 - Implement the platform abstractions with recipes

[< Previous Solution](../challenge-03/solution-03.md) - **[Home](../../Readme.md)** - [Next Challenge](../../challenges/challenge-05.md)

Duration: 60-90 minutes

## Coach notes

Challenge 03 defined contracts. Challenge 04 implements them.

The teaching sequence is deliberate:

1. Manually author one Azure SQL recipe to understand `context`, AVM, and `result`.
2. Register the complete recipe sets as environment-as-code.

Do not let teams skip directly to automation. The optional script at the end exists
for setup recovery and participants who explicitly choose not to follow the tutorial.

## Recipe concepts

A recipe is a Bicep file or Terraform module that Radius invokes when a developer
deploys a matching resource type.

```text
Resource type contract                    Recipe implementation
----------------------------------        -----------------------------------
Radius.Resources/sqlDatabases             iac/recipes/sql-server.bicep
input: size, environment                  reads context.resource.properties
output: host, port, database              returns result.values
secret: password                          returns result.secrets
```

The application developer declares only the portable resource:

```bicep
resource db 'Radius.Resources/sqlDatabases@2025-08-01-preview' = {
  properties: {
    environment: environment
    application: app.id
    size: 'S'
  }
}
```

Radius looks up the recipe registered in the current environment, executes it, and
projects the recipe result back onto the resource.

### The context object

Radius injects `context` into every recipe:

| Field | Purpose |
| --- | --- |
| `context.resource.id` | Full Radius resource ID |
| `context.resource.name` | Developer-assigned resource name |
| `context.resource.properties` | Developer inputs such as `size` |
| `context.environment.id` | Radius environment ID |
| `context.environment.providers.azure.scope` | Azure subscription and resource-group scope |
| `context.runtime.kubernetes.namespace` | Kubernetes namespace |
| `context.application.name` | Application name for tags and labels |

### Azure Verified Modules

Azure recipes should use [Azure Verified Modules](https://aka.ms/avm) when a suitable
module exists. The recipe remains thin and maps Radius inputs and outputs; AVM provides
maintained Azure resource patterns and security defaults.

### The result object

Every recipe returns:

- `result.resources`: provisioned resources tracked for lifecycle operations
- `result.values`: read-only properties returned to the application
- `result.secrets`: sensitive values stored through Radius secret handling

## Manual tutorial, Stage 1: Author the Azure SQL recipe

Open `iac/recipes/sql-server.bicep` and walk through:

- Size-to-SKU mapping
- Deterministic naming from `context.resource.id`
- AVM SQL Server usage
- Radius and application tags
- Values and secret output mapping

The complete recipe is provided so students can compare their work:

```bicep
@description('Injected by Radius.')
param context object

@description('Database name.')
param databaseName string = context.resource.name

var skuMap = {
  S: { name: 'GP_Gen5', capacity: 2 }
  M: { name: 'GP_Gen5', capacity: 4 }
  L: { name: 'GP_Gen5', capacity: 8 }
}
var sizeKey = context.resource.properties.?size ?? 'S'
var sku = skuMap[sizeKey]
var seed = uniqueString(context.resource.id)
var serverName = 'sql-${take(seed, 10)}'
var adminPassword = '${uniqueString(context.resource.id)}Aa1!'

module sqlServer 'br/public:avm/res/sql/server:0.12.0' = {
  name: 'sql-server-${seed}'
  params: {
    name: serverName
    location: resourceGroup().location
    administratorLogin: 'sqladmin'
    administratorLoginPassword: adminPassword
    databases: [
      {
        name: databaseName
        sku: {
          name: '${sku.name}_${sku.capacity}'
        }
      }
    ]
    tags: {
      'radapp.io/environment': context.environment.id
      'radapp.io/resource': context.resource.id
      'radapp.io/application': context.application == null ? '' : context.application.name
    }
  }
}

output result object = {
  resources: [
    sqlServer.outputs.resourceId
  ]
  values: {
    host: sqlServer.outputs.fullyQualifiedDomainName
    port: 1433
    database: databaseName
    username: 'sqladmin'
  }
  secrets: {
    password: adminPassword
  }
}
```

Discuss why the password belongs in `secrets`, why the developer never supplies the
Azure resource group, and what changes when a different recipe implements the type.

## Manual tutorial, Stage 2: Publish and register the SQL recipe on AKS

Select AKS and its Radius workspace:

```bash
unset KUBECONFIG
kubectl config use-context aks-adaptive-apps
rad workspace switch ws-azure-prod
rad env switch env-azure-prod
rad group switch rg-trading
```

Create an ACR. Its name must be globally unique and lowercase:

```bash
export AZURE_SUBSCRIPTION="<subscription-id>"
export RESOURCE_GROUP="rg-adaptive-apps"
export ACR_NAME="<globally-unique-acr-name>"

az account set --subscription "$AZURE_SUBSCRIPTION"
az acr show \
  --resource-group "$RESOURCE_GROUP" \
  --name "$ACR_NAME" >/dev/null 2>&1 ||
  az acr create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$ACR_NAME" \
    --sku Basic
```

Authenticate with Docker:

```bash
az acr login --name "$ACR_NAME"
```

When Docker is unavailable, create temporary OCI authentication:

```bash
export DOCKER_CONFIG="$(mktemp -d)"
TOKEN="$(az acr login --name "$ACR_NAME" --expose-token \
  --query accessToken --output tsv)"
AUTH="$(printf '00000000-0000-0000-0000-000000000000:%s' "$TOKEN" |
  base64 | tr -d '\n')"

cat >"${DOCKER_CONFIG}/config.json" <<EOF
{
  "auths": {
    "${ACR_NAME}.azurecr.io": {
      "auth": "${AUTH}"
    }
  }
}
EOF
```

Publish the recipe:

```bash
rad bicep publish \
  --file iac/recipes/sql-server.bicep \
  --target "br:${ACR_NAME}.azurecr.io/recipes/sql-server:1.0.0"
```

Register it:

```bash
rad recipe register default \
  --environment env-azure-prod \
  --resource-type Radius.Resources/sqlDatabases \
  --template-kind bicep \
  --template-path "${ACR_NAME}.azurecr.io/recipes/sql-server:1.0.0"
```

Verify:

```bash
rad recipe list --environment env-azure-prod
```

## Manual tutorial, Stage 3: Register the complete AKS recipe set

The AKS environment definition registers Azure-backed implementations and the custom
SQL recipe:

```bash
export ISTIO_REVISION="$(kubectl get deployment \
  --namespace aks-istio-system \
  --selector app=istiod \
  --output jsonpath='{.items[0].metadata.labels.istio\.io/rev}')"

rad deploy iac/aks-env.bicep \
  --workspace ws-azure-prod \
  --group rg-trading \
  --environment env-azure-prod \
  --parameters environmentName=env-azure-prod \
  --parameters namespace=env-azure-prod \
  --parameters azureSubscriptionId="$AZURE_SUBSCRIPTION" \
  --parameters azureResourceGroup="$RESOURCE_GROUP" \
  --parameters istioRevision="$ISTIO_REVISION" \
  --parameters sqlDatabasesRecipeTemplatePath="${ACR_NAME}.azurecr.io/recipes/sql-server:1.0.0"
```

| Resource type | AKS/Azure backend |
| --- | --- |
| `postgreSqlDatabases` | Azure Database for PostgreSQL Flexible Server |
| `mqttBrokers` | Azure Event Grid MQTT |
| `idProviders` | In-cluster Keycloak |
| `workloadIdentities` | AKS workload identity |
| `aiModels` | Azure OpenAI |
| `governance` | In-cluster OPA |
| `agentGuardrails` | Agent Governance Toolkit sidecar support |
| `sqlDatabases` | Custom Azure SQL recipe |

## Manual tutorial, Stage 4: Register the complete K3s recipe set

Switch both kube context and Radius workspace:

```bash
export KUBECONFIG="$HOME/.kube/adaptive-apps-k3s.yaml"
kubectl config use-context k3s-azure-vm
rad workspace switch ws-local-prod
rad env switch env-local-prod
rad group switch rg-trading
```

Deploy the local environment definition:

```bash
rad deploy iac/local-env.bicep \
  --workspace ws-local-prod \
  --group rg-trading \
  --environment env-local-prod \
  --parameters environmentName=env-local-prod \
  --parameters namespace=env-local-prod
```

| Resource type | K3s/local backend |
| --- | --- |
| `postgreSqlDatabases` | PostgreSQL container |
| `mqttBrokers` | Eclipse Mosquitto container |
| `idProviders` | Keycloak container |
| `workloadIdentities` | Local Kubernetes no-op mapping |
| `aiModels` | Kaito recipe, requiring a GPU when deployed |
| `governance` | In-cluster OPA |
| `agentGuardrails` | Agent Governance Toolkit sidecar support |

Registering the Kaito recipe does not deploy a model. A GPU-enabled platform is
required only when that recipe is exercised in the AI challenge.

## Validate

AKS:

```bash
unset KUBECONFIG
kubectl config use-context aks-adaptive-apps
rad workspace switch ws-azure-prod
rad recipe list --environment env-azure-prod
```

K3s:

```bash
export KUBECONFIG="$HOME/.kube/adaptive-apps-k3s.yaml"
kubectl config use-context k3s-azure-vm
rad workspace switch ws-local-prod
rad recipe list --environment env-local-prod
```

For either active platform:

```bash
kubectl port-forward service/dashboard \
  --namespace radius-system 7007:80
```

Open <http://localhost:7007>, navigate to the environment, and inspect **Recipes**.

## Optional platforms

If Azure Local or Arc-enabled Kubernetes replaces K3s, use `iac/local-env.bicep` for
in-cluster implementations unless the platform team intentionally provides managed
services. Always use a distinct workspace and translate context and environment names
consistently.

## Optional automation

The manual tutorial is the intended learning path. To automate the same configuration:

```bash
export AZURE_SUBSCRIPTION="<subscription-id>"
export RESOURCE_GROUP="rg-adaptive-apps"
export ACR_NAME="<globally-unique-acr-name>"

# Configure both defaults:
bash resources/configure-recipes.sh all

# Or configure one:
bash resources/configure-recipes.sh aks
bash resources/configure-recipes.sh k3s
```

The script creates or reuses ACR, publishes the custom SQL recipe for AKS, deploys the
appropriate environment definition, and verifies the registered recipes.
