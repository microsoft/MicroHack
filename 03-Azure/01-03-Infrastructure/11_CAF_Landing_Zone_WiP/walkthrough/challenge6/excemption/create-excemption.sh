#!/usr/bin/env bash
set -euo pipefail

# Purpose: Create policy exemptions for all policy assignments at a given scope
#          that reference a specified policy definition (by GUID, full ID, or display name).
#          Exemptions are created at a provided exemption scope.
#
# Updated Requirements (req.txt):
# - pass in assignment scope (now supports management group scopes)
# - pass in policy name (GUID) OR the policy display name
# - pass in exemption scope (e.g., resource group) & its name
# - determine assignment id(s)
# - determine exemption scope resource id
# - create exemption for each matching assignment
#
# Backwards compatibility: --policy-definition-id retained but superseded by --policy if both supplied.
#
# Notes:
# 1. Supports assignment scopes at subscription or management group (e.g. /providers/Microsoft.Management/managementGroups/<mgId>).
# 2. Exemption target scopes currently: subscription, resourceGroup (extendable).
# 3. Policy display name matching is case-insensitive exact match.
# 4. Basic caching avoids redundant policy definition lookups without requiring associative arrays (macOS default bash 3.x).
# 5. "excemption" spelling kept to align with provided folder name.

usage() {
  cat <<EOF
Usage: $0 \\
  --assignment-scope <scopeId> \\
  --policy <policy GUID | full definition ID | display name> \\
  [--policy-definition-id <legacy full definition ID>] \\
  --exemption-scope-type <subscription|resourceGroup> \\
  --exemption-scope-name <name or subscriptionId> \\
  [--exemption-category <Waiver|Mitigated>] \\
  [--reason <free text reason>] \\
  [--dry-run] \\
  [--verbose]

Examples:
  # Exempt a resource group from a specific policy definition (by GUID) enforced at subscription scope
  $0 \
    --assignment-scope /subscriptions/00000000-0000-0000-0000-000000000000 \
    --policy a1b2c3d4-1111-2222-3333-444455556666 \
    --exemption-scope-type resourceGroup \
    --exemption-scope-name my-workload-rg

  # Exempt using display name (quotes required if spaces)
  $0 \
    --assignment-scope /providers/Microsoft.Management/managementGroups/myRootMG \
    --policy "Storage accounts should disable public network access" \
    --exemption-scope-type subscription \
    --exemption-scope-name 00000000-0000-0000-0000-000000000000

  # Dry run to see which assignments would get exemptions (full ID example)
  $0 --assignment-scope /subscriptions/000... \
     --policy /providers/Microsoft.Authorization/policyDefinitions/a1b2c3d4 \
     --exemption-scope-type subscription \
     --exemption-scope-name 00000000-0000-0000-0000-000000000000 \
     --dry-run --verbose

EOF
  exit 1
}

ASSIGNMENT_SCOPE=""
POLICY_INPUT=""
LEGACY_POLICY_DEFINITION_ID=""
EXEMPTION_SCOPE_TYPE=""
EXEMPTION_SCOPE_NAME=""
EXEMPTION_CATEGORY="Waiver"
REASON="Policy exemption generated via automation script."
DRY_RUN=false
VERBOSE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --assignment-scope) ASSIGNMENT_SCOPE="$2"; shift 2;;
  --policy) POLICY_INPUT="$2"; shift 2;;
  --policy-definition-id) LEGACY_POLICY_DEFINITION_ID="$2"; shift 2;;
    --exemption-scope-type) EXEMPTION_SCOPE_TYPE="$2"; shift 2;;
    --exemption-scope-name) EXEMPTION_SCOPE_NAME="$2"; shift 2;;
    --exemption-category) EXEMPTION_CATEGORY="$2"; shift 2;;
    --reason) REASON="$2"; shift 2;;
    --dry-run) DRY_RUN=true; shift 1;;
    --verbose) VERBOSE=true; shift 1;;
    -h|--help) usage;;
    *) echo "Unknown argument: $1"; usage;;
  esac
