# Walkthrough Challenge 01 - Prepare the platforms

[< Previous Solution](../challenge-00/solution-00.md) - **[Home](../../Readme.md)** - [Next Solution](../challenge-02/solution-02.md)

Duration: 30-60 minutes

## Prerequisites

Complete [Challenge 00](../challenge-00/solution-00.md) and the
[general prerequisites](../../Readme.md#general-prerequisites) before starting.

This challenge provisions Kubernetes only. Do not install Radius, the Adaptive Apps
portfolio, recipes, or application workloads yet.

## Default workshop topology

| Logical environment | Platform | Purpose |
| --- | --- | --- |
| Azure | Azure Kubernetes Service (AKS) | Azure-managed Kubernetes with OIDC issuer, workload identity, and managed Istio enabled. |
| Local | Single-node K3s on an Azure Linux VM | Self-managed Kubernetes representative of an on-premises or edge platform. |

Both clusters run in Azure for workshop convenience, but only one is AKS. K3s does not
inherit AKS cluster identity, networking, ACR integration, or managed add-ons. Those
differences form the portability boundary used in later challenges.

The scripts are idempotent: rerunning one reuses its resource group and cluster or VM,
refreshes credentials, and repeats the health check.

Common blockers:

| Blocker | Guidance |
| --- | --- |
| Azure cannot allocate the requested VM size | Set `AKS_NODE_VM_SIZE` or `K3S_VM_SIZE` to an available size, or choose another `AZURE_LOCATION`. |
| AKS nodes remain `NotReady` | Check `az aks show --query provisioningState` and allow time for the initial node image pull. |
| K3s API is unreachable | Confirm the caller is included in `ADMIN_CIDR` and TCP 6443 is allowed by the VM network security group. |
| A teammate cannot access K3s | Add the teammate's public CIDR deliberately; do not expose management ports to the internet. |
| Commands target the wrong cluster | Check both `KUBECONFIG` and `kubectl config current-context`. |

## Task 1: Provision AKS

The script creates or updates an Azure resource group and a two-node AKS cluster,
enables OIDC issuer and workload identity, refreshes kubeconfig, and runs health checks.
It does not create ACR, Key Vault, Storage, Radius, or portfolio resources.

From the MicroHack directory:

```bash
cd "03-Azure/01-01-App Innovation/04-adaptive-apps"

export AZURE_SUBSCRIPTION="<subscription-id>"
export AZURE_LOCATION="westeurope"
export RESOURCE_GROUP="rg-adaptive-apps"
export AKS_CLUSTER="aks-adaptive-apps"

chmod +x resources/prepare-aks.sh
./resources/prepare-aks.sh
```

Optional settings:

```bash
export AKS_NODE_COUNT=2
export AKS_NODE_VM_SIZE="Standard_D4s_v5"
```

The script merges AKS credentials into the default kubeconfig and activates the
context named after `AKS_CLUSTER`.

## Task 2: Provision K3s on an Azure VM

The script creates or reuses an Ubuntu VM with a static public IP, restricts SSH and
the Kubernetes API to the coach's CIDR, opens HTTP/HTTPS for later exercises, installs
K3s, writes a dedicated kubeconfig, and runs health checks.

```bash
export AZURE_SUBSCRIPTION="<subscription-id>"
export AZURE_LOCATION="westeurope"
export RESOURCE_GROUP="rg-adaptive-apps"
export K3S_VM_NAME="vm-adaptive-apps-k3s"

# Recommended: set this explicitly to the coach or workshop egress IP.
export ADMIN_CIDR="<public-ip>/32"

chmod +x resources/prepare-k3s-azure-vm.sh
./resources/prepare-k3s-azure-vm.sh
```

Optional settings:

```bash
export K3S_VM_SIZE="Standard_D4s_v5"
export K3S_ADMIN_USERNAME="azureuser"
export K3S_KUBECONFIG="$HOME/.kube/adaptive-apps-k3s.yaml"
```

Use K3s:

```bash
export KUBECONFIG="$HOME/.kube/adaptive-apps-k3s.yaml"
kubectl config use-context k3s-azure-vm
kubectl get nodes
```

Return to AKS:

```bash
unset KUBECONFIG
kubectl config use-context aks-adaptive-apps
kubectl get nodes
```

> [!IMPORTANT]
> Treat kubeconfig files as credentials. Share the K3s kubeconfig only through an
> approved secure channel and remove access when the workshop ends.

## Health checks

Each script exits with a nonzero status when its environment is unhealthy. Checks
cover Azure provisioning, the active context, Kubernetes API readiness, node
readiness, AKS identity features, and the K3s service.

Repeat the Kubernetes checks manually:

```bash
# AKS
unset KUBECONFIG
kubectl config use-context aks-adaptive-apps
kubectl get --raw="/readyz"
kubectl wait --for=condition=Ready nodes --all --timeout=10m
kubectl get nodes -o wide

# K3s
export KUBECONFIG="$HOME/.kube/adaptive-apps-k3s.yaml"
kubectl config use-context k3s-azure-vm
kubectl get --raw="/readyz"
kubectl wait --for=condition=Ready nodes --all --timeout=10m
kubectl get nodes -o wide
```

Do not continue until both APIs return `ok` and every node is `Ready`.

## Optional platforms

Use these manual paths only when the workshop already has suitable infrastructure:

| Platform | Manual preparation |
| --- | --- |
| Azure Local with AKS enabled by Azure Arc | [Prepare Azure Local](../../docs/prepare-azure-local.md) |
| Existing Kubernetes connected with Azure Arc | [Prepare Azure Arc-enabled Kubernetes](../../docs/prepare-arc.md) |

Arc enablement is optional for the default K3s VM. Arc projects an existing cluster
into Azure management; it does not create the cluster and is not required by Radius.

## Completion criteria

- Both scripts finish successfully.
- Coaches can switch explicitly between AKS and K3s.
- Both Kubernetes APIs and all nodes are healthy.
- No Radius control plane, portfolio, recipes, or application workloads are installed.
