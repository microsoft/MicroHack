#!/usr/bin/env bash
# =============================================================================
# Challenge 4 · Deploy the CLM MCP server to Azure Container Apps (remote MCP)
# -----------------------------------------------------------------------------
# Builds the image in the cloud (no local Docker needed) and prints the /mcp URL
# a Foundry agent connects to. Run this from the REPO ROOT; the Docker build
# context is the src/ folder (Dockerfile + requirements.txt + app code).
#
# ZERO-CONFIG by default: it reads your repo-root `.env` (the same file the
# agents use) for AZURE_AI_PROJECT_ENDPOINT + MODEL_*, then auto-discovers the
# resource group, Foundry account id and region from that endpoint. So usually:
#
#     bash deploy/mcp-server/deploy.sh          # from the repo root, no args
#
# Everything is still overridable via env vars (RESOURCE_GROUP, LOCATION,
# FOUNDRY_ACCOUNT_ID, AZURE_AI_PROJECT_ENDPOINT, APP_NAME, MODEL_*).
#
# Prereqs: az CLI logged in (`az login`) on your lab subscription, and a filled
# `.env` (Challenge 1's deploy script autofills it).
# =============================================================================
set -euo pipefail

# ---- Load repo-root .env (only fills vars you haven't already set) ----------
ENV_FILE="${ENV_FILE:-.env}"
if [[ -f "$ENV_FILE" ]]; then
  echo "==> Reading $ENV_FILE"
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%$'\r'}"                       # strip CRLF (Windows-edited .env)
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ "$line" != *=* ]] && continue
    key="${line%%=*}"; val="${line#*=}"
    key="$(echo "$key" | xargs)"               # trim whitespace around the name
    [[ -z "$key" ]] && continue
    [[ -z "${!key:-}" ]] && export "$key=$val" # don't clobber an explicit override
  done < "$ENV_FILE"
fi

# ---- Inputs (all overridable via env) ---------------------------------------
APP_NAME="${APP_NAME:-clm-mcp}"
PROJECT_ENDPOINT="${AZURE_AI_PROJECT_ENDPOINT:?set AZURE_AI_PROJECT_ENDPOINT (in .env or env)}"
MODEL_ORCHESTRATOR="${MODEL_ORCHESTRATOR:-gpt-5.4}"
MODEL_DRAFTING="${MODEL_DRAFTING:-gpt-5.4}"
MODEL_CLAUSE_RISK="${MODEL_CLAUSE_RISK:-gpt-5.6-sol}"
RESOURCE_GROUP="${RESOURCE_GROUP:-}"
LOCATION="${LOCATION:-}"
FOUNDRY_ACCOUNT_ID="${FOUNDRY_ACCOUNT_ID:-}"

# ---- Auto-discover RG / Foundry account / region from the project endpoint --
# Endpoint looks like https://<account>.services.ai.azure.com/api/projects/<proj>
# so the first host label is the Foundry (Azure AI Services) account name.
if [[ -z "$FOUNDRY_ACCOUNT_ID" || -z "$RESOURCE_GROUP" || -z "$LOCATION" ]]; then
  host="${PROJECT_ENDPOINT#*://}"; host="${host%%/*}"
  account="${host%%.*}"
  echo "==> Discovering the Foundry account '$account' in your subscription"
  read -r d_id d_rg d_loc < <(az cognitiveservices account list \
      --query "[?name=='$account'].[id,resourceGroup,location] | [0]" -o tsv 2>/dev/null || true)
  if [[ -z "${d_id:-}" ]]; then   # name didn't match (e.g. custom domain) → first account
    read -r d_id d_rg d_loc < <(az cognitiveservices account list \
        --query "[0].[id,resourceGroup,location]" -o tsv 2>/dev/null || true)
    [[ -n "${d_id:-}" ]] && echo "    (no exact name match — using the first AI account found)"
  fi
  FOUNDRY_ACCOUNT_ID="${FOUNDRY_ACCOUNT_ID:-${d_id:-}}"
  RESOURCE_GROUP="${RESOURCE_GROUP:-${d_rg:-}}"
  LOCATION="${LOCATION:-${d_loc:-}}"
fi
# Last-resort fallbacks
[[ -z "$RESOURCE_GROUP" && -n "$FOUNDRY_ACCOUNT_ID" ]] && \
  RESOURCE_GROUP="$(sed -E 's#.*/resourceGroups/([^/]+)/.*#\1#' <<<"$FOUNDRY_ACCOUNT_ID")"
