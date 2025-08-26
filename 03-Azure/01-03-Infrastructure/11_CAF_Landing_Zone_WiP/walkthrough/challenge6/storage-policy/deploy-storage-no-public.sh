#!/usr/bin/env bash
set -euo pipefail

# Deploy a policy assignment that enforces no public blob access for storage accounts in a resource group.
# The script discovers the built-in policy definition name (GUID) using its display name unless one is provided.
#
# Built-in policy display name commonly used: "Storage accounts should disallow public blob access"
# If Microsoft renames the policy, override with -i <definitionId> or -n <definitionName>.
#
# Usage:
#  ./deploy-storage-no-public.sh -g MyRG
#  ./deploy-storage-no-public.sh -g MyRG -a customAssignName -m DoNotEnforce
#  ./deploy-storage-no-public.sh -g MyRG -n <definitionNameGuid>
#  ./deploy-storage-no-public.sh -g MyRG -i /providers/Microsoft.Authorization/policyDefinitions/<guid>
#
# Requirements: az CLI logged in & correct subscription selected.

ASSIGN_NAME="enforce-storage-no-public-blob"
DISPLAY_NAME="Deny storage public blob access"
DESCRIPTION="Ensures storage accounts in this resource group do not permit public blob access."
RG_NAME=""
LOCATION="eastus" # deployment location (subscription deployment requirement)
ENFORCEMENT_MODE="Default"
POLICY_DEF_NAME=""      # GUID (name) of the policy definition
POLICY_DEF_ID=""        # Full resource ID
POLICY_DISPLAY_NAME="Storage accounts should disallow public blob access"

while getopts ":g:a:l:m:n:i:d:h" opt; do
  case $opt in
    g) RG_NAME="$OPTARG" ;;
    a) ASSIGN_NAME="$OPTARG" ;;
    l) LOCATION="$OPTARG" ;;
    m) ENFORCEMENT_MODE="$OPTARG" ;;
    n) POLICY_DEF_NAME="$OPTARG" ;;
    i) POLICY_DEF_ID="$OPTARG" ;;
    d) DISPLAY_NAME="$OPTARG" ;;
    h)
      grep '^# ' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "Invalid option: -$OPTARG" >&2; exit 1 ;;
  esac
done

if [[ -z "$RG_NAME" ]]; then
  echo "ERROR: Resource group (-g) is required." >&2
  exit 1
fi

if [[ "$ENFORCEMENT_MODE" != "Default" && "$ENFORCEMENT_MODE" != "DoNotEnforce" ]]; then
  echo "ERROR: Enforcement mode must be Default or DoNotEnforce" >&2
  exit 1
fi

echo "==> Ensuring az login context"
az account show >/dev/null 2>&1 || { echo "Run 'az login' first." >&2; exit 1; }

echo "==> Checking resource group '$RG_NAME' exists"
az group show -n "$RG_NAME" >/dev/null 2>&1 || { echo "Resource group '$RG_NAME' not found" >&2; exit 1; }

if [[ -z "$POLICY_DEF_ID" && -z "$POLICY_DEF_NAME" ]]; then
  echo "==> Resolving built-in policy definition name by displayName: $POLICY_DISPLAY_NAME"
  POLICY_DEF_NAME=$(az policy definition list --query "[?displayName=='$POLICY_DISPLAY_NAME'].name | [0]" -o tsv)
  if [[ -z "$POLICY_DEF_NAME" ]]; then
    echo "ERROR: Could not resolve built-in policy by display name. Use -n <nameGuid> or -i <fullId>." >&2
    exit 1
  fi
fi

if [[ -z "$POLICY_DEF_ID" ]]; then
  POLICY_DEF_ID="/providers/Microsoft.Authorization/policyDefinitions/$POLICY_DEF_NAME"
fi

STAMP=$(date +%Y%m%d%H%M%S)
TEMPLATE_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
TEMPLATE_FILE="$TEMPLATE_DIR/storageNoPublicAccessAssignment.bicep"

echo "==> Deploying policy assignment $ASSIGN_NAME to RG $RG_NAME using definition $POLICY_DEF_ID"
az deployment sub create \
  --name "${ASSIGN_NAME}-${STAMP}" \
  --location "$LOCATION" \
  --template-file "$TEMPLATE_FILE" \
  --parameters assignmentName="$ASSIGN_NAME" \
               displayName="$DISPLAY_NAME" \
               assignmentDescription="$DESCRIPTION" \
               targetResourceGroupName="$RG_NAME" \
               policyDefinitionId="$POLICY_DEF_ID" \
               enforcementMode="$ENFORCEMENT_MODE"

echo "==> Done. Verify with: az policy assignment list --resource-group $RG_NAME --query \"[?name=='$ASSIGN_NAME']\""
