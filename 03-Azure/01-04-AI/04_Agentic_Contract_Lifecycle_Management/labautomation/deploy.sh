#!/usr/bin/env bash
# ==========================================================================
# Challenge 1 — provision the Foundry CLM microhack resources and write .env
# ==========================================================================
# Usage:   ./labautomation/deploy.sh [--with-sql] [--with-bing]
# Requires: az CLI (logged in via `az login`), an Azure subscription with
#           rights to deploy GPT and Anthropic Claude models.
#
# NOTE: Model + region availability changes over time. Confirm your target
#       region offers gpt-5.4, gpt-5-mini, gpt-5.6-sol AND Claude Opus 4.8 in the
#       Foundry model catalog before running. See the challenge-0 README.
# ==========================================================================
set -euo pipefail

# ---- Configuration (override via environment) ----------------------------
LOCATION="${LOCATION:-swedencentral}"
SUFFIX="${SUFFIX:-$(echo $RANDOM | md5sum 2>/dev/null | cut -c1-5 || echo $RANDOM)}"
RG="${RG:-rg-clm-microhack}"
FOUNDRY="${FOUNDRY:-clmfoundry${SUFFIX}}"
PROJECT="${PROJECT:-clm-project}"
SEARCH="${SEARCH:-clmsearch${SUFFIX}}"
APPINSIGHTS="${APPINSIGHTS:-clm-appinsights}"
WITH_SQL="false"
WITH_BING="false"
for arg in "$@"; do
  case "$arg" in
    --with-sql)  WITH_SQL="true" ;;
    --with-bing) WITH_BING="true" ;;
  esac
done

# Model deployments (name=catalog-model:version:format)
GPT_ORCH="gpt-5.4"
GPT_MINI="gpt-5-mini"
GPT56SOL="gpt-5.6-sol"
CLAUDE="claude-opus-4-8"

