#!/usr/bin/env bash
set -euo pipefail

# Deploys the workshop HR MCP server to Azure Container Apps using only Azure CLI,
# Azure Developer CLI environment values, and ACR remote builds. Local Docker is not required.

export PYTHONWARNINGS="${PYTHONWARNINGS:+$PYTHONWARNINGS,}ignore"
export AZURE_CORE_ONLY_SHOW_ERRORS="${AZURE_CORE_ONLY_SHOW_ERRORS:-True}"

ACR_PULL_ROLE_ID="7f951dda-4ed3-4680-a7ca-43fe172d538d"
AZURE_CLI_CLIENT_ID="04b07795-8ddb-461a-bbee-02f9e1bf7b46"
SECURITY_CONTROL_TAG="SecurityControl=Ignore"
DEFAULT_SCOPE_VALUE="Mcp.Access"
DEFAULT_APP_ROLE_VALUE="Mcp.Invoke"

log() {
  printf '\n==> %s\n' "$1"
}

warn() {
  printf 'Warning: %s\n' "$1" >&2
}

fail() {
  printf 'Error: %s\n' "$1" >&2
  exit 1
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    fail "Required command not found: $1"
  fi
}

azd_get_optional() {
  local value
  if value="$(azd env get-value "$1" 2>/dev/null)"; then
    printf '%s' "$value"
  fi
}

first_non_empty() {
  local value
  for value in "$@"; do
    if [[ -n "${value:-}" ]]; then
      printf '%s' "$value"
      return 0
    fi
  done
  return 0
}

safe_name_part() {
  local value="$1"
  value="$(printf '%s' "$value" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]/-/g; s/--*/-/g; s/^-*//; s/-*$//')"
  if [[ -z "$value" ]]; then
    value="hr-mcp"
  fi
  printf '%s' "$value"
}

