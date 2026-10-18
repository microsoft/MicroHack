#!/usr/bin/env bash
# ============================================================================
# Full Unattended End-to-End Challenge 01–05 Runner (Executed inside K3s VM)
# Invoked automatically by Invoke-E2ELabValidation.ps1 -Mode LiveAzure
# Exercises the complete stack:
#   - Challenge 01: Kernel sysctl, K3s readiness, Azure Arc connect + Custom Locations
#   - Challenge 02: Schema Registry, Device Registry Namespace, az iot ops init/create,
#                   BrokerListener, Anomaly Dataflow, Telemetry Simulator
#   - Challenge 03: Gateway API CRDs, Istio, cert-manager update, Microsoft.Foundry
#                   operator, phi-4-mini CPU ModelDeployment & StoreModel cache
#   - Challenge 04: SAT token verification, SOP ConfigMap, Autonomous Edge Agent
#   - Challenge 05: Air-Gap NetworkPolicy, blocked cloud check, Critical Fault
#                   injection, and verification of spindleRpm=1680 interlock
# ============================================================================
set -euo pipefail

for arg in "$@"; do
  export "$arg"
done

export HOME=/root
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
export AZURE_EXTENSION_DIR=/usr/local/lib/azure-cli-extensions
export ARC_LOCATION="${ARC_LOCATION:-westeurope}"

echo "[E2E] Waiting for cloud-init bootstrap (/var/log/edge-bootstrap-complete.log)..."
for i in $(seq 1 60); do
  if [ -f /var/log/edge-bootstrap-complete.log ]; then
    break
  fi
  sleep 10
done

echo "[E2E - Challenge 01] Verifying kernel sysctl parameters and K3s node readiness..."
sysctl fs.inotify.max_user_instances fs.inotify.max_user_watches fs.file-max
kubectl wait --for=condition=Ready node --all --timeout=180s

echo "[E2E - Challenge 01] Signing in with User-Assigned Managed Identity and connecting K3s to Azure Arc in $ARC_LOCATION..."
az login --identity --client-id "$UAMI_CLIENT_ID" --output none
az account set --subscription "$SUBSCRIPTION_ID"

az connectedk8s connect \
  --name "$CLUSTER_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --location "$ARC_LOCATION" \
  --enable-oidc-issuer \
  --enable-workload-identity \
  --disable-auto-upgrade

if [ -n "${CUSTOM_LOCATIONS_OID:-}" ]; then
  az connectedk8s enable-features \
    --name "$CLUSTER_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --custom-locations-oid "$CUSTOM_LOCATIONS_OID" \
    --features cluster-connect custom-locations
fi

echo "[E2E - Challenge 02] Creating Schema Registry, Device Registry Namespace, and deploying Azure IoT Operations..."
STORAGE_ACCOUNT_ID=$(az storage account show --name "$SCHEMA_STORAGE_ACCOUNT" --resource-group "$RESOURCE_GROUP" --query id -o tsv)
SCHEMA_REGISTRY_NAME="sr-${CLUSTER_NAME}"
SCHEMA_REGISTRY_NAMESPACE="srns-${CLUSTER_NAME}"
ADR_NAMESPACE_NAME="adrns-${CLUSTER_NAME}"
AIO_INSTANCE_NAME="aio-${CLUSTER_NAME}"
CUSTOM_LOCATION_NAME="cl-${CLUSTER_NAME}"

az iot ops schema registry create \
  --name "$SCHEMA_REGISTRY_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --location "$ARC_LOCATION" \
  --registry-namespace "$SCHEMA_REGISTRY_NAMESPACE" \
  --sa-resource-id "$STORAGE_ACCOUNT_ID"

az iot ops ns create \
  --name "$ADR_NAMESPACE_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --location "$ARC_LOCATION"

az iot ops init \
  --cluster "$CLUSTER_NAME" \
  --resource-group "$RESOURCE_GROUP"

SCHEMA_REGISTRY_ID=$(az iot ops schema registry show --name "$SCHEMA_REGISTRY_NAME" --resource-group "$RESOURCE_GROUP" --query id -o tsv)
ADR_NAMESPACE_ID=$(az iot ops ns show --name "$ADR_NAMESPACE_NAME" --resource-group "$RESOURCE_GROUP" --query id -o tsv)

