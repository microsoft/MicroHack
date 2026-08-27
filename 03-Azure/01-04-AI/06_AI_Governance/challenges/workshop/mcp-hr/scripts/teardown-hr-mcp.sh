#!/usr/bin/env bash
set -euo pipefail

# Tear down the HR MCP deployment created by deploy-hr-mcp.sh and published by
# publish-hr-mcp-apim.sh. Every step is best-effort and idempotent: objects that
# were already removed (for example, deleted by hand in the portal) are skipped
# with a notice instead of failing the run. Finally, all HR_MCP_* values are
# cleared from the active azd environment so a stale backend URL can never leak
# into a later deploy/publish cycle.

log() { printf '\n==> %s\n' "$1"; }
note() { printf '   - %s\n' "$1"; }
warn() { printf 'Warning: %s\n' "$1" >&2; }
fail() { printf 'Error: %s\n' "$1" >&2; exit 1; }
require_command() { command -v "$1" >/dev/null 2>&1 || fail "Required command not found: $1"; }
azd_get_optional() { local v; if v="$(azd env get-value "$1" 2>/dev/null)"; then printf '%s' "$v"; fi; }
first_non_empty() { local v; for v in "$@"; do [[ -n "${v:-}" ]] && { printf '%s' "$v"; return 0; }; done; return 0; }

assume_yes=false
no_wait=false
keep_azd_env=false
skip_apim=false
skip_dns=false
skip_rg=false
skip_subnet=false

usage() {
  cat <<'EOF'
Usage: teardown-hr-mcp.sh [options]

Removes the HR MCP infrastructure resource group, its APIM publication objects
(subscription, product, API, backend), and the per-deployment private DNS zone,
then clears HR_MCP_* values from the active azd environment. If deploy-hr-mcp
expanded the Citadel hub VNet (HR_MCP_ACA_ADDED_VNET_PREFIX), that added address
space is removed after the dedicated subnet is deleted.

Options:
  -y, --yes          Do not prompt for confirmation.
      --no-wait      Start the resource group deletion without waiting for it to finish.
      --keep-azd-env Leave HR_MCP_* values in the azd environment.
      --skip-apim    Do not touch the APIM publication objects.
      --skip-dns     Do not touch the private DNS zone.
      --skip-rg      Do not delete the HR MCP infrastructure resource group.
      --skip-subnet  Do not delete the dedicated ACA subnet (and added VNet address space).
  -h, --help         Show this help.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -y|--yes) assume_yes=true ;;
    --no-wait) no_wait=true ;;
    --keep-azd-env) keep_azd_env=true ;;
    --skip-apim) skip_apim=true ;;
    --skip-dns) skip_dns=true ;;
    --skip-rg) skip_rg=true ;;
    --skip-subnet) skip_subnet=true ;;
    -h|--help) usage; exit 0 ;;
    *) fail "Unknown option: $1" ;;
  esac
  shift
done

require_command az
require_command azd
if ! az account show >/dev/null 2>&1; then
  fail 'Azure CLI is not logged in. Run az login, then rerun this script.'
fi

subscription_id="$(first_non_empty "${AZURE_SUBSCRIPTION_ID:-}" "$(azd_get_optional AZURE_SUBSCRIPTION_ID)" "$(az account show --query id -o tsv 2>/dev/null)")"
if [[ -n "$subscription_id" ]]; then
  az account set --subscription "$subscription_id" >/dev/null 2>&1 || true
fi