# Claude can be skipped when the subscription has no Anthropic quota or the
# marketplace offer is unavailable: run with DEPLOY_CLAUDE=false. The
# drafting agent then falls back to the GPT orchestrator deployment (Clause & Risk stays on gpt-5.6-sol).
# When DEPLOY_CLAUDE is NOT set, auto-probe Anthropic Claude Opus 4.8 quota in
# $LOCATION and skip Claude when it is 0 — otherwise the deployment fails with
# "InsufficientQuota ... Claude Opus 4.8 ... available capacity 0". Availability !=
# quota: even in a region that offers the model a fresh sandbox sub usually starts at 0.
claude_quota_ok () {  # region [required-capacity] -> exit 0 if deployable
  local region="$1" required="${2:-20}" sub_id url json limit used avail
  sub_id=$(az account show --query id -o tsv 2>/dev/null || echo "")
  if [[ -z "$sub_id" ]]; then
    echo "  · Claude preflight: could not resolve subscription id (run az login) — skipping Claude (GPT-only)." >&2
    return 1
  fi
  url="https://management.azure.com/subscriptions/${sub_id}/providers/Microsoft.CognitiveServices/locations/${region}/usages?api-version=2024-10-01"
  json=$(az rest --method get --url "$url" -o json 2>/dev/null || echo "")
  if [[ -z "$json" ]]; then
    echo "  · Claude preflight: usages query failed for $region — skipping Claude (GPT-only). Set DEPLOY_CLAUDE=true to force it." >&2
    return 1
  fi
  # Prefer the exact quota family; fall back to any entry mentioning the model.
  read -r limit used < <(printf '%s' "$json" | python3 -c '
import json,sys
data=json.load(sys.stdin).get("value",[])
fam="AIServices.GlobalStandard.claude-opus-4-8"
def nm(e):
    n=e.get("name"); return n.get("value","") if isinstance(n,dict) else str(n or "")
e=next((u for u in data if nm(u)==fam),None)
if e is None:
    c=[u for u in data if "claude-opus-4-8" in nm(u)]
    c.sort(key=lambda u: float(u.get("limit",0) or 0), reverse=True)
    e=c[0] if c else None
if e is None: print("0 0")
else: print(float(e.get("limit",0) or 0), float(e.get("currentValue",0) or 0))
' 2>/dev/null || echo "0 0")
  avail=$(python3 -c "print(${limit:-0} - ${used:-0})" 2>/dev/null || echo "0")
  if python3 -c "import sys; sys.exit(0 if (${limit:-0} > 0 and ${avail:-0} >= ${required}) else 1)" 2>/dev/null; then
    echo "  ✓ Claude preflight: claude-opus-4-8 deployable in $region (limit=${limit}, used=${used})."
    return 0
  fi
  echo "  · Claude preflight: insufficient quota in $region (limit=${limit}, used=${used}, need=${required}) — skipping Claude (GPT-only)." >&2
  return 1
}

if [[ -z "${DEPLOY_CLAUDE:-}" ]]; then
  if claude_quota_ok "$LOCATION"; then DEPLOY_CLAUDE="true"; else DEPLOY_CLAUDE="false"; fi
fi
if [[ "$(printf '%s' "$DEPLOY_CLAUDE" | tr '[:upper:]' '[:lower:]')" == "true" ]]; then
  DRAFTING_MODEL="$CLAUDE"
else
  DRAFTING_MODEL="$GPT_ORCH"
fi

# Anthropic Marketplace attestation — REQUIRED by the Cognitive Services RP for
# every Claude deployment (it auto-accepts the marketplace offer on your behalf).
# Override to describe your organisation: CLAUDE_ORGANIZATION_NAME / _COUNTRY_CODE /
# _INDUSTRY. Omitting these is what triggers InvalidModelProviderData.
CLAUDE_ORGANIZATION_NAME="${CLAUDE_ORGANIZATION_NAME:-Contoso}"
CLAUDE_COUNTRY_CODE="${CLAUDE_COUNTRY_CODE:-US}"
CLAUDE_INDUSTRY="${CLAUDE_INDUSTRY:-technology}"

echo "▶ Resource group:  $RG ($LOCATION)"
echo "▶ Foundry account: $FOUNDRY / project $PROJECT"

# ---- 1. Resource group ---------------------------------------------------
az group create -n "$RG" -l "$LOCATION" -o none

# ---- 2. Foundry (AI Services) account + project --------------------------
az cognitiveservices account create \
  -n "$FOUNDRY" -g "$RG" -l "$LOCATION" \
  --kind AIServices --sku S0 --custom-domain "$FOUNDRY" \
  --yes -o none
echo "  ✓ Foundry account created"

# Create the Foundry project (preview CLI extension may be required:
#   az extension add --name ai-foundry   OR create the project in the portal).
az cognitiveservices account project create \
  --account-name "$FOUNDRY" -g "$RG" --project-name "$PROJECT" -o none \
  || echo "  ! Project create via CLI unavailable — create '$PROJECT' in the Foundry portal, then re-run to fetch the endpoint."

# ---- 3. Model deployments (GPT + Claude) ---------------------------------
deploy_model () {  # name  model-name  version  format  sku-capacity
  echo "  → deploying $1 ($4 $2 v$3)"
  az cognitiveservices account deployment create \
    -n "$FOUNDRY" -g "$RG" \
    --deployment-name "$1" \
    --model-name "$2" --model-version "$3" --model-format "$4" \
    --sku-name "GlobalStandard" --sku-capacity "${5:-20}" -o none \
    || echo "    ! $1 deployment failed — check the model is available in $LOCATION."
}
# gpt-5.4 orchestrator: swedencentral offers the base gpt-5.4 flagship directly.
# Confirm the exact model/version in your region's Foundry catalog.
deploy_model "$GPT_ORCH" "gpt-5.4"          "2026-03-05" "OpenAI"    30
# Renewal / lightweight agent: gpt-4o-mini is deprecating in swedencentral, so
# deploy gpt-5-mini instead (same GlobalStandard SKU, later deprecation date).
deploy_model "$GPT_MINI" "gpt-5-mini"       "2025-08-07" "OpenAI"    30
# Clause & Risk runs on gpt-5.6-sol — its own deployment, independent of Claude.
deploy_model "$GPT56SOL" "gpt-5.6-sol"      "2026-07-09" "OpenAI"    30
# Claude: Anthropic deployments REQUIRE a modelProviderData block that the
# `az cognitiveservices account deployment create` CLI can't send, so deploy it
# via the ARM REST API instead (auto-accepts the marketplace offer, avoiding
# InvalidModelProviderData). Version is the date-stamped Azure catalog version.
deploy_claude () {
  local sub_id url state i
  sub_id=$(az account show --query id -o tsv)
  url="https://management.azure.com/subscriptions/${sub_id}/resourceGroups/${RG}/providers/Microsoft.CognitiveServices/accounts/${FOUNDRY}/deployments/${CLAUDE}?api-version=2025-04-01-preview"
  echo "  → deploying $CLAUDE (Anthropic claude-opus-4-8 v2) with modelProviderData"
  if ! az rest --method put --url "$url" \
      --body "{\"sku\":{\"name\":\"GlobalStandard\",\"capacity\":20},\"properties\":{\"model\":{\"format\":\"Anthropic\",\"name\":\"claude-opus-4-8\",\"version\":\"2\"},\"modelProviderData\":{\"organizationName\":\"${CLAUDE_ORGANIZATION_NAME}\",\"countryCode\":\"${CLAUDE_COUNTRY_CODE}\",\"industry\":\"${CLAUDE_INDUSTRY}\"}}}" -o none; then
    echo "    ! Claude deployment request failed — check Anthropic eligibility in $LOCATION, or set DEPLOY_CLAUDE=false to skip."
    return
  fi
  for i in $(seq 1 30); do
    state=$(az rest --method get --url "$url" --query "properties.provisioningState" -o tsv 2>/dev/null || echo "")
    case "$state" in
      Succeeded)       echo "    ✓ Claude deployment succeeded"; return ;;
      Failed|Canceled) echo "    ! Claude deployment $state — set DEPLOY_CLAUDE=false to skip."; return ;;
    esac
    sleep 10
  done
  echo "    · Claude still provisioning — check the Foundry portal before the smoke test."
}
if [[ "$DRAFTING_MODEL" == "$CLAUDE" ]]; then
  deploy_claude