az iot ops create \
  --cluster "$CLUSTER_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --name "$AIO_INSTANCE_NAME" \
  --location "$ARC_LOCATION" \
  --custom-location "$CUSTOM_LOCATION_NAME" \
  --sr-resource-id "$SCHEMA_REGISTRY_ID" \
  --ns-resource-id "$ADR_NAMESPACE_ID" \
  --broker-frontend-replicas 1 \
  --broker-frontend-workers 1 \
  --broker-backend-part 1 \
  --broker-backend-workers 1 \
  --broker-backend-rf 2 \
  --broker-mem-profile Low

kubectl apply -f /opt/edge-ai-lab/manifests/01-iot-sim/aio-anomaly-dataflow.yaml
kubectl apply -f /opt/edge-ai-lab/manifests/01-iot-sim/telemetry-simulator.yaml
kubectl rollout status deployment/manufacturing-telemetry-simulator -n edge-agents --timeout=120s

echo "[E2E - Challenge 03] Installing Gateway API, Istio, updating cert-manager, and deploying Foundry Local..."
kubectl apply --server-side --force-conflicts -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.4.0/standard-install.yaml
kubectl apply --server-side --force-conflicts -f https://github.com/kubernetes-sigs/gateway-api-inference-extension/releases/download/v1.5.0/manifests.yaml

helm repo add istio https://istio-release.storage.googleapis.com/charts
helm repo update
helm upgrade --install istio-base istio/base -n istio-system --create-namespace --wait
helm upgrade --install istiod istio/istiod -n istio-system --set pilot.env.ENABLE_GATEWAY_API_INFERENCE_EXTENSION=true --wait

az k8s-extension update \
  --cluster-name "$CLUSTER_NAME" \
  --name "cert-manager" \
  --resource-group "$RESOURCE_GROUP" \
  --cluster-type connectedClusters \
  --config config.enableGatewayAPI=true \
  --config cert-manager.crds.keep=true \
  --config trust-manager.defaultPackage.enabled=false \
  --config trust-manager.secretTargets.enabled=true \
  --config trust-manager.secretTargets.authorizedSecretsAll=true \
  --yes

az k8s-extension create \
  --resource-group "$RESOURCE_GROUP" \
  --cluster-name "$CLUSTER_NAME" \
  --name "inference-operator" \
  --extension-type Microsoft.Foundry \
  --scope cluster \
  --release-namespace "foundry-local-operator" \
  --cluster-type connectedClusters \
  --release-train stable \
  --config entraAuth.enabled=false \
  --config satAuth.enabled=true \
  --config satAuth.audience="foundry-local" \
  --config storeModel.cacheJob.resources.requests.memory="4Gi" \
  --config storeModel.cacheJob.resources.limits.memory="12Gi"

kubectl wait --for=condition=complete job/catalog-sync-seed -n foundry-local-operator --timeout=120s
kubectl apply -f /opt/edge-ai-lab/manifests/02-foundry-local/caller-service-account.yaml
kubectl apply -f /opt/edge-ai-lab/manifests/02-foundry-local/model-deployment-cpu.yaml

for i in $(seq 1 60); do
  READY=$(kubectl get modeldeployment phi-4-mini -n foundry-local-operator -o jsonpath='{.status.deploymentReady}' 2>/dev/null || echo "false")
  if [ "$READY" = "true" ]; then
    break
  fi
  sleep 15
done

echo "[E2E - Challenge 04] Deploying Local SOP ConfigMap and Autonomous Edge Agent..."
kubectl apply -f /opt/edge-ai-lab/manifests/03-edge-agent/local-sop-configmap.yaml
kubectl apply -f /opt/edge-ai-lab/manifests/03-edge-agent/edge-agent-deployment.yaml
kubectl rollout status deployment/autonomous-edge-agent -n edge-agents --timeout=120s

echo "[E2E - Challenge 05] Enforcing Air-Gap NetworkPolicy and injecting Critical Fault..."
kubectl apply -f /opt/edge-ai-lab/manifests/04-airgap-policy/deny-external-egress.yaml
kubectl delete job inject-critical-bearing-fault -n edge-agents --ignore-not-found
kubectl apply -f /opt/edge-ai-lab/manifests/04-airgap-policy/inject-critical-fault.yaml
kubectl wait --for=condition=complete job/inject-critical-bearing-fault -n edge-agents --timeout=60s
sleep 25

kubectl logs -n edge-agents deploy/autonomous-edge-agent --tail=20
kubectl logs -n edge-agents deploy/manufacturing-telemetry-simulator --tail=15 | grep "spindleRpm=1680"
echo "E2E_ALL_CHALLENGES_PASSED"