mcp_rg="$(first_non_empty "${HR_MCP_RESOURCE_GROUP:-}" "$(azd_get_optional HR_MCP_RESOURCE_GROUP)")"
apim_name="$(first_non_empty "${HR_MCP_APIM_NAME:-}" "$(azd_get_optional HR_MCP_APIM_NAME)" "${APIM_NAME:-}" "$(azd_get_optional APIM_NAME)")"
apim_rg="$(first_non_empty "${HR_MCP_APIM_RESOURCE_GROUP:-}" "$(azd_get_optional HR_MCP_APIM_RESOURCE_GROUP)" "$(azd_get_optional AZURE_RESOURCE_GROUP)")"
api_name="$(first_non_empty "${HR_MCP_APIM_API_NAME:-}" "$(azd_get_optional HR_MCP_APIM_API_NAME)" 'hr-mcp-api')"
backend_name="$(first_non_empty "${HR_MCP_APIM_BACKEND_NAME:-}" "$(azd_get_optional HR_MCP_APIM_BACKEND_NAME)" 'hr-mcp-aca-backend')"
product_id="$(first_non_empty "${HR_MCP_APIM_PRODUCT_ID:-}" "$(azd_get_optional HR_MCP_APIM_PRODUCT_ID)" 'MCP-HR-Tools-DEV')"
subscription_name="$(first_non_empty "${HR_MCP_APIM_SUBSCRIPTION_NAME:-}" "$(azd_get_optional HR_MCP_APIM_SUBSCRIPTION_NAME)" 'MCP-HR-Tools-DEV-SUB-01')"
dns_rg="$(first_non_empty "${HR_MCP_PRIVATE_DNS_RESOURCE_GROUP:-}" "$(azd_get_optional HR_MCP_PRIVATE_DNS_RESOURCE_GROUP)")"
dns_zone="$(first_non_empty "${HR_MCP_PRIVATE_DNS_ZONE:-}" "$(azd_get_optional HR_MCP_PRIVATE_DNS_ZONE)")"
dns_link_name='lnk-hr-mcp-aca'

# Dedicated ACA subnet that deploy-hr-mcp creates inside the shared Citadel hub VNet. It is
# delegated to Microsoft.App/environments, so it can only be removed after the resource group
# (and its ACA environment) is gone.
subnet_id="$(first_non_empty "${HR_MCP_ACA_SUBNET_ID:-}" "$(azd_get_optional HR_MCP_ACA_SUBNET_ID)")"
hub_rg="$(first_non_empty "${HR_MCP_CITADEL_RESOURCE_GROUP:-}" "$(azd_get_optional HR_MCP_CITADEL_RESOURCE_GROUP)")"
vnet_name="$(first_non_empty "${HR_MCP_CITADEL_VNET_NAME:-}" "$(azd_get_optional HR_MCP_CITADEL_VNET_NAME)")"
subnet_name="$(first_non_empty "${HR_MCP_ACA_SUBNET_NAME:-}" "$(azd_get_optional HR_MCP_ACA_SUBNET_NAME)")"
# Address prefix deploy-hr-mcp added to the hub VNet when no free subnet was available.
# It is removed only after the dedicated subnet is gone, leaving the original space intact.
added_vnet_prefix="$(first_non_empty "${HR_MCP_ACA_ADDED_VNET_PREFIX:-}" "$(azd_get_optional HR_MCP_ACA_ADDED_VNET_PREFIX)")"
if [[ -n "$subnet_id" ]]; then
  [[ -n "$hub_rg" ]] || hub_rg="$(printf '%s' "$subnet_id" | sed -E 's#.*/resourceGroups/([^/]+)/.*#\1#')"
  [[ -n "$vnet_name" ]] || vnet_name="$(printf '%s' "$subnet_id" | sed -E 's#.*/virtualNetworks/([^/]+)/.*#\1#')"
  [[ -n "$subnet_name" ]] || subnet_name="$(basename "$subnet_id")"
fi

log 'HR MCP teardown plan'
note "Subscription:            ${subscription_id:-<unknown>}"
if [[ "$skip_apim" == true ]]; then
  note 'APIM publication:        SKIPPED (--skip-apim)'
elif [[ -n "$apim_name" && -n "$apim_rg" ]]; then
  note "APIM service:            $apim_name ($apim_rg)"
  note "  - subscription:        $subscription_name"
  note "  - product:             $product_id"
  note "  - API:                 $api_name"
  note "  - backend:             $backend_name"
else
  note 'APIM publication:        SKIPPED (APIM name/resource group not resolved)'
fi
if [[ "$skip_dns" == true ]]; then
  note 'Private DNS zone:        SKIPPED (--skip-dns)'
elif [[ -n "$dns_rg" && -n "$dns_zone" ]]; then
  note "Private DNS zone:        $dns_zone ($dns_rg)"
else
  note 'Private DNS zone:        SKIPPED (zone/resource group not resolved)'
fi
if [[ "$skip_rg" == true ]]; then
  note 'Infrastructure RG:       SKIPPED (--skip-rg)'
elif [[ -n "$mcp_rg" ]]; then
  note "Infrastructure RG:       $mcp_rg (DELETE)"
else
  note 'Infrastructure RG:       SKIPPED (HR_MCP_RESOURCE_GROUP not resolved)'
fi
if [[ "$skip_subnet" == true ]]; then
  note 'ACA hub subnet:          SKIPPED (--skip-subnet)'
