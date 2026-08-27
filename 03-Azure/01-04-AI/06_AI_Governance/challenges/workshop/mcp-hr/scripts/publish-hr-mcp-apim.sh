#!/usr/bin/env bash
set -euo pipefail

log() { printf '\n==> %s\n' "$1"; }
fail() { printf 'Error: %s\n' "$1" >&2; exit 1; }
warn() { printf 'Warning: %s\n' "$1" >&2; }
require_command() { command -v "$1" >/dev/null 2>&1 || fail "Required command not found: $1"; }
azd_get_optional() {
  local value
  if value="$(azd env get-value "$1" 2>/dev/null)"; then
    printf '%s' "$value"
  fi
}
first_non_empty() { local v; for v in "$@"; do [[ -n "${v:-}" ]] && { printf '%s' "$v"; return 0; }; done; return 0; }
save_azd_value() {
  local k="$1" v="$2"
  if [[ -n "$v" ]]; then
    azd env set "$k" "$v" >/dev/null
  fi
}
trim_mcp_suffix() { local url="${1%/}"; printf '%s' "${url%/mcp}"; }
truthy() { case "${1:-}" in 1|true|TRUE|True|yes|YES|Yes) return 0;; *) return 1;; esac; }

require_command az
require_command azd

if ! az account show >/dev/null 2>&1; then
  fail 'Azure CLI is not logged in. Run az login, then rerun this script.'
fi

azd_resource_group="$(azd_get_optional AZURE_RESOURCE_GROUP)"
azd_subscription_id="$(azd_get_optional AZURE_SUBSCRIPTION_ID)"
azd_tenant_id="$(azd_get_optional AZURE_TENANT_ID)"

subscription_id="$(first_non_empty "${AZURE_SUBSCRIPTION_ID:-}" "$azd_subscription_id")"
if [[ -n "$subscription_id" ]]; then
  az account set --subscription "$subscription_id"
fi

tenant_id="$(first_non_empty "${HR_MCP_TENANT_ID:-}" "$(azd_get_optional HR_MCP_TENANT_ID)" "${AZURE_TENANT_ID:-}" "$azd_tenant_id" "$(az account show --query tenantId -o tsv)")"

apim_name="$(first_non_empty "${HR_MCP_APIM_NAME:-}" "${APIM_NAME:-}" "${AZURE_APIM_NAME:-}" "$(azd_get_optional HR_MCP_APIM_NAME)" "$(azd_get_optional APIM_NAME)" "$(azd_get_optional AZURE_APIM_NAME)")"
apim_rg="$(first_non_empty "${HR_MCP_APIM_RESOURCE_GROUP:-}" "${APIM_RESOURCE_GROUP:-}" "${AZURE_APIM_RESOURCE_GROUP:-}" "$(azd_get_optional HR_MCP_APIM_RESOURCE_GROUP)" "$(azd_get_optional APIM_RESOURCE_GROUP)" "$(azd_get_optional AZURE_APIM_RESOURCE_GROUP)" "$azd_resource_group")"

if [[ -z "$apim_name" ]]; then
  if [[ -n "$apim_rg" ]]; then
    count="$(az apim list --resource-group "$apim_rg" --query 'length(@)' -o tsv 2>/dev/null || printf '0')"
    if [[ "$count" == "1" ]]; then
      apim_name="$(az apim list --resource-group "$apim_rg" --query '[0].name' -o tsv)"
      warn "APIM name was not provided; using the only APIM instance in resource group '$apim_rg': $apim_name"
    fi
  fi
  if [[ -z "$apim_name" ]]; then
    count="$(az apim list --query 'length(@)' -o tsv 2>/dev/null || printf '0')"
    if [[ "$count" == "1" ]]; then
      apim_name="$(az apim list --query '[0].name' -o tsv)"
      apim_rg="$(az apim list --query '[0].resourceGroup' -o tsv)"
      warn "APIM name was not provided; using the only APIM instance in the subscription: $apim_name"
    else
      fail 'Could not determine APIM instance. Set HR_MCP_APIM_NAME and HR_MCP_APIM_RESOURCE_GROUP, or azd env values APIM_NAME/AZURE_APIM_NAME.'
    fi
  fi
fi

if [[ -z "$apim_rg" ]] || ! az apim show --name "$apim_name" --resource-group "$apim_rg" >/dev/null 2>&1; then
  matches="$(az apim list --query "[?name=='${apim_name}']" -o json 2>/dev/null || printf '[]')"
  match_count="$(python3 -c 'import json,sys; print(len(json.load(sys.stdin)))' <<<"$matches")"
  if [[ "$match_count" == "1" ]]; then
    apim_rg="$(python3 -c 'import json,sys; print(json.load(sys.stdin)[0]["resourceGroup"])' <<<"$matches")"
    warn "Resolved APIM resource group for $apim_name: $apim_rg"
  else
    fail "APIM '$apim_name' was not found in resource group '$apim_rg'. Set HR_MCP_APIM_RESOURCE_GROUP explicitly."
  fi
