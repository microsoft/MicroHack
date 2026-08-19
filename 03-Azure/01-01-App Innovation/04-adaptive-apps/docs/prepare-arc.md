# Prepare an Azure Arc-enabled Kubernetes cluster

Use this optional path when the workshop already has a CNCF-conformant Kubernetes
cluster reachable from the coach workstation. Arc does not create the cluster.

When connecting the default private K3s VM from this MicroHack, first establish its
localhost API tunnel:

```bash
export AZURE_SUBSCRIPTION="<subscription-id>"
bash resources/prepare-k3s-azure-vm.sh connect
export KUBECONFIG="$HOME/.kube/adaptive-apps-k3s.yaml"
```

The Arc agents run on the cluster and make outbound Azure connections; Arc does not
replace the participant's Bastion tunnel for direct `kubectl` access to the private API.

Follow the current Microsoft documentation:

1. Review the [Azure Arc-enabled Kubernetes prerequisites](https://learn.microsoft.com/azure/azure-arc/kubernetes/quickstart-connect-cluster#prerequisites).
2. Review the [network requirements](https://learn.microsoft.com/azure/azure-arc/kubernetes/network-requirements).
3. [Connect the existing cluster to Azure Arc](https://learn.microsoft.com/azure/azure-arc/kubernetes/quickstart-connect-cluster).
4. Confirm `connectivityStatus` is `Connected` and all `azure-arc` pods are healthy.

```bash
az connectedk8s show \
  --resource-group "<resource-group>" \
  --name "<arc-cluster-name>" \
  --query connectivityStatus \
  --output tsv

kubectl get nodes
kubectl get pods -n azure-arc
```

Radius is installed separately in Challenge 02.
