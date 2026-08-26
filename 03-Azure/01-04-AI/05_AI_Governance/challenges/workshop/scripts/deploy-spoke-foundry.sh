#!/usr/bin/env bash
set -euo pipefail

# Silence a known Azure CLI Python SyntaxWarning from an upstream dependency.
export PYTHONWARNINGS="${PYTHONWARNINGS:+$PYTHONWARNINGS,}ignore::SyntaxWarning"

AI_PROJECT_MANAGER_ROLE_ID="eadc314b-1a2d-4efa-be10-5d325db5065e"
KEY_VAULT_SECRETS_USER_ROLE_ID="4633458b-17de-408a-b874-0445c86b69e6"
ACR_PULL_ROLE_ID="7f951dda-4ed3-4680-a7ca-43fe172d538d"
FOUNDRY_APPINSIGHTS_CONNECTION_API_VERSION="2025-06-01"
SECURITY_CONTROL_TAG="SecurityControl=Ignore"
spoke_suffix="${SPOKE_SUFFIX:-}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -s|--spoke-suffix)
      if [[ $# -lt 2 ]]; then
        printf 'Missing value for %s\n' "$1" >&2
        exit 1
      fi
      spoke_suffix="$2"
      shift 2
      ;;
    --spoke-suffix=*)
      spoke_suffix="${1#*=}"
      shift
      ;;
    *)
      if [[ -z "$spoke_suffix" ]]; then
        spoke_suffix="$1"
        shift
      else
        printf 'Unknown argument: %s\n' "$1" >&2
        exit 1
      fi
      ;;
  esac
done

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
    printf 'Required azd environment value is missing: %s\nRun azd up/provision first, then rerun this script.\n' "$key" >&2
    exit 1
  fi
  printf '%s' "$value"
}

azd_get_optional() {
  azd env get-value "$1" 2>/dev/null || true
}

safe_name_part() {
  local value="$1"
  value="$(printf '%s' "$value" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]/-/g; s/--*/-/g; s/^-*//; s/-*$//')"
  if [[ -z "$value" ]]; then
    value="citadel"
  fi
  printf '%s' "$value"
}

compact_name_part() {
  local value="$1"
  value="$(printf '%s' "$value" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]//g')"
  if [[ -z "$value" ]]; then
    value="citadel"
  fi
  printf '%s' "$value"
}

trim_trailing_hyphen() {
  sed 's/-*$//'
}

assign_role_if_missing() {
  local principal_id="$1"
  local principal_type="$2"
  local role_id="$3"
  local role_name="$4"
  local scope="$5"

  local assignment_id
  assignment_id="$(az role assignment list \
    --assignee-object-id "$principal_id" \
    --role "$role_id" \
    --scope "$scope" \
    --all \
    --fill-principal-name false \
    --fill-role-definition-name false \
    --query '[0].id' \
    -o tsv 2>/dev/null || true)"

  if [[ -n "$assignment_id" ]]; then
    printf 'Role assignment already exists: %s\n' "$role_name"
    return
  fi

  az role assignment create \
    --assignee-object-id "$principal_id" \
    --assignee-principal-type "$principal_type" \
    --role "$role_id" \
    --scope "$scope" \
    --only-show-errors \
    -o none
  printf 'Assigned role: %s\n' "$role_name"
}

tag_resource_ignore() {
  local resource_id="$1"

  if [[ -z "$resource_id" ]]; then
    return
  fi

  az tag update \
    --resource-id "$resource_id" \
    --operation Merge \
    --tags "$SECURITY_CONTROL_TAG" \
    --only-show-errors \
    -o none
}

require_command az
require_command azd

if ! az account show >/dev/null 2>&1; then
  printf 'Azure CLI is not logged in. Run az login, then rerun this script.\n' >&2
  exit 1
fi

if ! az cognitiveservices account project -h >/dev/null 2>&1; then
  printf 'This Azure CLI does not include az cognitiveservices account project. Update Azure CLI and rerun this script.\n' >&2
  exit 1
fi

governance_rg="$(azd_get_required AZURE_RESOURCE_GROUP)"
location="$(azd_get_required AZURE_LOCATION)"
azd_env_name="$(azd_get_optional AZURE_ENV_NAME)"
subscription_id="$(azd_get_optional AZURE_SUBSCRIPTION_ID)"

if [[ -n "$subscription_id" ]]; then
  az account set --subscription "$subscription_id"
else
  subscription_id="$(az account show --query id -o tsv)"
fi

base_name_seed="$(safe_name_part "${azd_env_name:-$governance_rg}")"
base_compact_seed="$(compact_name_part "${azd_env_name:-$governance_rg}")"

