# Challenge 00 - Prerequisites: ready, set, go

**[Home](../Readme.md)** - [Next Challenge >](challenge-01.md)

Estimated time: 30-60 minutes | Difficulty: beginner

## Challenge objective

Prepare and validate the workstation, Azure access, permissions, and regional capacity
required by every challenge in this MicroHack.

Challenge 00 is a universal prerequisite. Complete it before starting a challenge in
any bucket.

## Learning goals

- Establish a consistent command-line toolchain.
- Select the correct Azure subscription and confirm the required access.
- Verify that the target region can host the default workshop topology.
- Understand where Kubernetes credentials and Radius workspace configuration will be
  stored.

## Default workshop topology

Later challenges use two independent Kubernetes environments:

| Logical environment | Default platform | Default size |
| --- | --- | --- |
| Azure | Two-node Azure Kubernetes Service (AKS) cluster | `Standard_D4s_v5` nodes |
| Local | Single-node K3s cluster on an Azure Linux VM | `Standard_D4s_v5` VM |

Both platforms run in Azure for workshop convenience. K3s remains a self-managed
Kubernetes distribution and represents a local or edge environment.

## Tasks

### Task 1: Confirm access and capacity

Confirm that your workshop team has:

- An Azure subscription
- Permission to create a resource group, AKS cluster, Linux VM, networking resources,
  public IP addresses, and role assignments
- Permission to create a Microsoft Entra application and service principal
- Regional quota for the AKS nodes, K3s VM, and standard public IP addresses
- A known public egress CIDR that can be used to restrict SSH and Kubernetes API access
  to the K3s VM

> [!IMPORTANT]
> Later challenges grant a Radius identity `Owner` on the dedicated lab resource group
> because recipes can create role assignments. Use an isolated workshop subscription
> or resource group rather than a production scope.

### Task 2: Choose a workstation setup

The Adaptive Apps devcontainer is the recommended setup because it provides a
consistent Linux toolchain for Challenges 00-04. A manual host installation remains
supported.

#### Option A: Use the recommended devcontainer

Host prerequisites:

