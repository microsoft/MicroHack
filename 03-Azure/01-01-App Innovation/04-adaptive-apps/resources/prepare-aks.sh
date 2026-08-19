#!/usr/bin/env bash
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
  az aks create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$AKS_CLUSTER" \
    --location "$AZURE_LOCATION" \
    --node-count "$AKS_NODE_COUNT" \
    --node-vm-size "$AKS_NODE_VM_SIZE" \
    --node-osdisk-type Managed \
    --enable-oidc-issuer \
    --enable-workload-identity \
    --enable-asm \
    --generate-ssh-keys \
    --output none
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
