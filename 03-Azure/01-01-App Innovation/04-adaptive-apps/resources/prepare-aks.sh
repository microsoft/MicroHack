#!/usr/bin/env bash
# Invoke with Bash from the Adaptive Apps MicroHack root; executable bits are not required.
set -euo pipefail

# AKS credentials belong in the default kubeconfig, not a previously selected K3s file.
unset KUBECONFIG

for command_name in az grep kubectl; do
  command -v "$command_name" >/dev/null 2>&1 || {
    echo "Required command not found: $command_name" >&2
    exit 1
  }
done

: "${AZURE_SUBSCRIPTION:?Set AZURE_SUBSCRIPTION to the target subscription ID.}"
AZURE_LOCATION="${AZURE_LOCATION:-westeurope}"
RESOURCE_GROUP="${RESOURCE_GROUP:-rg-adaptive-apps}"
AKS_CLUSTER="${AKS_CLUSTER:-aks-adaptive-apps}"
AKS_NODE_COUNT="${AKS_NODE_COUNT:-2}"
AKS_NODE_VM_SIZE="${AKS_NODE_VM_SIZE:-Standard_D4s_v5}"

# Four-vCPU, 16 GiB x64 sizes in decreasing order of preference. Regions and
# subscriptions differ in what they offer, so the script falls back automatically.
# These are Azure VM sizes: an arm64 workstation still provisions x64 Azure nodes.
read -r -a AKS_NODE_VM_SIZE_CANDIDATES <<<"${AKS_NODE_VM_SIZE_CANDIDATES:-${AKS_NODE_VM_SIZE} Standard_D4as_v5 Standard_D4s_v4 Standard_D4as_v4 Standard_D4s_v3 Standard_D4a_v4}"

AVAILABLE_VM_SIZES=""

