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

for command_name in az base64 grep kubectl mktemp rad tr; do
  command -v "$command_name" >/dev/null 2>&1 || {
    echo "Required command not found: $command_name" >&2
    exit 1
  }
done

AKS_CONTEXT="${AKS_CONTEXT:-aks-adaptive-apps}"
AKS_CLUSTER_NAME="${AKS_CLUSTER_NAME:-aks-adaptive-apps}"
K3S_CONTEXT="${K3S_CONTEXT:-k3s-azure-vm}"
K3S_KUBECONFIG="${K3S_KUBECONFIG:-$HOME/.kube/adaptive-apps-k3s.yaml}"
AKS_WORKSPACE="${AKS_WORKSPACE:-ws-azure-prod}"
K3S_WORKSPACE="${K3S_WORKSPACE:-ws-local-prod}"
AKS_ENVIRONMENT="${AKS_ENVIRONMENT:-env-azure-prod}"
K3S_ENVIRONMENT="${K3S_ENVIRONMENT:-env-local-prod}"
RADIUS_GROUP="${RADIUS_GROUP:-rg-trading}"
RECIPE_REGISTRY="${RECIPE_REGISTRY:-ghcr.io/microsoft/adaptive-apps/recipes}"
WORKSHOP_RECIPE_VERSION="${WORKSHOP_RECIPE_VERSION:-1.0.3}"
[[ "$WORKSHOP_RECIPE_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
  echo "WORKSHOP_RECIPE_VERSION must be an immutable semantic version such as 1.0.0." >&2
  exit 1
}
TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT

is_ipv4() {
  local ip="$1"
  local octet
  [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1
  IFS='.' read -r -a octets <<<"$ip"
  for octet in "${octets[@]}"; do
    ((10#$octet <= 255)) || return 1
  done
}

get_aks_egress_ips() {
  local outbound_type
  local id_query
  local resource_id
  local allocation
  local sku
  local ip
  local -a ip_fields=()
  local -a resource_ids=()
  local -a ips=()

  outbound_type="$(az aks show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$AKS_CLUSTER_NAME" \
    --query networkProfile.outboundType \
    --output tsv | tr -d '\r')"

  case "$outbound_type" in
    loadBalancer)
      id_query='networkProfile.loadBalancerProfile.effectiveOutboundIPs[].id'
      ;;
    managedNATGateway|userAssignedNATGateway)
      id_query='networkProfile.natGatewayProfile.effectiveOutboundIPs[].id'
      ;;
    *)
      echo "Unsupported AKS outbound type '${outbound_type}'." >&2
      echo "Use loadBalancer, managedNATGateway, or userAssignedNATGateway with static public IP resources." >&2
      return 1
      ;;
  esac

  mapfile -t resource_ids < <(az aks show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$AKS_CLUSTER_NAME" \
    --query "$id_query" \
    --output tsv | tr -d '\r')
  ((${#resource_ids[@]} > 0)) || {
    echo "AKS reports no effective outbound public IP resources for '${outbound_type}'." >&2
    return 1
  }

  for resource_id in "${resource_ids[@]}"; do
    [[ "${resource_id,,}" == *"/providers/microsoft.network/publicipaddresses/"* ]] || {
      echo "Unsupported AKS egress resource '${resource_id}'; public IP prefixes and broad ranges are not allowed." >&2
      return 1
    }
    # Azure CLI renders a JMESPath multi-select list as one value per line rather than as
    # tab-separated columns, so collect the fields as rows instead of reading a single row.
    mapfile -t ip_fields < <(az network public-ip show \
      --ids "$resource_id" \
      --query "[ipAddress,publicIPAllocationMethod,sku.name]" \
      --output tsv | tr -d '\r')
    ip="${ip_fields[0]:-}"
    allocation="${ip_fields[1]:-}"
    sku="${ip_fields[2]:-}"
    [[ "$allocation" == "Static" && "$sku" == "Standard" ]] || {
      echo "AKS egress IP '${resource_id}' must be a Standard, statically allocated public IP (observed sku='${sku}', allocation='${allocation}')." >&2
      return 1
    }
    is_ipv4 "$ip" || {
      echo "AKS egress resource '${resource_id}' does not expose a valid IPv4 address." >&2
      return 1
    }
    ips+=("$ip")
  done

  local IFS=,
  printf '%s\n' "${ips[*]}"
}

publish_workshop_recipes() {
  : "${AZURE_SUBSCRIPTION:?Set AZURE_SUBSCRIPTION for workshop recipe publishing.}"
  : "${RESOURCE_GROUP:?Set RESOURCE_GROUP for workshop recipe publishing.}"
  : "${ACR_NAME:?Set a globally unique lowercase ACR_NAME.}"

  az account show >/dev/null 2>&1 || az login
  az account set --subscription "$AZURE_SUBSCRIPTION"

  if ! az acr show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$ACR_NAME" >/dev/null 2>&1; then
    az acr create \
      --resource-group "$RESOURCE_GROUP" \
      --name "$ACR_NAME" \
      --sku Standard \
      --output none
  fi
  az acr update \
    --resource-group "$RESOURCE_GROUP" \
    --name "$ACR_NAME" \
    --sku Standard \
    --anonymous-pull-enabled true \
    --output none

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
    --target "br:${ACR_NAME}.azurecr.io/recipes/sql-server:${WORKSHOP_RECIPE_VERSION}"
  DOCKER_CONFIG="${TEMP_DIR}/docker" rad bicep publish \
    --file iac/recipes/postgres-azure-flex.bicep \
    --target "br:${ACR_NAME}.azurecr.io/recipes/postgres-azure-flex:${WORKSHOP_RECIPE_VERSION}"
  DOCKER_CONFIG="${TEMP_DIR}/docker" rad bicep publish \
    --file iac/recipes/postgres-kubernetes.bicep \
    --target "br:${ACR_NAME}.azurecr.io/recipes/postgres-kubernetes:${WORKSHOP_RECIPE_VERSION}"
}

# `rad recipe list` prints an empty table and still exits 0 when no recipes are
# registered, so assert the registrations that the later challenges depend on.
assert_recipes() {
  local workspace="$1"
  local environment="$2"
  shift 2
  local recipe_json
  local resource_type
  local missing=0

  rad recipe list \
    --workspace "$workspace" \
    --group "$RADIUS_GROUP" \
    --environment "$environment"

  recipe_json="$(rad recipe list \
    --workspace "$workspace" \
    --group "$RADIUS_GROUP" \
    --environment "$environment" \
    --output json)"

  for resource_type in "$@"; do
    grep -Fq "$resource_type" <<<"$recipe_json" || {
      echo "Missing 'default' recipe for ${resource_type} in ${environment}." >&2
      missing=1
    }
  done

  ((missing == 0)) || {
    echo "Recipe verification failed for ${environment}; the environment definition did not register the expected recipes." >&2
    return 1
  }
}

configure_aks() {
  unset KUBECONFIG
  kubectl config use-context "$AKS_CONTEXT" >/dev/null
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
  local aks_egress_ips
  aks_egress_ips="$(get_aks_egress_ips)"

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
    --parameters "postgresRecipeTemplatePath=${ACR_NAME}.azurecr.io/recipes/postgres-azure-flex:${WORKSHOP_RECIPE_VERSION}" \
    --parameters "aksEgressIps=${aks_egress_ips}" \
    --parameters "sqlDatabasesRecipeTemplatePath=${ACR_NAME}.azurecr.io/recipes/sql-server:${WORKSHOP_RECIPE_VERSION}"

  assert_recipes "$AKS_WORKSPACE" "$AKS_ENVIRONMENT" \
    Radius.Resources/postgreSqlDatabases \
    Radius.Resources/mqttBrokers \
    Radius.Resources/idProviders \
    Radius.Resources/workloadIdentities \
    Radius.Resources/aiModels \
    Radius.Resources/governance \
    Radius.Resources/agentGuardrails \
    Radius.Resources/sqlDatabases
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
    --parameters "recipeRegistry=${RECIPE_REGISTRY}" \
    --parameters "postgresRecipeTemplatePath=${ACR_NAME}.azurecr.io/recipes/postgres-kubernetes:${WORKSHOP_RECIPE_VERSION}"

  assert_recipes "$K3S_WORKSPACE" "$K3S_ENVIRONMENT" \
    Radius.Resources/postgreSqlDatabases \
    Radius.Resources/mqttBrokers \
    Radius.Resources/idProviders \
    Radius.Resources/workloadIdentities \
    Radius.Resources/aiModels \
    Radius.Resources/governance \
    Radius.Resources/agentGuardrails
}

publish_workshop_recipes
if [[ "$TARGET_PLATFORM" == "aks" || "$TARGET_PLATFORM" == "all" ]]; then
  configure_aks
fi
if [[ "$TARGET_PLATFORM" == "k3s" || "$TARGET_PLATFORM" == "all" ]]; then
  configure_k3s
fi

echo "Recipe configuration completed for ${TARGET_PLATFORM}."
