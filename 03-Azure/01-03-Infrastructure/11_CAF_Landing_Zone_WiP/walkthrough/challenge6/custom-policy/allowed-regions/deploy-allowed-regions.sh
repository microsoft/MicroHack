#!/usr/bin/env bash
set -euo pipefail

# Deploy and assign the custom Allowed Regions policy using Bicep templates.
# This script deploys the policy definition at subscription scope and then
# assigns it to a specified resource group.
#
# Requirements:
#  - Azure CLI logged in (az login)
#  - Appropriate RBAC: Policy Contributor (definition) + Resource Policy Contributor / Owner on target RG
#  - Bicep CLI (bundled in az CLI >= 2.20)
#
# Usage examples:
#  ./deploy-allowed-regions.sh -g MyWorkloadRG -r "eastus westeurope" \
#      -d custom-allowed-regions -a custom-allowed-regions-assignment -l eastus
#
# Flags:
#  -g  Target resource group name (required)
#  -r  Space-separated list of allowed regions (required)
#  -d  Policy definition name (default: custom-allowed-regions)
#  -a  Policy assignment name (default: custom-allowed-regions-assignment)
#  -l  Deployment location for the sub-level deployments (default: eastus)
#  -e  Enforcement mode (Default|DoNotEnforce) (default: Default)
#  -h  Help

DEF_NAME="custom-allowed-regions"
ASSIGN_NAME="custom-allowed-regions-assignment"
DEPLOY_LOCATION="eastus"
ENFORCEMENT_MODE="Default"
TARGET_RG=""
ALLOWED_REGIONS=()

while getopts ":g:r:d:a:l:e:h" opt; do
  case ${opt} in
    g) TARGET_RG="$OPTARG" ;;
    r) IFS=' ' read -r -a ALLOWED_REGIONS <<< "$OPTARG" ;;
    d) DEF_NAME="$OPTARG" ;;
    a) ASSIGN_NAME="$OPTARG" ;;
    l) DEPLOY_LOCATION="$OPTARG" ;;
    e) ENFORCEMENT_MODE="$OPTARG" ;;
    h)
      grep '^# ' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "Invalid option: -$OPTARG" >&2; exit 1 ;;
  esac
done

if [[ -z "$TARGET_RG" || ${#ALLOWED_REGIONS[@]} -eq 0 ]]; then
  echo "ERROR: Resource group (-g) and allowed regions (-r) are required." >&2
  exit 1
fi

if [[ "$ENFORCEMENT_MODE" != "Default" && "$ENFORCEMENT_MODE" != "DoNotEnforce" ]]; then
  echo "ERROR: enforcement mode must be 'Default' or 'DoNotEnforce'" >&2
  exit 1
fi

echo "==> Verifying Azure CLI login..."
az account show >/dev/null 2>&1 || { echo "Please run 'az login' first." >&2; exit 1; }

echo "==> Checking that resource group '$TARGET_RG' exists..."
if ! az group show -n "$TARGET_RG" >/dev/null 2>&1; then
  echo "ERROR: Resource group '$TARGET_RG' not found." >&2
  exit 1
fi

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
DEF_FILE="$SCRIPT_DIR/policyDefinition.bicep"
ASSIGN_FILE="$SCRIPT_DIR/policyAssignment.bicep"

if [[ ! -f "$DEF_FILE" || ! -f "$ASSIGN_FILE" ]]; then
  echo "ERROR: Bicep files not found next to script." >&2
  exit 1
fi

# Build JSON array string for allowedLocations parameter.
ALLOWED_JSON=$(printf '"%s",' "${ALLOWED_REGIONS[@]}")
ALLOWED_JSON="[${ALLOWED_JSON%,}]"

STAMP=$(date +%Y%m%d%H%M%S)

echo "==> Deploying policy definition '$DEF_NAME' (definition does not need allowed locations values)"
az deployment sub create \
  --name "${DEF_NAME}-def-${STAMP}" \
  --location "$DEPLOY_LOCATION" \
  --template-file "$DEF_FILE" \
  --parameters policyDefinitionName="$DEF_NAME"

echo "==> Deploying policy assignment '$ASSIGN_NAME' to resource group '$TARGET_RG'"
az deployment sub create \
  --name "${ASSIGN_NAME}-assign-${STAMP}" \
  --location "$DEPLOY_LOCATION" \
  --template-file "$ASSIGN_FILE" \
  --parameters assignmentName="$ASSIGN_NAME" policyDefinitionName="$DEF_NAME" \
               targetResourceGroupName="$TARGET_RG" allowedLocations="$ALLOWED_JSON" \
               enforcementMode="$ENFORCEMENT_MODE"

echo "==> Completed. Verification suggestions:"
echo "    az policy assignment list --query \"[?name=='$ASSIGN_NAME']\""
echo "    az policy state summarize --resource-group '$TARGET_RG'"