#!/usr/bin/env bash
set -euo pipefail

APIM_API_VERSION="2024-05-01"

log() {
  printf '\n==> %s\n' "$1"
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'Required command not found: %s\n' "$1" >&2
    exit 1
  fi
}

azd_get_required() {
  local key="$1"
  local value
  value="$(azd env get-value "$key" 2>/dev/null || true)"
  if [[ -z "$value" ]]; then
    printf 'Required azd environment value is missing: %s\nRun azd up first, then rerun this script.\n' "$key" >&2
    exit 1
  fi
  printf '%s' "$value"
}

azd_get_optional() {
  azd env get-value "$1" 2>/dev/null || true
}

delete_default_product() {
  local product_id="$1"

  if az apim product show \
    --resource-group "$resource_group" \
    --service-name "$apim_name" \
    --product-id "$product_id" \
    --only-show-errors \
    -o none >/dev/null 2>&1; then
    log "Deleting APIM default product: $product_id"
    az apim product delete \
      --resource-group "$resource_group" \
      --service-name "$apim_name" \
      --product-id "$product_id" \
      --delete-subscriptions true \
      --yes \
      --only-show-errors \
      -o none
  else
    printf 'Default product already absent: %s\n' "$product_id"
  fi
}

delete_default_subscription() {
  local subscription_name="$1"
  local subscription_uri="/subscriptions/${subscription_id}/resourceGroups/${resource_group}/providers/Microsoft.ApiManagement/service/${apim_name}/subscriptions/${subscription_name}?api-version=${APIM_API_VERSION}"

  if az rest \
    --method delete \
    --uri "$subscription_uri" \
    --headers 'If-Match=*' \
    --only-show-errors \
    -o none >/dev/null 2>&1; then
    printf 'Deleted default subscription: %s\n' "$subscription_name"
  else
    printf 'Default subscription already absent or could not be deleted: %s\n' "$subscription_name"
  fi
}

require_command az
require_command azd

if ! az account show >/dev/null 2>&1; then
  printf 'Azure CLI is not logged in. Run az login, then rerun this script.\n' >&2
  exit 1
fi

resource_group="$(azd_get_required AZURE_RESOURCE_GROUP)"
subscription_id="$(azd_get_optional AZURE_SUBSCRIPTION_ID)"
apim_name="$(azd_get_optional APIM_NAME)"

if [[ -n "$subscription_id" ]]; then
  az account set --subscription "$subscription_id"
else
  subscription_id="$(az account show --query id -o tsv)"
fi

if [[ -z "$apim_name" ]]; then
  apim_name="$(az apim list --resource-group "$resource_group" --query '[0].name' -o tsv 2>/dev/null || true)"
fi

if [[ -z "$apim_name" ]]; then
  printf 'Could not resolve the APIM service name from azd or the resource group.\n' >&2
  exit 1
fi

sku_name="$(az apim show --resource-group "$resource_group" --name "$apim_name" --query 'sku.name' -o tsv)"

if [[ "$sku_name" != "Developer" ]]; then
  printf 'APIM SKU is %s. Cleanup only runs for Developer SKU, so no action was taken.\n' "$sku_name"
  exit 0
fi

log "Developer SKU detected for APIM service $apim_name"

delete_default_product starter
delete_default_product unlimited

log "Checking for remaining default APIM subscriptions"
remaining_subscriptions="$(
  az rest \
    --method get \
    --uri "/subscriptions/${subscription_id}/resourceGroups/${resource_group}/providers/Microsoft.ApiManagement/service/${apim_name}/subscriptions?api-version=${APIM_API_VERSION}" \
    --query "value[?name != 'master'].name" \
    -o tsv
  2>/dev/null || true
)"

if [[ -z "$remaining_subscriptions" ]]; then
  printf 'No remaining subscriptions were found after preserving master.\n'
  exit 0
fi

while IFS= read -r subscription_name; do
  [[ -z "$subscription_name" ]] && continue
  delete_default_subscription "$subscription_name"
done <<< "$remaining_subscriptions"

printf '\nAPIM default cleanup completed.\n'