else
  echo "  · Skipping Claude (DEPLOY_CLAUDE=false) — MODEL_DRAFTING uses $GPT_ORCH"
fi

# ---- 4. Azure AI Search (Foundry IQ backing store) -----------------------
az search service create \
  -n "$SEARCH" -g "$RG" -l "$LOCATION" \
  --sku basic --partition-count 1 --replica-count 1 -o none
echo "  ✓ Azure AI Search created"

# ---- 5. Corpus source: SharePoint (bring-your-own) -----------------------
# The contract PDFs live in a SharePoint document library (Microsoft 365, not an
# Azure resource — nothing to create here). src/scripts/seed_corpus.py creates the
# Azure AI Search SharePoint Online data source + indexer that crawls it into the
# clm-corpus index. Fill the SHAREPOINT_* values in .env first (see challenge-0 README).
echo "  · Corpus source is SharePoint (BYO) — set SHAREPOINT_* in .env, then run seed_corpus.py"

# ---- 6. Application Insights ---------------------------------------------
az monitor app-insights component create \
  --app "$APPINSIGHTS" -g "$RG" -l "$LOCATION" --kind web -o none
APPINSIGHTS_CONN=$(az monitor app-insights component show --app "$APPINSIGHTS" -g "$RG" --query connectionString -o tsv)
echo "  ✓ Application Insights created"

