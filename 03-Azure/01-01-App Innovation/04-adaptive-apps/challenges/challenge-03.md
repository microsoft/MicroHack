# Challenge 03 - Deploy and explore Radius

[< Previous Challenge](https://github.com/microsoft/MicroHack/blob/main/03-Azure/01-01-App%20Innovation/04-adaptive-apps/challenges/challenge-02.md) - **[Home](https://github.com/microsoft/MicroHack/blob/main/03-Azure/01-01-App%20Innovation/04-adaptive-apps/Readme.md)** - [Next Challenge >](https://github.com/microsoft/MicroHack/blob/main/03-Azure/01-01-App%20Innovation/04-adaptive-apps/challenges/challenge-04.md)

Estimated time: 30-45 minutes per environment | Difficulty: intermediate

## Challenge objective

**LAB** means facilitator-provided infrastructure; **BYOS** means bring your own
subscription. For LAB, use the supplied resource names and the **managed identity**
option for the installation below.

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

## Connect to the lab resources

Run once in **Bash from the Adaptive Apps lab directory**, after `az login`.
Use your assigned values (not provisioning commands); LAB participants
can source `artifacts/console-env.sh` instead of the two exports.

```bash
export AZURE_SUBSCRIPTION="<subscription-id>"
export RESOURCE_GROUP="<lab-resource-group>"
bash resources/connect-lab.sh && source artifacts/lab-env.sh
```

The helper connects AKS, refreshes K3s credentials, opens the private Bastion API
tunnel, and checks both clusters without provisioning or installing Radius.
It requires AKS credential access, VM Run Command/start, and Bastion tunnel permissions.
For nondefault names, export `AKS_CLUSTER`, `K3S_VM_NAME`, and `BASTION_NAME` first.
If resources are missing or access is denied, stop and contact the facilitator.
Do not disable TLS verification.

Variables are now set for the remaining steps. In a new terminal, source
`artifacts/lab-env.sh`; after a devcontainer restart, also rerun the helper.
Switch platforms explicitly:

| Target | Bash commands |
| --- | --- |
| AKS (selected initially) | `unset KUBECONFIG; kubectl config use-context "$AKS_CONTEXT"` |
| K3s | `export KUBECONFIG="$K3S_KUBECONFIG"; kubectl config use-context "$K3S_CONTEXT"` |

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

1. Select AKS using the connection table above.
2. **LAB:** create a user-assigned managed identity in the supplied lab resource
   group. **BYOS:** use that same path, or create a Microsoft
   Entra application and service principal if you have tenant permissions.
3. Use the AKS OIDC issuer to create federated credentials for the Radius service
   accounts in namespace `radius-system`: `applications-rp`, `bicep-de`, `ucp`,
   and `dynamic-rp`. Do not configure only the first service account.
4. Grant the Radius identity the required role on the isolated lab resource group.

Install Radius with Azure workload identity enabled. Only one team member should run
the control-plane installation.

Create and select:

- Workspace `ws-azure-prod`, targeting context `aks-adaptive-apps`
- Group `rg-trading`
- Environment `env-azure-prod`, using Kubernetes namespace `env-azure-prod`

Configure the environment's Azure subscription and resource group, then register the
Azure workload-identity credential.

The [manual walkthrough](https://github.com/microsoft/MicroHack/blob/main/03-Azure/01-01-App%20Innovation/04-adaptive-apps/walkthrough/challenge-03/solution-03.md#2-prepare-azure-workload-identity)
contains both identity options and the common installation steps. The managed
identity and its role assignment stay within the lab resource group; no tenant
app registration or service-principal creation command is required.

### Task 3: Install Radius manually on K3s

Switch to K3s using the connection table above, then install a second, independent
Radius control plane.

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

Manual installation is the intended learning path. These scripts automate
**Radius installation and post-configuration on existing clusters**, not
AKS/K3s infrastructure provisioning or reinstallation:

- `resources/deploy-radius-aks.sh`
- `resources/deploy-radius-k3s.sh`

For K3s in **LAB and BYOS**, switch to K3s using the connection table above, then run
`RADIUS_REINSTALL=false bash resources/deploy-radius-k3s.sh` on **each participant's workstation**.
It preserves an existing Radius installation, creates missing workspace/group/environment
configuration, and validates the selected context, group, environment, and namespace.
Conflicting existing environment settings fail explicitly rather than being overwritten.
Use `RADIUS_REINSTALL=true` only for an intentional, team-coordinated reinstall.
Dashboard exploration and the team discussion remain manual.

For AKS in **LAB and BYOS**, source `artifacts/lab-env.sh`, unset `KUBECONFIG`,
and select `"$AKS_CONTEXT"`, then run
`RADIUS_IDENTITY_MODE=managedidentity RADIUS_REINSTALL=false bash resources/deploy-radius-aks.sh`.
Managed identity is required for LAB; BYOS can alternatively use an Entra application
if tenant permissions allow it. Keep the explicit `RADIUS_REINSTALL=false` to install
Radius if missing or retain its existing control plane, then run post-configuration
in either case. `RADIUS_REINSTALL=true` reinstalls **Radius only**, never AKS or K3s.
The [walkthrough](../walkthrough/challenge-03/solution-03.md#optional-automation)
details both identity options and the scripts' different raw defaults.

If Azure Local or an existing Arc-enabled cluster replaces K3s, use its active context,
create a distinct Radius workspace and environment, and decide explicitly whether it
needs an Azure provider.

## Learning resources

The workshop pins **Radius 0.60.0**. Current official docs describe a newer preview;
use them for reference, not to switch the lab to preview resource types/recipe packs.

- [What is Radius?](https://docs.radapp.io/concepts/)
- [Install Radius on Kubernetes](https://docs.radapp.io/installation/control-plane/)
- [Radius workspaces](https://docs.radapp.io/management/workspaces/)
- [Radius environments](https://docs.radapp.io/concepts/environments/)
- [Radius dashboard](https://docs.radapp.io/installation/dashboard/)
