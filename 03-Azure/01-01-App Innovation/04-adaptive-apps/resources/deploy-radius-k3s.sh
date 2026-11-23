#!/usr/bin/env bash
# Invoke with Bash from the Adaptive Apps MicroHack root; executable bits are not required.
set -Eeuo pipefail
trap 'echo "ERROR: K3s Radius setup failed at line ${LINENO}; setup is incomplete. Resolve the error above, then rerun this script." >&2' ERR

for command_name in grep jq kubectl rad; do
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
RADIUS_REINSTALL="${RADIUS_REINSTALL:-false}"
case "$RADIUS_REINSTALL" in
  true | false) ;;
  *) echo "RADIUS_REINSTALL must be true or false." >&2; exit 2 ;;
esac

export KUBECONFIG="${KUBECONFIG:-$K3S_KUBECONFIG}"

CURRENT_CONTEXT="$(kubectl config current-context)"
if [[ "$CURRENT_CONTEXT" != "$K3S_CONTEXT" ]]; then
  echo "Current context is $CURRENT_CONTEXT; expected $K3S_CONTEXT." >&2
  exit 1
fi

kubectl --request-timeout=15s get --raw=/readyz | grep -qx "ok"
kubectl wait --for=condition=Ready nodes --all --timeout=5m

INSTALL_ARGS=(kubernetes --kubecontext "$CURRENT_CONTEXT")
RADIUS_NAMESPACE_EXISTS="$(kubectl get namespace radius-system --ignore-not-found --output name)"
if [[ -n "$RADIUS_NAMESPACE_EXISTS" && "$RADIUS_REINSTALL" == "true" ]]; then
  INSTALL_ARGS+=(--reinstall)
fi
if [[ -z "$RADIUS_NAMESPACE_EXISTS" || "$RADIUS_REINSTALL" == "true" ]]; then
  rad install "${INSTALL_ARGS[@]}"
else
  echo "Keeping the existing Radius installation; validating it below."
fi

kubectl wait --for=condition=Available deployments --all \
  --namespace radius-system \
  --timeout=10m
kubectl get crd recipes.radapp.io deploymenttemplates.radapp.io deploymentresources.radapp.io >/dev/null

rad workspace create kubernetes "$RADIUS_WORKSPACE" \
  --context "$CURRENT_CONTEXT" \
  --force
rad workspace switch "$RADIUS_WORKSPACE"

# A failed lookup is not evidence that a resource is absent.
groups="$(rad group list --workspace "$RADIUS_WORKSPACE" --output json)"
jq -e 'type == "array" and all(.[]; (.name | type) == "string")' <<<"$groups" >/dev/null
if ! jq -e --arg name "$RADIUS_GROUP" 'any(.[]; .name == $name)' <<<"$groups" >/dev/null; then
  rad group create "$RADIUS_GROUP" --workspace "$RADIUS_WORKSPACE"
fi
rad group switch "$RADIUS_GROUP" --workspace "$RADIUS_WORKSPACE"

environments="$(rad env list --workspace "$RADIUS_WORKSPACE" --group "$RADIUS_GROUP" --output json)"
jq -e 'type == "array" and all(.[]; (.name | type) == "string")' <<<"$environments" >/dev/null
if ! jq -e --arg name "$RADIUS_ENVIRONMENT" 'any(.[]; .name == $name)' <<<"$environments" >/dev/null; then
  rad env create "$RADIUS_ENVIRONMENT" \
    --workspace "$RADIUS_WORKSPACE" \
    --group "$RADIUS_GROUP" \
    --kubernetes-namespace "$RADIUS_NAMESPACE"
fi
rad env switch "$RADIUS_ENVIRONMENT" --workspace "$RADIUS_WORKSPACE"

scope="/planes/radius/local/resourceGroups/${RADIUS_GROUP}"
environment_id="${scope}/providers/Applications.Core/environments/${RADIUS_ENVIRONMENT}"
workspace="$(rad workspace show --output json)"
if ! jq -e --arg context "$K3S_CONTEXT" --arg scope "$scope" --arg environment "$environment_id" \
  '.connection.kind == "kubernetes" and .connection.context == $context and
   .scope == $scope and .environment == $environment' <<<"$workspace" >/dev/null; then
  echo "ERROR: The active workspace must target ${K3S_CONTEXT}, group ${RADIUS_GROUP}, and environment ${RADIUS_ENVIRONMENT}." >&2
  exit 1
fi
rad group show "$RADIUS_GROUP" --workspace "$RADIUS_WORKSPACE"
environment="$(rad env show "$RADIUS_ENVIRONMENT" --workspace "$RADIUS_WORKSPACE" \
  --group "$RADIUS_GROUP" --output json)"
if ! jq -e --arg name "$RADIUS_ENVIRONMENT" --arg namespace "$RADIUS_NAMESPACE" \
  '.name == $name and .properties.compute.kind == "kubernetes" and
   .properties.compute.namespace == $namespace and .properties.providers.azure == null' \
  <<<"$environment" >/dev/null; then
  echo "ERROR: Environment ${RADIUS_ENVIRONMENT} must use Kubernetes namespace ${RADIUS_NAMESPACE} with no Azure provider. Inspect it with rad env show; existing configuration was not overwritten." >&2
  exit 1
fi
kubectl get pods --namespace radius-system

echo "Radius on K3s is healthy: workspace ${RADIUS_WORKSPACE}, group ${RADIUS_GROUP}, environment ${RADIUS_ENVIRONMENT}, namespace ${RADIUS_NAMESPACE}."
echo "Explore the dashboard: kubectl port-forward service/dashboard --namespace radius-system 7007:80"