# Connect App Insights to the Foundry project so the portal Tracing tab renders
# spans. Creating the component alone is NOT enough — the project needs a
# connection to it, otherwise Tracing stays empty even when spans reach App
# Insights. (Challenge 3.)
APPINSIGHTS_ID=$(az monitor app-insights component show --app "$APPINSIGHTS" -g "$RG" --query id -o tsv)
SUB_ID=$(az account show --query id -o tsv)
PROJECT_ARM_ID="/subscriptions/${SUB_ID}/resourceGroups/${RG}/providers/Microsoft.CognitiveServices/accounts/${FOUNDRY}/projects/${PROJECT}"
if [[ -n "$APPINSIGHTS_ID" && -n "$APPINSIGHTS_CONN" ]]; then
  az rest --method put \
    --url "https://management.azure.com${PROJECT_ARM_ID}/connections/clm-appinsights?api-version=2025-04-01-preview" \
    --body "{\"properties\":{\"category\":\"AppInsights\",\"target\":\"${APPINSIGHTS_ID}\",\"authType\":\"ApiKey\",\"credentials\":{\"key\":\"${APPINSIGHTS_CONN}\"},\"isSharedToAll\":true,\"metadata\":{\"ApiType\":\"Azure\",\"ResourceId\":\"${APPINSIGHTS_ID}\"}}}" -o none \
    && echo "  ✓ Application Insights connected to project '$PROJECT' — portal Tracing enabled" \
    || echo "    ! App Insights connection failed — in the portal open project '$PROJECT' → Tracing → Connect and pick '$APPINSIGHTS'."
fi

# ---- 7. Grounding with Bing Search (optional web grounding) --------------
# Provisions a Bing.Grounding resource + a Foundry project connection (resolved
# by name AZURE_BING_CONNECTION_NAME) that the Clause & Risk agent's
# build_web_search_tool() attaches. Bing search data leaves the Azure compliance
# boundary — opt in only when web grounding is wanted.
BING_CONN_NAME=""
if [[ "$WITH_BING" == "true" ]]; then
  BING="clmbing${SUFFIX}"
  BING_CONN_NAME="clm-bing"
  echo "  → provisioning Grounding with Bing Search ($BING)"
  az provider register --namespace Microsoft.Bing -o none 2>/dev/null || true
  az resource create -g "$RG" -n "$BING" \
    --resource-type "Microsoft.Bing/accounts" --api-version "2020-06-10" --is-full-object \
    --properties '{"location":"global","sku":{"name":"G1"},"kind":"Bing.Grounding","properties":{}}' -o none \
    || echo "    ! Bing resource create failed — check the Microsoft.Bing provider is registered and available."
  BING_ID=$(az resource show -g "$RG" -n "$BING" --resource-type "Microsoft.Bing/accounts" --api-version "2020-06-10" --query id -o tsv 2>/dev/null || true)
  BING_KEY=$(az resource invoke-action -g "$RG" -n "$BING" --resource-type "Microsoft.Bing/accounts" --api-version "2020-06-10" --action listKeys --query key1 -o tsv 2>/dev/null || true)
  SUB_ID=$(az account show --query id -o tsv)
  PROJECT_ARM_ID="/subscriptions/${SUB_ID}/resourceGroups/${RG}/providers/Microsoft.CognitiveServices/accounts/${FOUNDRY}/projects/${PROJECT}"
  if [[ -n "$BING_ID" && -n "$BING_KEY" ]]; then
    az rest --method put \
      --url "https://management.azure.com${PROJECT_ARM_ID}/connections/${BING_CONN_NAME}?api-version=2025-04-01-preview" \
      --body "{\"properties\":{\"category\":\"ApiKey\",\"target\":\"https://api.bing.microsoft.com/\",\"authType\":\"ApiKey\",\"credentials\":{\"key\":\"${BING_KEY}\"},\"isSharedToAll\":true,\"metadata\":{\"ApiType\":\"Azure\",\"Location\":\"global\",\"ResourceId\":\"${BING_ID}\",\"type\":\"bing_grounding\"}}}" -o none \
      && echo "  ✓ Bing connection '$BING_CONN_NAME' created on project '$PROJECT'" \
      || echo "    ! Bing connection create failed — add connection '$BING_CONN_NAME' to project '$PROJECT' in the portal."
  fi
