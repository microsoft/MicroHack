#!/usr/bin/env bash
# =============================================================================
# Challenge 5 · Deploy the Teams "capture reference" bot to Azure Container Apps
# -----------------------------------------------------------------------------
# Removes the local run + dev tunnel from Task 6: builds the bot image in the
# cloud (no local Docker) and gives you a stable public HTTPS messaging endpoint
# to paste into your Azure Bot. You still message the bot once in Teams — it then
# echoes TEAMS_SERVICE_URL + TEAMS_CONVERSATION_ID back in the chat so you can
# paste them into your local .env and run proactive_alerts.py.
#
# Run from the REPO ROOT so the Docker build context (requirements.txt + src/)
# is correct:
#
#     bash deploy/capture-bot/deploy.sh          # zero-config, reads .env
#
# Needs in .env (from Task 6 step 1 — your OWN single-tenant app):
#     MICROSOFT_APP_ID, MICROSOFT_APP_PASSWORD, MICROSOFT_APP_TENANT_ID
# Resource group / region are auto-discovered from AZURE_AI_PROJECT_ENDPOINT so
# the bot lands next to the rest of the lab (override with RESOURCE_GROUP /
# LOCATION). This bot calls NO Foundry models, so it needs no managed identity.
#
# Prereq: az CLI logged in (`az login`) on your lab subscription.
# Note: the app secret is passed as a plain container env var here for lab
# simplicity — this bot is throwaway; delete it (and its app) when done.
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
APP_NAME="${APP_NAME:-clm-capture-bot}"
APP_ID="${MICROSOFT_APP_ID:?set MICROSOFT_APP_ID — your OWN single-tenant app (Task 6 step 1)}"
APP_PASSWORD="${MICROSOFT_APP_PASSWORD:?set MICROSOFT_APP_PASSWORD — the client-secret Value}"
APP_TENANT="${MICROSOFT_APP_TENANT_ID:?set MICROSOFT_APP_TENANT_ID — your directory (tenant) id}"
RESOURCE_GROUP="${RESOURCE_GROUP:-}"
LOCATION="${LOCATION:-}"
PROJECT_ENDPOINT="${AZURE_AI_PROJECT_ENDPOINT:-}"

# ---- Auto-discover RG / region from the Foundry project endpoint ------------
# Endpoint looks like https://<account>.services.ai.azure.com/api/projects/<proj>
# so the first host label is the Foundry (Azure AI Services) account name; we use
# it only to place this bot in the same resource group / region as the lab.
if [[ ( -z "$RESOURCE_GROUP" || -z "$LOCATION" ) && -n "$PROJECT_ENDPOINT" ]]; then
  host="${PROJECT_ENDPOINT#*://}"; host="${host%%/*}"; account="${host%%.*}"
  echo "==> Discovering the lab resource group from '$account'"
  read -r d_rg d_loc < <(az cognitiveservices account list \
      --query "[?name=='$account'].[resourceGroup,location] | [0]" -o tsv 2>/dev/null || true)
  if [[ -z "${d_rg:-}" ]]; then   # name didn't match (custom domain) → first account
    read -r d_rg d_loc < <(az cognitiveservices account list \
        --query "[0].[resourceGroup,location]" -o tsv 2>/dev/null || true)
  fi
  RESOURCE_GROUP="${RESOURCE_GROUP:-${d_rg:-}}"
  LOCATION="${LOCATION:-${d_loc:-}}"
fi
LOCATION="${LOCATION:-swedencentral}"
: "${RESOURCE_GROUP:?could not determine RESOURCE_GROUP — set it explicitly (az login done?)}"

echo "==> Using:"
echo "    app name       = $APP_NAME"
echo "    resource group = $RESOURCE_GROUP"
echo "    region         = $LOCATION"
echo "    bot app id     = $APP_ID"

echo "==> Ensuring the containerapp CLI extension + providers are ready"
az extension add --name containerapp --upgrade --only-show-errors >/dev/null || true
az provider register --namespace Microsoft.App --wait >/dev/null || true
az provider register --namespace Microsoft.OperationalInsights --wait >/dev/null || true

# The shared Dockerfile runs the capture bot when APP_ROLE=capture-bot, and binds
# 0.0.0.0 (via CAPTURE_BOT_HOST) so the Container Apps ingress can reach :3978.
echo "==> Building + deploying '$APP_NAME' to Azure Container Apps (image builds in the cloud)"
az containerapp up \
  --name "$APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --source . \
  --ingress external \
  --target-port 3978 \
  --env-vars \
      "APP_ROLE=capture-bot" \
      "CAPTURE_BOT_HOST=0.0.0.0" \
      "CAPTURE_BOT_PORT=3978" \
      "MICROSOFT_APP_ID=$APP_ID" \
      "MICROSOFT_APP_PASSWORD=$APP_PASSWORD" \
      "MICROSOFT_APP_TENANT_ID=$APP_TENANT"

FQDN="$(az containerapp show -n "$APP_NAME" -g "$RESOURCE_GROUP" \
  --query properties.configuration.ingress.fqdn -o tsv)"
echo ""
echo "============================================================"
echo " clm-capture-bot is live. Set this as your Azure Bot's Messaging endpoint"
echo " (your Bot -> Configuration -> Messaging endpoint -> Apply):"
echo ""
echo "     https://$FQDN/api/messages"
echo ""
echo " Then: your Bot -> Channels -> Microsoft Teams -> Open in Teams -> send 'hi'."
echo " The bot replies with TEAMS_SERVICE_URL + TEAMS_CONVERSATION_ID — paste those"
echo " two lines into your local .env, then fire the alert:"
echo "     python src/proactive_alerts.py --from-renewals --days 30"
echo ""
echo " Missed the reply? Read the values from the logs:"
echo "     az containerapp logs show -n $APP_NAME -g $RESOURCE_GROUP --tail 50"
echo ""
echo " Clean up when done:"
echo "     az containerapp delete -n $APP_NAME -g $RESOURCE_GROUP --yes"
echo "============================================================"
