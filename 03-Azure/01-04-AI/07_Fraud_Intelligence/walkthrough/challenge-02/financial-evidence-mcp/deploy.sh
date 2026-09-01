#!/usr/bin/env bash
# Deploy the Financial Evidence MCP to Azure Functions Flex Consumption.
# The Function uses system-assigned managed identity for host storage and
# read-only access to an existing Azure Cosmos DB for NoSQL database.
#
# Usage:
#   ./deploy.sh -g <resource-group> -a <cosmos-account> -d <database> [options]
#
# Required:
#   -g  Function App resource group
#   -a  Existing Cosmos DB account name
#   -d  Existing Cosmos DB database name
#
# Options:
#   -c  Cosmos DB resource group (defaults to the Function App resource group)
#   -l  Azure location (default: swedencentral)
#   -n  Function App name (generated when omitted)
#   -s  Function host storage account name (generated when omitted)
#   -b  Bank container name (default: dim-bank)
#   -t  Transaction container name (default: fact-laundering-pattern-txn)
#   -u  Azure subscription ID
#   -h  Show this help
#
# Requirements: Azure CLI, Azure Functions Core Tools, and permissions to
# create Function resources and Cosmos DB SQL role assignments.

set -euo pipefail

LOCATION="swedencentral"
FUNCTION_APP_NAME=""
STORAGE_NAME=""
RESOURCE_GROUP=""
COSMOS_RESOURCE_GROUP=""
COSMOS_ACCOUNT_NAME=""
COSMOS_DATABASE_NAME=""
BANK_CONTAINER_NAME="dim-bank"
TRANSACTION_CONTAINER_NAME="fact-laundering-pattern-txn"
SUBSCRIPTION=""
COSMOS_DATA_READER_ROLE_ID="00000000-0000-0000-0000-000000000001"

usage() {
  grep '^#' "$0" | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

while getopts ":g:a:d:c:l:n:s:b:t:u:h" opt; do
  case "$opt" in
    g) RESOURCE_GROUP="$OPTARG" ;;
    a) COSMOS_ACCOUNT_NAME="$OPTARG" ;;
    d) COSMOS_DATABASE_NAME="$OPTARG" ;;
    c) COSMOS_RESOURCE_GROUP="$OPTARG" ;;
    l) LOCATION="$OPTARG" ;;
    n) FUNCTION_APP_NAME="$OPTARG" ;;
    s) STORAGE_NAME="$OPTARG" ;;
    b) BANK_CONTAINER_NAME="$OPTARG" ;;
    t) TRANSACTION_CONTAINER_NAME="$OPTARG" ;;
    u) SUBSCRIPTION="$OPTARG" ;;
    h) usage 0 ;;
    :) echo "ERROR: -$OPTARG requires a value." >&2; usage 1 ;;
    *) echo "ERROR: unknown option -$OPTARG." >&2; usage 1 ;;
  esac
done

if [[ -z "$RESOURCE_GROUP" || -z "$COSMOS_ACCOUNT_NAME" || -z "$COSMOS_DATABASE_NAME" ]]; then
  echo "ERROR: -g, -a, and -d are required." >&2
  usage 1
fi

command -v az >/dev/null || { echo "ERROR: Azure CLI not found." >&2; exit 1; }
command -v func >/dev/null || {
  echo "ERROR: Azure Functions Core Tools (func) not found." >&2
  exit 1
}

if [[ -n "$SUBSCRIPTION" ]]; then
  az account set --subscription "$SUBSCRIPTION"
fi

SUBSCRIPTION_ID="$(az account show --query id --output tsv)"
COSMOS_RESOURCE_GROUP="${COSMOS_RESOURCE_GROUP:-$RESOURCE_GROUP}"
SUFFIX="$(printf '%s' "${RESOURCE_GROUP}-${SUBSCRIPTION_ID}" | sha256sum | cut -c1-6)"
FUNCTION_APP_NAME="${FUNCTION_APP_NAME:-mcp-financial-evidence-${SUFFIX}}"
STORAGE_NAME="${STORAGE_NAME:-mcpfinance${SUFFIX}sa}"
STORAGE_NAME="$(printf '%s' "$STORAGE_NAME" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9' | cut -c1-24)"
DEPLOY_CONTAINER="app-package-${FUNCTION_APP_NAME}"

