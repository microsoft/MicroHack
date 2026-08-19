# Prepare K3s on an Azure VM

The default local environment is single-node K3s on an Azure Linux VM. It represents
self-managed on-premises or edge Kubernetes without requiring participant compute.
The VM is not AKS, and Arc enablement is optional.

## Automated preparation

```bash
export AZURE_SUBSCRIPTION="<subscription-id>"
export AZURE_LOCATION="westeurope"
export RESOURCE_GROUP="rg-adaptive-apps"
export K3S_VM_NAME="vm-adaptive-apps-k3s"
export ADMIN_CIDR="<workshop-public-ip>/32"

# Run from the Adaptive Apps MicroHack root.
bash resources/prepare-k3s-azure-vm.sh
```

Optional settings are `K3S_VM_SIZE`, `K3S_ADMIN_USERNAME`, and `K3S_KUBECONFIG`.
If `ADMIN_CIDR` is omitted, the script detects the caller's public IP through
`https://api.ipify.org` and applies a `/32` rule.

The script creates the VM and network rules, installs K3s, writes a dedicated
kubeconfig, and runs platform health checks.

## Use and validate the cluster

```bash
export KUBECONFIG="$HOME/.kube/adaptive-apps-k3s.yaml"
kubectl config use-context k3s-azure-vm
kubectl get --raw="/readyz"
kubectl wait --for=condition=Ready nodes --all --timeout=10m
kubectl get nodes -o wide
```

> [!IMPORTANT]
> The K3s kubeconfig contains cluster credentials. Store and share it securely.

K3s can optionally be connected to Azure Arc by following
[Prepare an Azure Arc-enabled cluster](prepare-arc.md). Radius is installed in
Challenge 02.
