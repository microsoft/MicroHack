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
  Azure Bastion Standard, its managed public IP, a NAT gateway and its public IP, VM Run
  Command, and role assignments
- Permission to create a Microsoft Entra application and service principal
- Regional quota for the AKS nodes, K3s VM, Azure Bastion, and two Standard public IP
  addresses
- Contributor or equivalent resource permissions, Network Contributor where networking
  is delegated, and permission to open Bastion native-client tunnels

> [!IMPORTANT]
> Later challenges grant a Radius identity `Owner` on the dedicated lab resource group
> because recipes can create role assignments. Use an isolated workshop subscription
> or resource group rather than a production scope.

Register the resource providers the MicroHack uses. A subscription that has never
deployed these services silently fails later with provider or feature errors:

```bash
az account set --subscription "<subscription-id>"

for provider in Microsoft.Network Microsoft.Compute Microsoft.ContainerService \
  Microsoft.ContainerRegistry Microsoft.KeyVault Microsoft.Storage; do
  az provider register --namespace "$provider" --wait
done

az provider list \
  --query "[?namespace=='Microsoft.Network' || namespace=='Microsoft.Compute' || namespace=='Microsoft.ContainerService' || namespace=='Microsoft.ContainerRegistry'].{provider:namespace,state:registrationState}" \
  --output table
```

Every provider must report `Registered`.

Then confirm the subscription can actually create a public IP address, because
Challenge 01 needs one for Azure Bastion:

```bash
az group create --name rg-adaptive-apps-preflight --location westeurope --output none
az network public-ip create \
  --resource-group rg-adaptive-apps-preflight \
  --name pip-preflight \
  --sku Standard \
  --allocation-method Static \
  --output none
az group delete --name rg-adaptive-apps-preflight --yes --no-wait
```

If that fails with
`SubscriptionNotRegisteredForFeature ... Microsoft.Network/AllowBringYourOwnPublicIpAddress`,
the subscription's networking registration is incomplete. Repair it and retry:

```bash
az feature register --namespace Microsoft.Network --name AllowBringYourOwnPublicIpAddress
az provider register --namespace Microsoft.Network --wait
```

### Task 1b: Check regional VM capacity

Regions differ in which VM sizes they offer, and quota is granted per size family. List
the four-vCPU sizes your subscription can actually use in the target region:

```bash
az vm list-skus \
  --location westeurope \
  --resource-type virtualMachines \
  --query "[?length(restrictions[?type=='Location']) == \`0\`].name" \
  --output tsv | grep -E '^Standard_D4(a|as|s|ds)?_v[345]$' | sort
```

A `Zone` restriction is not a problem, because the MicroHack deploys regionally rather
than into a specific availability zone. A `Location` restriction means the size is
unavailable to you in that region.

Then confirm the family quota covers 12 vCPUs (two AKS nodes plus the K3s VM):

```bash
az vm list-usage --location westeurope --output table |
  grep -E 'Total Regional vCPUs|Standard DSv5 Family'
```

`resources/prepare-aks.sh` and `resources/prepare-k3s-azure-vm.sh` perform this check
themselves. Each script picks the first size that the region offers and, if allocation
still fails because of capacity or quota, automatically retries the next size in
`AKS_NODE_VM_SIZE_CANDIDATES` or `K3S_VM_SIZE_CANDIDATES`. Override either variable to
supply your own ordered list:

```bash
export K3S_VM_SIZE_CANDIDATES="Standard_D4s_v5 Standard_D4s_v4 Standard_D4s_v3"
```

If no size in the region works, choose a different `AZURE_LOCATION`.

### Task 2: Choose a workstation setup

The Adaptive Apps devcontainer is the recommended setup because it provides a
consistent Linux toolchain for Challenges 00-04. A manual host installation remains
supported.

#### Option A: Use the recommended devcontainer

The devcontainer gives every participant the same tested Linux toolchain, so this is the
recommended path. It needs a container runtime on the host. If you have never used
containers before, work through A1 to A4 once; budget about 20 minutes.

##### A1. Windows only: enable WSL 2

Windows runs Linux containers inside WSL 2. In an elevated PowerShell window:

```powershell
wsl --install
wsl --set-default-version 2
```

Restart if prompted, then confirm that a distribution is installed and reports `2`:

```powershell
wsl --list --verbose
```

macOS and Linux hosts skip this step.

##### A2. Install a container runtime

Any of the following works with the Dev Containers extension. Choose one.

