#!/usr/bin/env bash
# Invoke with Bash from the Adaptive Apps MicroHack root; executable bits are not required.
set -euo pipefail

for command_name in az grep kubectl mktemp rad; do
  command -v "$command_name" >/dev/null 2>&1 || {
    echo "Required command not found: $command_name" >&2
    exit 1
  }
done

: "${AZURE_SUBSCRIPTION:?Set AZURE_SUBSCRIPTION to the target subscription ID.}"
: "${RESOURCE_GROUP:?Set RESOURCE_GROUP to the Azure resource group used by Radius.}"

AKS_CLUSTER="${AKS_CLUSTER:-aks-adaptive-apps}"
RADIUS_WORKSPACE="${RADIUS_WORKSPACE:-ws-azure-prod}"
RADIUS_ENVIRONMENT="${RADIUS_ENVIRONMENT:-env-azure-prod}"
RADIUS_GROUP="${RADIUS_GROUP:-rg-trading}"
RADIUS_NAMESPACE="${RADIUS_NAMESPACE:-env-azure-prod}"
RADIUS_AZURE_ROLE="${RADIUS_AZURE_ROLE:-Owner}"
RADIUS_APP_NAME="${RADIUS_APP_NAME:-${AKS_CLUSTER}-radius-app}"

az account show >/dev/null 2>&1 || az login
az account set --subscription "$AZURE_SUBSCRIPTION"

CURRENT_CONTEXT="$(kubectl config current-context)"
if [[ "$CURRENT_CONTEXT" != "$AKS_CLUSTER" ]]; then
  echo "Current context is $CURRENT_CONTEXT; expected $AKS_CLUSTER." >&2
  exit 1
fi

OIDC_ISSUER="$(az aks show \
  --resource-group "$RESOURCE_GROUP" \
  --name "$AKS_CLUSTER" \
  --query oidcIssuerProfile.issuerUrl \
  --output tsv)"
[[ -n "$OIDC_ISSUER" ]] || {
  echo "AKS OIDC issuer is not enabled." >&2
  exit 1
}

APPLICATION_CLIENT_ID="$(az ad app list \
  --filter "displayName eq '${RADIUS_APP_NAME}'" \
  --query "[0].appId" \
  --output tsv)"

if [[ -z "$APPLICATION_CLIENT_ID" ]]; then
  APPLICATION_CLIENT_ID="$(az ad app create \
    --display-name "$RADIUS_APP_NAME" \
    --query appId \
    --output tsv)"
fi

APPLICATION_OBJECT_ID="$(az ad app show \
  --id "$APPLICATION_CLIENT_ID" \
  --query id \
  --output tsv)"

if ! az ad sp show --id "$APPLICATION_CLIENT_ID" >/dev/null 2>&1; then
  az ad sp create --id "$APPLICATION_CLIENT_ID" --output none
  for attempt in {1..30}; do
    az ad sp show --id "$APPLICATION_CLIENT_ID" >/dev/null 2>&1 && break
    [[ "$attempt" -lt 30 ]] || {
      echo "Timed out waiting for the Radius service principal." >&2
      exit 1
    }
    sleep 5
  done
fi

SERVICE_PRINCIPAL_OBJECT_ID="$(az ad sp show \
  --id "$APPLICATION_CLIENT_ID" \
  --query id \
  --output tsv)"

TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT

ensure_federated_credential() {
  local name="$1"
  local service_account="$2"
  local credential_id
  local current_issuer
  local current_subject

  credential_id="$(az ad app federated-credential list \
    --id "$APPLICATION_OBJECT_ID" \
    --query "[?name=='${name}'].id | [0]" \
    --output tsv)"

  if [[ -n "$credential_id" ]]; then
    current_issuer="$(az ad app federated-credential show \
      --id "$APPLICATION_OBJECT_ID" \
      --federated-credential-id "$credential_id" \
      --query issuer \
      --output tsv)"
    current_subject="$(az ad app federated-credential show \
      --id "$APPLICATION_OBJECT_ID" \
      --federated-credential-id "$credential_id" \
      --query subject \
      --output tsv)"
    if [[ "$current_issuer" == "$OIDC_ISSUER" &&
          "$current_subject" == "system:serviceaccount:radius-system:${service_account}" ]]; then
      return
    fi
    az ad app federated-credential delete \
      --id "$APPLICATION_OBJECT_ID" \
      --federated-credential-id "$credential_id"
  fi

  cat >"${TEMP_DIR}/${name}.json" <<EOF
{
  "name": "${name}",
  "issuer": "${OIDC_ISSUER}",
  "subject": "system:serviceaccount:radius-system:${service_account}",
  "description": "Radius workload identity for ${service_account}",
  "audiences": ["api://AzureADTokenExchange"]
}
EOF

  az ad app federated-credential create \
    --id "$APPLICATION_OBJECT_ID" \
    --parameters "@${TEMP_DIR}/${name}.json" \
    --output none
}

ensure_federated_credential radius-applications-rp applications-rp
ensure_federated_credential radius-bicep-de bicep-de
ensure_federated_credential radius-ucp ucp
ensure_federated_credential radius-dynamic-rp dynamic-rp

SCOPE="/subscriptions/${AZURE_SUBSCRIPTION}/resourceGroups/${RESOURCE_GROUP}"
ASSIGNMENT_ID="$(az role assignment list \
  --assignee-object-id "$SERVICE_PRINCIPAL_OBJECT_ID" \
  --fill-principal-name false \
  --scope "$SCOPE" \
  --role "$RADIUS_AZURE_ROLE" \
  --query "[0].id" \
  --output tsv)"
if [[ -z "$ASSIGNMENT_ID" ]]; then
  az role assignment create \
    --assignee-object-id "$SERVICE_PRINCIPAL_OBJECT_ID" \
    --assignee-principal-type ServicePrincipal \
    --role "$RADIUS_AZURE_ROLE" \
    --scope "$SCOPE" \
    --output none
fi

INSTALL_ARGS=(
  kubernetes
  --kubecontext "$CURRENT_CONTEXT"
  --set global.azureWorkloadIdentity.enabled=true
)
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
rad env update "$RADIUS_ENVIRONMENT" \
  --azure-subscription-id "$AZURE_SUBSCRIPTION" \
  --azure-resource-group "$RESOURCE_GROUP"
rad env switch "$RADIUS_ENVIRONMENT"

TENANT_ID="$(az account show --query tenantId --output tsv)"
rad credential register azure wi \
  --client-id "$APPLICATION_CLIENT_ID" \
  --tenant-id "$TENANT_ID"

kubectl wait --for=condition=Available deployments --all \
  --namespace radius-system \
  --timeout=10m
kubectl get crd applications.radapp.io >/dev/null
rad env show "$RADIUS_ENVIRONMENT" >/dev/null
rad group show "$RADIUS_GROUP" >/dev/null
rad credential show azure >/dev/null
kubectl get pods --namespace radius-system

echo "Radius on AKS is healthy in workspace ${RADIUS_WORKSPACE}."
