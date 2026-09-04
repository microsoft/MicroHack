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
| Azure cannot allocate the requested VM size | The scripts detect this and fall back automatically. Override the ordered list with `AKS_NODE_VM_SIZE_CANDIDATES` or `K3S_VM_SIZE_CANDIDATES`, or choose another `AZURE_LOCATION`. |
| AKS nodes remain `NotReady` | Check `az aks show --query provisioningState` and allow time for the initial node image pull. |
| K3s API is unreachable | Run the helper in `connect` mode and inspect the recorded tunnel log. |
| Bastion or networking is denied | Confirm FDPO policy, region/SKU, Network Contributor, VM Run Command, and Bastion tunnel permissions. |
| K3s installer cannot be downloaded | The subnet has no outbound path. Confirm the NAT gateway is attached, or re-run with `K3S_ENABLE_NAT_GATEWAY=false` where policy allows it. |
| Commands target the wrong cluster | Check both `KUBECONFIG` and `kubectl config current-context`. |

Both scripts resolve the node or VM size before creating anything. They list the sizes
the subscription can use in the target region, ignore `Zone`-only restrictions because
the deployment is regional, and pick the first candidate that is offered. If the
allocation still fails with a capacity or quota error, the failed resource is removed and
the next candidate is tried. Authorization and policy failures are not retried.

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
export AKS_NODE_VM_SIZE_CANDIDATES="Standard_D4s_v5 Standard_D4s_v4 Standard_D4s_v3"
```

`AKS_NODE_VM_SIZE` is the preferred size. `AKS_NODE_VM_SIZE_CANDIDATES` replaces the
whole ordered fallback list when a region needs different sizes.

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
export K3S_VM_SIZE_CANDIDATES="Standard_D4s_v5 Standard_D4s_v4 Standard_D4s_v3"
export K3S_ADMIN_USERNAME="azureuser"
export K3S_KUBECONFIG="$HOME/.kube/adaptive-apps-k3s.yaml"
export VNET_PREFIX="10.42.0.0/16"
export K3S_SUBNET_PREFIX="10.42.0.0/24"
export BASTION_SUBNET_PREFIX="10.42.1.0/26"
export K3S_LOCAL_PORT=16443
export K3S_ENABLE_NAT_GATEWAY=true
```

### Outbound access for the private VM

The VM has no inbound internet exposure, but it needs outbound access to download K3s and
pull images. Azure is retiring implicit default outbound access: for API versions released
after 2026-03-31, new virtual networks default to private subnets with no outbound path,
so the behavior depends on the Azure CLI version rather than the date.

The script sets the posture explicitly instead of inheriting the platform default:

| Posture | Selection | Cost |
| --- | --- | --- |
| NAT gateway, subnet stays private | default | Hourly charge plus per-GB data processing |
| Default outbound access, set explicitly on `snet-k3s` | `K3S_ENABLE_NAT_GATEWAY=false` | None |

```bash
export K3S_ENABLE_NAT_GATEWAY=false
bash resources/prepare-k3s-azure-vm.sh
```

The NAT gateway is the default because it is explicit, survives the retirement of default
outbound access, and gives a deterministic egress IP that a firewall can allowlist. The
subnet is deliberately kept private, because a nonprivate subnet can still receive a
platform-assigned fallback outbound IP alongside the NAT gateway.

Use `K3S_ENABLE_NAT_GATEWAY=false` only to avoid the NAT gateway cost, and only where
Azure Policy still permits default outbound access. If the posture changes on an existing
deployment, the script reconciles it and restarts the VM, because the change only applies
after a deallocate and start. Remember to delete the NAT gateway and its public IP during
cleanup.

The generated kubeconfig points to `https://127.0.0.1:16443`. Its credentials are
retrieved in bounded chunks and are never printed. The script also registers the
`k3s-azure-vm` context in the default `~/.kube/config` without changing the active
context, because the Radius CLI resolves part of its installation through the default
kubeconfig rather than through `KUBECONFIG`. Explicitly exporting `KUBECONFIG` remains
the documented way to target K3s.

After reopening or rebuilding the devcontainer, re-establish the tunnel without changing
Azure resources:

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
`SIGTERM`; it never kills by process name. The Azure CLI launcher runs its Python entry
point as a child process, so `disconnect` stops every process whose command line matches
this tunnel's Bastion name, resource group, and both ports. A tunnel orphaned by a
crashed shell is reclaimed automatically on the next `connect`. The tunnel exposes only
the Kubernetes API. Use `kubectl port-forward` for later Radius and application access.

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