done

if [[ -z "$POLICY_INPUT" && -n "$LEGACY_POLICY_DEFINITION_ID" ]]; then
  POLICY_INPUT="$LEGACY_POLICY_DEFINITION_ID"
fi

[[ -z "$ASSIGNMENT_SCOPE" || -z "$POLICY_INPUT" || -z "$EXEMPTION_SCOPE_TYPE" || -z "$EXEMPTION_SCOPE_NAME" ]] && usage

log() { echo "[INFO] $*"; }
vlog() { if $VERBOSE; then echo "[DEBUG] $*"; fi; }
warn() { echo "[WARN] $*" >&2; }
err() { echo "[ERROR] $*" >&2; exit 1; }

require_tool() { command -v "$1" >/dev/null 2>&1 || err "Required tool '$1' not found in PATH"; }
require_tool az

if ! az account show >/dev/null 2>&1; then
  err "Not logged in to Azure CLI. Run 'az login' first."
fi

# Build the exemption scope resource ID
build_exemption_scope_id() {
  case "$EXEMPTION_SCOPE_TYPE" in
    subscription)
      # Name must be subscription GUID
      echo "/subscriptions/${EXEMPTION_SCOPE_NAME}" ;;
    resourceGroup)
      # Derive current subscription from assignment scope if possible
      # If assignment scope is at subscription or RG under the same subscription
      local subId
      if [[ "$ASSIGNMENT_SCOPE" =~ ^/subscriptions/([^/]+) ]]; then
        subId="${BASH_REMATCH[1]}"
      else
        # fallback: use current subscription
        subId=$(az account show --query id -o tsv)
      fi
      echo "/subscriptions/${subId}/resourceGroups/${EXEMPTION_SCOPE_NAME}" ;;
    *)
      err "Unsupported --exemption-scope-type '$EXEMPTION_SCOPE_TYPE' (supported: subscription, resourceGroup)" ;;
  esac
}

EXEMPTION_SCOPE_ID=$(build_exemption_scope_id)
log "Exemption scope resource ID: ${EXEMPTION_SCOPE_ID}"

log "Querying policy assignments at scope: $ASSIGNMENT_SCOPE"
ASSIGNMENTS_RAW=$(az policy assignment list --scope "$ASSIGNMENT_SCOPE" -o json)

if [[ -z "$ASSIGNMENTS_RAW" || "$ASSIGNMENTS_RAW" == "[]" ]]; then
  warn "No policy assignments found at scope: $ASSIGNMENT_SCOPE"
  exit 0
fi

# Determine match type for POLICY_INPUT
POLICY_INPUT_LOWER=$(echo "$POLICY_INPUT" | tr '[:upper:]' '[:lower:]')
MATCHED_ASSIGNMENTS=""

# Simple pattern detection
is_guid=false
if [[ "$POLICY_INPUT" =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$ ]]; then
  is_guid=true
fi

is_full_id=false
if [[ "$POLICY_INPUT_LOWER" == *"/providers/microsoft.authorization/policydefinitions/"* || "$POLICY_INPUT_LOWER" == *"/providers/microsoft.authorization/policysetdefinitions/"* ]]; then
  is_full_id=true
fi

# Cache file for policy definition display names (id|lower(displayName))
PD_CACHE=$(mktemp)
trap 'rm -f "$PD_CACHE"' EXIT

get_cached_display_name_lower() {
  local defId="$1"
  local line
  line=$(grep "^${defId}|" "$PD_CACHE" || true)
  if [[ -n "$line" ]]; then
    echo "${line#${defId}|}"
    return 0
  fi
  # Determine if definition or set definition
  local lowerId=$(echo "$defId" | tr '[:upper:]' '[:lower:]')
  local showCmd
  if [[ "$lowerId" == *"/policysetdefinitions/"* ]]; then
    showCmd=(az policy set-definition show --id "$defId" --query displayName -o tsv)
  else
    showCmd=(az policy definition show --id "$defId" --query displayName -o tsv)
  fi
  local dn
  if dn=$("${showCmd[@]}" 2>/dev/null); then
    local dnLower=$(echo "$dn" | tr '[:upper:]' '[:lower:]')
    echo "${defId}|${dnLower}" >> "$PD_CACHE"
    echo "$dnLower"
  else
    echo "" >> "$PD_CACHE"
    echo ""
  fi
}

