#!/usr/bin/env bash
set -euo pipefail

for command_name in curl helm kubectl mktemp rad tar; do
  command -v "$command_name" >/dev/null 2>&1 || {
    echo "Required command not found: $command_name" >&2
    exit 1
  }
done

K3S_KUBECONFIG="${K3S_KUBECONFIG:-$HOME/.kube/adaptive-apps-k3s.yaml}"
K3S_CONTEXT="${K3S_CONTEXT:-k3s-azure-vm}"
RADIUS_WORKSPACE="${RADIUS_WORKSPACE:-ws-local-prod}"
SQL_TYPE_FILE="${SQL_TYPE_FILE:-iac/sql-databases.yaml}"
TYPES_URL="${TYPES_URL:-https://raw.githubusercontent.com/microsoft/adaptive-apps/885627980684e5bcc6fe4bbd2848c1ec247b0a0b/radius/resource-types/types.yaml}"
BICEP_EXTENSION_TARGET="${BICEP_EXTENSION_TARGET:-artifacts/types.tgz}"
PORTFOLIO="${PORTFOLIO:-core}"
SOURCE_COMMIT="${SOURCE_COMMIT:-885627980684e5bcc6fe4bbd2848c1ec247b0a0b}"

export KUBECONFIG="${KUBECONFIG:-$K3S_KUBECONFIG}"

[[ "$(kubectl config current-context)" == "$K3S_CONTEXT" ]] || {
  echo "Select K3s context $K3S_CONTEXT before running this script." >&2
  exit 1
}
[[ -f "$SQL_TYPE_FILE" ]] || {
  echo "Resource type file not found: $SQL_TYPE_FILE" >&2
  exit 1
}

TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT
CATALOG_FILE="${TEMP_DIR}/types.yaml"
SOURCE_ARCHIVE="${TEMP_DIR}/adaptive-apps.tar.gz"
SOURCE_ROOT="${TEMP_DIR}/adaptive-apps-${SOURCE_COMMIT}"

curl --fail --location "$TYPES_URL" --output "$CATALOG_FILE"
curl --fail --location \
  "https://github.com/microsoft/adaptive-apps/archive/${SOURCE_COMMIT}.tar.gz" \
  --output "$SOURCE_ARCHIVE"
tar --extract --gzip --file "$SOURCE_ARCHIVE" --directory "$TEMP_DIR"

helm upgrade --install "$PORTFOLIO" \
  "${SOURCE_ROOT}/charts/adaptive-apps" \
  --values "${SOURCE_ROOT}/charts/adaptive-apps/profiles/${PORTFOLIO}.yaml" \
  --namespace "$PORTFOLIO" \
  --create-namespace
kubectl rollout status deployment --all --namespace "$PORTFOLIO" --timeout=15m
kubectl rollout status statefulset --all --namespace "$PORTFOLIO" --timeout=15m

rad workspace switch "$RADIUS_WORKSPACE"
rad resource-type create --workspace "$RADIUS_WORKSPACE" --from-file "$SQL_TYPE_FILE"
rad resource-type create --workspace "$RADIUS_WORKSPACE" --from-file "$CATALOG_FILE"

mkdir -p "$(dirname "$BICEP_EXTENSION_TARGET")"
rad bicep publish-extension \
  --from-file "$CATALOG_FILE" \
  --target "$BICEP_EXTENSION_TARGET" \
  --force

rad resource-type show Radius.Resources/sqlDatabases >/dev/null
rad resource-type show Radius.Resources/postgreSqlDatabases >/dev/null
rad resource-type show Radius.Resources/aiModels >/dev/null
rad resource-type list

echo "Portfolio and resource types configured on K3s workspace ${RADIUS_WORKSPACE}."