fi

private_required="$(first_non_empty "${HR_MCP_APIM_REQUIRE_PRIVATE_BACKEND:-}" "$(azd_get_optional HR_MCP_APIM_REQUIRE_PRIVATE_BACKEND)")"
# Honor HR_MCP_APIM_BACKEND_BASE_URL only when it is set explicitly for THIS run. The azd-persisted
# value is intentionally NOT read here: after a teardown + redeploy the ACA managed-environment
# domain changes, and a stale persisted override would otherwise win over the freshly deployed
# HR_MCP_PRIVATE_BACKEND_URL and silently point APIM at a backend host that no longer resolves.
backend_override="${HR_MCP_APIM_BACKEND_BASE_URL:-}"
private_backend="$(first_non_empty "${HR_MCP_PRIVATE_BACKEND_URL:-}" "$(azd_get_optional HR_MCP_PRIVATE_BACKEND_URL)")"
private_backend_ip="$(first_non_empty "${HR_MCP_PRIVATE_BACKEND_IP_URL:-}" "$(azd_get_optional HR_MCP_PRIVATE_BACKEND_IP_URL)")"
backend_host_header="$(first_non_empty "${HR_MCP_APIM_BACKEND_HOST_HEADER:-}" "$(azd_get_optional HR_MCP_APIM_BACKEND_HOST_HEADER)")"
aca_internal_fqdn="$(first_non_empty "${HR_MCP_ACA_INTERNAL_FQDN:-}" "$(azd_get_optional HR_MCP_ACA_INTERNAL_FQDN)")"
direct_url="$(first_non_empty "${HR_MCP_DIRECT_URL:-}" "$(azd_get_optional HR_MCP_DIRECT_URL)")"
direct_mcp_url="$(first_non_empty "${HR_MCP_DIRECT_MCP_URL:-}" "$(azd_get_optional HR_MCP_DIRECT_MCP_URL)")"

if [[ -z "$private_backend" && -n "$aca_internal_fqdn" ]]; then
  private_backend="https://${aca_internal_fqdn}"
fi

# Prefer the HTTPS FQDN backend ($private_backend) over the HTTP IP backend ($private_backend_ip).
# The ACA internal load balancer has allowInsecure=false, so an http:// IP backend triggers a
# 301 redirect to https://<internal-fqdn>, which clients cannot resolve. HTTPS to the FQDN also
# provides the correct SNI for ACA ingress routing.
if truthy "$private_required"; then
  backend_base_url="$(first_non_empty "$backend_override" "$private_backend" "$private_backend_ip")"
  [[ -n "$backend_base_url" ]] || fail 'Private APIM-to-ACA backend was requested. Set HR_MCP_PRIVATE_BACKEND_URL or HR_MCP_APIM_BACKEND_BASE_URL after VNet/DNS routing is ready.'
else
  backend_base_url="$(first_non_empty "$backend_override" "$private_backend" "$private_backend_ip" "$direct_url" "$(trim_mcp_suffix "$direct_mcp_url")")"
