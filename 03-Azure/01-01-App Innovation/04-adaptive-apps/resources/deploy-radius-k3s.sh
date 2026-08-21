#!/usr/bin/env bash
# Invoke with Bash from the Adaptive Apps MicroHack root; executable bits are not required.
set -euo pipefail

for command_name in kubectl rad; do
  command -v "$command_name" >/dev/null 2>&1 || {
    echo "Required command not found: $command_name" >&2
    exit 1
  }
done

K3S_KUBECONFIG="${K3S_KUBECONFIG:-$HOME/.kube/adaptive-apps-k3s.yaml}"
K3S_CONTEXT="${K3S_CONTEXT:-k3s-azure-vm}"
RADIUS_WORKSPACE="${RADIUS_WORKSPACE:-ws-local-prod}"
RADIUS_ENVIRONMENT="${RADIUS_ENVIRONMENT:-env-local-prod}"
RADIUS_GROUP="${RADIUS_GROUP:-rg-trading}"
RADIUS_NAMESPACE="${RADIUS_NAMESPACE:-env-local-prod}"

export KUBECONFIG="${KUBECONFIG:-$K3S_KUBECONFIG}"

CURRENT_CONTEXT="$(kubectl config current-context)"
if [[ "$CURRENT_CONTEXT" != "$K3S_CONTEXT" ]]; then
  echo "Current context is $CURRENT_CONTEXT; expected $K3S_CONTEXT." >&2
  exit 1
fi

INSTALL_ARGS=(kubernetes --kubecontext "$CURRENT_CONTEXT")
if kubectl get namespace radius-system >/dev/null 2>&1; then
  INSTALL_ARGS+=(--reinstall)
fi
rad install "${INSTALL_ARGS[@]}"

rad workspace create kubernetes "$RADIUS_WORKSPACE" \
  --context "$CURRENT_CONTEXT" \
  --force
rad workspace switch "$RADIUS_WORKSPACE"

rad group show "$RADIUS_GROUP" >/dev/null 2>&1 ||
  rad group create "$RADIUS_GROUP"
rad group switch "$RADIUS_GROUP"

rad env show "$RADIUS_ENVIRONMENT" >/dev/null 2>&1 ||
  rad env create "$RADIUS_ENVIRONMENT" \
    --group "$RADIUS_GROUP" \
    --kubernetes-namespace "$RADIUS_NAMESPACE"
rad env switch "$RADIUS_ENVIRONMENT"

kubectl wait --for=condition=Available deployments --all \
  --namespace radius-system \
  --timeout=10m
kubectl get crd recipes.radapp.io deploymenttemplates.radapp.io deploymentresources.radapp.io >/dev/null
rad env show "$RADIUS_ENVIRONMENT" >/dev/null
rad group show "$RADIUS_GROUP" >/dev/null
kubectl get pods --namespace radius-system

echo "Radius on K3s is healthy in workspace ${RADIUS_WORKSPACE}."