elif [[ -n "$hub_rg" && -n "$vnet_name" && -n "$subnet_name" ]]; then
  note "ACA hub subnet:          $subnet_name in $vnet_name ($hub_rg)"
  if [[ -n "$added_vnet_prefix" ]]; then
    note "Added VNet address space: $added_vnet_prefix (REMOVE after subnet)"
  fi
else
  note 'ACA hub subnet:          SKIPPED (subnet/VNet not resolved)'
fi
if [[ "$keep_azd_env" == true ]]; then
  note 'azd HR_MCP_* values:     KEPT (--keep-azd-env)'
else
  note 'azd HR_MCP_* values:     CLEARED'
fi

if [[ "$assume_yes" != true ]]; then
  printf '\nProceed with teardown? Type "yes" to continue: '
  read -r reply
  if [[ "$reply" != "yes" ]]; then
    printf '\nTeardown cancelled. No changes were made.\n'
    exit 0
  fi
fi

apim_delete() {
  # Best-effort DELETE of an APIM child resource by relative path. A 404 (already
  # gone) or any other failure is reported and skipped rather than aborting.
  local rel="$1" label="$2" extra_query="${3:-}"
  local url="https://management.azure.com/subscriptions/${subscription_id}/resourceGroups/${apim_rg}/providers/Microsoft.ApiManagement/service/${apim_name}/${rel}?api-version=2024-06-01-preview${extra_query}"
  if az rest --method delete --url "$url" --only-show-errors -o none >/dev/null 2>&1; then
    note "Deleted APIM $label"
  else
    note "APIM $label already absent or not deletable (continuing)"
  fi
}

if [[ "$skip_apim" != true && -n "$apim_name" && -n "$apim_rg" && -n "$subscription_id" ]]; then
  if az apim show --name "$apim_name" --resource-group "$apim_rg" >/dev/null 2>&1; then
    log "Removing HR MCP publication objects from APIM: $apim_name"
    apim_delete "subscriptions/${subscription_name}" "subscription '$subscription_name'"
    apim_delete "products/${product_id}" "product '$product_id'" '&deleteSubscriptions=true'
    apim_delete "apis/${api_name}" "API '$api_name'"
    apim_delete "backends/${backend_name}" "backend '$backend_name'"
  else
    log "APIM service '$apim_name' not found in '$apim_rg'; skipping APIM cleanup."
  fi
fi

if [[ "$skip_dns" != true && -n "$dns_rg" && -n "$dns_zone" ]]; then
  if az network private-dns zone show --resource-group "$dns_rg" --name "$dns_zone" >/dev/null 2>&1; then
    log "Removing private DNS zone: $dns_zone"
    if az network private-dns link vnet show --resource-group "$dns_rg" --zone-name "$dns_zone" --name "$dns_link_name" >/dev/null 2>&1; then
      az network private-dns link vnet delete --resource-group "$dns_rg" --zone-name "$dns_zone" --name "$dns_link_name" --yes --only-show-errors -o none >/dev/null 2>&1 \
        && note "Deleted vnet link '$dns_link_name'" || note "Could not delete vnet link '$dns_link_name' (continuing)"
    else
      note "Vnet link '$dns_link_name' already absent (continuing)"
    fi
    if az network private-dns zone delete --resource-group "$dns_rg" --name "$dns_zone" --yes --only-show-errors -o none >/dev/null 2>&1; then
      note "Deleted private DNS zone '$dns_zone'"
    else
      note "Could not delete private DNS zone '$dns_zone' (continuing)"
    fi
  else
    log "Private DNS zone '$dns_zone' already absent (continuing)."
  fi
fi

if [[ "$skip_rg" != true && -n "$mcp_rg" ]]; then
  if az group show --name "$mcp_rg" >/dev/null 2>&1; then
    if [[ "$no_wait" == true ]]; then
      log "Deleting resource group (no wait): $mcp_rg"
      az group delete --name "$mcp_rg" --yes --no-wait -o none
      note 'Deletion started in the background.'
      rg_delete_async=true
    else
      log "Deleting resource group (this can take several minutes): $mcp_rg"
      az group delete --name "$mcp_rg" --yes -o none
      note 'Resource group deleted.'
    fi
  else
    log "Resource group '$mcp_rg' already absent (continuing)."
  fi
fi

