# Challenge 02 - Deploy and explore Radius

[< Previous Challenge](challenge-01.md) - **[Home](../Readme.md)** - [Next Challenge >](challenge-03.md)

Estimated time: 30-45 minutes per environment | Difficulty: intermediate

## Challenge objective

Install and explore independent Radius control planes on both default platforms.
Configure the matching local CLI workspaces, Radius environments, and groups:

| Platform | Workspace | Environment | Group |
| --- | --- | --- | --- |
| AKS | `ws-azure-prod` | `env-azure-prod` | `rg-trading` |
| K3s on an Azure VM | `ws-local-prod` | `env-local-prod` | `rg-trading` |

The default workshop architecture is federated: each platform has its own Radius
control plane and can operate independently.

## Learning goals

- Compare centralized and federated Radius control-plane models.
- Install Radius manually on Azure-managed and self-managed Kubernetes.
- Distinguish a control plane, local CLI workspace, environment, group, and
  application.
- Configure Azure workload identity for the AKS Radius control plane.
- Validate Radius through Kubernetes, the CLI, and the dashboard.

Before the first K3s command in this challenge, re-establish the private API tunnel if
the devcontainer was reopened or rebuilt:

```bash
export AZURE_SUBSCRIPTION="<subscription-id>"
bash resources/prepare-k3s-azure-vm.sh connect
export KUBECONFIG="$HOME/.kube/adaptive-apps-k3s.yaml"
```

## Tasks

### Task 1: Select the control-plane model

Compare these approaches:

- **Centralized:** one management control plane governs multiple execution
  environments.
- **Federated:** each site runs an independent control plane and receives configuration
  from shared source control.

Document why the federated model is appropriate for a scenario that includes an
intermittently connected or disconnected site. Identify the availability and
governance trade-offs.

### Task 2: Install Radius manually on AKS

Before installation:

1. Select kube context `aks-adaptive-apps`.
2. Create a Microsoft Entra application and service principal for Radius.
3. Use the AKS OIDC issuer to create federated credentials for the Radius service
   accounts in namespace `radius-system`.
4. Grant the Radius identity the required role on the isolated lab resource group.

Install Radius with Azure workload identity enabled. Only one team member should run
the control-plane installation.

Create and select:

- Workspace `ws-azure-prod`, targeting context `aks-adaptive-apps`
- Group `rg-trading`
- Environment `env-azure-prod`, using Kubernetes namespace `env-azure-prod`

Configure the environment's Azure subscription and resource group, then register the
Azure workload-identity credential.

### Task 3: Install Radius manually on K3s

Select the dedicated K3s kubeconfig and context `k3s-azure-vm`, then install a second,
independent Radius control plane.

Create and select:

- Workspace `ws-local-prod`, targeting context `k3s-azure-vm`
- Group `rg-trading`
- Environment `env-local-prod`, using Kubernetes namespace `env-local-prod`

Do not register Azure credentials or configure an Azure provider for K3s.

### Task 4: Validate and explore both installations

For each platform, activate the matching Kubernetes context and Radius workspace, then
verify:

```bash
kubectl wait --for=condition=Available deployments --all \
  --namespace radius-system \
  --timeout=10m
kubectl get pods --namespace radius-system
kubectl get crd recipes.radapp.io deploymenttemplates.radapp.io deploymentresources.radapp.io

rad workspace list
rad env list
rad group list
```

Port-forward the Radius dashboard service in `radius-system`, explore the active
environment, and then repeat with the other platform.

Prepare a short team explanation of:

- Which objects live in Kubernetes and which configuration is local to a workstation
- Why both control planes can use a group named `rg-trading` without sharing one group
- Which environment can provision Azure-managed resources
- What happens to applications on K3s if AKS is unavailable

## Success criteria

- The team can explain why the default topology uses federated control planes.
- Radius deployments in `radius-system` are healthy on AKS and K3s.
- Radius CRDs exist on both clusters.
- `ws-azure-prod` targets AKS and exposes `env-azure-prod` and `rg-trading`.
- `ws-local-prod` targets K3s and exposes `env-local-prod` and `rg-trading`.
- AKS has a Radius Azure workload-identity credential and Azure provider settings.
- K3s has neither Azure credentials nor an Azure provider.
- The dashboard is accessible for each control plane.
- No capability portfolio, resource type, recipe, or application deployment has
  started.

## Hints

- Check both `kubectl config current-context` and the selected Radius workspace before
  every operation.
- Radius startup can take 5-10 minutes. Inspect pod state before rerunning an install.
- A workspace is local CLI configuration in `~/.rad/config.yaml`; it is not stored in
  the cluster.
- The environment points applications at a Kubernetes namespace and can hold provider
  and recipe configuration.
- Microsoft Entra and Azure role assignments can take time to propagate.
- If GHCR returns HTTP 403, clear stale registry credentials before retrying the
  Radius installation.

## Optional automation and platforms

Manual installation is the intended learning path. If a participant must skip or
recover the exercise, these scripts perform the same setup:

- `resources/deploy-radius-aks.sh`
- `resources/deploy-radius-k3s.sh`

If Azure Local or an existing Arc-enabled cluster replaces K3s, use its active context,
create a distinct Radius workspace and environment, and decide explicitly whether it
needs an Azure provider.

## Learning resources

- [What is Radius?](https://docs.radapp.io/concepts/)
- [Install Radius on Kubernetes](https://docs.radapp.io/guides/operations/kubernetes/install/)
- [Radius workspaces](https://docs.radapp.io/guides/operations/workspaces/overview/)
- [Radius environments](https://docs.radapp.io/guides/deploy-apps/environments/overview/)
- [Radius dashboard](https://docs.radapp.io/guides/tooling/dashboard/)
