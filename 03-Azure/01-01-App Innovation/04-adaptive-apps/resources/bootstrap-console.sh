#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
trap 'echo "ERROR: Console bootstrap failed at line ${LINENO}." >&2' ERR

if (($# != 1)); then
  echo "Usage: $0 <aks-radius|k3s-radius|aks-types|k3s-types|recipes|verify>" >&2
  exit 2
fi
case "$1" in
  aks-radius | k3s-radius | aks-types | k3s-types | recipes | verify) ;;
  *) echo "Unknown Console bootstrap phase: $1" >&2; exit 2 ;;
esac
: "${RESOURCE_GROUP:?Set RESOURCE_GROUP to the Console lab resource group.}"
: "${ACR_NAME:?Set ACR_NAME to the provisioned recipe registry.}"
: "${K3S_LOCAL_PORT:?Set an isolated K3S_LOCAL_PORT for this Console job.}"
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source resources/console-session.sh
source resources/azure-session.sh
export RADIUS_REINSTALL=false
export RADIUS_IDENTITY_MODE=managedidentity

cleanup() {
  local result=$?
  trap - EXIT
  if ! bash resources/prepare-k3s-azure-vm.sh disconnect; then
    echo "Unable to stop this Console job's Bastion tunnel." >&2
    result=1
  fi
  exit "$result"
}
trap cleanup EXIT

case "$1" in
  aks-radius)
    connect_aks
    bash resources/deploy-radius-aks.sh
    ;;
  k3s-radius)
    connect_k3s
    bash resources/deploy-radius-k3s.sh
    ;;
  aks-types)
    connect_aks
    select_workspace ws-azure-prod "$AKS_CONTEXT" env-azure-prod
    bash resources/configure-resource-types-aks.sh
    ;;
  k3s-types)
    connect_k3s
    select_workspace ws-local-prod "$K3S_CONTEXT" env-local-prod
    bash resources/configure-resource-types-k3s.sh
    ;;
  recipes | verify)
    connect_aks
    select_workspace ws-azure-prod "$AKS_CONTEXT" env-azure-prod
    connect_k3s
    select_workspace ws-local-prod "$K3S_CONTEXT" env-local-prod
    if [[ "$1" == "recipes" ]]; then
      bash resources/configure-recipes.sh all
    else
      verify_environment ws-local-prod env-local-prod
      unset KUBECONFIG
      kubectl config use-context "$AKS_CONTEXT" >/dev/null
      rad workspace switch ws-azure-prod
      verify_environment ws-azure-prod env-azure-prod
    fi
    ;;
esac
