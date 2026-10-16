# Prepare Azure Local

This is an optional manual alternative, not part of the hosted baseline.
Hosted participants use [Console setup](https://github.com/microsoft/MicroHack/blob/main/03-Azure/01-01-App%20Innovation/04-adaptive-apps/docs/console-setup.md)
for the supplied AKS/K3s environments instead.

Use this optional path when the workshop already has Azure Local and an AKS enabled by
Azure Arc cluster available. Azure Local provisioning is environment-specific and is
not automated by this MicroHack.

Follow the current Microsoft documentation:

1. Review [AKS enabled by Azure Arc overview](https://learn.microsoft.com/azure/aks/aksarc/aks-overview).
2. [Create a Kubernetes cluster on Azure Local](https://learn.microsoft.com/azure/aks/aksarc/aks-create-clusters-cli).
3. Obtain credentials and confirm the cluster is reachable from the coach workstation.

```bash
kubectl config current-context
kubectl get --raw="/readyz"
kubectl wait --for=condition=Ready nodes --all --timeout=10m
kubectl get nodes -o wide
```

Radius is installed separately in Challenge 03.