if [[ -n "$spoke_suffix" ]]; then
  spoke_suffix_name="$(safe_name_part "$spoke_suffix")"
  spoke_suffix_compact="$(compact_name_part "$spoke_suffix")"
  name_seed="${base_name_seed}-spoke-${spoke_suffix_name}"
  compact_seed="${base_compact_seed}spoke${spoke_suffix_compact}"
  default_spoke_resource_group_name="${governance_rg}-spoke-${spoke_suffix_name}"
else
  name_seed="$base_name_seed"
  compact_seed="$base_compact_seed"
  default_spoke_resource_group_name="${governance_rg}-spoke"
fi

spoke_resource_group_name="${SPOKE_RESOURCE_GROUP_NAME:-$default_spoke_resource_group_name}"
subscription_suffix="$(printf '%s' "$subscription_id" | tr -d '-' | cut -c1-8)"

default_foundry_name="$(printf 'aif-%s-%s' "$name_seed" "$subscription_suffix" | cut -c1-64 | trim_trailing_hyphen)"
default_log_analytics_name="$(printf 'law-%s-%s' "$name_seed" "$subscription_suffix" | cut -c1-63 | trim_trailing_hyphen)"
default_app_insights_name="$(printf 'appi-%s-%s' "$name_seed" "$subscription_suffix" | cut -c1-255 | trim_trailing_hyphen)"
default_key_vault_name="$(printf 'kv%s%s' "$compact_seed" "$subscription_suffix" | cut -c1-24)"

foundry_account_name="${FOUNDRY_ACCOUNT_NAME:-$default_foundry_name}"
foundry_project_name="${FOUNDRY_PROJECT_NAME:-citadel-agents-project}"
log_analytics_workspace_name="${SPOKE_LOG_ANALYTICS_NAME:-$default_log_analytics_name}"
app_insights_name="${SPOKE_APP_INSIGHTS_NAME:-$default_app_insights_name}"
foundry_appinsights_connection_name="${SPOKE_AI_FOUNDRY_APPINSIGHTS_CONNECTION_NAME:-appinsights-connection}"
key_vault_name="${KEY_VAULT_NAME:-$default_key_vault_name}"
key_vault_enable_purge_protection="${KEY_VAULT_ENABLE_PURGE_PROTECTION:-false}"
current_user_object_id="$(az ad signed-in-user show --query id -o tsv 2>/dev/null || true)"

if [[ -z "$current_user_object_id" ]]; then
  printf 'Could not resolve the signed-in user object ID. This script expects an interactive user login.\n' >&2
  exit 1
fi

log "Creating spoke resource group"
az group create \
  --name "$spoke_resource_group_name" \
  --location "$location" \
  --tags "azd-env-name=${azd_env_name:-unknown}" "workload=citadel-spoke" \
  -o none

log "Creating Azure AI Foundry account"
if ! az cognitiveservices account show --name "$foundry_account_name" --resource-group "$spoke_resource_group_name" >/dev/null 2>&1; then
  az cognitiveservices account create \
    --name "$foundry_account_name" \
    --resource-group "$spoke_resource_group_name" \
    --location "$location" \
    --kind AIServices \
    --sku S0 \
    --assign-identity \
    --custom-domain "$foundry_account_name" \
    --allow-project-management true \
    --yes \
    --tags "azd-env-name=${azd_env_name:-unknown}" "workload=citadel-spoke" "$SECURITY_CONTROL_TAG" \
    -o none
else
  printf 'Foundry account already exists: %s\n' "$foundry_account_name"
fi

foundry_account_id="$(az cognitiveservices account show \
  --name "$foundry_account_name" \
  --resource-group "$spoke_resource_group_name" \
  --query id \
  -o tsv)"
tag_resource_ignore "$foundry_account_id"

az rest \
  --method patch \
  --uri "https://management.azure.com${foundry_account_id}?api-version=2025-06-01" \
  --headers 'Content-Type=application/json' \
  --body '{"properties":{"allowProjectManagement":true,"disableLocalAuth":true,"publicNetworkAccess":"Enabled","networkAcls":{"defaultAction":"Allow","ipRules":[],"virtualNetworkRules":[]}}}' \
  -o none

log "Creating Azure AI Foundry project"
if ! az cognitiveservices account project show \
  --name "$foundry_account_name" \
  --resource-group "$spoke_resource_group_name" \
  --project-name "$foundry_project_name" >/dev/null 2>&1; then
  az cognitiveservices account project create \
    --name "$foundry_account_name" \
    --resource-group "$spoke_resource_group_name" \
    --project-name "$foundry_project_name" \
    --location "$location" \
    --assign-identity \
    --display-name "$foundry_project_name" \
    --description 'Citadel workshop project for Foundry Agents.' \
    -o none
