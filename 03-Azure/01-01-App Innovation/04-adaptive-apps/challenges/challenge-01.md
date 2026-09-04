# Challenge 01 - Prepare the platforms

[< Previous Challenge](challenge-00.md) - **[Home](../Readme.md)** - [Next Challenge >](challenge-02.md)

Estimated time: 30-60 minutes | Difficulty: intermediate

## Challenge objective

Prepare and validate the two Kubernetes platforms used throughout the MicroHack:

| Logical environment | Platform | Purpose |
| --- | --- | --- |
| Azure | Azure Kubernetes Service (AKS) | Azure-managed Kubernetes with workload identity and managed Istio |
| Local | K3s on an Azure Linux VM | Self-managed Kubernetes representing an on-premises or edge platform |

Both environments run in Azure for workshop convenience, but only one is AKS. Their
different identity, networking, registry, and managed-service capabilities create the
portability boundary explored in later challenges.

> [!IMPORTANT]
> This challenge provisions Kubernetes only. Do not install Radius, the Adaptive Apps
> portfolio, recipes, or application workloads.

## Learning goals

- Prepare Azure-managed and self-managed Kubernetes platforms.
- Configure AKS features needed by later identity and service-mesh exercises.
- Secure access to a K3s API running on an Azure VM.
- Switch deliberately between kubeconfig files and Kubernetes contexts.
- Establish a healthy baseline before adding platform components.

## Tasks

### Task 1: Plan the environment

Agree on names and values for:

- Azure subscription and location
- Lab resource group
- AKS cluster
- Private K3s VNet, VM, and Azure Bastion names
- AKS node and K3s VM sizes
- Nonoverlapping VNet, workload-subnet, and `/26` `AzureBastionSubnet` CIDRs

The local helper scripts use these defaults:

```text
Resource group: rg-adaptive-apps
AKS context: aks-adaptive-apps
K3s VM: vm-adaptive-apps-k3s
K3s context: k3s-azure-vm
K3s kubeconfig: ~/.kube/adaptive-apps-k3s.yaml
K3s API endpoint: https://127.0.0.1:16443
Azure Bastion: bas-adaptive-apps
```

### Task 2: Provision AKS

Create a two-node AKS cluster with:

- OIDC issuer enabled
- Microsoft Entra workload identity enabled
- Managed Istio enabled
- Credentials merged into the default kubeconfig

The repository includes `resources/prepare-aks.sh` as the supported provisioning path.
Review its inputs before running it, set the subscription, location, resource-group,
and cluster values explicitly, then validate the result independently.

### Task 3: Provision K3s on an Azure VM

Create an Ubuntu VM with:

- A private NIC and no VM public IP
- A workload subnet plus a correctly named `/26` or larger `AzureBastionSubnet`
- Azure Bastion Standard with native client tunneling enabled
- VM NSG access on TCP 22 and 6443 only from `AzureBastionSubnet`
- K3s installed without its bundled Traefik ingress controller
- A dedicated local kubeconfig using context `k3s-azure-vm` and a localhost endpoint
- A persistent localhost tunnel from port 16443 to the private K3s API

The repository includes `resources/prepare-k3s-azure-vm.sh`. Review its network and
kubeconfig behavior before running it. Treat the generated kubeconfig as a credential.
Use its `connect` mode after a devcontainer restart. JIT is not a route to a private VM,
and RDP does not apply to Linux; Bastion supplies the private path.

### Task 4: Validate both platforms

For each platform, verify:

```bash
kubectl config current-context
kubectl get --raw="/readyz"
kubectl wait --for=condition=Ready nodes --all --timeout=10m
kubectl get nodes -o wide
```

For AKS, also confirm that OIDC issuer, workload identity, and managed Istio are
enabled. For K3s, confirm the VM has no public IP, Bastion native tunneling is enabled,
the recorded localhost tunnel is healthy, and the K3s service is active.

### Task 5: Practice explicit context switching

Demonstrate that your team can:

1. Use the default kubeconfig and select `aks-adaptive-apps`.
2. Set `KUBECONFIG` to the dedicated K3s file and select `k3s-azure-vm`.
3. Return to AKS without accidentally continuing to target K3s.

Record the active kubeconfig and context whenever you switch platforms.

## Success criteria

- AKS provisioning state is `Succeeded`.
- AKS has OIDC issuer, workload identity, and managed Istio enabled.
- The K3s VM is running and its K3s service is active.
- The K3s VM has no public IP or Internet-sourced inbound rule.
- Azure Bastion is `Succeeded`, Standard or Premium, and native tunneling is enabled.
- Both Kubernetes APIs return `ok`.
- Every node reports `Ready`.
- The team can identify and switch between the AKS and K3s kubeconfig/context pairs.
- K3s management access is restricted to `AzureBastionSubnet`.
- No Radius control plane, portfolio, recipe, or application workload is installed.

## Hints

- If Azure cannot allocate a requested VM size, select another size or region rather
  than repeatedly retrying the same deployment.
- Check AKS provisioning state and node readiness before rerunning provisioning.
- A K3s API timeout often means the Bastion tunnel must be reconnected after the
  devcontainer restarted.
- The tunnel exposes only the Kubernetes API on localhost. Use `kubectl port-forward`
  for application and Radius services without opening workload ports on the VM.
- `KUBECONFIG` can override the default configuration even when the context name looks
  familiar. Check both before every platform operation.
- Arc enablement projects an existing cluster into Azure management; it does not create
  the Kubernetes cluster and is not required for the default K3s path.

## Optional platform alternatives

If the workshop already provides suitable infrastructure, Azure Local or an existing
Arc-enabled Kubernetes cluster can replace K3s:

- [Prepare Azure Local](../docs/prepare-azure-local.md)
- [Prepare Azure Arc-enabled Kubernetes](../docs/prepare-arc.md)

These are optional manual alternatives. Keep distinct kubeconfig, context, and logical
environment names when substituting a platform.

## Learning resources

- [Azure Kubernetes Service documentation](https://learn.microsoft.com/azure/aks/)
- [K3s documentation](https://docs.k3s.io/)
- [Microsoft Entra workload identity on AKS](https://learn.microsoft.com/azure/aks/workload-identity-overview)
- [Managed Istio on AKS](https://learn.microsoft.com/azure/aks/istio-about)
- [Azure Arc-enabled Kubernetes overview](https://learn.microsoft.com/azure/azure-arc/kubernetes/overview)
