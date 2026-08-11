#!/usr/bin/env bash
# ==========================================================================
# Challenge 1 — provision the Foundry CLM microhack resources and write .env
# ==========================================================================
# Usage:   ./labautomation/deploy.sh [--with-sql] [--with-bing]
# Requires: az CLI (logged in via `az login`), an Azure subscription with
#           rights to deploy GPT models.
#
# NOTE: Model + region availability changes over time. Confirm your target
#       region offers gpt-5.4, gpt-5.4-nano, and gpt-5.6-sol in the
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
GPT_MINI="gpt-5.4-nano"
GPT56SOL="gpt-5.6-sol"

# The Intake & Drafting agent shares the gpt-5.4 orchestrator deployment (the
# highest-quota flagship in the project), so no separate drafting model is deployed.
DRAFTING_MODEL="$GPT_ORCH"

echo "▶ Resource group:  $RG ($LOCATION)"
echo "▶ Foundry account: $FOUNDRY / project $PROJECT"

# ---- 1. Resource group ---------------------------------------------------
az group create -n "$RG" -l "$LOCATION" -o none

# ---- 2. Foundry (AI Services) account + project --------------------------
az cognitiveservices account create \
  -n "$FOUNDRY" -g "$RG" -l "$LOCATION" \
  --kind AIServices --sku S0 --custom-domain "$FOUNDRY" \
  --assign-identity --yes -o none
echo "  ✓ Foundry account created"

# Create the Foundry project (preview CLI extension may be required:
#   az extension add --name ai-foundry   OR create the project in the portal).
az cognitiveservices account project create \
  --account-name "$FOUNDRY" -g "$RG" --project-name "$PROJECT" -o none \
  || echo "  ! Project create via CLI unavailable — create '$PROJECT' in the Foundry portal, then re-run to fetch the endpoint."

# ---- 3. Model deployments (GPT) ------------------------------------------
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
# deploy gpt-5.4-nano instead (same GlobalStandard SKU, later deprecation date).
deploy_model "$GPT_MINI" "gpt-5.4-nano"     "2026-03-17" "OpenAI"    30
# Clause & Risk runs on gpt-5.6-sol — its own dedicated deployment.
deploy_model "$GPT56SOL" "gpt-5.6-sol"      "2026-07-09" "OpenAI"    30

# ---- 4. Azure AI Search (Foundry IQ backing store) -----------------------
az search service create \
  -n "$SEARCH" -g "$RG" -l "$LOCATION" \
  --sku basic --partition-count 1 --replica-count 1 \
  --identity-type SystemAssigned -o none
echo "  ✓ Azure AI Search created"

# Foundry IQ uses managed identity end-to-end: the project reads the Search
# index and the Search service calls gpt-5.4 for query planning.
SUB_ID=$(az account show --query id -o tsv)
ACCOUNT_ID="/subscriptions/${SUB_ID}/resourceGroups/${RG}/providers/Microsoft.CognitiveServices/accounts/${FOUNDRY}"
PROJECT_ARM_ID="${ACCOUNT_ID}/projects/${PROJECT}"
SEARCH_ID="/subscriptions/${SUB_ID}/resourceGroups/${RG}/providers/Microsoft.Search/searchServices/${SEARCH}"
az resource update --ids "$PROJECT_ARM_ID" --api-version "2025-04-01-preview" \
  --set identity.type=SystemAssigned -o none
ACCOUNT_MI=$(az resource show --ids "$ACCOUNT_ID" --api-version "2025-06-01" --query identity.principalId -o tsv)
PROJECT_MI=$(az resource show --ids "$PROJECT_ARM_ID" --api-version "2025-04-01-preview" --query identity.principalId -o tsv)
SEARCH_MI=$(az search service show -n "$SEARCH" -g "$RG" --query identity.principalId -o tsv)
for principal in "$ACCOUNT_MI" "$PROJECT_MI"; do
  az role assignment create --assignee-object-id "$principal" --assignee-principal-type ServicePrincipal \
    --role "Search Index Data Reader" --scope "$SEARCH_ID" -o none
  az role assignment create --assignee-object-id "$principal" --assignee-principal-type ServicePrincipal \
    --role "Search Service Contributor" --scope "$SEARCH_ID" -o none
done
az role assignment create --assignee-object-id "$SEARCH_MI" --assignee-principal-type ServicePrincipal \
  --role "Cognitive Services User" --scope "$ACCOUNT_ID" -o none

SEARCH_ENDPOINT="https://${SEARCH}.search.windows.net"
az rest --method put \
  --url "https://management.azure.com${PROJECT_ARM_ID}/connections/clm-search?api-version=2025-04-01-preview" \
  --body "{\"properties\":{\"category\":\"CognitiveSearch\",\"target\":\"${SEARCH_ENDPOINT}\",\"authType\":\"AAD\",\"isSharedToAll\":true,\"metadata\":{\"ApiType\":\"Azure\",\"ResourceId\":\"${SEARCH_ID}\",\"location\":\"${LOCATION}\"}}}" -o none
az rest --method put \
  --url "https://management.azure.com${PROJECT_ARM_ID}/connections/clm-knowledge-mcp?api-version=2025-04-01-preview" \
  --body "{\"properties\":{\"category\":\"RemoteTool\",\"target\":\"${SEARCH_ENDPOINT}/knowledgebases/clm-contracts-kb/mcp?api-version=2026-05-01-preview\",\"authType\":\"ProjectManagedIdentity\",\"isSharedToAll\":true,\"audience\":\"https://search.azure.com/\",\"metadata\":{\"ApiType\":\"Azure\"}}}" -o none
echo "  ✓ Foundry IQ identity and project connections configured"

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
FOUNDRY_IQ_KNOWLEDGE_SOURCE=clm-corpus-ks
FOUNDRY_IQ_KNOWLEDGE_BASE=clm-contracts-kb
FOUNDRY_IQ_CONNECTION_NAME=clm-knowledge-mcp
FOUNDRY_IQ_API_VERSION=2026-05-01-preview

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