if [[ "$skip_subnet" != true && -n "$hub_rg" && -n "$vnet_name" && -n "$subnet_name" ]]; then
  if az network vnet subnet show --resource-group "$hub_rg" --vnet-name "$vnet_name" --name "$subnet_name" >/dev/null 2>&1; then
    if [[ "${rg_delete_async:-false}" == true ]]; then
      log "Deferring ACA subnet '$subnet_name' deletion"
      note 'The subnet is still delegated to the ACA environment while the resource group deletes in the background.'
      note "Rerun: teardown-hr-mcp.sh --skip-apim --skip-dns --skip-rg --keep-azd-env  (after '$mcp_rg' is gone)"
    else
      log "Deleting ACA subnet '$subnet_name' from Citadel hub VNet '$vnet_name'"
      if az network vnet subnet delete --resource-group "$hub_rg" --vnet-name "$vnet_name" --name "$subnet_name" --only-show-errors -o none >/dev/null 2>&1; then
        note "Deleted subnet '$subnet_name'"
        # Subnet is gone; now remove the address prefix deploy added (if any), but only
        # when no other subnet still sits inside it, so we never shrink space in use.
        if [[ -n "$added_vnet_prefix" ]]; then
          vnet_json="$(az network vnet show --resource-group "$hub_rg" --name "$vnet_name" \
            --query '{addressPrefixes:addressSpace.addressPrefixes,subnetPrefixes:subnets[].addressPrefix}' -o json 2>/dev/null || true)"
          remove_index="$(python3 - "$added_vnet_prefix" "$vnet_json" <<'PY'
import ipaddress, json, sys
target = ipaddress.ip_network(sys.argv[1], strict=False)
data = json.loads(sys.argv[2] or "{}")
prefixes = [p for p in (data.get("addressPrefixes") or []) if p]
subnets = [p for p in (data.get("subnetPrefixes") or []) if p]
# Refuse to remove if any remaining subnet still lives inside the added prefix.
for s in subnets:
    if ipaddress.ip_network(s, strict=False).subnet_of(target):
        print("INUSE"); raise SystemExit(0)
for i, p in enumerate(prefixes):
    if ipaddress.ip_network(p, strict=False) == target:
        print(i); raise SystemExit(0)
print("ABSENT")
PY
)"
          if [[ "$remove_index" == "INUSE" ]]; then
            note "Address prefix '$added_vnet_prefix' still has subnets; leaving it on the VNet."
          elif [[ "$remove_index" == "ABSENT" || -z "$remove_index" ]]; then
            note "Address prefix '$added_vnet_prefix' already absent from VNet (continuing)."
          elif az network vnet update --resource-group "$hub_rg" --name "$vnet_name" \
              --remove "addressSpace.addressPrefixes" "$remove_index" --only-show-errors -o none >/dev/null 2>&1; then
            note "Removed added VNet address space '$added_vnet_prefix'"
          else
            warn "Could not remove added VNet address space '$added_vnet_prefix' (continuing). Remove it manually if no longer needed."
          fi
        fi
      else
        warn "Could not delete subnet '$subnet_name'. It may still be in use by the ACA environment; rerun this script once '$mcp_rg' has finished deleting."
      fi
    fi
  else
    log "Subnet '$subnet_name' already absent (continuing)."
  fi
fi

if [[ "$keep_azd_env" != true ]]; then
  log 'Clearing HR_MCP_* values from the active azd environment'
  dotenv_path="$(azd env list -o json 2>/dev/null | python3 -c '
import json, sys
def get(d, *keys):
    for k in keys:
        for kk in d:
            if kk.lower() == k.lower():
                return d[kk]
    return ""
try:
    envs = json.load(sys.stdin)
except Exception:
    sys.exit(0)
for e in envs:
    if get(e, "IsDefault"):
        print(get(e, "DotEnvPath"))
        break
' 2>/dev/null || true)"
  if [[ -n "$dotenv_path" && -f "$dotenv_path" ]]; then
    tmp="${dotenv_path}.teardown.tmp"
    if grep -v -E '^HR_MCP_[A-Z0-9_]+=' "$dotenv_path" > "$tmp"; then
      mv "$tmp" "$dotenv_path"
      note "Removed HR_MCP_* entries from $dotenv_path"
    else
      rm -f "$tmp"
      note "No HR_MCP_* entries found in $dotenv_path"
    fi
  else
    warn 'Could not locate the active azd .env file; HR_MCP_* values were left in place. Select an azd environment or clear them manually.'
  fi
fi

log 'HR MCP teardown complete.'
printf 'Re-run deploy-hr-mcp then publish-hr-mcp-apim to recreate a clean deployment.\n'