compact_name_part() {
  local value="$1"
  value="$(printf '%s' "$value" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]//g')"
  if [[ -z "$value" ]]; then
    value="hrmcp"
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
    --scope "$scope" \
    --fill-principal-name false \
    --fill-role-definition-name false \
    --query "[?principalId=='${principal_id}' && contains(roleDefinitionId, '${role_id}')].id | [0]" \
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

wait_for_role_assignment() {
  local principal_id="$1"
  local role_id="$2"
  local scope="$3"
  local role_name="$4"
  local max_retries="${5:-5}"
  local sleep_seconds="${6:-30}"
  local role

  for i in $(seq 1 "$max_retries"); do
    role="$(az role assignment list \
      --scope "$scope" \
      --fill-principal-name false \
      --fill-role-definition-name false \
      --query "[?principalId=='${principal_id}' && contains(roleDefinitionId, '${role_id}')].id | [0]" \
      -o tsv 2>/dev/null || true)"
    if [[ -n "$role" ]]; then
      printf '%s role assignment is visible.\n' "$role_name"
      return 0
    fi
    printf '%s role assignment not visible yet (attempt %s/%s); waiting %ss...\n' "$role_name" "$i" "$max_retries" "$sleep_seconds"
    sleep "$sleep_seconds"
  done

  warn "$role_name role assignment did not become visible after waiting. Continuing because role assignment creation succeeded; if image pull fails, wait a few minutes and rerun the script."
  return 0
}

ensure_extension() {
  local name="$1"
  log "Ensuring Azure CLI extension: $name"
  az extension add --name "$name" --upgrade --only-show-errors >/dev/null
}

# Import the container base image into the target ACR so remote builds do not
# pull from a public registry on every build. The image bundles Python 3.13 and
# uv and is hosted on GHCR, which is not subject to Docker Hub's anonymous
# pull-rate limit. Sets HR_MCP_BASE_IMAGE_REF; falls back to the public ref.
ensure_acr_base_images() {
  local acr="$1"
  local acr_login="$2"
  local source_ref="ghcr.io/astral-sh/uv:python3.13-bookworm-slim"
  local target_repo="astral-sh/uv-python:3.13-bookworm-slim"
  HR_MCP_BASE_IMAGE_REF="$source_ref"
  [[ -n "$acr_login" ]] || return 0

  if az acr import --name "$acr" --source "$source_ref" --image "$target_repo" --force --only-show-errors -o none 2>/dev/null; then
    HR_MCP_BASE_IMAGE_REF="${acr_login}/${target_repo}"
  else
    warn "Could not import ${source_ref} into ${acr}; building from GHCR directly."
  fi
}

ensure_private_dns_a_record() {
  local zone_rg="$1"
  local zone_name="$2"
  local record_name="$3"
  local ip="$4"
  local existing

  if ! az network private-dns record-set a show \
    --resource-group "$zone_rg" \
    --zone-name "$zone_name" \
    --name "$record_name" >/dev/null 2>&1; then
    az network private-dns record-set a create \
      --resource-group "$zone_rg" \
      --zone-name "$zone_name" \
      --name "$record_name" \
      --ttl 30 \
      --only-show-errors \
      -o none >/dev/null
  fi

  existing="$(az network private-dns record-set a show \
    --resource-group "$zone_rg" \
    --zone-name "$zone_name" \
    --name "$record_name" \
    --query "aRecords[?ipv4Address=='${ip}'].ipv4Address | [0]" \
    -o tsv 2>/dev/null || true)"
  if [[ -z "$existing" ]]; then
    az network private-dns record-set a add-record \
      --resource-group "$zone_rg" \
      --zone-name "$zone_name" \
      --record-set-name "$record_name" \
      --ipv4-address "$ip" \
      --only-show-errors \
      -o none
  fi
}

ensure_private_aca_dns() {
  local zone_rg="$1"
  local vnet_id="$2"
  local default_domain="$3"
  local static_ip="$4"
  local link_name

  [[ -n "$default_domain" ]] || fail 'Private Container Apps environment defaultDomain is missing; cannot configure private DNS.'
  [[ -n "$static_ip" ]] || fail 'Private Container Apps environment staticIp is missing; cannot configure private DNS.'

  log "Configuring private DNS for internal ACA domain: $default_domain"
  if ! az network private-dns zone show \
    --resource-group "$zone_rg" \
    --name "$default_domain" >/dev/null 2>&1; then
    az network private-dns zone create \
      --resource-group "$zone_rg" \
      --name "$default_domain" \
      --only-show-errors \
      -o none >/dev/null
  fi

  link_name="lnk-hr-mcp-aca"
  if ! az network private-dns link vnet show \
    --resource-group "$zone_rg" \
    --zone-name "$default_domain" \
    --name "$link_name" >/dev/null 2>&1; then
    az network private-dns link vnet create \
      --resource-group "$zone_rg" \
      --zone-name "$default_domain" \
      --name "$link_name" \
      --virtual-network "$vnet_id" \
      --registration-enabled false \
      --only-show-errors \
      -o none
  fi

  ensure_private_dns_a_record "$zone_rg" "$default_domain" "*" "$static_ip"
  ensure_private_dns_a_record "$zone_rg" "$default_domain" "*.internal" "$static_ip"
}

prefix_inside_any_vnet_prefix() {
  local requested_prefix="$1"
  shift
  python3 - "$requested_prefix" "$@" <<'PY'
import ipaddress
import sys

requested = ipaddress.ip_network(sys.argv[1], strict=False)
for prefix in sys.argv[2:]:
    if requested.subnet_of(ipaddress.ip_network(prefix, strict=False)):
        raise SystemExit(0)
raise SystemExit(1)
PY
}

resolve_available_subnet_prefix() {
  local hub_rg="$1"
  local vnet_name="$2"
  local prefix_length="$3"

  python3 - "$prefix_length" \
    "$(az network vnet show \
      --resource-group "$hub_rg" \
      --name "$vnet_name" \
      --query '{addressPrefixes:addressSpace.addressPrefixes,subnetPrefixes:subnets[].addressPrefix}' \
      -o json)" <<'PY'
import ipaddress
import json
import sys

prefix_length = int(sys.argv[1])
data = json.loads(sys.argv[2])
vnet_prefixes = [ipaddress.ip_network(p, strict=False) for p in data.get("addressPrefixes", [])]
used = [ipaddress.ip_network(p, strict=False) for p in data.get("subnetPrefixes", []) if p]

for parent in sorted(vnet_prefixes, key=lambda n: (n.version, int(n.network_address), n.prefixlen)):
    if parent.version != 4 or parent.prefixlen > prefix_length:
        continue
    for candidate in parent.subnets(new_prefix=prefix_length):
        if all(not candidate.overlaps(existing) for existing in used):
            print(candidate)
            raise SystemExit(0)

raise SystemExit(1)
PY
}

# Computes how to expand the VNet when no free subnet exists inside the current
# address space. It walks forward from the end of the highest existing VNet prefix
# and returns TWO space-separated values:
#   1. a new VNet address prefix to ADD (sized to match the existing VNet block, so
#      addressing stays consistent, e.g. extend 10.170.0.0/24 -> add 10.170.1.0/24)
#   2. the subnet prefix to carve from it (e.g. 10.170.1.0/26)
# Both are private, aligned, and non-overlapping with existing prefixes/subnets.
# The supernet block size defaults to the largest existing VNet block and can be
# overridden with HR_MCP_ACA_EXPAND_PREFIX_LENGTH.
compute_expansion_subnet_prefix() {
  local hub_rg="$1"
  local vnet_name="$2"
  local prefix_length="$3"
  local supernet_length="${4:-}"

  python3 - "$prefix_length" "$supernet_length" \
    "$(az network vnet show \
      --resource-group "$hub_rg" \
      --name "$vnet_name" \
      --query '{addressPrefixes:addressSpace.addressPrefixes,subnetPrefixes:subnets[].addressPrefix}' \
      -o json)" <<'PY'
import ipaddress
import json
import sys

prefix_length = int(sys.argv[1])
supernet_arg = sys.argv[2].strip()
data = json.loads(sys.argv[3])
vnet_prefixes = [ipaddress.ip_network(p, strict=False) for p in data.get("addressPrefixes", []) if p]
subnet_prefixes = [ipaddress.ip_network(p, strict=False) for p in data.get("subnetPrefixes", []) if p]

ipv4_vnet = [n for n in vnet_prefixes if n.version == 4]
if not ipv4_vnet:
    raise SystemExit(1)

# Size the new VNet address prefix to match the existing block style so addressing
# stays consistent (e.g. a /24 VNet is extended with another /24). Never larger
# (numerically smaller) than the subnet prefix length we need to carve.
if supernet_arg:
    supernet_length = int(supernet_arg)
else:
    supernet_length = min(n.prefixlen for n in ipv4_vnet)
supernet_length = min(supernet_length, prefix_length)

block = 1 << (32 - supernet_length)
max_end = max(int(n.broadcast_address) for n in ipv4_vnet)
# Align the first candidate up to the next /<supernet_length> boundary past existing space.
candidate_int = ((max_end + 1 + block - 1) // block) * block

# Bound the search so we never loop unexpectedly; 4096 blocks is far more than needed.
for _ in range(4096):
    if candidate_int + block - 1 > 0xFFFFFFFF:
        break
    vnet_block = ipaddress.ip_network((candidate_int, supernet_length))
    if vnet_block.is_private and \
       all(not vnet_block.overlaps(n) for n in vnet_prefixes) and \
       all(not vnet_block.overlaps(s) for s in subnet_prefixes):
        subnet = next(vnet_block.subnets(new_prefix=prefix_length))
        print(vnet_block, subnet)
        raise SystemExit(0)
    candidate_int += block

raise SystemExit(1)
PY
}

# Given an explicit subnet prefix that falls OUTSIDE the current VNet address space,
# returns the aligned address-space block (sized to the existing VNet block style) that
# contains it and can be added to the VNet, e.g. subnet 10.170.1.0/26 -> add 10.170.1.0/24.
# The block must be private and not overlap any existing VNet prefix or subnet.
compute_expansion_vnet_prefix_for_subnet() {
  local hub_rg="$1"
  local vnet_name="$2"
  local subnet_prefix="$3"
  local supernet_length="${4:-}"

  python3 - "$subnet_prefix" "$supernet_length" \
    "$(az network vnet show \
      --resource-group "$hub_rg" \
      --name "$vnet_name" \
      --query '{addressPrefixes:addressSpace.addressPrefixes,subnetPrefixes:subnets[].addressPrefix}' \
      -o json)" <<'PY'
import ipaddress
import json
import sys

subnet = ipaddress.ip_network(sys.argv[1], strict=False)
supernet_arg = sys.argv[2].strip()
data = json.loads(sys.argv[3])
vnet_prefixes = [ipaddress.ip_network(p, strict=False) for p in data.get("addressPrefixes", []) if p]
subnet_prefixes = [ipaddress.ip_network(p, strict=False) for p in data.get("subnetPrefixes", []) if p]

if subnet.version != 4:
    raise SystemExit(1)

ipv4_vnet = [n for n in vnet_prefixes if n.version == 4]
if supernet_arg:
    supernet_length = int(supernet_arg)
elif ipv4_vnet:
    supernet_length = min(n.prefixlen for n in ipv4_vnet)
else:
    supernet_length = subnet.prefixlen
supernet_length = min(supernet_length, subnet.prefixlen)

block = subnet.supernet(new_prefix=supernet_length)

if not block.is_private:
    raise SystemExit(1)
if any(block.overlaps(n) for n in vnet_prefixes):
    raise SystemExit(1)
if any(block.overlaps(s) for s in subnet_prefixes):
    raise SystemExit(1)

print(block)
raise SystemExit(0)
PY
}

resolve_citadel_aca_subnet() {
  local hub_rg="$1"
  local requested_vnet="$2"
  local requested_subnet="$3"
  local requested_subnet_id="$4"
  local requested_prefix="$5"
  local prefix_length="$6"
  local vnet_count delegation subnet_id
  local needs_expansion=0
  local vnet_prefixes=()
  local expansion_vnet_prefix=""

  if [[ -n "$requested_subnet_id" ]]; then
    HR_MCP_CITADEL_VNET_NAME_VALUE="$(az network vnet list --resource-group "$hub_rg" --query "[?contains('${requested_subnet_id}', id)].name | [0]" -o tsv 2>/dev/null || true)"
    HR_MCP_ACA_SUBNET_NAME_VALUE="$(basename "$requested_subnet_id")"
    HR_MCP_ACA_SUBNET_ID_VALUE="$requested_subnet_id"
    delegation="$(az network vnet subnet show \
      --ids "$HR_MCP_ACA_SUBNET_ID_VALUE" \
      --query "delegations[?serviceName=='Microsoft.App/environments'].serviceName | [0]" \
      -o tsv 2>/dev/null || true)"
    if [[ -z "$delegation" ]]; then
      fail "Subnet '$HR_MCP_ACA_SUBNET_NAME_VALUE' is not delegated to Microsoft.App/environments. Set HR_MCP_ACA_SUBNET_ID to a dedicated ACA subnet."
    fi
    return
  fi

  if [[ -n "$requested_vnet" ]]; then
    HR_MCP_CITADEL_VNET_NAME_VALUE="$requested_vnet"
  else
    vnet_count="$(az network vnet list --resource-group "$hub_rg" --query 'length(@)' -o tsv 2>/dev/null || printf '0')"
    if [[ "$vnet_count" != "1" ]]; then
      fail "Expected exactly one Citadel hub VNet in resource group '$hub_rg' but found $vnet_count. Set HR_MCP_CITADEL_VNET_NAME or HR_MCP_ACA_SUBNET_ID."
    fi
    HR_MCP_CITADEL_VNET_NAME_VALUE="$(az network vnet list --resource-group "$hub_rg" --query '[0].name' -o tsv)"
  fi

  HR_MCP_ACA_SUBNET_NAME_VALUE="${requested_subnet:-snet-mcp}"
  subnet_id="$(az network vnet subnet show \
    --resource-group "$hub_rg" \
    --vnet-name "$HR_MCP_CITADEL_VNET_NAME_VALUE" \
    --name "$HR_MCP_ACA_SUBNET_NAME_VALUE" \
    --query id \
    -o tsv 2>/dev/null || true)"

  if [[ -z "$subnet_id" ]]; then
    vnet_prefixes=()
    while IFS= read -r prefix; do
      [[ -n "$prefix" ]] && vnet_prefixes+=("$prefix")
    done < <(az network vnet show \
        --resource-group "$hub_rg" \
        --name "$HR_MCP_CITADEL_VNET_NAME_VALUE" \
        --query 'addressSpace.addressPrefixes[]' \
        -o tsv)

    if [[ -z "$requested_prefix" ]]; then
      requested_prefix="$(resolve_available_subnet_prefix "$hub_rg" "$HR_MCP_CITADEL_VNET_NAME_VALUE" "$prefix_length" 2>/dev/null || true)"
      if [[ -z "$requested_prefix" ]]; then
        if [[ "${HR_MCP_ACA_EXPAND_VNET:-true}" != "true" ]]; then
          fail "Could not find an available /${prefix_length} subnet in VNet '$HR_MCP_CITADEL_VNET_NAME_VALUE'. Set HR_MCP_ACA_SUBNET_PREFIX to an available, non-overlapping prefix, or set HR_MCP_ACA_EXPAND_VNET=true to auto-expand the Citadel hub VNet address space."
        fi
        read -r expansion_vnet_prefix requested_prefix < <(compute_expansion_subnet_prefix "$hub_rg" "$HR_MCP_CITADEL_VNET_NAME_VALUE" "$prefix_length" "${HR_MCP_ACA_EXPAND_PREFIX_LENGTH:-}" 2>/dev/null || true)
        [[ -n "$requested_prefix" && -n "$expansion_vnet_prefix" ]] || fail "No free /${prefix_length} subnet inside VNet '$HR_MCP_CITADEL_VNET_NAME_VALUE' and could not compute a non-overlapping prefix to expand it. Set HR_MCP_ACA_SUBNET_PREFIX explicitly."
        needs_expansion=1
      fi
    elif ! prefix_inside_any_vnet_prefix "$requested_prefix" "${vnet_prefixes[@]}"; then
      if [[ "${HR_MCP_ACA_EXPAND_VNET:-true}" != "true" ]]; then
        fail "Requested HR_MCP_ACA_SUBNET_PREFIX '$requested_prefix' is outside VNet '$HR_MCP_CITADEL_VNET_NAME_VALUE'. Choose a prefix inside the existing VNet address space, or set HR_MCP_ACA_EXPAND_VNET=true to add it to the VNet."
      fi
      expansion_vnet_prefix="$(compute_expansion_vnet_prefix_for_subnet "$hub_rg" "$HR_MCP_CITADEL_VNET_NAME_VALUE" "$requested_prefix" "${HR_MCP_ACA_EXPAND_PREFIX_LENGTH:-}" 2>/dev/null || true)"
      [[ -n "$expansion_vnet_prefix" ]] || fail "Requested HR_MCP_ACA_SUBNET_PREFIX '$requested_prefix' is outside VNet '$HR_MCP_CITADEL_VNET_NAME_VALUE' and could not be aligned to a non-overlapping address space block. Choose a different prefix."
      needs_expansion=1
    fi

    if [[ "$needs_expansion" == "1" ]]; then
      log "No free /${prefix_length} subnet in VNet '${HR_MCP_CITADEL_VNET_NAME_VALUE}'; extending address space with '${expansion_vnet_prefix}' and carving subnet '${requested_prefix}'"
      az network vnet update \
        --resource-group "$hub_rg" \
        --name "$HR_MCP_CITADEL_VNET_NAME_VALUE" \
        --add addressSpace.addressPrefixes "$expansion_vnet_prefix" \
        --only-show-errors \
        -o none || fail "Could not add address prefix '${expansion_vnet_prefix}' to VNet '${HR_MCP_CITADEL_VNET_NAME_VALUE}' (it may overlap a peered network). Set HR_MCP_ACA_SUBNET_PREFIX to a non-overlapping prefix."
      vnet_prefixes+=("$expansion_vnet_prefix")
      # Record the prefix we added so teardown can remove it once the subnet is gone.
      HR_MCP_ACA_ADDED_VNET_PREFIX_VALUE="$expansion_vnet_prefix"
    fi

    log "Creating dedicated HR MCP subnet '${HR_MCP_ACA_SUBNET_NAME_VALUE}' in Citadel hub VNet"
    prefix_inside_any_vnet_prefix "$requested_prefix" "${vnet_prefixes[@]}" || fail "Resolved subnet prefix '$requested_prefix' is outside VNet '$HR_MCP_CITADEL_VNET_NAME_VALUE'. Set HR_MCP_ACA_SUBNET_PREFIX to an available prefix inside the Citadel hub VNet address space."

    az network vnet subnet create \
      --resource-group "$hub_rg" \
      --vnet-name "$HR_MCP_CITADEL_VNET_NAME_VALUE" \
      --name "$HR_MCP_ACA_SUBNET_NAME_VALUE" \
      --address-prefixes "$requested_prefix" \
      --delegations Microsoft.App/environments \
      --only-show-errors \
      -o none || fail "Could not create subnet '$HR_MCP_ACA_SUBNET_NAME_VALUE'. Set HR_MCP_ACA_SUBNET_PREFIX to an available, non-overlapping prefix."
    subnet_id="$(az network vnet subnet show \
      --resource-group "$hub_rg" \
      --vnet-name "$HR_MCP_CITADEL_VNET_NAME_VALUE" \
      --name "$HR_MCP_ACA_SUBNET_NAME_VALUE" \
      --query id \
      -o tsv)"
  fi

  HR_MCP_ACA_SUBNET_ID_VALUE="$subnet_id"

  delegation="$(az network vnet subnet show \
    --ids "$HR_MCP_ACA_SUBNET_ID_VALUE" \
    --query "delegations[?serviceName=='Microsoft.App/environments'].serviceName | [0]" \
    -o tsv 2>/dev/null || true)"
  if [[ -z "$delegation" ]]; then
    fail "Subnet '$HR_MCP_ACA_SUBNET_NAME_VALUE' is not delegated to Microsoft.App/environments. Use a dedicated ACA subnet or set HR_MCP_ACA_SUBNET_ID to one."
  fi
}

find_app_object_id_by_display_name() {
  local display_name="$1"
  az ad app list \
    --display-name "$display_name" \
    --query 'length(@) == `1` && [0].id || `MULTIPLE_OR_NONE`' \
    -o tsv 2>/dev/null || true
}

get_app_client_id_from_object_id() {
  local object_id="$1"
  az ad app show --id "$object_id" --query appId -o tsv
}

ensure_single_app_by_display_name() {
  local display_name="$1"
  local object_id
  object_id="$(find_app_object_id_by_display_name "$display_name")"

  if [[ "$object_id" == "MULTIPLE_OR_NONE" ]]; then
    local count
    count="$(az ad app list --display-name "$display_name" --query 'length(@)' -o tsv 2>/dev/null || printf '0')"
    if [[ "$count" == "0" ]]; then
      object_id="$(az ad app create \
        --display-name "$display_name" \
        --sign-in-audience AzureADMyOrg \
        --query id \
        -o tsv)" || fail "Could not create app registration '$display_name'. You may need Application Developer permissions."
      printf '%s' "$object_id"
      return
    fi
    fail "Multiple app registrations named '$display_name' exist. Set HR_MCP_API_CLIENT_ID or HR_MCP_PUBLIC_CLIENT_ID to disambiguate."
  fi

  printf '%s' "$object_id"
}

patch_graph_application() {
  local object_id="$1"
  local body="$2"
  az rest \
    --method PATCH \
    --uri "https://graph.microsoft.com/v1.0/applications/${object_id}" \
    --headers 'Content-Type=application/json' \
    --body "$body" \
    --only-show-errors \
    -o none || fail "Could not update Entra app registration ${object_id}. Ensure Microsoft Graph Application.ReadWrite.All or Application Developer permissions are available."
}

validate_scope_name() {
  local value="$1"
  if [[ ! "$value" =~ ^[A-Za-z0-9._-]+$ ]]; then
    fail "HR_MCP_SCOPE_NAME must contain only letters, numbers, '.', '_' or '-'."
  fi
}

ensure_api_app_registration() {
  local display_name="$1"
  local requested_client_id="$2"
  local scope_value="$3"
  local role_value="$4"
  local object_id client_id app_id_uri existing_scope_id scope_id body

  if [[ -n "$requested_client_id" ]]; then
    object_id="$(az ad app show --id "$requested_client_id" --query id -o tsv 2>/dev/null)" || fail "HR_MCP_API_CLIENT_ID '$requested_client_id' was not found."
  else
    object_id="$(ensure_single_app_by_display_name "$display_name")"
  fi

  client_id="$(get_app_client_id_from_object_id "$object_id")"
  app_id_uri="api://${client_id}"

  existing_scope_id="$(az ad app show --id "$client_id" --query "api.oauth2PermissionScopes[?value=='${scope_value}'].id | [0]" -o tsv 2>/dev/null || true)"
  if [[ -n "$existing_scope_id" ]]; then
    scope_id="$existing_scope_id"
  else
    scope_id="$(uuidgen | tr '[:upper:]' '[:lower:]')"
  fi

  # Application role for managed-identity callers (the hosted agent). Entra
  # forbids an app role and a delegated scope from sharing the same value, so
  # the role uses a distinct value (default Mcp.Invoke) that both APIM and the
  # MCP server accept in the 'roles' claim.
  local existing_role_id role_id
  existing_role_id="$(az ad app show --id "$client_id" --query "appRoles[?value=='${role_value}'].id | [0]" -o tsv 2>/dev/null || true)"
  if [[ -n "$existing_role_id" ]]; then
    role_id="$existing_role_id"
  else
    role_id="$(uuidgen | tr '[:upper:]' '[:lower:]')"
  fi

  body="$(cat <<JSON
{"identifierUris":["${app_id_uri}"],"api":{"requestedAccessTokenVersion":2,"oauth2PermissionScopes":[{"id":"${scope_id}","adminConsentDescription":"Access the HR MCP API.","adminConsentDisplayName":"Access HR MCP","isEnabled":true,"type":"User","userConsentDescription":"Access the HR MCP API on your behalf.","userConsentDisplayName":"Access HR MCP","value":"${scope_value}"}]},"appRoles":[{"id":"${role_id}","allowedMemberTypes":["Application"],"description":"Applications can call the HR MCP API.","displayName":"Invoke HR MCP (application)","isEnabled":true,"value":"${role_value}"}]}
JSON
)"
  patch_graph_application "$object_id" "$body"

  HR_MCP_API_OBJECT_ID="$object_id"
  HR_MCP_API_CLIENT_ID_VALUE="$client_id"
  HR_MCP_SCOPE_ID="$scope_id"
  HR_MCP_APP_ROLE_ID="$role_id"
  HR_MCP_AUDIENCE_VALUE="$app_id_uri"
  HR_MCP_SCOPE_VALUE="${app_id_uri}/${scope_value}"
}

ensure_public_client_registration() {
  local display_name="$1"
  local requested_client_id="$2"
  local api_client_id="$3"
  local scope_id="$4"
  local object_id client_id body

  if [[ -n "$requested_client_id" ]]; then
    object_id="$(az ad app show --id "$requested_client_id" --query id -o tsv 2>/dev/null)" || fail "HR_MCP_PUBLIC_CLIENT_ID '$requested_client_id' was not found."
  else
    object_id="$(ensure_single_app_by_display_name "$display_name")"
  fi

  client_id="$(get_app_client_id_from_object_id "$object_id")"
  body="$(cat <<JSON
{"isFallbackPublicClient":true,"publicClient":{"redirectUris":["http://localhost"]},"requiredResourceAccess":[{"resourceAppId":"${api_client_id}","resourceAccess":[{"id":"${scope_id}","type":"Scope"}]}]}
JSON
)"
  patch_graph_application "$object_id" "$body"

  HR_MCP_PUBLIC_OBJECT_ID="$object_id"
  HR_MCP_PUBLIC_CLIENT_ID_VALUE="$client_id"
}

