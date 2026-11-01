# Solution 03 — Deploy Foundry Local Operator & Serve a Quantized CPU SLM

**[Home](../../Readme.md)** - [← Previous Solution](../challenge-02/solution-02.md) - [Back to Challenge 03](../../challenges/challenge-03.md) - [Next Solution →](../challenge-04/solution-04.md)

**Duration:** 45 minutes

## Step 1: Install Kubernetes Gateway API CRDs & Istio

Foundry Local routes model inference traffic through the **Kubernetes Gateway API** using **Istio** (`istio-base` + `istiod`) as the Gateway controller. Install the Gateway API CRDs and Inference Extension CRDs **before** installing `istiod`:

```bash
source ~/edge-env.sh
cd ~/MicroHack/03-Azure/01-04-AI/09_Air_Gapped_Agentic_Edge_AI

# 1. Install Kubernetes Gateway API CRDs (v1.4.0 standard channel, reconciling with cert-manager's Helm fields)
kubectl apply --server-side --force-conflicts -f \
  https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.4.0/standard-install.yaml

# 2. Install Gateway API Inference Extension CRDs (v1.5.0)
kubectl apply --server-side --force-conflicts -f \
  https://github.com/kubernetes-sigs/gateway-api-inference-extension/releases/download/v1.5.0/manifests.yaml

# 3. Install Istio base and istiod with Inference Extension support
helm repo add istio https://istio-release.storage.googleapis.com/charts
helm repo update

helm upgrade --install istio-base istio/base \
  -n istio-system --create-namespace --wait

helm upgrade --install istiod istio/istiod \
  -n istio-system \
  --set pilot.env.ENABLE_GATEWAY_API_INFERENCE_EXTENSION=true \
  --wait
```

Verify that the `istio` `GatewayClass` is `Accepted`:

```bash
kubectl get gatewayclass istio
```

Expected output:

```text
NAME    CONTROLLER                    ACCEPTED   AGE
istio   istio.io/gateway-controller   True       1m
```

---

## Step 2: Update `cert-manager` (`Microsoft.CertManagement`) for Foundry Local

When you ran `az iot ops init` in Challenge 02, Azure IoT Operations automatically installed the **`cert-manager` (`microsoft.certmanagement`)** Arc extension, but configured it with `trust-manager.secretTargets.enabled=false`.

Foundry Local (`Microsoft.Foundry`) requires `trust-manager` secret targets (`foundry-local-operator-ca-bundle`) and Gateway API certificate support to be enabled on `cert-manager`. Update the existing `cert-manager` extension in place **before** installing Foundry Local:

```bash
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
```

---

## Step 3: Install the Foundry Local Extension (`Microsoft.Foundry`)

Install the **Foundry Local** inference operator with:
- Kubernetes **Service Account Token (SAT)** authentication enabled (`satAuth.enabled=true`, `satAuth.audience=foundry-local`) for air-gapped in-cluster agents.
- Reduced model-cache job memory requests (`4Gi` request / `12Gi` limit) sized for quantized CPU SLMs on a 16-vCPU/64-GiB edge host.

```bash
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
```

Verify that the operator pods and catalog ConfigMap are ready in `foundry-local-operator` (waiting for the `catalog-sync-seed` job to finish populating the 177-model catalog):

```bash
kubectl get pods -n foundry-local-operator
kubectl wait --for=condition=complete job/catalog-sync-seed -n foundry-local-operator --timeout=120s
kubectl get configmap foundry-local-catalog -n foundry-local-operator \
  -o jsonpath="{.data['catalog\.json']}" | jq '.models[] | select(.supportedCompute[] == "cpu") | {alias: .alias, displayName: .displayName, framework: .framework, compute: .supportedCompute}'
```

---

## Step 4: Deploy the Quantized CPU Small Language Model (`ModelDeployment`)

First, create the `inference-client` `ServiceAccount` in `edge-agents` so it can be referenced in the `ModelDeployment` authorization list:

```bash
kubectl apply -f resources/manifests/02-foundry-local/caller-service-account.yaml
```

Next, apply [`resources/manifests/02-foundry-local/model-deployment-cpu.yaml`](../../resources/manifests/02-foundry-local/model-deployment-cpu.yaml) to deploy **`phi-4-mini` (`spec.model.catalog.name: phi-4-mini`, which resolves to `Phi-4-mini-instruct-generic-cpu:5`, `compute: cpu`, `runtime: onnx-genai`, `exposure: internal`)**:

```bash
kubectl apply -f resources/manifests/02-foundry-local/model-deployment-cpu.yaml
```

Monitor the `StoreModel` cache job (~6–7 minutes to download and validate the 5.15 GB ONNX INT4 weights into the local cluster registry) and the `ModelDeployment` status until `STATE` is `Running` and `READY` is `true`:

```bash
kubectl get storemodel,modeldeployment -n foundry-local-operator -w
```

Once `phi-4-mini` reaches the `Running` state, inspect its internal cluster endpoint (`https://inference-internal-gateway-istio.foundry-local-operator.svc.cluster.local:443/phi-4-mini`):

```bash
ENDPOINT=$(kubectl get modeldeployment phi-4-mini -n foundry-local-operator -o jsonpath='{.status.endpoints.internal}')
echo "Internal Foundry Local Endpoint: $ENDPOINT"
```

![Challenge 03 — Azure Portal Arc-enabled Kubernetes Extensions](../../img/portal-arc-extensions.png)

![Challenge 03 — Live Azure Bastion Terminal: StoreModel Caching & Operator Pods](../../img/bastion-challenge-03-storing.png)

![Challenge 03 — Foundry Local Extension, StoreModel Cache & Phi-4-mini CPU ModelDeployment](../../img/challenge-03-foundry-local-operator.png)

**Common stumbles:** `inference-operator` fails with `secret "foundry-local-operator-ca-bundle" not found` (happens if Step 2 `az k8s-extension update --name cert-manager` was skipped before installing `Microsoft.Foundry`) · `ModelDeployment` rejected as unknown catalog model (use lowercase alias `phi-4-mini` in `spec.model.catalog.name`, which resolves to `Phi-4-mini-instruct-generic-cpu:5`).

---

## Grounding Questions — Suggested Answers

**1. How does Foundry Local's `StoreModel` + `inference-operator-model-store` architecture ensure that model pods can restart or scale when the cluster is air-gapped?**
When a `ModelDeployment` is created, the operator spawns a `StoreModel` cache job that downloads the ONNX model files once, verifies their cryptographic hashes and manifest completeness, and pushes them as an OCI artifact into the local in-cluster registry (`model-store.foundry-local-operator.svc.cluster.local:8443`) backed by a persistent volume. Inference pods pull weights exclusively from this local cluster registry, never from the internet.

**2. Why did we set `entraAuth.enabled=false` and `satAuth.enabled=true` on the `inference-operator` extension for this sovereign edge scenario?**
In an air-gapped or WAN-disconnected factory, pods cannot reach public Microsoft Entra ID endpoints to issue tokens or validate RBAC assignments against Azure Resource Manager. Kubernetes Service Account Token (`satAuth`) authentication relies entirely on the local Kubernetes cluster's OIDC keyset, making it 100% resilient to internet outages.

[← Previous Solution](../challenge-02/solution-02.md) | [Back to Challenge 03](../../challenges/challenge-03.md) | [Next Solution →](../challenge-04/solution-04.md)