LOCATION="${LOCATION:-swedencentral}"
: "${RESOURCE_GROUP:?could not determine RESOURCE_GROUP — set it explicitly (az login done?)}"

echo "==> Using:"
echo "    resource group   = $RESOURCE_GROUP"
echo "    region           = $LOCATION"
echo "    Foundry account  = ${FOUNDRY_ACCOUNT_ID:-<none found — role grant will be skipped>}"
echo "    project endpoint = $PROJECT_ENDPOINT"

echo "==> Ensuring the containerapp CLI extension + providers are ready"
az extension add --name containerapp --upgrade --only-show-errors >/dev/null || true
# Provider registration is a SUBSCRIPTION-scope action. In a resource-group lab you
# only own the RG, so re-registering fails with AuthorizationFailed — but the platform
# already registered these when it provisioned the lab. Check first; only try to register
# if actually needed, and never let it abort the deploy.
for ns in Microsoft.App Microsoft.OperationalInsights; do
  state=$(az provider show --namespace "$ns" --query registrationState -o tsv 2>/dev/null || true)
  if [ "$state" = "Registered" ]; then
    echo "    $ns already registered"
  else
    echo "    registering $ns (needs subscription rights; skipping if not allowed)"
    az provider register --namespace "$ns" --only-show-errors >/dev/null 2>&1 || true
  fi
done

echo "==> Building + deploying '$APP_NAME' to Azure Container Apps (image builds in the cloud)"
set +e   # handle a cloud-build failure with a clear message instead of a bare abort
az containerapp up \
  --name "$APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --source src \
  --ingress external \
  --target-port 8000 \
  --env-vars \
      "AZURE_AI_PROJECT_ENDPOINT=$PROJECT_ENDPOINT" \
      "MODEL_ORCHESTRATOR=$MODEL_ORCHESTRATOR" \
      "MODEL_DRAFTING=$MODEL_DRAFTING" \
      "MODEL_CLAUSE_RISK=$MODEL_CLAUSE_RISK" \
      "MCP_TRANSPORT=streamable-http" \
      "MCP_PORT=8000"
up_rc=$?
set -e
if [ "$up_rc" -ne 0 ]; then
  echo "" >&2
  echo "!! 'az containerapp up' failed (exit $up_rc) - stopping before the identity/role steps." >&2
  echo "   If the traceback mentions \"'NoneType' object has no attribute 'linux'\" (in queue_acr_build)," >&2
  echo "   your Azure CLI has the 2.86.0 cloud-build bug (Azure/azure-cli#33369)." >&2
  echo "   Fix: run 'az upgrade' (need >= 2.87.0) then 'az extension update -n containerapp', and re-run -" >&2
  echo "   the half-created ACR + Container Apps environment are reused, so re-running is safe." >&2
  exit 1
fi

echo "==> Enabling the app's system-assigned managed identity"
az containerapp identity assign \
  --name "$APP_NAME" --resource-group "$RESOURCE_GROUP" --system-assigned >/dev/null
PRINCIPAL_ID="$(az containerapp show -n "$APP_NAME" -g "$RESOURCE_GROUP" \
  --query identity.principalId -o tsv)"
echo "    principalId = $PRINCIPAL_ID"

if [[ -n "$FOUNDRY_ACCOUNT_ID" ]]; then
  echo "==> Granting the identity access to your Foundry models"
  az role assignment create --assignee-object-id "$PRINCIPAL_ID" \
      --assignee-principal-type ServicePrincipal \
      --role "Azure AI User" --scope "$FOUNDRY_ACCOUNT_ID" >/dev/null \
  || az role assignment create --assignee-object-id "$PRINCIPAL_ID" \
      --assignee-principal-type ServicePrincipal \
      --role "Cognitive Services User" --scope "$FOUNDRY_ACCOUNT_ID" >/dev/null
  echo "    role assigned (identity propagation can take ~1 minute)"
else
  echo "!! FOUNDRY_ACCOUNT_ID not set — grant a data-plane role to the identity yourself:"
  echo "     az role assignment create --assignee-object-id $PRINCIPAL_ID \\"
  echo "       --assignee-principal-type ServicePrincipal \\"
  echo "       --role 'Azure AI User' --scope <your Foundry account resource id>"
fi

FQDN="$(az containerapp show -n "$APP_NAME" -g "$RESOURCE_GROUP" \
  --query properties.configuration.ingress.fqdn -o tsv)"
echo ""
echo "============================================================"
echo " clm-mcp is live. Use this MCP endpoint in Foundry / CLM_MCP_URL:"
echo "     https://$FQDN/mcp"
echo "============================================================"