ensure_api_service_principal() {
  local api_client_id="$1"
  if az ad sp show --id "$api_client_id" >/dev/null 2>&1; then
    printf 'Service principal already exists for HR MCP API app.\n'
    return
  fi
  az ad sp create --id "$api_client_id" --only-show-errors -o none \
    || fail "Could not create service principal for HR MCP API app '$api_client_id'. Ensure you have permission to create Enterprise Applications/service principals."
  printf 'Created service principal for HR MCP API app.\n'
}

preauthorize_api_clients() {
  local api_object_id="$1"
  local scope_id="$2"
  shift 2
  local app_json body
  app_json="$(az ad app show --id "$api_object_id" -o json)"
  body="$(python3 -c '
import json
import sys

scope_id = sys.argv[1]
app = json.loads(sys.argv[2])
client_ids = [c for c in sys.argv[3:] if c]
api = app.get("api") or {}
scopes = api.get("oauth2PermissionScopes") or []
preauth = api.get("preAuthorizedApplications") or []
by_app = {item.get("appId"): item for item in preauth if item.get("appId")}
for client_id in client_ids:
    entry = by_app.setdefault(client_id, {"appId": client_id, "delegatedPermissionIds": []})
    ids = entry.setdefault("delegatedPermissionIds", [])
    if scope_id not in ids:
        ids.append(scope_id)
payload = {
    "api": {
        "requestedAccessTokenVersion": api.get("requestedAccessTokenVersion") or 2,
        "oauth2PermissionScopes": scopes,
        "preAuthorizedApplications": list(by_app.values()),
    }
}
print(json.dumps(payload, separators=(",", ":")))
' "$scope_id" "$app_json" "$@")"
  patch_graph_application "$api_object_id" "$body"
  printf 'Pre-authorized Azure CLI/public clients for HR MCP delegated scope.\n'
}