else
  printf 'Foundry project already exists: %s\n' "$foundry_project_name"
fi

project_resource_id="/subscriptions/${subscription_id}/resourceGroups/${spoke_resource_group_name}/providers/Microsoft.CognitiveServices/accounts/${foundry_account_name}/projects/${foundry_project_name}"
tag_resource_ignore "$project_resource_id"

log "Ensuring Application Insights CLI extension"
az extension add --name application-insights --upgrade --only-show-errors >/dev/null

log "Creating Log Analytics workspace"
if ! az monitor log-analytics workspace show \
  --resource-group "$spoke_resource_group_name" \
  --workspace-name "$log_analytics_workspace_name" >/dev/null 2>&1; then
  az monitor log-analytics workspace create \
    --resource-group "$spoke_resource_group_name" \
    --workspace-name "$log_analytics_workspace_name" \
    --location "$location" \
    --sku PerGB2018 \
    --tags "azd-env-name=${azd_env_name:-unknown}" "workload=citadel-spoke" \
    -o none
else
  printf 'Log Analytics workspace already exists: %s\n' "$log_analytics_workspace_name"
fi

log_analytics_workspace_id="$(az monitor log-analytics workspace show \
  --resource-group "$spoke_resource_group_name" \
  --workspace-name "$log_analytics_workspace_name" \
  --query id \
  -o tsv)"

log "Creating Application Insights"
if ! az monitor app-insights component show \
  --app "$app_insights_name" \
  --resource-group "$spoke_resource_group_name" >/dev/null 2>&1; then
  az monitor app-insights component create \
    --app "$app_insights_name" \
    --location "$location" \
    --resource-group "$spoke_resource_group_name" \
    --workspace "$log_analytics_workspace_id" \
    --kind web \
    --application-type web \
    --tags "azd-env-name=${azd_env_name:-unknown}" "workload=citadel-spoke" \
    -o none
else
  printf 'Application Insights already exists: %s\n' "$app_insights_name"
fi

app_insights_id="$(az monitor app-insights component show \
  --app "$app_insights_name" \
  --resource-group "$spoke_resource_group_name" \
  --query id \
  -o tsv)"

app_insights_connection_string="$(az monitor app-insights component show \
  --app "$app_insights_name" \
  --resource-group "$spoke_resource_group_name" \
  --query connectionString \
  -o tsv)"

connection_body_file="$(mktemp)"
trap 'rm -f "$connection_body_file"' EXIT
cat >"$connection_body_file" <<EOF
{
  "properties": {
    "category": "AppInsights",
    "target": "${app_insights_id}",
    "authType": "ApiKey",
    "credentials": {
      "key": "${app_insights_connection_string}"
    },
    "metadata": {
      "ApiType": "Azure",
      "ResourceId": "${app_insights_id}"
    },
    "isSharedToAll": true
  }
}
EOF

log "Connecting Application Insights to Azure AI Foundry project"
# The cognitiveservices project connection wrapper currently rejects a valid
# App Insights payload, so use the ARM resource endpoint directly.
az rest \
  --method PUT \
  --url "https://management.azure.com${project_resource_id}/connections/${foundry_appinsights_connection_name}?api-version=${FOUNDRY_APPINSIGHTS_CONNECTION_API_VERSION}" \
  --body "@${connection_body_file}" \
  -o none

log "Creating Key Vault"
if ! az keyvault show --name "$key_vault_name" --resource-group "$spoke_resource_group_name" >/dev/null 2>&1; then
  key_vault_create_args=(
    --name "$key_vault_name" \
    --resource-group "$spoke_resource_group_name" \
    --location "$location" \
    --sku standard \
    --enable-rbac-authorization true \
    --public-network-access Enabled \
    --default-action Allow \
    --bypass AzureServices \
    --tags "azd-env-name=${azd_env_name:-unknown}" "workload=citadel-spoke" \
    -o none
  )
  case "$key_vault_enable_purge_protection" in
    true|TRUE|True)
      key_vault_create_args+=(--enable-purge-protection true)
      ;;
  esac
  az keyvault create "${key_vault_create_args[@]}"
else
  printf 'Key Vault already exists: %s\n' "$key_vault_name"
fi

existing_key_vault_purge_protection="$(az keyvault show \
  --name "$key_vault_name" \
  --resource-group "$spoke_resource_group_name" \
  --query 'properties.enablePurgeProtection' \
  -o tsv)"

