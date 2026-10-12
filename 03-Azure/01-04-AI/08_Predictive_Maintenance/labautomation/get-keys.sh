#!/bin/bash
# =============================================================================
# Predictive Maintenance MicroHack - Environment Configuration Script
# =============================================================================
# Resolves resource names, endpoints, and keys from your Azure deployment
# and creates a clean .env file containing the settings required by the hack.
# =============================================================================

set -e

# Resolve paths relative to this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_OUT="$SCRIPT_DIR/../.env"

# Ensure Azure CLI login
if [ -z "$(az account show 2>/dev/null)" ]; then
    echo "User not signed in to Azure. Signing in via device code..."
    az login --use-device-code
fi

# Parse named parameters
resourceGroupName=""
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --resource-group) resourceGroupName="$2"; shift ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

# Prompt for resource group if not passed
if [ -z "$resourceGroupName" ]; then
    read -p "Enter the resource group name where your lab resources are deployed: " resourceGroupName
fi

echo "Retrieving deployment information from resource group '$resourceGroupName'..."

# Fetch subscription ID and tenant ID
subscriptionId=$(az account show --query id -o tsv)

# Find the lab deployment (prefers platform mhh* deployments, main.bicep, or the newest deployment)
deploymentName=$(az deployment group list --resource-group "$resourceGroupName" \
    --query "sort_by([?starts_with(name, 'mhh') || contains(name, 'main') || contains(name, 'azuredeploy') || contains(name, 'hack-deployment')], &properties.timestamp)[-1].name" \
    -o tsv 2>/dev/null || echo "")

if [ -z "$deploymentName" ]; then
    deploymentName=$(az deployment group list --resource-group "$resourceGroupName" \
        --query "sort_by(@, &properties.timestamp)[-1].name" \
        -o tsv 2>/dev/null || echo "")
fi

# Helper to read a deployment output safely
get_output() {
    local key="$1"
    if [ -n "$deploymentName" ]; then
        az deployment group show --resource-group "$resourceGroupName" --name "$deploymentName" \
            --query "properties.outputs.${key}.value" -o tsv 2>/dev/null || echo ""
    else
        echo ""
    fi
}

echo "Discovering Azure resources..."

# 1. Storage Account
storageAccountName=$(get_output "storageAccountName")
if [ -z "$storageAccountName" ]; then
    storageAccountName=$(az storage account list --resource-group "$resourceGroupName" --query "[0].name" -o tsv 2>/dev/null || echo "")
fi

if [ -n "$storageAccountName" ]; then
    storageAccountKey=$(az storage account keys list --account-name "$storageAccountName" --resource-group "$resourceGroupName" --query "[0].value" -o tsv 2>/dev/null || echo "")
    storageConnectionString="DefaultEndpointsProtocol=https;AccountName=${storageAccountName};AccountKey=${storageAccountKey};EndpointSuffix=core.windows.net"
else
    storageConnectionString=""
fi

# 2. Microsoft Foundry / Cognitive Services Account
foundryAccountName=$(get_output "aiFoundryHubName")
if [ -z "$foundryAccountName" ]; then
    foundryAccountName=$(az cognitiveservices account list --resource-group "$resourceGroupName" --query "[?kind=='AIServices'].name | [0]" -o tsv 2>/dev/null || echo "")
fi

foundryProjectName=$(get_output "aiFoundryProjectName")
if [ -z "$foundryProjectName" ]; then
    foundryProjectName="predictive-maintenance"
fi

if [ -n "$foundryAccountName" ]; then
    foundryKey=$(az cognitiveservices account keys list --name "$foundryAccountName" --resource-group "$resourceGroupName" --query key1 -o tsv 2>/dev/null || echo "")
    aiProjectEndpoint="https://${foundryAccountName}.services.ai.azure.com/api/projects/${foundryProjectName}"
    aiProjectResourceId="/subscriptions/${subscriptionId}/resourceGroups/${resourceGroupName}/providers/Microsoft.CognitiveServices/accounts/${foundryAccountName}/projects/${foundryProjectName}"
    azureOpenAIEndpoint="https://${foundryAccountName}.openai.azure.com/"
else
    foundryKey=""
    aiProjectEndpoint=""
    aiProjectResourceId=""
    azureOpenAIEndpoint=""
fi

# 3. Cosmos DB
cosmosAccountName=$(get_output "cosmosDbAccountName")
if [ -z "$cosmosAccountName" ]; then
    cosmosAccountName=$(az cosmosdb list --resource-group "$resourceGroupName" --query "[0].name" -o tsv 2>/dev/null || echo "")
fi

if [ -n "$cosmosAccountName" ]; then
    cosmosEndpoint=$(get_output "cosmosDbEndpoint")
    if [ -z "$cosmosEndpoint" ]; then
        cosmosEndpoint=$(az cosmosdb show --name "$cosmosAccountName" --resource-group "$resourceGroupName" --query documentEndpoint -o tsv 2>/dev/null || echo "")
    fi
    cosmosKey=$(az cosmosdb keys list --name "$cosmosAccountName" --resource-group "$resourceGroupName" --query primaryMasterKey -o tsv 2>/dev/null || echo "")