count_total=$(echo "$ASSIGNMENTS_RAW" | az dataplane transform --only-show-errors --output tsv --query 'length(@)' 2>/dev/null || echo 0)
vlog "Total assignments retrieved: $count_total"

# Extract id, name, policyDefinitionId using az's JMESPath (avoid jq dependency)
ASSIGNMENTS_TSV=$(echo "$ASSIGNMENTS_RAW" | az dataplane transform --only-show-errors -o tsv --query "[].[id,name,policyDefinitionId]") || true

while IFS=$'\t' read -r aId aName aPolicyDefId; do
  [[ -z "$aId" ]] && continue
  aPolicyDefIdLower=$(echo "$aPolicyDefId" | tr '[:upper:]' '[:lower:]')
  match=false
  if $is_full_id; then
    if [[ "$aPolicyDefIdLower" == "$POLICY_INPUT_LOWER" ]]; then match=true; fi
  elif $is_guid; then
    # Compare trailing GUID segment
    trailingGuid=$(echo "$aPolicyDefIdLower" | sed 's:.*/::')
    if [[ "$trailingGuid" == "$POLICY_INPUT_LOWER" ]]; then match=true; fi
  else
    # Display name match (case-insensitive)
    dnLower=$(get_cached_display_name_lower "$aPolicyDefId")
    if [[ "$dnLower" == "$POLICY_INPUT_LOWER" ]]; then match=true; fi
  fi
  if $match; then
    MATCHED_ASSIGNMENTS+="$aId\t$aName\n"
  fi
done <<< "$ASSIGNMENTS_TSV"

if [[ -z "$MATCHED_ASSIGNMENTS" ]]; then
  warn "No policy assignments matched policy filter: $POLICY_INPUT"
  exit 0
fi

ASSIGNMENTS="$MATCHED_ASSIGNMENTS"
log "Found $(echo "$ASSIGNMENTS" | grep -c '.') matching assignment(s)."

create_exemption() {
  local assignmentId="$1" assignmentName="$2"
  # Stable short name based on assignmentId hash
  local hashPart
  if command -v md5 >/dev/null 2>&1; then
    hashPart=$(echo -n "$assignmentId" | md5 | cut -c1-8)
  else
    hashPart=$(echo -n "$assignmentId" | shasum | cut -c1-8)
  fi
  local exemptionName="ex-${EXEMPTION_SCOPE_NAME}-${hashPart}"
  local displayName="Exemption for ${assignmentName} on ${EXEMPTION_SCOPE_NAME}"

  # Check if an exemption with same name already exists
  if az policy exemption show --name "$exemptionName" --scope "$EXEMPTION_SCOPE_ID" >/dev/null 2>&1; then
    log "Exemption already exists: $exemptionName (scope: $EXEMPTION_SCOPE_ID) - skipping"
    return 0
  fi

  if $DRY_RUN; then
    log "[DRY-RUN] Would create exemption '$exemptionName' for assignment '$assignmentName'"
    return 0
  fi

  log "Creating exemption '$exemptionName' for assignment '$assignmentName'"
  az policy exemption create \
    --name "$exemptionName" \
    --scope "$EXEMPTION_SCOPE_ID" \
    --policy-assignment "$assignmentId" \
    --exemption-category "$EXEMPTION_CATEGORY" \
    --display-name "$displayName" \
    --description "$REASON" \
    --only-show-errors 1>/dev/null

  log "Created exemption: $exemptionName"
}

while IFS=$'\t' read -r assignmentId assignmentName; do
  vlog "Processing assignment: $assignmentName ($assignmentId)"
  create_exemption "$assignmentId" "$assignmentName"
done <<< "$ASSIGNMENTS"

log "Completed processing exemptions."
