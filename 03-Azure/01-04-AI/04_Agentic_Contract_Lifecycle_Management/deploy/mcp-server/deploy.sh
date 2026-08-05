#!/usr/bin/env bash
# =============================================================================
# Challenge 4 · Deploy the CLM MCP server to Azure Container Apps (remote MCP)
# -----------------------------------------------------------------------------
# Builds the image in the cloud (no local Docker needed) and prints the /mcp URL
# a Foundry agent connects to. Run this from the REPO ROOT so the Docker build
# context (requirements.txt + src/) is correct.
#
# Prereqs:
#   - az CLI logged in:            az login
#   - Your Challenge 1 lab resource group + Foundry project (.env values)
#
# Usage (from repo root):
#   RESOURCE_GROUP=<your-lab-rg> \
#   AZURE_AI_PROJECT_ENDPOINT=<your-project-endpoint> \
#   FOUNDRY_ACCOUNT_ID=<your-foundry-account-resource-id> \
#     bash deploy/mcp-server/deploy.sh
# =============================================================================
set -euo pipefail

# ---- Inputs (override via env) ----------------------------------------------
APP_NAME="${APP_NAME:-clm-mcp}"
RESOURCE_GROUP="${RESOURCE_GROUP:?set RESOURCE_GROUP to your lab resource group}"
LOCATION="${LOCATION:-swedencentral}"
PROJECT_ENDPOINT="${AZURE_AI_PROJECT_ENDPOINT:?set AZURE_AI_PROJECT_ENDPOINT (from your .env)}"
MODEL_ORCHESTRATOR="${MODEL_ORCHESTRATOR:-gpt-5.4}"
MODEL_DRAFTING="${MODEL_DRAFTING:-gpt-5.4}"
MODEL_CLAUSE_RISK="${MODEL_CLAUSE_RISK:-gpt-5.6-sol}"
# The Azure AI Services / Foundry account backing your project. Needed to grant
# the container's managed identity access to your model deployments. Find it with:
#   az cognitiveservices account list -g "$RESOURCE_GROUP" --query "[].id" -o tsv
FOUNDRY_ACCOUNT_ID="${FOUNDRY_ACCOUNT_ID:-}"

echo "==> Ensuring the containerapp CLI extension + providers are ready"
az extension add --name containerapp --upgrade --only-show-errors >/dev/null || true
az provider register --namespace Microsoft.App --wait >/dev/null || true
az provider register --namespace Microsoft.OperationalInsights --wait >/dev/null || true

echo "==> Building + deploying '$APP_NAME' to Azure Container Apps (image builds in the cloud)"
az containerapp up \
  --name "$APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --source . \
  --ingress external \
  --target-port 8000 \
  --env-vars \
      "AZURE_AI_PROJECT_ENDPOINT=$PROJECT_ENDPOINT" \
      "MODEL_ORCHESTRATOR=$MODEL_ORCHESTRATOR" \
      "MODEL_DRAFTING=$MODEL_DRAFTING" \
      "MODEL_CLAUSE_RISK=$MODEL_CLAUSE_RISK" \
      "MCP_TRANSPORT=streamable-http" \
      "MCP_PORT=8000"

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