else
    cosmosAccountName=""
    cosmosEndpoint=""
    cosmosKey=""
fi

# 4. Azure AI Search
searchServiceName=$(get_output "searchServiceName")
if [ -z "$searchServiceName" ]; then
    searchServiceName=$(az search service list --resource-group "$resourceGroupName" --query "[0].name" -o tsv 2>/dev/null || echo "")
fi

if [ -n "$searchServiceName" ]; then
    searchServiceEndpoint="https://${searchServiceName}.search.windows.net/"
    searchAdminKey=$(az search admin-key show --resource-group "$resourceGroupName" --service-name "$searchServiceName" --query primaryKey -o tsv 2>/dev/null || echo "")
else
    searchServiceEndpoint=""
    searchAdminKey=""
fi

# 5. API Management
apimName=$(get_output "apimName")
if [ -z "$apimName" ]; then
    apimName=$(az apim list --resource-group "$resourceGroupName" --query "[0].name" -o tsv 2>/dev/null || echo "")
fi

if [ -n "$apimName" ]; then
    apimGatewayUrl=$(get_output "apimGatewayUrl")
    if [ -z "$apimGatewayUrl" ]; then
        apimGatewayUrl=$(az apim show --name "$apimName" --resource-group "$resourceGroupName" --query gatewayUrl -o tsv 2>/dev/null || echo "")
    fi
    apimSubscriptionKey=$(az rest --method post \
        --url "https://management.azure.com/subscriptions/${subscriptionId}/resourceGroups/${resourceGroupName}/providers/Microsoft.ApiManagement/service/${apimName}/subscriptions/master/listSecrets?api-version=2024-05-01" \
        --query "primaryKey" -o tsv 2>/dev/null || echo "")
else
    apimGatewayUrl=""
    apimSubscriptionKey=""
fi

# 6. Application Insights
appInsightsName=$(get_output "applicationInsightsName")
if [ -z "$appInsightsName" ]; then
    appInsightsName=$(az resource list --resource-group "$resourceGroupName" --resource-type "Microsoft.Insights/components" --query "[0].name" -o tsv 2>/dev/null || echo "")
fi

if [ -n "$appInsightsName" ]; then
    appInsightsConnectionString=$(az resource show --resource-group "$resourceGroupName" --name "$appInsightsName" --resource-type "Microsoft.Insights/components" --query properties.ConnectionString -o tsv 2>/dev/null || echo "")
else
    appInsightsConnectionString=""
fi

# =============================================================================
# Write .env file
# =============================================================================
echo "Writing environment settings to $ENV_OUT..."

cat <<EOF > "$ENV_OUT"
# Azure Environment
RESOURCE_GROUP="$resourceGroupName"
AZURE_SUBSCRIPTION_ID="$subscriptionId"

# Microsoft Foundry / Azure AI
AZURE_AI_PROJECT_ENDPOINT="$aiProjectEndpoint"
AZURE_AI_PROJECT_RESOURCE_ID="$aiProjectResourceId"
MODEL_DEPLOYMENT_NAME="gpt-5.4"
EMBEDDING_MODEL_DEPLOYMENT_NAME="text-embedding-3-large"

# Azure OpenAI (vectorizer in create_knowledge_base.ipynb & Aspire flow)
AZURE_OPENAI_ENDPOINT="$azureOpenAIEndpoint"
AZURE_OPENAI_KEY="$foundryKey"
AZURE_OPENAI_DEPLOYMENT_NAME="gpt-5.4"

# Azure Cosmos DB (SQL API)
COSMOS_ACCOUNT_NAME="$cosmosAccountName"
COSMOS_ENDPOINT="$cosmosEndpoint"
COSMOS_KEY="$cosmosKey"
COSMOS_DATABASE_NAME="FactoryOpsDB"

# Azure AI Search
SEARCH_SERVICE_ENDPOINT="$searchServiceEndpoint"
SEARCH_ADMIN_KEY="$searchAdminKey"

# Azure Storage
AZURE_STORAGE_CONNECTION_STRING="$storageConnectionString"

# API Management
APIM_GATEWAY_URL="$apimGatewayUrl"
APIM_SUBSCRIPTION_KEY="$apimSubscriptionKey"

# Application Insights
APPLICATIONINSIGHTS_CONNECTION_STRING="$appInsightsConnectionString"
EOF

echo "Environment file created: $ENV_OUT"
echo ""
echo "=== Configuration Summary ==="
echo "Resource Group:        $resourceGroupName"
echo "Foundry Project URL:   $aiProjectEndpoint"
echo "Cosmos DB Endpoint:    $cosmosEndpoint"
echo "Cosmos DB Account:     $cosmosAccountName"
echo "Search Endpoint:       $searchServiceEndpoint"
echo "APIM Gateway URL:      $apimGatewayUrl"
echo "Storage Account:       $storageAccountName"
echo "Application Insights:  ${appInsightsName:-"(none)"}"
echo "============================="
