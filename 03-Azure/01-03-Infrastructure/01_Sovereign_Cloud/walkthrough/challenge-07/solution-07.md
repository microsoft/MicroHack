# Walkthrough Challenge 7 - Adaptive Apps Across Sovereign Environments

[Previous Challenge Solution](../challenge-06/solution-06.md) - **[Home](../../Readme.md)**

Duration: 60 minutes

## Prerequisites

Please ensure that you successfully verified the [General prerequisites](../../Readme.md#general-prerequisites) before continuing.

Install these tools on your workstation or use a development container that includes them:

* Azure CLI with the `bastion` extension
* `kubectl`
* `jq` and OpenSSL
* [Radius CLI (`rad`)](https://docs.radapp.io/getting-started/install/)

Set the values shown on your lab dashboard:

```bash
export AZURE_SUBSCRIPTION="{{subscriptionId}}"
export RESOURCE_GROUP="{{resourceGroup}}"
export AKS_CLUSTER="{{adaptiveAppsAksCluster}}"
export K3S_VM="{{adaptiveAppsK3sVm}}"
export BASTION_NAME="{{adaptiveAppsBastion}}"
export K3S_KUBECONFIG="$HOME/.kube/adaptive-apps-k3s.yaml"
export K3S_CONTEXT="k3s-azure-vm"

az account set --subscription "$AZURE_SUBSCRIPTION"
```

> [!NOTE]
> The platform creates stable resource names and credentials. Re-running the lab deployment converges on the same names and replaces the isolated resource group only when region fallback is required.

## Task 1: Connect to and validate both platforms (10 minutes)

💡 **Start with explicit target discipline. A Kubernetes context and a Radius workspace are independent selectors.**

### Validate AKS

```bash
unset KUBECONFIG
az aks get-credentials \
  --resource-group "$RESOURCE_GROUP" \
  --name "$AKS_CLUSTER" \
  --overwrite-existing

kubectl config rename-context "$AKS_CLUSTER" aks-adaptive-apps 2>/dev/null || true
kubectl config use-context aks-adaptive-apps
kubectl get --raw='/readyz'
kubectl wait --for=condition=Ready nodes --all --timeout=10m
```

Confirm the sovereign-ready AKS features:

```bash
az aks show \
  --resource-group "$RESOURCE_GROUP" \
  --name "$AKS_CLUSTER" \
  --query '{oidc:oidcIssuerProfile.enabled,workloadIdentity:securityProfile.workloadIdentity.enabled,serviceMesh:serviceMeshProfile.mode}' \
  --output table
```

### Retrieve the K3s kubeconfig securely

The kubeconfig is retrieved in bounded chunks through Azure VM Run Command. It is written with user-only permissions and changed to use the localhost tunnel endpoint.

```bash
mkdir -p "$(dirname "$K3S_KUBECONFIG")"
chmod 0700 "$(dirname "$K3S_KUBECONFIG")"
ENCODED_KUBECONFIG="$(mktemp)"
DECODED_KUBECONFIG="$(mktemp)"

LENGTH_RESPONSE="$(az vm run-command invoke \
  --resource-group "$RESOURCE_GROUP" \
  --name "$K3S_VM" \
  --command-id RunShellScript \
  --scripts 'encoded="$(base64 -w0 /etc/rancher/k3s/k3s.yaml)"; printf "K3S_LENGTH:%s\n" "${#encoded}"' \
  --output json)"
ENCODED_LENGTH="$(printf '%s' "$LENGTH_RESPONSE" \
  | jq -r '.value[]?.message // empty' \
  | sed -n 's/^K3S_LENGTH:\([0-9][0-9]*\)$/\1/p' \
  | tail -n 1)"

test -n "$ENCODED_LENGTH"
: >"$ENCODED_KUBECONFIG"
for ((START = 1; START <= ENCODED_LENGTH; START += 1800)); do
  END=$((START + 1799))
  RESPONSE="$(az vm run-command invoke \
    --resource-group "$RESOURCE_GROUP" \
    --name "$K3S_VM" \
    --command-id RunShellScript \
    --scripts "printf 'K3S_CHUNK_BEGIN\\n'; base64 -w0 /etc/rancher/k3s/k3s.yaml | cut -c ${START}-${END}; printf '\\nK3S_CHUNK_END\\n'" \
    --output json)"
  CHUNK="$(printf '%s' "$RESPONSE" \
    | jq -r '.value[]?.message // empty' \
    | sed -n '/^K3S_CHUNK_BEGIN$/,/^K3S_CHUNK_END$/p' \
    | sed '1d;$d' \
    | tr -d '\r\n')"
  test -n "$CHUNK"
  printf '%s' "$CHUNK" >>"$ENCODED_KUBECONFIG"
done

test "$(wc -c <"$ENCODED_KUBECONFIG" | tr -d '[:space:]')" = "$ENCODED_LENGTH"
openssl base64 -d -A -in "$ENCODED_KUBECONFIG" -out "$DECODED_KUBECONFIG"
sed 's#server: https://[^:]*:6443#server: https://127.0.0.1:16443#' \
  "$DECODED_KUBECONFIG" >"$K3S_KUBECONFIG"
chmod 0600 "$K3S_KUBECONFIG"
KUBECONFIG="$K3S_KUBECONFIG" kubectl config rename-context default "$K3S_CONTEXT" 2>/dev/null || true
rm -f "$ENCODED_KUBECONFIG" "$DECODED_KUBECONFIG"

# Radius resolves installation contexts from the default kubeconfig. Merge the
# K3s context there while keeping the dedicated file as the explicit selector.
touch "$HOME/.kube/config"
MERGED_KUBECONFIG="$(mktemp)"
KUBECONFIG="$HOME/.kube/config:$K3S_KUBECONFIG" \
  kubectl config view --flatten >"$MERGED_KUBECONFIG"
install -m 0600 "$MERGED_KUBECONFIG" "$HOME/.kube/config"
rm -f "$MERGED_KUBECONFIG"
```

Start the Bastion tunnel in a second terminal and leave it running:

```bash
az network bastion tunnel \
  --name "$BASTION_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --target-resource-id "/subscriptions/${AZURE_SUBSCRIPTION}/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.Compute/virtualMachines/${K3S_VM}" \
  --resource-port 6443 \
  --port 16443
```

Return to the first terminal and validate K3s:

```bash
export KUBECONFIG="$K3S_KUBECONFIG"
kubectl config use-context "$K3S_CONTEXT"
kubectl get --raw='/readyz'
kubectl wait --for=condition=Ready nodes --all --timeout=10m

az vm show \
  --resource-group "$RESOURCE_GROUP" \
  --name "$K3S_VM" \
  --show-details \
  --query publicIps \
  --output tsv
```

✅ The readiness endpoint returns `ok`, the node is `Ready`, and the final command returns an empty value because the VM has no public IP.

## Task 2: Install federated Radius control planes (20 minutes)

🔑 **A federated control plane keeps each site operationally independent. Shared source control can promote the same application model without introducing a runtime dependency between sites.**

### Install Radius on K3s

```bash
export KUBECONFIG="$K3S_KUBECONFIG"
kubectl config use-context "$K3S_CONTEXT"

rad install kubernetes --kubecontext "$K3S_CONTEXT"
rad workspace create kubernetes ws-local-prod \
  --context "$K3S_CONTEXT" \
  --force
rad workspace switch ws-local-prod
rad group show rg-trading >/dev/null 2>&1 || rad group create rg-trading
rad group switch rg-trading
rad env show env-local-prod >/dev/null 2>&1 || rad env create env-local-prod \
  --group rg-trading \
  --kubernetes-namespace env-local-prod
rad env switch env-local-prod

kubectl wait --for=condition=Available deployments --all \
  --namespace radius-system \
  --timeout=10m
```

### Install Radius on AKS

```bash
unset KUBECONFIG
kubectl config use-context aks-adaptive-apps

rad install kubernetes --kubecontext aks-adaptive-apps
rad workspace create kubernetes ws-azure-prod \
  --context aks-adaptive-apps \
  --force
rad workspace switch ws-azure-prod
rad group show rg-trading >/dev/null 2>&1 || rad group create rg-trading
rad group switch rg-trading
rad env show env-azure-prod >/dev/null 2>&1 || rad env create env-azure-prod \
  --group rg-trading \
  --kubernetes-namespace env-azure-prod
rad env switch env-azure-prod

kubectl wait --for=condition=Available deployments --all \
  --namespace radius-system \
  --timeout=10m
```

💡 **This challenge does not register an Azure provider with Radius. The portable application uses Kubernetes compute only. Later Adaptive Apps challenges can add workload identity and recipes for Azure-managed capabilities without changing the application boundary.**

## Task 3: Create one portable application model (10 minutes)

💥 **Create a Radius Bicep file that contains no AKS cluster name, VM address, namespace, or cloud-specific resource.**

```bash
cat >sovereign-web.bicep <<'BICEP'
extension radius

@description('The Radius environment ID injected by the Radius CLI.')
param environment string

resource app 'Applications.Core/applications@2023-10-01-preview' = {
  name: 'sovereign-web'
  properties: {
    environment: environment
  }
}

resource web 'Applications.Core/containers@2023-10-01-preview' = {
  name: 'web'
  properties: {
    application: app.id
    container: {
      image: 'nginx:1.27-alpine'
      ports: {
        http: {
          containerPort: 80
        }
      }
    }
  }
}
BICEP
```

Review the file and identify the portability boundary:

* The application team owns the application, image, and requested port.
* The selected Radius environment owns the Kubernetes namespace and target control plane.
* A platform team can later attach recipes to portable capability resources without adding platform details to this application model.

## Task 4: Deploy the unchanged model twice (15 minutes)

### Deploy to K3s

```bash
export KUBECONFIG="$K3S_KUBECONFIG"
kubectl config use-context "$K3S_CONTEXT"
rad workspace switch ws-local-prod
rad group switch rg-trading
rad env switch env-local-prod

test "$(kubectl config current-context)" = "$K3S_CONTEXT"
rad deploy sovereign-web.bicep \
  --workspace ws-local-prod \
  --group rg-trading \
  --environment env-local-prod

rad app graph --application sovereign-web
rad resource list --application sovereign-web
```

Expose the application, browse to <http://localhost:8080>, and stop the foreground process with <kbd>Ctrl</kbd>+<kbd>C</kbd>:

```bash
rad resource expose Applications.Core/containers web \
  --application sovereign-web \
  --port 8080 \
  --remote-port 80
```

### Deploy the same file to AKS

```bash
unset KUBECONFIG
kubectl config use-context aks-adaptive-apps
rad workspace switch ws-azure-prod
rad group switch rg-trading
rad env switch env-azure-prod

test "$(kubectl config current-context)" = 'aks-adaptive-apps'
rad deploy sovereign-web.bicep \
  --workspace ws-azure-prod \
  --group rg-trading \
  --environment env-azure-prod

rad app graph --application sovereign-web
rad resource list --application sovereign-web
```

Expose the AKS application and browse to <http://localhost:8080>:

```bash
rad resource expose Applications.Core/containers web \
  --application sovereign-web \
  --port 8080 \
  --remote-port 80
```

> [!IMPORTANT]
> Do not edit `sovereign-web.bicep` between deployments. Changing the target selectors is the point of the exercise.

## Task 5: Validate site independence (5 minutes)

Stop the AKS exposure, switch back to K3s, and inspect its application without selecting or contacting the AKS Radius control plane:

```bash
export KUBECONFIG="$K3S_KUBECONFIG"
kubectl config use-context "$K3S_CONTEXT"
rad workspace switch ws-local-prod
rad app graph --application sovereign-web
kubectl get pods --all-namespaces --selector radapp.io/application=sovereign-web
```

🔑 **The two applications have the same name and model but independent state. A loss of AKS or connectivity to Azure does not remove the K3s control plane or its running application. Data synchronization, configuration promotion, and disconnected software distribution remain separate architecture decisions.**

## Validation

You have completed the challenge when:

* Both clusters are healthy and the K3s VM has no public IP.
* Both `radius-system` installations are healthy.
* The workspace target matches the Kubernetes context before every deployment.
* `sovereign-web.bicep` remains unchanged.
* Both Radius control planes show an independent `sovereign-web` graph.
* Each deployment displays the NGINX page through local port forwarding.
* You can explain why federated control planes improve site autonomy and where Radius recipes fit when managed and local capability implementations differ.

> [!WARNING]
> Delete the lab resource group promptly after the workshop. AKS nodes, the K3s VM, NAT Gateway, and Azure Bastion accrue hourly charges.