# az vm list-skus already omits sizes the subscription cannot use. A Location
# restriction blocks the whole region; a Zone restriction only removes individual
# availability zones and does not block the regional, non-zonal deployment used here.
load_available_vm_sizes() {
  [[ -z "$AVAILABLE_VM_SIZES" ]] || return 0
  AVAILABLE_VM_SIZES="$(az vm list-skus \
    --location "$AZURE_LOCATION" \
    --resource-type virtualMachines \
    --query "[?length(restrictions[?type=='Location']) == \`0\`].name" \
    --output tsv)"
}

vm_size_is_available() {
  load_available_vm_sizes
  grep -qx -- "$1" <<<"$AVAILABLE_VM_SIZES"
}

# Capacity and quota problems only surface when the control plane tries to allocate.
is_capacity_error() {
  grep -Eqi 'AllocationFailed|SkuNotAvailable|ZonalAllocationFailed|OverconstrainedAllocationRequest|QuotaExceeded|exceeding approved .* quota|InsufficientCapacity' "$1"
}

az account show >/dev/null 2>&1 || az login
az account set --subscription "$AZURE_SUBSCRIPTION"
az group create --name "$RESOURCE_GROUP" --location "$AZURE_LOCATION" --output none

if az aks show --resource-group "$RESOURCE_GROUP" --name "$AKS_CLUSTER" >/dev/null 2>&1; then
  az aks update \
    --resource-group "$RESOURCE_GROUP" \
    --name "$AKS_CLUSTER" \
    --enable-oidc-issuer \
    --enable-workload-identity \
    --output none
  EXISTING_SERVICE_MESH_MODE="$(az aks show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$AKS_CLUSTER" \
    --query serviceMeshProfile.mode \
    --output tsv)"
  if [[ "$EXISTING_SERVICE_MESH_MODE" != "Istio" ]]; then
    az aks mesh enable \
      --resource-group "$RESOURCE_GROUP" \
      --name "$AKS_CLUSTER" \
      --output none
  fi
else
  create_aks_cluster() {
    local size
    local create_log
    local attempted=0

    create_log="$(mktemp)"

    for size in "${AKS_NODE_VM_SIZE_CANDIDATES[@]}"; do
      if ! vm_size_is_available "$size"; then
        echo "Node size ${size} is not offered in ${AZURE_LOCATION} for this subscription; trying the next candidate." >&2
        continue
      fi
      attempted=1
      echo "Creating AKS cluster ${AKS_CLUSTER} with node size ${size}."
      if az aks create \
        --resource-group "$RESOURCE_GROUP" \
        --name "$AKS_CLUSTER" \
        --location "$AZURE_LOCATION" \
        --node-count "$AKS_NODE_COUNT" \
        --node-vm-size "$size" \
        --node-osdisk-type Managed \
        --enable-oidc-issuer \
        --enable-workload-identity \
        --enable-asm \
        --generate-ssh-keys \
        --output none 2>"$create_log"; then
        rm -f "$create_log"
        return 0
      fi

      cat "$create_log" >&2
      if ! is_capacity_error "$create_log"; then
        rm -f "$create_log"
        return 1
      fi

      echo "Node size ${size} has no capacity or quota in ${AZURE_LOCATION}; removing the failed cluster and trying the next size." >&2
      az aks delete \
        --resource-group "$RESOURCE_GROUP" \
        --name "$AKS_CLUSTER" \
        --yes \
        --output none 2>/dev/null || true
    done

    rm -f "$create_log"
    if ((attempted == 0)); then
      echo "None of the candidate node sizes is offered in ${AZURE_LOCATION}: ${AKS_NODE_VM_SIZE_CANDIDATES[*]}" >&2
    else
      echo "Every candidate node size failed to allocate in ${AZURE_LOCATION}: ${AKS_NODE_VM_SIZE_CANDIDATES[*]}" >&2
    fi
    echo "Set AKS_NODE_VM_SIZE_CANDIDATES to sizes offered in your region, or choose another AZURE_LOCATION." >&2
    return 1
  }

  create_aks_cluster
fi

az aks get-credentials \
  --resource-group "$RESOURCE_GROUP" \
  --name "$AKS_CLUSTER" \
  --overwrite-existing \
  --output none
kubectl config use-context "$AKS_CLUSTER" >/dev/null

PROVISIONING_STATE="$(az aks show -g "$RESOURCE_GROUP" -n "$AKS_CLUSTER" --query provisioningState -o tsv)"
OIDC_ENABLED="$(az aks show -g "$RESOURCE_GROUP" -n "$AKS_CLUSTER" --query oidcIssuerProfile.enabled -o tsv)"
WORKLOAD_IDENTITY_ENABLED="$(az aks show -g "$RESOURCE_GROUP" -n "$AKS_CLUSTER" --query securityProfile.workloadIdentity.enabled -o tsv)"
SERVICE_MESH_MODE="$(az aks show -g "$RESOURCE_GROUP" -n "$AKS_CLUSTER" --query serviceMeshProfile.mode -o tsv)"

[[ "$PROVISIONING_STATE" == "Succeeded" ]] || {
  echo "AKS provisioning state is $PROVISIONING_STATE." >&2
  exit 1
}
[[ "${OIDC_ENABLED,,}" == "true" ]] || {
  echo "AKS OIDC issuer is not enabled." >&2
  exit 1
}
[[ "${WORKLOAD_IDENTITY_ENABLED,,}" == "true" ]] || {
  echo "AKS workload identity is not enabled." >&2
  exit 1
}
[[ "$SERVICE_MESH_MODE" == "Istio" ]] || {
  echo "AKS managed Istio is not enabled." >&2
  exit 1
}

kubectl get --raw="/readyz" | grep -qx "ok"
kubectl wait --for=condition=Ready nodes --all --timeout=10m
kubectl get namespace aks-istio-system >/dev/null
kubectl get nodes -o wide

echo "AKS environment is healthy. Context: $(kubectl config current-context)"