save_azd_value() {
  local key="$1"
  local value="$2"
  if [[ -n "$value" ]]; then
    azd env set "$key" "$value" >/dev/null
  fi
}

require_command az
require_command azd
require_command python3
require_command uuidgen

if ! az account show >/dev/null 2>&1; then
  fail 'Azure CLI is not logged in. Run az login, then rerun this script.'
fi

ensure_extension application-insights
ensure_extension containerapp

azd_resource_group="$(azd_get_optional AZURE_RESOURCE_GROUP)"
azd_location="$(azd_get_optional AZURE_LOCATION)"
azd_env_name="$(azd_get_optional AZURE_ENV_NAME)"
azd_subscription_id="$(azd_get_optional AZURE_SUBSCRIPTION_ID)"

location="$(first_non_empty "${AZURE_LOCATION:-}" "$azd_location")"
[[ -n "$location" ]] || fail 'AZURE_LOCATION is missing. Set AZURE_LOCATION or select an azd environment with AZURE_LOCATION.'

subscription_id="$(first_non_empty "${AZURE_SUBSCRIPTION_ID:-}" "$azd_subscription_id")"
if [[ -n "$subscription_id" ]]; then
  az account set --subscription "$subscription_id"
else
  subscription_id="$(az account show --query id -o tsv)"