fi
backend_base_url="$(trim_mcp_suffix "$backend_base_url")"
[[ -n "$backend_base_url" ]] || fail 'Could not determine HR MCP backend base URL. Set HR_MCP_DIRECT_URL, HR_MCP_DIRECT_MCP_URL, or HR_MCP_APIM_BACKEND_BASE_URL.'
backend_host="$(printf '%s' "$backend_base_url" | sed -E 's#^[a-zA-Z]+://##; s#/.*$##')"
if [[ "$backend_host" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  # IP backend: APIM must send the ACA internal FQDN as the Host header for ingress routing.
  if [[ -z "$backend_host_header" ]]; then
    backend_host_header="$(first_non_empty "$aca_internal_fqdn" "$(azd_get_optional HR_MCP_ACA_INTERNAL_FQDN)")"
  fi
else
  # FQDN backend: always tie the Host header to the chosen backend host so a stale persisted
  # HR_MCP_APIM_BACKEND_HOST_HEADER can never disagree with the backend URL after a redeploy.
  backend_host_header="$backend_host"
fi

audience="$(first_non_empty "${HR_MCP_AUDIENCE:-}" "$(azd_get_optional HR_MCP_AUDIENCE)")"
scope="$(first_non_empty "${HR_MCP_SCOPE:-}" "$(azd_get_optional HR_MCP_SCOPE)")"
required_scope="$(first_non_empty "${HR_MCP_REQUIRED_SCOPE_CLAIM:-}" "$(azd_get_optional HR_MCP_REQUIRED_SCOPE_CLAIM)")"
if [[ -z "$required_scope" && -n "$scope" ]]; then
  required_scope="${scope##*/}"
fi
[[ -n "$tenant_id" ]] || fail 'HR_MCP_TENANT_ID is missing.'
[[ -n "$audience" ]] || fail 'HR_MCP_AUDIENCE is missing. Run deploy-hr-mcp first or set it explicitly.'
[[ -n "$required_scope" ]] || fail 'HR_MCP_SCOPE is missing. Run deploy-hr-mcp first or set HR_MCP_REQUIRED_SCOPE_CLAIM.'
required_role="$(first_non_empty "${HR_MCP_APP_ROLE_VALUE:-}" "$(azd_get_optional HR_MCP_APP_ROLE_VALUE)" 'Mcp.Invoke')"

api_name="$(first_non_empty "${HR_MCP_APIM_API_NAME:-}" "$(azd_get_optional HR_MCP_APIM_API_NAME)" 'hr-mcp-api')"
api_path="$(first_non_empty "${HR_MCP_APIM_PATH:-}" "$(azd_get_optional HR_MCP_APIM_PATH)" 'hr-mcp')"
backend_name="$(first_non_empty "${HR_MCP_APIM_BACKEND_NAME:-}" "$(azd_get_optional HR_MCP_APIM_BACKEND_NAME)" 'hr-mcp-aca-backend')"
product_id="$(first_non_empty "${HR_MCP_APIM_PRODUCT_ID:-}" "$(azd_get_optional HR_MCP_APIM_PRODUCT_ID)" 'MCP-HR-Tools-DEV')"
subscription_name="$(first_non_empty "${HR_MCP_APIM_SUBSCRIPTION_NAME:-}" "$(azd_get_optional HR_MCP_APIM_SUBSCRIPTION_NAME)" 'MCP-HR-Tools-DEV-SUB-01')"

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
infra_dir="$(cd -- "${script_dir}/../infra" && pwd)"

gateway_url="$(az apim show --name "$apim_name" --resource-group "$apim_rg" --query gatewayUrl -o tsv)"
mcp_url="${gateway_url%/}/${api_path}/mcp"

log 'Publishing HR MCP API, backend, product, policy, and subscription to APIM'
az deployment group create \
  --name 'publish-hr-mcp-apim' \
  --resource-group "$apim_rg" \
  --template-file "${infra_dir}/main.bicep" \
  --parameters \
    apimName="$apim_name" \
    apiName="$api_name" \
    apiPath="$api_path" \
    backendName="$backend_name" \
    backendBaseUrl="$backend_base_url" \
    backendHostHeader="$backend_host_header" \
    productId="$product_id" \
    subscriptionName="$subscription_name" \
    tenantId="$tenant_id" \
    jwtAudience="$audience" \
    requiredScope="$required_scope" \
    requiredRole="$required_role" \
  --only-show-errors \
  -o none

log 'Saving HR MCP APIM outputs to azd environment'
save_azd_value HR_MCP_APIM_NAME "$apim_name"
save_azd_value HR_MCP_APIM_RESOURCE_GROUP "$apim_rg"
save_azd_value HR_MCP_APIM_API_NAME "$api_name"
save_azd_value HR_MCP_APIM_PATH "$api_path"
save_azd_value HR_MCP_APIM_MCP_URL "$mcp_url"
save_azd_value HR_MCP_APIM_PRODUCT_ID "$product_id"
save_azd_value HR_MCP_APIM_SUBSCRIPTION_NAME "$subscription_name"
save_azd_value HR_MCP_APIM_BACKEND_NAME "$backend_name"
save_azd_value HR_MCP_APIM_BACKEND_BASE_URL "$backend_base_url"
save_azd_value HR_MCP_APIM_BACKEND_HOST_HEADER "$backend_host_header"

cat <<EOF

HR MCP APIM publication is ready.
APIM: $apim_name ($apim_rg)
Backend base URL: $backend_base_url
Backend Host header: $backend_host_header
MCP endpoint: $mcp_url
Product: $product_id
Subscription: $subscription_name

Use the APIM subscription key plus Authorization: Bearer <Entra token> when calling the APIM MCP endpoint.

Smoke test from the repository root:
  cd workshop && uv run python ./mcp-hr/scripts/test-hr-mcp-apim.py

If automatic subscription-key retrieval is unavailable, set it without printing it:
  export HR_MCP_APIM_SUBSCRIPTION_KEY="\$(az apim subscription show --resource-group "$apim_rg" --service-name "$apim_name" --sid "$subscription_name" --query primaryKey -o tsv)"
  cd workshop && uv run python ./mcp-hr/scripts/test-hr-mcp-apim.py
EOF
