#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
trap 'echo "ERROR: Lab connection failed at line ${LINENO}. Check the selected resources and Azure permissions; contact the facilitator if resources are missing." >&2' ERR

if (($# != 0)); then
  echo "Usage: AZURE_SUBSCRIPTION=<id> RESOURCE_GROUP=<group> bash resources/connect-lab.sh" >&2
  exit 2
fi
: "${AZURE_SUBSCRIPTION:?Set AZURE_SUBSCRIPTION to your assigned subscription ID.}"
: "${RESOURCE_GROUP:?Set RESOURCE_GROUP to your assigned lab resource group.}"
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source resources/console-session.sh
export AZURE_SUBSCRIPTION RESOURCE_GROUP
export K3S_LOCAL_PORT="${K3S_LOCAL_PORT:-16443}"
export K3S_REFRESH_KUBECONFIG=true
export RADIUS_IDENTITY_MODE=managedidentity
export RADIUS_REINSTALL=false

environment_file=""
tunnel_attempted=false
cleanup() {
  local result=$?
  trap - EXIT
  if [[ -n "$environment_file" ]]; then
    rm -f "$environment_file"
  fi
  if ((result != 0)) && [[ "$tunnel_attempted" == "true" ]]; then
    if ! bash resources/prepare-k3s-azure-vm.sh disconnect; then
      echo "Unable to stop the Bastion tunnel after the connection failure." >&2
    fi
  fi
  exit "$result"
}
trap cleanup EXIT

mkdir -p artifacts
rm -f artifacts/lab-env.sh
source resources/azure-session.sh
az group show --name "$RESOURCE_GROUP" --output none
export AZURE_LOCATION
AZURE_LOCATION="$(az aks show --resource-group "$RESOURCE_GROUP" \
  --name "$AKS_CLUSTER" --query location --output tsv)"
connect_aks
kubectl --request-timeout=15s get --raw=/readyz | grep -qx "ok"
tunnel_attempted=true
connect_k3s
unset KUBECONFIG
kubectl config use-context "$AKS_CONTEXT" >/dev/null

environment_file="$(mktemp artifacts/lab-env.XXXXXX)"
printf 'unset KUBECONFIG\n' >"$environment_file"
for name in AZURE_SUBSCRIPTION RESOURCE_GROUP AZURE_LOCATION AKS_CLUSTER AKS_CLUSTER_NAME \
  AKS_CONTEXT K3S_CONTEXT K3S_VM_NAME BASTION_NAME K3S_KUBECONFIG K3S_LOCAL_PORT \
  K3S_TUNNEL_STATE_DIR RADIUS_GROUP RADIUS_IDENTITY_MODE RADIUS_REINSTALL; do
  declare -p "$name" | sed 's/^declare -x /export /; s/^declare -- /export /' >>"$environment_file"
done
mv "$environment_file" artifacts/lab-env.sh
echo "Connected to AKS and K3s; AKS is selected. No infrastructure or Radius installation was provisioned."
echo "In this terminal and each new Bash terminal: source artifacts/lab-env.sh"
echo "After a devcontainer restart: bash resources/connect-lab.sh"