fi

tenant_id="$(az account show --query tenantId -o tsv)"
env_name="$(first_non_empty "${AZURE_ENV_NAME:-}" "$azd_env_name" "hrmcp")"
seed_source="$(first_non_empty "${HR_MCP_NAME_SEED:-}" "$env_name" "$azd_resource_group")"
name_seed="$(safe_name_part "$seed_source")"
compact_seed="$(compact_name_part "$seed_source")"
subscription_suffix="$(printf '%s' "$subscription_id" | tr -d '-' | cut -c1-8)"
tag_env_name="${env_name:-unknown}"

hr_mcp_resource_group="$(first_non_empty "${HR_MCP_RESOURCE_GROUP:-}" "$(printf 'rg-%s-hr-mcp' "$name_seed" | cut -c1-90 | trim_trailing_hyphen)")"
log_analytics_workspace_name="$(first_non_empty "${HR_MCP_LOG_ANALYTICS_NAME:-}" "$(printf 'law-%s-hr-%s' "$name_seed" "$subscription_suffix" | cut -c1-63 | trim_trailing_hyphen)")"
app_insights_name="$(first_non_empty "${HR_MCP_APP_INSIGHTS_NAME:-}" "$(printf 'appi-%s-hr-%s' "$name_seed" "$subscription_suffix" | cut -c1-255 | trim_trailing_hyphen)")"
acr_name="$(first_non_empty "${HR_MCP_ACR_NAME:-}" "$(printf 'acr%shr%s' "$compact_seed" "$subscription_suffix" | sed 's/[^a-zA-Z0-9]//g' | cut -c1-50)")"
aca_environment_name="$(first_non_empty "${HR_MCP_ACA_ENVIRONMENT_NAME:-}" "$(printf 'cae-%s-hr-mcp' "$name_seed" | cut -c1-32 | trim_trailing_hyphen)")"
container_app_name="$(first_non_empty "${HR_MCP_CONTAINER_APP_NAME:-}" "$(printf 'ca-%s-hr-mcp' "$name_seed" | cut -c1-32 | trim_trailing_hyphen)")"
private_aca_environment_name="$(first_non_empty "${HR_MCP_PRIVATE_ACA_ENVIRONMENT_NAME:-}" "$(printf 'cae-%s-hr-mcp-int' "$name_seed" | cut -c1-32 | trim_trailing_hyphen)")"
private_container_app_name="$(first_non_empty "${HR_MCP_PRIVATE_CONTAINER_APP_NAME:-}" "$(printf 'ca-%s-hr-mcp-int' "$name_seed" | cut -c1-32 | trim_trailing_hyphen)")"
api_display_name="$(first_non_empty "${HR_MCP_API_APP_DISPLAY_NAME:-}" "${env_name}-hr-mcp-api")"
public_display_name="$(first_non_empty "${HR_MCP_PUBLIC_CLIENT_DISPLAY_NAME:-}" "${env_name}-hr-mcp-public-client")"
scope_name="$(first_non_empty "${HR_MCP_SCOPE_NAME:-}" "$DEFAULT_SCOPE_VALUE")"
app_role_value="$(first_non_empty "${HR_MCP_APP_ROLE_VALUE:-}" "$DEFAULT_APP_ROLE_VALUE")"
validate_scope_name "$scope_name"
image_repository="$(first_non_empty "${HR_MCP_IMAGE_REPOSITORY:-}" "hr-mcp")"
image_tag="$(first_non_empty "${HR_MCP_IMAGE_TAG:-}" "build-$(date -u +%Y%m%d%H%M%S)")"
issuer="$(first_non_empty "${HR_MCP_ISSUER:-}" "https://login.microsoftonline.com/${tenant_id}/v2.0")"

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" && pwd)"
workshop_dir="$(cd -- "${script_dir}/../.." && pwd)"
dockerfile_path="${workshop_dir}/mcp-hr/server/Dockerfile"
[[ -f "$dockerfile_path" ]] || fail "Dockerfile not found: $dockerfile_path"

