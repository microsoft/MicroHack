#!/usr/bin/env bash
# Invoke with Bash from the Adaptive Apps MicroHack root; executable bits are not required.
set -euo pipefail

TARGET_PLATFORM="${1:-all}"
if [[ "$TARGET_PLATFORM" != "aks" &&
      "$TARGET_PLATFORM" != "k3s" &&
      "$TARGET_PLATFORM" != "all" ]]; then
  echo "Usage: $0 [aks|k3s|all]" >&2
  exit 1
fi

for command_name in az base64 kubectl mktemp rad tr; do
  command -v "$command_name" >/dev/null 2>&1 || {
    echo "Required command not found: $command_name" >&2
    exit 1
  }
done

AKS_CONTEXT="${AKS_CONTEXT:-aks-adaptive-apps}"
K3S_CONTEXT="${K3S_CONTEXT:-k3s-azure-vm}"
K3S_KUBECONFIG="${K3S_KUBECONFIG:-$HOME/.kube/adaptive-apps-k3s.yaml}"
AKS_WORKSPACE="${AKS_WORKSPACE:-ws-azure-prod}"
K3S_WORKSPACE="${K3S_WORKSPACE:-ws-local-prod}"
AKS_ENVIRONMENT="${AKS_ENVIRONMENT:-env-azure-prod}"
K3S_ENVIRONMENT="${K3S_ENVIRONMENT:-env-local-prod}"
RADIUS_GROUP="${RADIUS_GROUP:-rg-trading}"
RECIPE_REGISTRY="${RECIPE_REGISTRY:-ghcr.io/microsoft/adaptive-apps/recipes}"
TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT

configure_aks() {
  : "${AZURE_SUBSCRIPTION:?Set AZURE_SUBSCRIPTION for the AKS recipe configuration.}"
  : "${RESOURCE_GROUP:?Set RESOURCE_GROUP for the AKS recipe configuration.}"
  : "${ACR_NAME:?Set a globally unique lowercase ACR_NAME.}"

  unset KUBECONFIG
  kubectl config use-context "$AKS_CONTEXT" >/dev/null
  az account show >/dev/null 2>&1 || az login
  az account set --subscription "$AZURE_SUBSCRIPTION"

  if ! az acr show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$ACR_NAME" >/dev/null 2>&1; then
    az acr create \
      --resource-group "$RESOURCE_GROUP" \
      --name "$ACR_NAME" \
      --sku Basic \
      --output none
  fi

  local token
  local auth
  token="$(az acr login \
    --name "$ACR_NAME" \
    --expose-token \
    --query accessToken \
    --output tsv)"
  auth="$(printf '00000000-0000-0000-0000-000000000000:%s' "$token" |
    base64 | tr -d '\n')"
  mkdir -p "${TEMP_DIR}/docker"
  cat >"${TEMP_DIR}/docker/config.json" <<EOF
{
  "auths": {
    "${ACR_NAME}.azurecr.io": {
      "auth": "${auth}"
    }
  }
}
EOF

  DOCKER_CONFIG="${TEMP_DIR}/docker" rad bicep publish \
    --file iac/recipes/sql-server.bicep \
    --target "br:${ACR_NAME}.azurecr.io/recipes/sql-server:1.0.0"

  rad workspace switch "$AKS_WORKSPACE"
  local istio_revision
  istio_revision="$(kubectl get deployment \
    --namespace aks-istio-system \
    --selector app=istiod \
    --output jsonpath='{.items[0].metadata.labels.istio\.io/rev}')"
  [[ -n "$istio_revision" ]] || {
    echo "Could not determine the AKS managed Istio revision." >&2
    exit 1
  }

  rad deploy iac/aks-env.bicep \
    --workspace "$AKS_WORKSPACE" \
    --group "$RADIUS_GROUP" \
    --environment "$AKS_ENVIRONMENT" \
    --parameters "environmentName=${AKS_ENVIRONMENT}" \
    --parameters "namespace=${AKS_ENVIRONMENT}" \
    --parameters "azureSubscriptionId=${AZURE_SUBSCRIPTION}" \
    --parameters "azureResourceGroup=${RESOURCE_GROUP}" \
    --parameters "istioRevision=${istio_revision}" \
    --parameters "recipeRegistry=${RECIPE_REGISTRY}" \
    --parameters "sqlDatabasesRecipeTemplatePath=${ACR_NAME}.azurecr.io/recipes/sql-server:1.0.0"

  rad recipe list \
    --workspace "$AKS_WORKSPACE" \
    --group "$RADIUS_GROUP" \
    --environment "$AKS_ENVIRONMENT"
}

configure_k3s() {
  export KUBECONFIG="$K3S_KUBECONFIG"
  kubectl config use-context "$K3S_CONTEXT" >/dev/null
  rad workspace switch "$K3S_WORKSPACE"

  rad deploy iac/local-env.bicep \
    --workspace "$K3S_WORKSPACE" \
    --group "$RADIUS_GROUP" \
    --environment "$K3S_ENVIRONMENT" \
    --parameters "environmentName=${K3S_ENVIRONMENT}" \
    --parameters "namespace=${K3S_ENVIRONMENT}" \
    --parameters "recipeRegistry=${RECIPE_REGISTRY}"

  rad recipe list \
    --workspace "$K3S_WORKSPACE" \
    --group "$RADIUS_GROUP" \
    --environment "$K3S_ENVIRONMENT"
}

if [[ "$TARGET_PLATFORM" == "aks" || "$TARGET_PLATFORM" == "all" ]]; then
  configure_aks
fi
if [[ "$TARGET_PLATFORM" == "k3s" || "$TARGET_PLATFORM" == "all" ]]; then
  configure_k3s
fi

echo "Recipe configuration completed for ${TARGET_PLATFORM}."
