# Prepare the AKS environment

The default Azure environment is AKS with OIDC issuer, workload identity, and the
managed Istio add-on enabled. Challenge 01 provisions Kubernetes only.

## Automated preparation

```bash
export AZURE_SUBSCRIPTION="<subscription-id>"
export AZURE_LOCATION="westeurope"
export RESOURCE_GROUP="rg-adaptive-apps"
export AKS_CLUSTER="aks-adaptive-apps"

chmod +x resources/prepare-aks.sh
./resources/prepare-aks.sh
```

Optional settings are `AKS_NODE_COUNT` and `AKS_NODE_VM_SIZE`.

## Manual equivalent

```bash
az account set --subscription "$AZURE_SUBSCRIPTION"
az group create --name "$RESOURCE_GROUP" --location "$AZURE_LOCATION"

az aks create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$AKS_CLUSTER" \
  --location "$AZURE_LOCATION" \
  --node-count 2 \
  --node-vm-size Standard_D4s_v5 \
  --node-osdisk-type Managed \
  --enable-oidc-issuer \
  --enable-workload-identity \
  --enable-asm \
  --generate-ssh-keys

az aks get-credentials \
  --resource-group "$RESOURCE_GROUP" \
  --name "$AKS_CLUSTER" \
  --overwrite-existing
```

For an existing cluster, enable the required features:

```bash
az aks update \
  --resource-group "$RESOURCE_GROUP" \
  --name "$AKS_CLUSTER" \
  --enable-oidc-issuer \
  --enable-workload-identity

az aks mesh enable \
  --resource-group "$RESOURCE_GROUP" \
  --name "$AKS_CLUSTER"
```

## Health check

```bash
kubectl config use-context "$AKS_CLUSTER"
kubectl get --raw="/readyz"
kubectl wait --for=condition=Ready nodes --all --timeout=10m
kubectl get nodes -o wide

az aks show \
  --resource-group "$RESOURCE_GROUP" \
  --name "$AKS_CLUSTER" \
  --query "{state:provisioningState,oidc:oidcIssuerProfile.enabled,workloadIdentity:securityProfile.workloadIdentity.enabled,serviceMesh:serviceMeshProfile.mode}"
```

Radius is installed in Challenge 02.