citadel_hub_resource_group="$(first_non_empty "${HR_MCP_CITADEL_RESOURCE_GROUP:-}" "${AZURE_RESOURCE_GROUP:-}" "$azd_resource_group")"
[[ -n "$citadel_hub_resource_group" ]] || fail 'Citadel hub resource group is missing. Set HR_MCP_CITADEL_RESOURCE_GROUP or ensure AZURE_RESOURCE_GROUP is available in azd env.'
HR_MCP_ACA_ADDED_VNET_PREFIX_VALUE=""
resolve_citadel_aca_subnet \
  "$citadel_hub_resource_group" \
  "${HR_MCP_CITADEL_VNET_NAME:-}" \
  "${HR_MCP_ACA_SUBNET_NAME:-snet-mcp}" \
  "${HR_MCP_ACA_SUBNET_ID:-}" \
  "${HR_MCP_ACA_SUBNET_PREFIX:-}" \
  "${HR_MCP_ACA_SUBNET_PREFIX_LENGTH:-26}"

log 'Creating HR MCP resource group'
az group create \
  --name "$hr_mcp_resource_group" \
  --location "$location" \
  --tags "azd-env-name=${tag_env_name}" "workload=hr-mcp" "$SECURITY_CONTROL_TAG" \
  -o none

log 'Creating Log Analytics workspace'
if ! az monitor log-analytics workspace show --resource-group "$hr_mcp_resource_group" --workspace-name "$log_analytics_workspace_name" >/dev/null 2>&1; then
  az monitor log-analytics workspace create \
    --resource-group "$hr_mcp_resource_group" \
    --workspace-name "$log_analytics_workspace_name" \
    --location "$location" \
    --sku PerGB2018 \
    --tags "azd-env-name=${tag_env_name}" "workload=hr-mcp" "$SECURITY_CONTROL_TAG" \
    -o none
else
  printf 'Log Analytics workspace already exists: %s\n' "$log_analytics_workspace_name"
fi
log_analytics_workspace_id="$(az monitor log-analytics workspace show --resource-group "$hr_mcp_resource_group" --workspace-name "$log_analytics_workspace_name" --query id -o tsv)"

log 'Creating workspace-based Application Insights'
if ! az monitor app-insights component show --app "$app_insights_name" --resource-group "$hr_mcp_resource_group" >/dev/null 2>&1; then
  az monitor app-insights component create \
    --app "$app_insights_name" \
    --location "$location" \
    --resource-group "$hr_mcp_resource_group" \
    --workspace "$log_analytics_workspace_id" \
    --kind web \
    --application-type web \
    --tags "azd-env-name=${tag_env_name}" "workload=hr-mcp" "$SECURITY_CONTROL_TAG" \
    -o none
else
  printf 'Application Insights already exists: %s\n' "$app_insights_name"
fi
app_insights_connection_string="$(az monitor app-insights component show --app "$app_insights_name" --resource-group "$hr_mcp_resource_group" --query connectionString -o tsv)"

log 'Creating or configuring Entra app registrations'
ensure_api_app_registration "$api_display_name" "${HR_MCP_API_CLIENT_ID:-}" "$scope_name" "$app_role_value"
ensure_public_client_registration "$public_display_name" "${HR_MCP_PUBLIC_CLIENT_ID:-}" "$HR_MCP_API_CLIENT_ID_VALUE" "$HR_MCP_SCOPE_ID"
ensure_api_service_principal "$HR_MCP_API_CLIENT_ID_VALUE"
preauthorize_api_clients "$HR_MCP_API_OBJECT_ID" "$HR_MCP_SCOPE_ID" "$AZURE_CLI_CLIENT_ID" "$HR_MCP_PUBLIC_CLIENT_ID_VALUE"

log 'Creating Azure Container Registry'
if ! az acr show --name "$acr_name" --resource-group "$hr_mcp_resource_group" >/dev/null 2>&1; then
  az acr create \
    --name "$acr_name" \
    --resource-group "$hr_mcp_resource_group" \
    --location "$location" \
    --sku Basic \
    --admin-enabled false \
    --tags "azd-env-name=${tag_env_name}" "workload=hr-mcp" "$SECURITY_CONTROL_TAG" \
    -o none
else
  printf 'Container Registry already exists: %s\n' "$acr_name"
fi
acr_id="$(az acr show --name "$acr_name" --resource-group "$hr_mcp_resource_group" --query id -o tsv)"
acr_login_server="$(az acr show --name "$acr_name" --resource-group "$hr_mcp_resource_group" --query loginServer -o tsv)"
image_name="${acr_login_server}/${image_repository}:${image_tag}"

log 'Building HR MCP image remotely with ACR'
ensure_acr_base_images "$acr_name" "$acr_login_server"
printf 'Note: ACR remote builds run on a shared agent pool. On Basic/Standard SKUs the run can sit in "Queued" (no log output) for several minutes before it starts; this is normal and not a hang. The build itself takes well under a minute.\n'
(
  # Build from inside the small server folder so ACR only uploads ~250 KB of
  # source instead of the entire workshop tree (e.g. a multi-hundred-MB .venv).
  # `--file` is resolved relative to the current directory, so cd into the
  # context root and pass "." as the build context.
  cd "$workshop_dir/mcp-hr/server"
  az acr build \
    --registry "$acr_name" \
    --image "${image_repository}:${image_tag}" \
    --file "Dockerfile" \
    --build-arg "BASE_IMAGE=${HR_MCP_BASE_IMAGE_REF}" \
    "." \
    --only-show-errors
)

log 'Creating Container Apps environment'
if ! az containerapp env show --name "$aca_environment_name" --resource-group "$hr_mcp_resource_group" >/dev/null 2>&1; then
  az containerapp env create \
    --name "$aca_environment_name" \
    --resource-group "$hr_mcp_resource_group" \
    --location "$location" \
    --logs-workspace-id "$(az monitor log-analytics workspace show --resource-group "$hr_mcp_resource_group" --workspace-name "$log_analytics_workspace_name" --query customerId -o tsv)" \
    --logs-workspace-key "$(az monitor log-analytics workspace get-shared-keys --resource-group "$hr_mcp_resource_group" --workspace-name "$log_analytics_workspace_name" --query primarySharedKey -o tsv)" \
    --tags "azd-env-name=${tag_env_name}" "workload=hr-mcp" "$SECURITY_CONTROL_TAG" \
    --only-show-errors \
    -o none
else
  printf 'Container Apps environment already exists: %s\n' "$aca_environment_name"
fi

