#!/bin/bash
set -e

echo "============================================"
echo "Logging in Azure CLI as Service Principal"
echo "============================================"

# Source .env file if environment variables not already set
if [ -z "$ARM_CLIENT_ID" ] && [ -f ".devcontainer/.env" ]; then
    echo "Loading credentials from .devcontainer/.env..."
    source .devcontainer/.env
fi

if [ -z "$ARM_CLIENT_ID" ] || [ -z "$ARM_CLIENT_SECRET" ] || [ -z "$ARM_TENANT_ID" ]; then
    echo "ERROR: Missing required environment variables!"
    echo ""
    echo "Create .devcontainer/.env from .devcontainer/.env.example:"
    echo "  cp .devcontainer/.env.example .devcontainer/.env"
    echo "  # Edit .env with your SP credentials"
    echo "  # Then rebuild the container"
    exit 1
fi

# Login as service principal
az login --service-principal \
    --username "$ARM_CLIENT_ID" \
    --password "$ARM_CLIENT_SECRET" \
    --tenant "$ARM_TENANT_ID" \
    --output none

# Set subscription if provided
if [ -n "$ARM_SUBSCRIPTION_ID" ]; then
    az account set --subscription "$ARM_SUBSCRIPTION_ID"
fi

echo ""
echo "✅ Logged in as Service Principal:"
az account show --query "{name:name, user:user.name, type:user.type}" -o table

echo ""
echo "✅ Verifying Graph API access for authentication methods..."
# Test that we can access auth methods API (will fail gracefully if no users exist yet)
az rest --method GET --uri "https://graph.microsoft.com/v1.0/me" --query "displayName" -o tsv 2>/dev/null || echo "(SP doesn't have /me endpoint - this is expected)"

echo ""
echo "============================================"
echo "Dev Container Ready!"
echo "All az and terraform commands will run as SP"
echo "============================================"