- Docker Desktop or another runtime compatible with VS Code Dev Containers
- [Visual Studio Code](https://code.visualstudio.com/)
- The [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)
- On Windows, Docker Desktop configured with its WSL 2 backend

Clone the fork and check out this MicroHack branch:

```bash
git clone https://github.com/djong1/MicroHack.git
cd MicroHack
git switch djong1-adaptive-apps-microhack
code .
```

In VS Code, run **Dev Containers: Reopen in Container** and select
`03-azure-01-01-app-innovation-04-adaptive-apps` when prompted. The configuration
lives under the repository's root `.devcontainer` directory and opens
`03-Azure/01-01-App Innovation/04-adaptive-apps` as the container workspace.

The container installs Azure CLI, Bicep, `kubectl`, Helm 3, Radius CLI, Git, `jq`,
`yq`, `curl`, SSH, and `tar`. These tools can run every command in Challenges 00-04.
The container is only a workstation: AKS, the Linux VM, K3s, Radius control planes,
portfolio workloads, and recipes are still created on the remote Azure and Kubernetes
targets by the commands you run.

> [!IMPORTANT]
> The configuration does not mount the host Docker socket. Challenge 04 supports
> token-based ACR authentication when Docker is unavailable.

#### Option B: Install tools on the host

Install the following tools in one consistent shell environment:

- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli)
- [Bicep CLI](https://learn.microsoft.com/azure/azure-resource-manager/bicep/install)
- [`kubectl`](https://kubernetes.io/docs/tasks/tools/)
- [Helm 3](https://helm.sh/docs/intro/install/)
- [Radius CLI (`rad`)](https://docs.radapp.io/getting-started/install/)
- [Git](https://git-scm.com/downloads)
- `jq`, `yq`, `curl`, OpenSSH client, and `tar`
- [Visual Studio Code](https://code.visualstudio.com/)

Windows participants should use WSL 2 for the Bash automation supplied with this
MicroHack. Install the complete toolchain inside WSL rather than mixing WSL and native
Windows executables or configuration files.

### Task 3: Understand devcontainer state and security

The devcontainer stores these directories in per-container Docker named volumes so
they survive a container rebuild without sharing credentials across separate clones:

| Path | Purpose |
| --- | --- |
| `~/.azure` | Azure CLI sign-in tokens, settings, and Bicep |
| `~/.kube` | Default AKS kubeconfig and the dedicated K3s kubeconfig |
| `~/.rad` | Radius CLI workspaces and downloaded components |
| `~/.ssh` | SSH keys and known hosts used by the K3s VM |

No credentials are baked into the image or committed to the repository. Treat the
named volumes as credentials: use only a trusted workstation, do not copy their
contents into the workspace, and remove the volumes when the lab is retired. Reopening
or rebuilding the container preserves them; removing the volumes resets the state.

The workspace files are mounted separately by VS Code. The host Docker socket and host
credential directories are not mounted.

### Task 4: Verify the toolchain

Run the appropriate version command for every required tool:

```bash
az --version
az bicep version
kubectl version --client
helm version
rad version
git --version
jq --version
yq --version
curl --version
ssh -V
tar --version
```

Resolve missing commands and `PATH` problems before continuing.

If the devcontainer setup did not complete, run **Dev Containers: Rebuild Container**
and inspect the creation log. Reopening a terminal is sufficient after a successful
build.

### Task 5: Select and validate the Azure subscription

Sign in, select the intended subscription, and verify the active account:

```bash
az login
az account list --output table
az account set --subscription "<subscription-id>"
az account show --output table
```

Confirm that these resource providers are registered or can be registered:

```bash
az provider register --namespace Microsoft.ContainerService
az provider register --namespace Microsoft.Compute
az provider register --namespace Microsoft.Network
```

Provider registration is asynchronous. Inspect the registration state instead of
repeatedly submitting the registration command.

Inside the devcontainer, `az login` performs an interactive browser or device-code
sign-in. The resulting Azure CLI state persists in the `~/.azure` volume. Radius does
not reuse the Azure CLI token as a workspace: Challenge 02 creates separate Radius
workspaces under `~/.rad` and registers the Azure workload-identity credential needed
by the AKS control plane.

### Task 6: Agree on local configuration locations

Before sharing access with teammates, decide:

- Which shell environment will run the MicroHack commands
- Where the default kubeconfig will be stored
- Where the dedicated K3s kubeconfig will be stored
- Who will provision each shared platform
- How the team will transfer kubeconfig files securely

No cluster connection is required yet. Challenge 01 creates the default platforms.
When those platforms exist, switch safely by changing both `KUBECONFIG` and context:

```bash
# AKS uses the default ~/.kube/config.
unset KUBECONFIG
kubectl config use-context aks-adaptive-apps

# K3s uses a dedicated persisted file.
export KUBECONFIG="$HOME/.kube/adaptive-apps-k3s.yaml"
kubectl config use-context k3s-azure-vm
```

Always run `kubectl config current-context` before a platform operation. Never copy a
kubeconfig or SSH private key into the Git workspace.

## Success criteria

You are ready to continue when:

- Every required tool returns a version successfully.
- Azure CLI targets the intended subscription.
- The team has the permissions and quota needed for AKS, the K3s VM, networking, and
  later identity configuration.
- The required Azure resource providers are registered or registration is underway.
- The workshop's public egress CIDR is known.
- Windows participants have a complete toolchain in one shell environment.
- The team knows where its Kubernetes and Radius CLI configuration will be stored.
- Devcontainer users can rebuild and reopen the container without losing Azure,
  kubeconfig, Radius workspace, or SSH state.

## Hints

- If a command is not found immediately after installation, restart the shell and
  inspect `PATH`.
- If Azure CLI uses the wrong subscription, list the available subscriptions and set
  the intended subscription explicitly.
- Azure Cloud Shell can help inspect Azure resources, but it does not replace the
  consistent local environment needed for K3s kubeconfig files and later authoring.
- If the browser cannot complete `az login` from a container, follow the device-code
  prompt shown by Azure CLI.
- If a rebuilt container appears signed out or has no Kubernetes contexts, confirm
  that the four `adaptive-apps-microhack-*` named volumes for that devcontainer still
  exist.
- Resolve quota or role-assignment blockers before the event; they are difficult to
  fix within a timed MicroHack.

## Learning resources

- [Azure CLI installation](https://learn.microsoft.com/cli/azure/install-azure-cli)
- [Install and set up kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Helm installation](https://helm.sh/docs/intro/install/)
- [Install the Radius CLI](https://docs.radapp.io/getting-started/install/)
- [Install WSL](https://learn.microsoft.com/windows/wsl/install)