log 'Creating private Container Apps environment in the Citadel hub VNet'
if ! az containerapp env show --name "$private_aca_environment_name" --resource-group "$hr_mcp_resource_group" >/dev/null 2>&1; then
  az containerapp env create \
    --name "$private_aca_environment_name" \
    --resource-group "$hr_mcp_resource_group" \
    --location "$location" \
    --logs-workspace-id "$(az monitor log-analytics workspace show --resource-group "$hr_mcp_resource_group" --workspace-name "$log_analytics_workspace_name" --query customerId -o tsv)" \
    --logs-workspace-key "$(az monitor log-analytics workspace get-shared-keys --resource-group "$hr_mcp_resource_group" --workspace-name "$log_analytics_workspace_name" --query primarySharedKey -o tsv)" \
    --infrastructure-subnet-resource-id "$HR_MCP_ACA_SUBNET_ID_VALUE" \
    --internal-only \
    --tags "azd-env-name=${tag_env_name}" "workload=hr-mcp" "$SECURITY_CONTROL_TAG" \
    --only-show-errors \
    -o none
else
  printf 'Private Container Apps environment already exists: %s\n' "$private_aca_environment_name"
fi

private_env_default_domain="$(az containerapp env show --name "$private_aca_environment_name" --resource-group "$hr_mcp_resource_group" --query properties.defaultDomain -o tsv)"
private_env_static_ip="$(az containerapp env show --name "$private_aca_environment_name" --resource-group "$hr_mcp_resource_group" --query properties.staticIp -o tsv)"
citadel_vnet_id="$(az network vnet show --resource-group "$citadel_hub_resource_group" --name "$HR_MCP_CITADEL_VNET_NAME_VALUE" --query id -o tsv)"
ensure_private_aca_dns "$citadel_hub_resource_group" "$citadel_vnet_id" "$private_env_default_domain" "$private_env_static_ip"

common_env_vars=(
  "AUTH_ENABLED=true"
  "ENTRA_TENANT_ID=${tenant_id}"
  "ENTRA_AUDIENCE=${HR_MCP_AUDIENCE_VALUE}"
  "ENTRA_REQUIRED_SCOPE=${scope_name}"
  "ENTRA_REQUIRED_ROLE=${app_role_value}"
  "ENTRA_ISSUER=${issuer}"
  "APPLICATIONINSIGHTS_CONNECTION_STRING=${app_insights_connection_string}"
  "OTEL_SERVICE_NAME=hr-mcp"
  "OTEL_RESOURCE_ATTRIBUTES=service.namespace=workshop,deployment.environment=${tag_env_name},azure.resource_group=${hr_mcp_resource_group}"
  "PORT=8080"
)

log 'Creating or updating HR MCP Container App'
if ! az containerapp show --name "$container_app_name" --resource-group "$hr_mcp_resource_group" >/dev/null 2>&1; then
  az containerapp create \
    --name "$container_app_name" \
    --resource-group "$hr_mcp_resource_group" \
    --environment "$aca_environment_name" \
    --image 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest' \
    --target-port 80 \
    --ingress external \
    --min-replicas 0 \
    --max-replicas 2 \
    --system-assigned \
    --env-vars "${common_env_vars[@]}" \
    --tags "azd-env-name=${tag_env_name}" "workload=hr-mcp" "$SECURITY_CONTROL_TAG" \
    --only-show-errors \
    -o none
else
  printf 'Container App already exists: %s\n' "$container_app_name"
  az containerapp identity assign \
    --name "$container_app_name" \
    --resource-group "$hr_mcp_resource_group" \
    --system-assigned \
    --only-show-errors \
    -o none >/dev/null
fi

container_app_principal_id="$(az containerapp show --name "$container_app_name" --resource-group "$hr_mcp_resource_group" --query identity.principalId -o tsv)"
[[ -n "$container_app_principal_id" ]] || fail 'Could not resolve Container App managed identity principalId.'
assign_role_if_missing "$container_app_principal_id" ServicePrincipal "$ACR_PULL_ROLE_ID" 'AcrPull (HR MCP Container App)' "$acr_id"
wait_for_role_assignment "$container_app_principal_id" "$ACR_PULL_ROLE_ID" "$acr_id" 'AcrPull'

az containerapp registry set \
  --name "$container_app_name" \
  --resource-group "$hr_mcp_resource_group" \
  --server "$acr_login_server" \
  --identity system \
  --only-show-errors \
  -o none

az containerapp ingress update \
  --name "$container_app_name" \
  --resource-group "$hr_mcp_resource_group" \
  --target-port 8080 \
  --only-show-errors \
  -o none

az containerapp update \
  --name "$container_app_name" \
  --resource-group "$hr_mcp_resource_group" \
  --image "$image_name" \
  --set-env-vars "${common_env_vars[@]}" \
  --min-replicas 0 \
  --max-replicas 2 \
  --only-show-errors \
  -o none

log 'Creating or updating private HR MCP Container App for APIM backend traffic'
if ! az containerapp show --name "$private_container_app_name" --resource-group "$hr_mcp_resource_group" >/dev/null 2>&1; then
  az containerapp create \
    --name "$private_container_app_name" \
    --resource-group "$hr_mcp_resource_group" \
    --environment "$private_aca_environment_name" \
    --image 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest' \
    --target-port 80 \
    --ingress external \
    --min-replicas 0 \
    --max-replicas 2 \
    --system-assigned \
    --env-vars "${common_env_vars[@]}" \
    --tags "azd-env-name=${tag_env_name}" "workload=hr-mcp-private" "$SECURITY_CONTROL_TAG" \
    --only-show-errors \
    -o none
else
  printf 'Private Container App already exists: %s\n' "$private_container_app_name"
  az containerapp identity assign \
    --name "$private_container_app_name" \
    --resource-group "$hr_mcp_resource_group" \
    --system-assigned \
    --only-show-errors \
    -o none >/dev/null
fi

private_container_app_principal_id="$(az containerapp show --name "$private_container_app_name" --resource-group "$hr_mcp_resource_group" --query identity.principalId -o tsv)"
[[ -n "$private_container_app_principal_id" ]] || fail 'Could not resolve private Container App managed identity principalId.'
assign_role_if_missing "$private_container_app_principal_id" ServicePrincipal "$ACR_PULL_ROLE_ID" 'AcrPull (Private HR MCP Container App)' "$acr_id"
wait_for_role_assignment "$private_container_app_principal_id" "$ACR_PULL_ROLE_ID" "$acr_id" 'AcrPull (private app)'

az containerapp registry set \
  --name "$private_container_app_name" \
  --resource-group "$hr_mcp_resource_group" \
  --server "$acr_login_server" \
  --identity system \
  --only-show-errors \
  -o none

az containerapp ingress update \
  --name "$private_container_app_name" \
  --resource-group "$hr_mcp_resource_group" \
  --target-port 8080 \
  --type external \
  --transport http \
  --only-show-errors \
  -o none

az containerapp update \
  --name "$private_container_app_name" \
  --resource-group "$hr_mcp_resource_group" \
  --image "$image_name" \
  --set-env-vars "${common_env_vars[@]}" \
  --min-replicas 0 \
  --max-replicas 2 \
  --only-show-errors \
  -o none

