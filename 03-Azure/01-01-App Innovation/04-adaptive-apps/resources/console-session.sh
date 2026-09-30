#!/usr/bin/env bash

export AKS_CLUSTER="${AKS_CLUSTER:-aks-adaptive-apps}"
export AKS_CLUSTER_NAME="$AKS_CLUSTER"
export AKS_CONTEXT="${AKS_CONTEXT:-$AKS_CLUSTER}"
export K3S_CONTEXT="${K3S_CONTEXT:-k3s-azure-vm}"
export K3S_VM_NAME="${K3S_VM_NAME:-vm-adaptive-apps-k3s}"
export BASTION_NAME="${BASTION_NAME:-bas-adaptive-apps}"
export K3S_KUBECONFIG="${K3S_KUBECONFIG:-$HOME/.kube/adaptive-apps-k3s.yaml}"
export K3S_TUNNEL_STATE_DIR="${K3S_TUNNEL_STATE_DIR:-$HOME/.kube/adaptive-apps-bastion}"
export RADIUS_GROUP="${RADIUS_GROUP:-rg-trading}"
export ADAPTIVE_APPS_NONINTERACTIVE=true

connect_aks() {
  unset KUBECONFIG
  install -d -m 0700 "$HOME/.kube"
  az aks get-credentials --resource-group "$RESOURCE_GROUP" --name "$AKS_CLUSTER" \
    --context "$AKS_CONTEXT" --overwrite-existing --file "$HOME/.kube/config"
  chmod 0600 "$HOME/.kube/config"
  kubectl config use-context "$AKS_CONTEXT" >/dev/null
  kubectl wait --for=condition=Ready nodes --all --timeout=5m
}

connect_k3s() {
  bash resources/prepare-k3s-azure-vm.sh connect
  export KUBECONFIG="$K3S_KUBECONFIG"
  kubectl config use-context "$K3S_CONTEXT" >/dev/null
}

select_workspace() {
  local workspace="$1" context="$2" environment="$3"
  rad workspace create kubernetes "$workspace" --context "$context" --force
  rad workspace switch "$workspace"
  rad group switch "$RADIUS_GROUP"
  rad env switch "$environment"
}

build_local_types() {
  local catalog
  catalog="$(mktemp)"
  if ! curl --fail --location --retry 3 \
    "https://raw.githubusercontent.com/microsoft/adaptive-apps/885627980684e5bcc6fe4bbd2848c1ec247b0a0b/radius/resource-types/types.yaml" \
    --output "$catalog"; then
    rm -f "$catalog"
    return 1
  fi
  mkdir -p artifacts
  if ! rad bicep publish-extension --from-file "$catalog" --target artifacts/types.tgz --force; then
    rm -f "$catalog"
    return 1
  fi
  rm -f "$catalog"
  [[ -s artifacts/types.tgz ]] || {
    echo "Radius did not generate artifacts/types.tgz." >&2
    return 1
  }
}

verify_environment() {
  local workspace="$1" environment="$2"
  local objects object
  kubectl wait --for=condition=Available deployments --all --namespace radius-system --timeout=10m
  kubectl get crd recipes.radapp.io deploymenttemplates.radapp.io deploymentresources.radapp.io >/dev/null
  objects="$(kubectl get deployments,statefulsets --namespace core --output name)"
  [[ -n "$objects" ]] || {
    echo "The core portfolio is empty in ${workspace}." >&2
    return 1
  }
  while IFS= read -r object; do
    kubectl rollout status "$object" --namespace core --timeout=15m
  done <<<"$objects"
  local -a types=(
    Radius.Resources/postgreSqlDatabases Radius.Resources/mqttBrokers
    Radius.Resources/idProviders Radius.Resources/workloadIdentities
    Radius.Resources/aiModels Radius.Resources/governance Radius.Resources/agentGuardrails
  )
  if [[ "$workspace" == "ws-azure-prod" ]]; then
    types+=(Radius.Resources/sqlDatabases)
    rad credential show azure --workspace "$workspace" >/dev/null
  fi
  for object in "${types[@]}"; do
    rad resource-type show "$object" --workspace "$workspace" >/dev/null
  done
  bash resources/verify-recipes.sh "$workspace" "$environment" "${types[@]}"
}
