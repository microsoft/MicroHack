#!/usr/bin/env bash
# Invoke with Bash from the Adaptive Apps MicroHack root; executable bits are not required.
set -euo pipefail

for command_name in curl helm kubectl mktemp rad tar; do
  command -v "$command_name" >/dev/null 2>&1 || {
    echo "Required command not found: $command_name" >&2
    exit 1
  }
done

AKS_CONTEXT="${AKS_CONTEXT:-aks-adaptive-apps}"
RADIUS_WORKSPACE="${RADIUS_WORKSPACE:-ws-azure-prod}"
SQL_TYPE_FILE="${SQL_TYPE_FILE:-iac/sql-databases.yaml}"
TYPES_URL="${TYPES_URL:-https://raw.githubusercontent.com/microsoft/adaptive-apps/885627980684e5bcc6fe4bbd2848c1ec247b0a0b/radius/resource-types/types.yaml}"
BICEP_EXTENSION_TARGET="${BICEP_EXTENSION_TARGET:-artifacts/types.tgz}"
PORTFOLIO="${PORTFOLIO:-core}"
SOURCE_COMMIT="${SOURCE_COMMIT:-885627980684e5bcc6fe4bbd2848c1ec247b0a0b}"

[[ "$(kubectl config current-context)" == "$AKS_CONTEXT" ]] || {
  echo "Select AKS context $AKS_CONTEXT before running this script." >&2
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
  --set features.istio.install=false \
  --set istio.namespace=aks-istio-system \
  --namespace "$PORTFOLIO" \
  --create-namespace

# kubectl rollout status accepts one object at a time; it has no --all flag.
wait_for_portfolio_rollout() {
  local kind="$1"
  local object
  local -a objects=()

  mapfile -t objects < <(kubectl get "$kind" --namespace "$PORTFOLIO" --output name)
  for object in "${objects[@]}"; do
    kubectl rollout status "$object" --namespace "$PORTFOLIO" --timeout=15m
  done
}

wait_for_portfolio_rollout deployment
wait_for_portfolio_rollout statefulset

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

echo "Portfolio and resource types configured on AKS workspace ${RADIUS_WORKSPACE}."