if [[ "$existing_key_vault_purge_protection" == "true" ]]; then
  printf 'Warning: Key Vault purge protection is enabled and cannot be disabled. Immediate purge will not be available for this vault.\n' >&2
fi

key_vault_id="$(az keyvault show \
  --name "$key_vault_name" \
  --resource-group "$spoke_resource_group_name" \
  --query id \
  -o tsv)"
tag_resource_ignore "$key_vault_id"

log "Assigning RBAC roles to the signed-in user"
assign_role_if_missing "$current_user_object_id" User "$AI_PROJECT_MANAGER_ROLE_ID" "Azure AI Project Manager" "$foundry_account_id"
assign_role_if_missing "$current_user_object_id" User "$KEY_VAULT_SECRETS_USER_ROLE_ID" "Key Vault Secrets User" "$key_vault_id"

# --- Azure Container Registry ---

acr_name="${SPOKE_ACR_NAME:-$(printf 'acr%s%s' "$compact_seed" "$subscription_suffix" | sed 's/[^a-zA-Z0-9]//g' | cut -c1-50)}"

log "Creating Azure Container Registry"
if ! az acr show --name "$acr_name" --resource-group "$spoke_resource_group_name" >/dev/null 2>&1; then
  az acr create \
    --name "$acr_name" \
    --resource-group "$spoke_resource_group_name" \
    --location "$location" \
    --sku Basic \
    --admin-enabled false \
    --tags "azd-env-name=${azd_env_name:-unknown}" "workload=citadel-spoke" "$SECURITY_CONTROL_TAG" \
    -o none
else
  printf 'Container Registry already exists: %s\n' "$acr_name"
fi

acr_id="$(az acr show \
  --name "$acr_name" \
  --resource-group "$spoke_resource_group_name" \
  --query id \
  -o tsv)"

acr_login_server="$(az acr show \
  --name "$acr_name" \
  --resource-group "$spoke_resource_group_name" \
  --query loginServer \
  -o tsv)"

log "Assigning AcrPull to Foundry project managed identity"
foundry_project_mi_object_id="$(az cognitiveservices account project show \
  --name "$foundry_account_name" \
  --resource-group "$spoke_resource_group_name" \
  --project-name "$foundry_project_name" \
  --query 'identity.principalId' \
  -o tsv 2>/dev/null || true)"

if [[ -n "$foundry_project_mi_object_id" ]]; then
  assign_role_if_missing "$foundry_project_mi_object_id" ServicePrincipal "$ACR_PULL_ROLE_ID" "AcrPull (Foundry project MI)" "$acr_id"
else
  printf 'Warning: Could not resolve Foundry project managed identity. AcrPull role assignment skipped.\n' >&2
fi

log "Saving spoke resource values to azd environment"
azd env set SPOKE_RESOURCE_GROUP "$spoke_resource_group_name" >/dev/null
azd env set SPOKE_AI_FOUNDRY_ACCOUNT_NAME "$foundry_account_name" >/dev/null
azd env set SPOKE_AI_FOUNDRY_PROJECT_NAME "$foundry_project_name" >/dev/null
azd env set SPOKE_LOG_ANALYTICS_NAME "$log_analytics_workspace_name" >/dev/null
azd env set SPOKE_APP_INSIGHTS_NAME "$app_insights_name" >/dev/null
azd env set SPOKE_APP_INSIGHTS_ID "$app_insights_id" >/dev/null
azd env set SPOKE_AI_FOUNDRY_APPINSIGHTS_CONNECTION_NAME "$foundry_appinsights_connection_name" >/dev/null
azd env set SPOKE_KEY_VAULT_NAME "$key_vault_name" >/dev/null
azd env set SPOKE_ACR_NAME "$acr_name" >/dev/null
azd env set SPOKE_ACR_LOGIN_SERVER "$acr_login_server" >/dev/null

cat <<EOF

Spoke resources are ready.
Resource group: $spoke_resource_group_name
Foundry account: $foundry_account_name
Foundry project: $foundry_project_name
Log Analytics workspace: $log_analytics_workspace_name
Application Insights: $app_insights_name
Foundry App Insights connection: $foundry_appinsights_connection_name
Key Vault: $key_vault_name
Container Registry: $acr_name ($acr_login_server)

After deleting these resources, purge soft-deleted names with:
az cognitiveservices account purge --name "$foundry_account_name" --resource-group "$spoke_resource_group_name" --location "$location"
az keyvault purge --name "$key_vault_name" --location "$location"
EOF