if az containerapp update -h 2>/dev/null | grep -q -- '--startup-probe'; then
  log 'Configuring health probes'
  az containerapp update \
    --name "$container_app_name" \
    --resource-group "$hr_mcp_resource_group" \
    --startup-probe 'path=/health,port=8080,transport=HTTP,initialDelaySeconds=10,periodSeconds=10,failureThreshold=12' \
    --liveness-probe 'path=/health,port=8080,transport=HTTP,initialDelaySeconds=30,periodSeconds=30,failureThreshold=3' \
    --only-show-errors \
    -o none || warn 'Probe configuration failed. The app is deployed; configure /health probes from the Container App portal if your CLI version lacks compatible probe syntax.'
  az containerapp update \
    --name "$private_container_app_name" \
    --resource-group "$hr_mcp_resource_group" \
    --startup-probe 'path=/health,port=8080,transport=HTTP,initialDelaySeconds=10,periodSeconds=10,failureThreshold=12' \
    --liveness-probe 'path=/health,port=8080,transport=HTTP,initialDelaySeconds=30,periodSeconds=30,failureThreshold=3' \
    --only-show-errors \
    -o none || warn 'Private app probe configuration failed. The app is deployed; configure /health probes from the Container App portal if your CLI version lacks compatible probe syntax.'
else
  warn 'Azure CLI containerapp extension does not expose probe flags. The app is configured correctly; add /health startup/liveness probes later if desired.'
fi

container_app_fqdn="$(az containerapp show --name "$container_app_name" --resource-group "$hr_mcp_resource_group" --query properties.configuration.ingress.fqdn -o tsv)"
direct_url="https://${container_app_fqdn}"
direct_mcp_url="${direct_url}/mcp"
private_container_app_fqdn="$(az containerapp show --name "$private_container_app_name" --resource-group "$hr_mcp_resource_group" --query properties.configuration.ingress.fqdn -o tsv)"
private_backend_url="https://${private_container_app_fqdn}"
private_mcp_url="${private_backend_url}/mcp"
private_backend_ip_url="http://${private_env_static_ip}"

log 'Saving HR MCP outputs to azd environment'
save_azd_value HR_MCP_RESOURCE_GROUP "$hr_mcp_resource_group"
save_azd_value HR_MCP_ACR_NAME "$acr_name"
save_azd_value HR_MCP_ACR_LOGIN_SERVER "$acr_login_server"
save_azd_value HR_MCP_CONTAINER_APP_NAME "$container_app_name"
save_azd_value HR_MCP_PRIVATE_ACA_ENVIRONMENT_NAME "$private_aca_environment_name"
save_azd_value HR_MCP_PRIVATE_CONTAINER_APP_NAME "$private_container_app_name"
save_azd_value HR_MCP_DIRECT_URL "$direct_url"
save_azd_value HR_MCP_DIRECT_MCP_URL "$direct_mcp_url"
save_azd_value HR_MCP_PRIVATE_BACKEND_URL "$private_backend_url"
save_azd_value HR_MCP_PRIVATE_BACKEND_IP_URL "$private_backend_ip_url"
save_azd_value HR_MCP_APIM_BACKEND_HOST_HEADER "$private_container_app_fqdn"
save_azd_value HR_MCP_PRIVATE_MCP_URL "$private_mcp_url"
save_azd_value HR_MCP_ACA_INTERNAL_FQDN "$private_container_app_fqdn"
save_azd_value HR_MCP_PRIVATE_DNS_ZONE "$private_env_default_domain"
save_azd_value HR_MCP_PRIVATE_DNS_RESOURCE_GROUP "$citadel_hub_resource_group"
save_azd_value HR_MCP_APIM_REQUIRE_PRIVATE_BACKEND "true"
save_azd_value HR_MCP_CITADEL_RESOURCE_GROUP "$citadel_hub_resource_group"
save_azd_value HR_MCP_CITADEL_VNET_NAME "$HR_MCP_CITADEL_VNET_NAME_VALUE"
save_azd_value HR_MCP_ACA_SUBNET_NAME "$HR_MCP_ACA_SUBNET_NAME_VALUE"
save_azd_value HR_MCP_ACA_SUBNET_ID "$HR_MCP_ACA_SUBNET_ID_VALUE"
save_azd_value HR_MCP_ACA_ADDED_VNET_PREFIX "$HR_MCP_ACA_ADDED_VNET_PREFIX_VALUE"
save_azd_value HR_MCP_APP_INSIGHTS_NAME "$app_insights_name"
save_azd_value HR_MCP_TENANT_ID "$tenant_id"
save_azd_value HR_MCP_API_CLIENT_ID "$HR_MCP_API_CLIENT_ID_VALUE"
save_azd_value HR_MCP_PUBLIC_CLIENT_ID "$HR_MCP_PUBLIC_CLIENT_ID_VALUE"
save_azd_value HR_MCP_AUDIENCE "$HR_MCP_AUDIENCE_VALUE"
save_azd_value HR_MCP_SCOPE "$HR_MCP_SCOPE_VALUE"
save_azd_value HR_MCP_APP_ROLE_ID "$HR_MCP_APP_ROLE_ID"
save_azd_value HR_MCP_APP_ROLE_VALUE "$app_role_value"
save_azd_value HR_MCP_API_OBJECT_ID "$HR_MCP_API_OBJECT_ID"
save_azd_value HR_MCP_REQUIRED_SCOPE_CLAIM "$scope_name"

cat <<EOF

HR MCP ACA deployment is ready.
Resource group: $hr_mcp_resource_group
Container App: $container_app_name
Direct URL: $direct_url
MCP endpoint: $direct_mcp_url
Private Container App: $private_container_app_name
Private backend URL for APIM: $private_backend_url
Private backend IP URL fallback: $private_backend_ip_url
Private ACA DNS zone: $private_env_default_domain ($citadel_hub_resource_group)
Citadel hub VNet/subnet: $HR_MCP_CITADEL_VNET_NAME_VALUE/$HR_MCP_ACA_SUBNET_NAME_VALUE
API app client id: $HR_MCP_API_CLIENT_ID_VALUE
Public client id: $HR_MCP_PUBLIC_CLIENT_ID_VALUE
Audience: $HR_MCP_AUDIENCE_VALUE
Scope: $HR_MCP_SCOPE_VALUE

Token acquisition examples (these print tokens; use only in your own shell):
az login --tenant "$tenant_id" --use-device-code
az account get-access-token --tenant "$tenant_id" --scope "$HR_MCP_SCOPE_VALUE" --query accessToken -o tsv

Smoke test (acquires a token with Azure CLI; does not print it):
cd workshop && uv run python mcp-hr/scripts/test-hr-mcp-direct.py

MCP config snippet (replace <ACCESS_TOKEN>; never store real tokens in source):
{
  "mcpServers": {
    "hr-mcp-direct": {
      "type": "http",
      "url": "$direct_mcp_url",
      "headers": {
        "Authorization": "Bearer <ACCESS_TOKEN>"
      }
    }
  }
}
EOF