| Runtime | When to choose it |
| --- | --- |
| [Docker Desktop](https://www.docker.com/products/docker-desktop/) | Simplest option. On Windows keep **Settings > General > Use the WSL 2 based engine** enabled. Docker Desktop requires a paid subscription for larger organizations, so check the [Docker Desktop license terms](https://docs.docker.com/subscription/desktop-license/) before using it for work. |
| [Docker Engine](https://docs.docker.com/engine/install/ubuntu/) inside WSL 2 or Linux | No Docker Desktop subscription. Install Docker Engine in the WSL 2 distribution, add your user to the `docker` group, then open the repository through **WSL: Connect to WSL** in VS Code so the extension uses that engine. |
| [Podman Desktop](https://podman-desktop.io/) or [Rancher Desktop](https://rancherdesktop.io/) | Organizations that standardize on a Docker Desktop alternative. Set the runtime as the active Docker-compatible endpoint. |

Confirm the runtime responds before continuing. The command must print server details
rather than a connection error:

```bash
docker info
```

##### A3. Install Visual Studio Code, the Dev Containers extension, and Git

- [Visual Studio Code](https://code.visualstudio.com/)
- [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)
  (`ms-vscode-remote.remote-containers`)
- [Git](https://git-scm.com/downloads) on the host, because the repository is cloned
  before the container starts

##### A4. Size the runtime

The container image, devcontainer features, and four small state volumes need roughly
10 GB of free disk. Allow the runtime at least 4 GB of memory. On Docker Desktop these
limits are under **Settings > Resources**.

##### A5. Processor architecture

Both `x86_64` and `arm64` workstations are supported, including Apple Silicon Macs and
Windows on Arm devices. The devcontainer selects matching Linux builds of `kubectl`,
Helm, the Radius CLI, `yq`, and Bicep automatically, so no extra configuration is
needed. Do not force `--platform linux/amd64`: emulation is slower and is not required.

The workstation architecture is independent of Azure. The AKS nodes and the K3s VM are
always x64 Azure VM sizes even when the devcontainer runs on arm64.

##### Start the container

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

The first build downloads the base image and every pinned tool, so it takes several
minutes. The build is finished when the terminal prints
`The container is ready. Sign in with 'az login' and select the lab subscription.`

The container installs Azure CLI, its `bastion` extension, Bicep, `kubectl`, Helm 3,
Radius CLI, PowerShell 7, Git, `jq`, `yq`, `curl`, SSH, and `tar`. These tools can run
every command in Challenges 00-05.
The container is only a workstation: AKS, the Linux VM, K3s, Radius control planes,
portfolio workloads, and recipes are still created on the remote Azure and Kubernetes
targets by the commands you run.

Sign in to Azure from inside the container. If the container cannot open a browser, use
the device-code flow:

```bash
az login --use-device-code
az account set --subscription "<subscription-id>"
az account show --output table
```

> [!IMPORTANT]
> The configuration does not mount the host Docker socket. Challenge 04 supports
> token-based ACR authentication when Docker is unavailable. It creates or upgrades a
> Standard ACR and enables anonymous pull only for the non-secret compiled recipe
> artifacts needed by both Radius control planes.

#### Option B: Install tools on the host

Install the following tools in one consistent shell environment:

- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli)
- [Azure CLI `bastion` extension](https://learn.microsoft.com/cli/azure/network/bastion)
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

When the repository root is a Windows Git worktree, its `.git` file points to metadata
using a Windows path that Linux cannot resolve. The devcontainer uses a simple
non-Git-aware Bash prompt in that case so normal MicroHack commands do not emit
recurring `fatal: not a git repository` messages. Repository-aware Git commands remain
unavailable inside that container session. The challenges do not require them; use a
normal clone instead of a worktree if you need Git operations inside the container.

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
az extension show --name bastion --query version --output tsv
curl --version
ssh -V
tar --version
```

Resolve missing commands and `PATH` problems before continuing.

If `kubectl` or another required tool is missing, first pull the current branch on the
host. Then run **Dev Containers: Rebuild Container** and inspect the creation log. A
Windows worktree cannot pull from inside the container; use the host shell. Reopen a
Bash terminal after a successful build.

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
- Azure Bastion Standard is permitted in the chosen region and its hourly cost is
  understood.
- Participants have VM Run Command and Bastion tunnel permissions.
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
- If a Windows worktree still shows Git errors in an already running terminal, rebuild
  the container and open a new Bash terminal so the prompt fallback is loaded.
- Resolve quota or role-assignment blockers before the event; they are difficult to
  fix within a timed MicroHack.

## Learning resources

- [Azure CLI installation](https://learn.microsoft.com/cli/azure/install-azure-cli)
- [Install and set up kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Helm installation](https://helm.sh/docs/intro/install/)
- [Install the Radius CLI](https://docs.radapp.io/getting-started/install/)
- [Install WSL](https://learn.microsoft.com/windows/wsl/install)
