#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
trap 'echo "ERROR: Console connection failed at line ${LINENO}; no readiness file was published." >&2' ERR

if (($# != 0)); then
  echo "Usage: AZURE_SUBSCRIPTION=<id> RESOURCE_GROUP=<group> bash resources/connect-console.sh" >&2
  exit 2
fi
: "${RESOURCE_GROUP:?Set RESOURCE_GROUP from your Console lab.}"
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source resources/console-session.sh
source resources/azure-session.sh
tunnel_attempted=false
environment_file=""
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
for command_name in kubectl rad jq curl; do
  command -v "$command_name" >/dev/null || {
    echo "Missing ${command_name}; complete Challenge 1 workstation setup." >&2
    exit 1
  }
done
group="$(az group show --name "$RESOURCE_GROUP" --output json)"
if [[ "$(jq -r '.tags.adaptiveAppsReady' <<<"$group")" != "true" ]]; then
  echo "This lab has not completed Console bootstrap. Ask the organizer to check the deployment." >&2
  exit 1
fi
ACR_NAME="$(jq -er '.tags.adaptiveAppsAcr | select(type == "string" and length > 0)' <<<"$group")"
export ACR_NAME
export AZURE_LOCATION
AZURE_LOCATION="$(jq -er '.location' <<<"$group")"
export K3S_LOCAL_PORT="${K3S_LOCAL_PORT:-16443}"
export K3S_REFRESH_KUBECONFIG=true

mkdir -p artifacts
rm -f artifacts/console-env.sh
connect_aks
select_workspace ws-azure-prod "$AKS_CONTEXT" env-azure-prod
verify_environment ws-azure-prod env-azure-prod
tunnel_attempted=true
connect_k3s
select_workspace ws-local-prod "$K3S_CONTEXT" env-local-prod
verify_environment ws-local-prod env-local-prod
build_local_types
unset KUBECONFIG
kubectl config use-context "$AKS_CONTEXT" >/dev/null
rad workspace switch ws-azure-prod

environment_file="$(mktemp artifacts/console-env.XXXXXX)"
printf 'unset KUBECONFIG\n' >"$environment_file"
for name in AZURE_SUBSCRIPTION RESOURCE_GROUP AZURE_LOCATION ACR_NAME AKS_CLUSTER AKS_CLUSTER_NAME \
  AKS_CONTEXT K3S_CONTEXT K3S_VM_NAME BASTION_NAME K3S_KUBECONFIG K3S_LOCAL_PORT \
  K3S_TUNNEL_STATE_DIR RADIUS_GROUP; do
  declare -p "$name" | sed 's/^declare -x /export /; s/^declare -- /export /' >>"$environment_file"
done
mv "$environment_file" artifacts/console-env.sh
echo "Connected to both platforms. The Bastion API tunnel is running in the background."
echo "In each new Bash terminal: source artifacts/console-env.sh"
echo "Reconnect after restarting your workstation: bash resources/connect-console.sh"
echo "Stop the tunnel: bash resources/prepare-k3s-azure-vm.sh disconnect"
echo "Continue with Challenge 06. No platform resources or recipes were redeployed."
