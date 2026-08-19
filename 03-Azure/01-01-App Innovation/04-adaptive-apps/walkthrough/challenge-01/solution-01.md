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
| K3s API is unreachable | Run the helper in `connect` mode and inspect the recorded tunnel log. |
| Bastion or networking is denied | Confirm FDPO policy, region/SKU, Network Contributor, VM Run Command, and Bastion tunnel permissions. |
| Commands target the wrong cluster | Check both `KUBECONFIG` and `kubectl config current-context`. |

## Task 1: Provision AKS

The script creates or updates an Azure resource group and a two-node AKS cluster,
enables OIDC issuer and workload identity, refreshes kubeconfig, and runs health checks.
It does not create ACR, Key Vault, Storage, Radius, or portfolio resources.

The devcontainer opens at the Adaptive Apps MicroHack root. Confirm the working
directory before running the script:

```bash
test -f resources/prepare-aks.sh &&
  test -f resources/prepare-k3s-azure-vm.sh
pwd

export AZURE_SUBSCRIPTION="<subscription-id>"
export AZURE_LOCATION="westeurope"
export RESOURCE_GROUP="rg-adaptive-apps"
export AKS_CLUSTER="aks-adaptive-apps"

bash resources/prepare-aks.sh
```

Optional settings:

```bash
export AKS_NODE_COUNT=2
export AKS_NODE_VM_SIZE="Standard_D4s_v5"
```

The script merges AKS credentials into the default kubeconfig and activates the
context named after `AKS_CLUSTER`.

## Task 2: Provision K3s on an Azure VM

The script creates or reuses a VNet, private Ubuntu VM, least-privilege NIC NSG, and
Azure Bastion Standard host. Only Bastion-subnet traffic can reach VM ports 22 and 6443;
all other inbound traffic is denied. The VM has no public IP. K3s installation and
kubeconfig retrieval use Azure VM Run Command, then a native Bastion tunnel maps the
private API to localhost.

JIT is not used because it only changes when an NSG rule is open; it does not create a
route to a private VM. RDP is a Windows protocol and does not apply to this Ubuntu host.
Azure Bastion supplies the private network path, with SSH retained only as an optional
Bastion-restricted Linux troubleshooting route.

```bash
export AZURE_SUBSCRIPTION="<subscription-id>"
export AZURE_LOCATION="westeurope"
export RESOURCE_GROUP="rg-adaptive-apps"
export K3S_VM_NAME="vm-adaptive-apps-k3s"

bash resources/prepare-k3s-azure-vm.sh
```

Optional settings:

```bash
export K3S_VM_SIZE="Standard_D4s_v5"
export K3S_ADMIN_USERNAME="azureuser"
export K3S_KUBECONFIG="$HOME/.kube/adaptive-apps-k3s.yaml"
export VNET_PREFIX="10.42.0.0/16"
export K3S_SUBNET_PREFIX="10.42.0.0/24"
export BASTION_SUBNET_PREFIX="10.42.1.0/26"
export K3S_LOCAL_PORT=16443
```

The generated kubeconfig points to `https://127.0.0.1:16443`. Its credentials are
retrieved in bounded chunks and are never printed. After reopening or rebuilding the
devcontainer, re-establish the tunnel without changing Azure resources:

```bash
export AZURE_SUBSCRIPTION="<subscription-id>"
bash resources/prepare-k3s-azure-vm.sh connect

export KUBECONFIG="$HOME/.kube/adaptive-apps-k3s.yaml"
kubectl config use-context k3s-azure-vm
kubectl get nodes
```

Inspect or stop the tunnel safely:

```bash
bash resources/prepare-k3s-azure-vm.sh status
bash resources/prepare-k3s-azure-vm.sh disconnect
```

The script records the exact PID and verifies its command line before sending
`SIGTERM`; it never kills by process name. The tunnel exposes only the Kubernetes API.
Use `kubectl port-forward` for later Radius and application access.

Return to AKS:

```bash
unset KUBECONFIG
kubectl config use-context aks-adaptive-apps
kubectl get nodes
```

> [!IMPORTANT]
> Treat kubeconfig files as credentials. Share the K3s kubeconfig only through an
> approved secure channel and remove access when the workshop ends. Azure Bastion
> accrues hourly cost while deployed; follow the
> [K3s cleanup guidance](../../docs/prepare-k3s.md#cost-and-cleanup).

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
export AZURE_SUBSCRIPTION="<subscription-id>"
bash resources/prepare-k3s-azure-vm.sh connect
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
- The K3s VM is private and reachable only through the localhost Bastion tunnel.
- No Radius control plane, portfolio, recipes, or application workloads are installed.