else
  echo "  · Skipping Bing web grounding (run with --with-bing to provision). Clause & Risk runs corpus-only."
fi

# ---- 8. Azure SQL (optional) ---------------------------------------------
SQL_CONN=""
if [[ "$WITH_SQL" == "true" ]]; then
  SQLSERVER="clmsql${SUFFIX}"
  SQLDB="clmdb"
  SQLPWD="Clm!$(openssl rand -hex 8)"
  az sql server create -n "$SQLSERVER" -g "$RG" -l "$LOCATION" \
    --admin-user clmadmin --admin-password "$SQLPWD" -o none
  az sql db create -s "$SQLSERVER" -g "$RG" -n "$SQLDB" --service-objective Basic -o none
  az sql server firewall-rule create -s "$SQLSERVER" -g "$RG" \
    -n AllowAzure --start-ip-address 0.0.0.0 --end-ip-address 0.0.0.0 -o none
  SQL_CONN="Driver={ODBC Driver 18 for SQL Server};Server=tcp:${SQLSERVER}.database.windows.net,1433;Database=${SQLDB};Uid=clmadmin;Pwd=${SQLPWD};Encrypt=yes;TrustServerCertificate=no;"
  echo "  ✓ Azure SQL created (admin password stored only in .env)"
else
  echo "  · Skipping Azure SQL (run with --with-sql to provision). The contract-status"
  echo "    tool will fall back to src/data/contracts_seed.json."
fi

# ---- 9. Resolve endpoints + write .env -----------------------------------
PROJECT_ENDPOINT="https://${FOUNDRY}.services.ai.azure.com/api/projects/${PROJECT}"
SEARCH_ENDPOINT="https://${SEARCH}.search.windows.net"

cat > .env <<ENV
# Autogenerated by labautomation/deploy.sh — do not commit.
AZURE_AI_PROJECT_ENDPOINT=${PROJECT_ENDPOINT}

MODEL_ORCHESTRATOR=${GPT_ORCH}
MODEL_DRAFTING=${DRAFTING_MODEL}
MODEL_CLAUSE_RISK=${GPT56SOL}
MODEL_RENEWAL=${GPT_MINI}

AZURE_SEARCH_ENDPOINT=${SEARCH_ENDPOINT}
AZURE_SEARCH_INDEX=clm-corpus
AZURE_SEARCH_CONNECTION_NAME=clm-search

# Web grounding (Grounding with Bing Search) — set when deployed with --with-bing.
AZURE_BING_CONNECTION_NAME=${BING_CONN_NAME}

# SharePoint corpus (BYO) — fill these in before running seed_corpus.py.
SHAREPOINT_SITE_URL=
SHAREPOINT_DOC_LIBRARY=Documents
SHAREPOINT_APP_ID=
SHAREPOINT_APP_SECRET=
SHAREPOINT_TENANT_ID=

APPLICATIONINSIGHTS_CONNECTION_STRING=${APPINSIGHTS_CONN}
AZURE_TRACING_GEN_AI_CONTENT_RECORDING_ENABLED=true

AZURE_SQL_CONNECTION_STRING=${SQL_CONN}

MICROSOFT_APP_ID=
MICROSOFT_APP_PASSWORD=
MICROSOFT_APP_TENANT_ID=
TEAMS_SERVICE_URL=
TEAMS_CONVERSATION_ID=
ENV

echo ""
echo "✅ Deployment complete. Wrote .env with the project endpoint + connection strings."
echo "   Next: python src/scripts/seed_corpus.py && python src/scripts/smoke_test.py"