if (( ${#STORAGE_NAME} < 3 )); then
  echo "ERROR: the normalized storage account name must contain at least 3 characters." >&2
  exit 1
fi

echo "Subscription       : $SUBSCRIPTION_ID"
echo "Function RG        : $RESOURCE_GROUP"
echo "Location           : $LOCATION"
echo "Function App       : $FUNCTION_APP_NAME (Flex Consumption, Python 3.13)"
echo "Storage account    : $STORAGE_NAME"
echo "Cosmos account     : $COSMOS_ACCOUNT_NAME"
echo "Cosmos database    : $COSMOS_DATABASE_NAME"
echo "Cosmos resource RG : $COSMOS_RESOURCE_GROUP"

if ! az group show --name "$RESOURCE_GROUP" >/dev/null 2>&1; then
  echo ">>> Creating resource group $RESOURCE_GROUP"
  az group create --name "$RESOURCE_GROUP" --location "$LOCATION" --output none
fi

if [[ "$(az provider show \
  --namespace Microsoft.Web \
  --query registrationState --output tsv)" != "Registered" ]]; then
  echo ">>> Registering Microsoft.Web resource provider"
  az provider register \
    --namespace Microsoft.Web \
    --wait \
    --output none
fi

echo ">>> Validating Cosmos DB resources"
COSMOS_ACCOUNT_ID="$(az cosmosdb show \
  --resource-group "$COSMOS_RESOURCE_GROUP" \
  --name "$COSMOS_ACCOUNT_NAME" \
  --query id --output tsv)"
COSMOS_ENDPOINT="$(az cosmosdb show \
  --resource-group "$COSMOS_RESOURCE_GROUP" \
  --name "$COSMOS_ACCOUNT_NAME" \
  --query documentEndpoint --output tsv)"
az cosmosdb sql database show \
  --resource-group "$COSMOS_RESOURCE_GROUP" \
  --account-name "$COSMOS_ACCOUNT_NAME" \
  --name "$COSMOS_DATABASE_NAME" \
  --output none

if ! az storage account show \
  --name "$STORAGE_NAME" \
  --resource-group "$RESOURCE_GROUP" >/dev/null 2>&1; then
  echo ">>> Creating storage account $STORAGE_NAME"
  az storage account create \
    --name "$STORAGE_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --location "$LOCATION" \
    --sku Standard_LRS \
    --kind StorageV2 \
    --allow-blob-public-access false \
    --public-network-access Enabled \
    --default-action Allow \
    --min-tls-version TLS1_2 \
    --output none
fi

STORAGE_ID="$(az storage account show \
  --name "$STORAGE_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query id --output tsv)"
CURRENT_USER_ID="$(az ad signed-in-user show --query id --output tsv 2>/dev/null || true)"

if [[ -n "$CURRENT_USER_ID" ]]; then
  if [[ "$(az role assignment list \
    --assignee "$CURRENT_USER_ID" \
    --role "Storage Blob Data Owner" \
    --scope "$STORAGE_ID" \
    --query 'length(@)' --output tsv)" == "0" ]]; then
    echo ">>> Granting the current user deployment storage access"
    az role assignment create \
      --assignee-object-id "$CURRENT_USER_ID" \
      --assignee-principal-type User \
      --role "Storage Blob Data Owner" \
      --scope "$STORAGE_ID" \
      --output none
  fi
else
  echo "ERROR: unable to resolve the signed-in user for deployment storage access." >&2
  echo "Run this script from an interactive Azure CLI user session." >&2
  exit 1
fi

echo ">>> Ensuring deployment container $DEPLOY_CONTAINER"
container_created=false
for attempt in 1 2 3 4 5 6; do
  if az storage container create \
    --name "$DEPLOY_CONTAINER" \
    --account-name "$STORAGE_NAME" \
    --auth-mode login \
    --output none 2>/dev/null; then
    container_created=true
    break
  fi
  echo "    Storage RBAC is propagating (attempt $attempt/6)..."
  sleep 5
done
if [[ "$container_created" != "true" ]]; then
  echo "ERROR: could not create deployment container after waiting for RBAC." >&2
  exit 1
fi

if ! az functionapp show \
  --name "$FUNCTION_APP_NAME" \
  --resource-group "$RESOURCE_GROUP" >/dev/null 2>&1; then
  echo ">>> Creating Function App $FUNCTION_APP_NAME"
  az functionapp create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$FUNCTION_APP_NAME" \
    --flexconsumption-location "$LOCATION" \
    --runtime python \
    --runtime-version 3.13 \
    --storage-account "$STORAGE_NAME" \
    --deployment-storage-name "$STORAGE_NAME" \
    --deployment-storage-container-name "$DEPLOY_CONTAINER" \
    --deployment-storage-auth-type SystemAssignedIdentity \
    --assign-identity '[system]' \
    --output none
else
  echo ">>> Ensuring the existing Function App has a system-assigned identity"
  az functionapp identity assign \
    --name "$FUNCTION_APP_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --output none
fi

echo ">>> Configuring one always-ready HTTP instance"
az functionapp scale config always-ready set \
  --resource-group "$RESOURCE_GROUP" \
  --name "$FUNCTION_APP_NAME" \
  --settings http=1 \
  --output none

FUNCTION_PRINCIPAL_ID="$(az functionapp identity show \
  --name "$FUNCTION_APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query principalId --output tsv)"

ensure_storage_role() {
  local role="$1"
  if [[ "$(az role assignment list \
    --assignee "$FUNCTION_PRINCIPAL_ID" \
    --role "$role" \
    --scope "$STORAGE_ID" \
    --query 'length(@)' --output tsv)" == "0" ]]; then
    az role assignment create \
      --assignee-object-id "$FUNCTION_PRINCIPAL_ID" \
      --assignee-principal-type ServicePrincipal \
      --role "$role" \
      --scope "$STORAGE_ID" \
      --output none
  fi
}

echo ">>> Granting Function host storage roles"
ensure_storage_role "Storage Blob Data Owner"
ensure_storage_role "Storage Queue Data Contributor"
ensure_storage_role "Storage Table Data Contributor"

COSMOS_SCOPE="${COSMOS_ACCOUNT_ID}/dbs/${COSMOS_DATABASE_NAME}"
COSMOS_ROLE_DEFINITION_ID="${COSMOS_ACCOUNT_ID}/sqlRoleDefinitions/${COSMOS_DATA_READER_ROLE_ID}"
EXISTING_COSMOS_ASSIGNMENT="$(az cosmosdb sql role assignment list \
  --resource-group "$COSMOS_RESOURCE_GROUP" \
  --account-name "$COSMOS_ACCOUNT_NAME" \
  --query "[?principalId=='${FUNCTION_PRINCIPAL_ID}' && scope=='${COSMOS_SCOPE}' && roleDefinitionId=='${COSMOS_ROLE_DEFINITION_ID}'] | length(@)" \
  --output tsv)"

if [[ "$EXISTING_COSMOS_ASSIGNMENT" == "0" ]]; then
  echo ">>> Granting Cosmos DB Built-in Data Reader at database scope"
  az cosmosdb sql role assignment create \
    --resource-group "$COSMOS_RESOURCE_GROUP" \
    --account-name "$COSMOS_ACCOUNT_NAME" \
    --principal-id "$FUNCTION_PRINCIPAL_ID" \
    --role-definition-id "$COSMOS_ROLE_DEFINITION_ID" \
    --scope "$COSMOS_SCOPE" \
    --output none
else
  echo ">>> Cosmos DB data reader assignment already exists"
fi

echo ">>> Configuring identity-based storage and Cosmos settings"
az functionapp config appsettings delete \
  --resource-group "$RESOURCE_GROUP" \
  --name "$FUNCTION_APP_NAME" \
  --setting-names AzureWebJobsStorage COSMOS_CONNECTION_STRING \
  --output none 2>/dev/null || true
az functionapp config appsettings set \
  --resource-group "$RESOURCE_GROUP" \
  --name "$FUNCTION_APP_NAME" \
  --settings \
    "AzureWebJobsStorage__accountName=$STORAGE_NAME" \
    "AzureWebJobsFeatureFlags=EnableWorkerIndexing" \
    "COSMOS_ENDPOINT=$COSMOS_ENDPOINT" \
    "COSMOS_DATABASE_NAME=$COSMOS_DATABASE_NAME" \
    "COSMOS_BANK_CONTAINER=$BANK_CONTAINER_NAME" \
    "COSMOS_TRANSACTION_CONTAINER=$TRANSACTION_CONTAINER_NAME" \
  --output none

echo ">>> Publishing Function code"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/src" && pwd)"
if [[ ! -f "$PROJECT_DIR/host.json" ]]; then
  echo "ERROR: Azure Functions project not found at $PROJECT_DIR." >&2
  exit 1
fi
pushd "$PROJECT_DIR" >/dev/null
func azure functionapp publish "$FUNCTION_APP_NAME" --python
popd >/dev/null

HOSTNAME="${FUNCTION_APP_NAME}.azurewebsites.net"
DEPLOYED_HOSTNAME="$(az rest \
  --method get \
  --url "https://management.azure.com/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.Web/sites/${FUNCTION_APP_NAME}?api-version=2024-11-01" \
  --query properties.defaultHostName \
  --output tsv 2>/dev/null || true)"
if [[ -n "$DEPLOYED_HOSTNAME" ]]; then
  HOSTNAME="$DEPLOYED_HOSTNAME"
fi

echo
echo "Done."
echo "Function App: https://${HOSTNAME}"
echo "MCP endpoint: https://${HOSTNAME}/runtime/webhooks/mcp"