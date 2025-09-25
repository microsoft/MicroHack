#!/usr/bin/env bash
set -euo pipefail

# Deploy storage account using storageAccount.bicep
# Params:
#  -g (resource group) REQUIRED
#  -n storage account name (override) (optional)
#  -l location (optional)
#  -p allow public blob access true|false (default false)
#  -s sku (default Standard_LRS)
#  -t extra tags (key=value;key2=value2)
#  -f parameter file (alternative to individual flags)
#
# Examples:
#  ./deploy-storage.sh -g MyRG -n mystorageacct001 -l westeurope -p false -s Standard_LRS -t env=dev;owner=you
#  ./deploy-storage.sh -g MyRG -f storageAccount.parameters.json

RG=""
NAME=""
LOCATION=""
PUBLIC="false"
SKU="Standard_LRS"
TAGS=""
PARAM_FILE=""

while getopts ":g:n:l:p:s:t:f:h" opt; do
  case $opt in
    g) RG="$OPTARG" ;;
    n) NAME="$OPTARG" ;;
    l) LOCATION="$OPTARG" ;;
    p) PUBLIC="$OPTARG" ;;
    s) SKU="$OPTARG" ;;
    t) TAGS="$OPTARG" ;;
    f) PARAM_FILE="$OPTARG" ;;
    h)
      grep '^# ' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Invalid option -$OPTARG" >&2; exit 1 ;;
  esac
done

[[ -z "$RG" ]] && { echo "-g resource group required" >&2; exit 1; }

az account show >/dev/null 2>&1 || { echo "Run az login first" >&2; exit 1; }
az group show -n "$RG" >/dev/null 2>&1 || { echo "Resource group $RG not found" >&2; exit 1; }

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
TEMPLATE="$SCRIPT_DIR/storageAccount.bicep"
DEPLOY_NAME="storageAcct$(date +%Y%m%d%H%M%S)"

CLI_ARGS=(--name "$DEPLOY_NAME" --resource-group "$RG" --template-file "$TEMPLATE")

if [[ -n "$PARAM_FILE" ]]; then
  CLI_ARGS+=(--parameters "$PARAM_FILE")
else
  [[ -n "$NAME" ]] && CLI_ARGS+=(--parameters storageAccountName="$NAME")
  [[ -n "$LOCATION" ]] && CLI_ARGS+=(--parameters location="$LOCATION")
  CLI_ARGS+=(--parameters allowBlobPublicAccess=$PUBLIC)
  CLI_ARGS+=(--parameters skuName="$SKU")
  if [[ -n "$TAGS" ]]; then
    # Convert key=value;key2=value2 to JSON object string
    IFS=';' read -r -a PAIRS <<< "$TAGS"
    TAG_JSON="{"
    FIRST=1
    for kv in "${PAIRS[@]}"; do
      k="${kv%%=*}"; v="${kv#*=}"
      [[ $FIRST -eq 0 ]] && TAG_JSON+=" ,"
      TAG_JSON+=" \"$k\": \"$v\""
      FIRST=0
    done
    TAG_JSON+=" }"
    CLI_ARGS+=(--parameters tags="$TAG_JSON")
  fi
fi

echo "==> Deploying storage account (deployment name: $DEPLOY_NAME)"
az deployment group create "${CLI_ARGS[@]}"

echo "==> Done. Show outputs:"
echo "    az deployment group show -g $RG -n $DEPLOY_NAME --query properties.outputs"