# Walkthrough Challenge 00 - Prerequisites: ready, set, go

**[Home](../../Readme.md)** - [Next Solution](../challenge-01/solution-01.md)

## Coach notes

Challenge 00 verifies prerequisites. Participants should arrive with most tools
installed or be prepared to install them quickly. Coaches should unblock environment
issues so teams can proceed to Challenge 01, where they provision AKS and K3s.

Share these instructions one or two weeks before the MicroHack when possible.

## Required access and capacity

Confirm the workshop has:

- An Azure subscription
- Permission to create a resource group, AKS cluster, Linux VM, networking, and role
  assignments
- Permission to create Azure Bastion Standard and its managed public IP, a NAT gateway
  and its public IP, invoke VM Run Command, and open Bastion native-client tunnels
- Permission to create a Microsoft Entra application and service principal
- Sufficient regional quota for:
  - A two-node AKS cluster using `Standard_D4s_v5` by default
  - One K3s VM using `Standard_D4s_v5` by default
  - One Standard Azure Bastion host and its managed public IP
  - One NAT gateway and one Standard public IP for K3s outbound access

The default scripts assign the Radius identity `Owner` at the lab resource-group
scope because later exercises can create role assignments. Use a dedicated lab
subscription or resource group.

## Required tools

- Azure CLI
- Azure CLI `bastion` extension
- Bicep CLI
- `kubectl`
- Helm
- Radius CLI (`rad`)
- Git
- `jq`
- `yq`
- `curl`
- OpenSSH client
- `tar`
- Visual Studio Code
- Bash for the optional automation scripts

Windows participants should use WSL 2 for the Bash automation scripts. Manual
instructions can also be followed from PowerShell 7 where equivalent commands are
available.

## Recommended devcontainer

The MicroHack includes a repository-level devcontainer at
`.devcontainer/03-azure-01-01-app-innovation-04-adaptive-apps/devcontainer.json`. It is
recommended for participants who can run containers locally because it keeps
Challenges 00-04 on one tested Linux toolchain. Manual installation remains available
below.

### Host prerequisites

Confirm each participant has:

- A container runtime (see the options below)
- Visual Studio Code
- The Dev Containers extension (`ms-vscode-remote.remote-containers`)
- Git on the host, because the repository is cloned before the container starts
- Roughly 10 GB of free disk for the Ubuntu base image, features, and four small state
  volumes, and at least 4 GB of memory available to the runtime

On Windows, WSL 2 must be enabled first (`wsl --install`, then `wsl --set-default-version 2`
in an elevated PowerShell, and `wsl --list --verbose` to confirm the distribution reports
`2`). The repository can be cloned in the WSL filesystem for better filesystem
performance.

Three container runtimes are known to work with this configuration:

| Runtime | Coach notes |
| --- | --- |
| Docker Desktop | Simplest to support. Keep the WSL 2 based engine enabled on Windows. Docker Desktop requires a paid subscription for larger organizations, so confirm participants are licensed before recommending it as the default. |
| Docker Engine inside WSL 2 or Linux | Avoids the Docker Desktop subscription. Participants install Docker Engine in the distribution, add themselves to the `docker` group, and open the repository through **WSL: Connect to WSL** so the extension targets that engine. |
| Podman Desktop or Rancher Desktop | Usable where an organization standardizes on a Docker Desktop alternative. |

Have participants prove the runtime works before the workshop starts. `docker info` must
print server details rather than a connection error. This single check removes most
day-one delays.

This configuration follows the MicroHack repository's multi-configuration convention.
It is documented for local VS Code Dev Containers; do not advertise Codespaces unless
the repository later adds and validates an explicit Codespaces selection workflow.

### Start the container

```bash
git clone https://github.com/djong1/MicroHack.git
cd MicroHack
git switch djong1-adaptive-apps-microhack
code .
```

In VS Code:

1. Confirm the Explorer root is the MicroHack repository.
2. Run **Dev Containers: Reopen in Container**.
3. Select `03-azure-01-01-app-innovation-04-adaptive-apps` from the available
   configurations.
4. Wait for
   `.devcontainer/03-azure-01-01-app-innovation-04-adaptive-apps/post-create.sh` to
   finish.
5. Confirm VS Code reopens
   `03-Azure/01-01-App Innovation/04-adaptive-apps` as the workspace and opens
   `Readme.md`.
6. Open a new Bash terminal in the container.

The configuration binds the repository root to `/workspaces/microhack` and sets the
container workspace to
`/workspaces/microhack/03-Azure/01-01-App Innovation/04-adaptive-apps`. Therefore,
commands in Challenges 00-04 start in the MicroHack directory even though VS Code
discovers the configuration from the repository root.

### Installed toolchain

The Azure CLI devcontainer feature installs Azure CLI 2.89.1. The post-create script
installs Bicep 0.46.1 and the Azure CLI `bastion` extension 1.4.3 into the persisted
Azure CLI state volume and also installs:

- `kubectl` 1.36.3
- Helm 3.21.4
- Radius CLI 0.60.0 and its Radius Bicep support
- PowerShell 7 through the official Dev Containers feature
- `yq` 4.53.4
- Git, `jq`, `curl`, OpenSSH client, `tar`, and CA certificates

Version pins make participant environments repeatable. Updating a pin requires static
validation of this MicroHack and compatibility with the Kubernetes versions offered by
AKS.

Every pinned tool ships both `amd64` and `arm64` Linux builds, and `post-create.sh`
selects the matching one from `uname -m`. The configuration is validated on `x86_64` and
`arm64` hosts, including Apple Silicon and Windows on Arm. Do not tell participants to
force `--platform linux/amd64`. The workstation architecture does not affect Azure: the
AKS nodes and the K3s VM are x64 Azure VM sizes in every case.

Rust, k3d, and application-development extensions from the source repository
devcontainer are intentionally omitted. Challenges 00-05 use Bash and PowerShell 7,
create K3s on an Azure VM, and do not build the Adaptive Apps application source.

### Persistent state and security

The configuration mounts four Docker named volumes. `${devcontainerId}` gives each
devcontainer its own stable suffix, so separate clones do not share credentials:

| Volume | Container path | Contents |
| --- | --- | --- |
| `adaptive-apps-microhack-azure-${devcontainerId}` | `/home/vscode/.azure` | Azure tokens, CLI settings, and Bicep |
| `adaptive-apps-microhack-kube-${devcontainerId}` | `/home/vscode/.kube` | AKS and K3s kubeconfig files |
| `adaptive-apps-microhack-radius-${devcontainerId}` | `/home/vscode/.rad` | Radius workspaces and components |
| `adaptive-apps-microhack-ssh-${devcontainerId}` | `/home/vscode/.ssh` | K3s VM SSH key and known hosts |

This state survives **Rebuild Container**. It does not survive deletion of the named
volumes. The files contain credentials and must be protected like the corresponding
host directories.

The configuration deliberately does not:

- Bake tokens, kubeconfig files, SSH keys, or Radius workspace state into the image
- Mount the host's `~/.azure`, `~/.kube`, `~/.rad`, or `~/.ssh`
- Mount the host Docker socket

### Windows Git worktrees

A Windows Git worktree stores a `.git` text pointer containing a Windows path such as
`C:/.../.git/worktrees/...`. Linux cannot resolve that host path through the repository
bind mount. Git-aware shell prompts can therefore print `fatal: not a git repository`
before otherwise unrelated commands.

The post-create script detects this pointer without changing it and appends a simple
non-Git-aware Bash prompt inside the container. It does not mount arbitrary host paths,
replace Git metadata, or mutate the host worktree. The MicroHack scripts do not require
repository-aware Git commands.

If participants need Git operations inside the container, use a normal repository
clone, whose `.git` metadata is contained in the bound directory, rather than a Windows
worktree. Git remains installed for normal clones, but do not claim repository Git
functionality for a Windows worktree bind mount.

Without a Docker socket, use the temporary `DOCKER_CONFIG` and `az acr login
--expose-token` flow documented in Solution 04 when publishing the recipe. The
`configure-recipes.sh` helper already uses this token-based approach.

### Azure and Radius authentication

Sign in from the container and select the lab subscription:

```bash
az login
az account set --subscription "<subscription-id>"
az account show --output table
```

Azure CLI may open a browser on the host or show a device-code prompt. When the
container cannot reach a browser at all, force the device-code flow:

```bash
az login --use-device-code
```

Tokens are saved only in the `~/.azure` volume.

Radius CLI state is separate. Challenge 02 creates `ws-azure-prod` and
`ws-local-prod` under `~/.rad/config.yaml`; it also configures the workload identity
used by the Radius control plane on AKS. Rebuilding the container preserves those
local workspace definitions.

### Kubeconfig, tunnel, and SSH-key behavior

Challenge 01 writes:

- AKS credentials to the default `~/.kube/config`
- K3s credentials and Bastion tunnel state under `~/.kube`
- The generated VM SSH key under `~/.ssh` for optional Bastion-only troubleshooting

The named volumes preserve this state. The tunnel process itself does not survive a
container restart; Challenge 01 documents its `connect` mode. Participants must still
switch safely:

```bash
# AKS
unset KUBECONFIG
kubectl config use-context aks-adaptive-apps

# K3s
export KUBECONFIG="$HOME/.kube/adaptive-apps-k3s.yaml"
kubectl config use-context k3s-azure-vm
```

Do not copy kubeconfig files or private keys into the Git workspace. If teammates need
K3s access, distribute credentials through an approved secure channel.

### What runs where

The devcontainer runs only participant tools. Commands executed inside it create or
configure remote resources:

- Challenge 01 creates AKS and an Azure VM, then installs K3s on that VM.
- Challenge 02 installs separate Radius control planes into AKS and K3s.
- Challenge 03 installs the portfolio and registers resource types remotely.
- Challenge 04 publishes a Bicep recipe to ACR and registers recipes with both Radius
  environments.

No Kubernetes cluster or Docker daemon runs inside this devcontainer.

### Verify and troubleshoot

Run:

```bash
az --version
az bicep version
kubectl version --client
helm version --short
rad version
pwsh --version
git --version
jq --version
yq --version
az extension show --name bastion --query version --output tsv
curl --version
ssh -V
tar --version
```

If creation fails:

1. Inspect the Dev Containers creation log for the first failed download or command.
2. If using a Windows worktree, pull or check out the fix on the Windows host because
   repository-aware Git commands are unavailable inside the container.
3. Run **Dev Containers: Rebuild Container** to apply the LF-normalized setup script,
   prompt fallback, and explicit tool `PATH`.
4. Open a new Bash terminal and rerun the verification commands above.
5. If a rebuild is temporarily unavailable after the host has the corrected files,
   rerun setup safely from the existing container:

   ```bash
   bash /workspaces/microhack/.devcontainer/03-azure-01-01-app-innovation-04-adaptive-apps/post-create.sh
   exec bash
   ```

6. Confirm `command -v kubectl` returns `/home/vscode/.local/bin/kubectl`.
7. Confirm Docker Desktop is running and the container can reach GitHub, Microsoft,
   Kubernetes, and Helm download endpoints.
8. If tools are installed but not found, open a new terminal so `.bashrc` and the
   devcontainer `remoteEnv` update
   `PATH`.
9. If state is unexpectedly missing, verify that the four named volumes still exist.
10. Delete a named volume only when intentionally resetting its credential state.

## Manual installation instructions

### macOS

Install Azure CLI:

```bash
brew install azure-cli
```

Install `kubectl`:

```bash
brew install kubectl
```

Install Helm:

```bash
brew install helm
```

Install Git and supporting command-line tools:

```bash
brew install git curl jq yq
az bicep install
```

Install Radius CLI:

```bash
curl -fsSL https://raw.githubusercontent.com/radius-project/radius/main/deploy/install.sh |
  /bin/bash
```

If `rad` is not found, add the installer path and reload the shell:

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >>~/.zshrc
source ~/.zshrc
```

Install Visual Studio Code:

```bash
brew install --cask visual-studio-code
```

### Linux: Ubuntu or Debian

Install Azure CLI:

```bash
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
```

Install `kubectl`:

```bash
curl -LO "https://dl.k8s.io/release/$(curl -L -s \
  https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
```

Install Helm:

```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

Install supporting tools:

```bash
sudo apt-get update
sudo apt-get install --yes git curl jq openssh-client tar
az bicep install

YQ_VERSION="v4.53.4"
YQ_ARCH="amd64"
[[ "$(uname -m)" == "aarch64" ]] && YQ_ARCH="arm64"
sudo curl --fail --location \
  "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_${YQ_ARCH}" \
  --output /usr/local/bin/yq
sudo chmod 0755 /usr/local/bin/yq
```

Install Radius CLI:

```bash
wget -q "https://raw.githubusercontent.com/radius-project/radius/main/deploy/install.sh" \
  -O - | /bin/bash
```

Add Radius to `PATH` if needed:

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >>~/.bashrc
source ~/.bashrc
```

Install Visual Studio Code from
[code.visualstudio.com](https://code.visualstudio.com/) or with Snap:

```bash
sudo snap install code --classic
```

### Windows: WSL 2 and PowerShell 7

Install WSL 2 with Ubuntu from an elevated PowerShell prompt:

```powershell
wsl --install -d Ubuntu
```

Restart if requested, open Ubuntu, and follow the Linux installation instructions.
This is the recommended environment for the Bash automation scripts.

Tools can alternatively be installed on Windows with `winget`:

```powershell
winget install Microsoft.AzureCLI
winget install Kubernetes.kubectl
winget install Helm.Helm
winget install RadiusProject.rad
winget install Git.Git
winget install jqlang.jq
winget install MikeFarah.yq
winget install Microsoft.VisualStudioCode
winget install Microsoft.PowerShell
az bicep install
```

> [!IMPORTANT]
> Keep a toolchain together. If automation runs in WSL, install Azure CLI, `kubectl`,
> Helm, `rad`, Git, SSH, and `tar` inside WSL and keep kubeconfig files there.

## Verify the workstation

Install or update the stable Bastion extension on a manual workstation:

```bash
az extension add \
  --name bastion \
  --version 1.4.3 \
  --upgrade \
  --yes \
  --allow-preview false
```

Run:

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

Sign in and select the intended subscription:

```bash
az login
az account list --output table
az account set --subscription "<subscription-id>"
az account show --output table
```

Confirm the required resource providers can be registered:

```bash
az provider register --namespace Microsoft.ContainerService
az provider register --namespace Microsoft.Compute
az provider register --namespace Microsoft.Network
```

Provider registration is asynchronous:

```bash
az provider show \
  --namespace Microsoft.ContainerService \
  --query registrationState \
  --output tsv
```

## Verification checklist

### Azure access

- `az account show` returns the intended subscription.
- The participant can create resources in the lab resource group.
- The coach can create Entra applications or has arranged an identity in advance.
- AKS and VM quota are sufficient in the selected region.

### Kubernetes tooling

- `kubectl version --client` succeeds.
- No cluster connection is required yet; Challenge 01 creates the clusters.

### Helm

- `helm version` succeeds.
- Helm 3 is installed.

### Radius

- `rad version` succeeds.
- Use the latest stable CLI so the installed control plane uses the matching version.

### Shell and supporting tools

- Bash can run the optional automation scripts.
- Git, `curl`, SSH, and `tar` are available.
- On Windows, the team has agreed whether commands run in WSL or native PowerShell.
- Devcontainer participants have confirmed that rebuilds preserve the expected named
  volumes and understand that those volumes contain credentials.

## Troubleshooting

| Tool or symptom | Guidance |
| --- | --- |
| `az: command not found` | Reinstall Azure CLI, restart the shell, and inspect `PATH`. |
| `kubectl: command not found` | Reinstall `kubectl` and inspect `PATH`. |
| `rad: command not found` | Add `$HOME/.local/bin` to `PATH` or reinstall from the Radius releases page. |
| Helm permission error | Verify the Helm binary and local cache ownership; do not default to running Helm as root. |
| Wrong Azure subscription | Run `az account set --subscription "<subscription-id>"`. |
| Azure authorization error | Confirm the participant's role and scope before troubleshooting scripts. |
| Bastion tunnel authorization error | Confirm the role includes `Microsoft.Network/bastionHosts/tunnels/action` and the participant can read the VM/NIC. |
| AKS or VM quota error | Select another VM size or region, or request quota before the event. |
| WSL cannot see native Windows tools | Install the complete toolchain inside WSL rather than mixing environments. |
| Devcontainer creation fails | Inspect the creation log, confirm network access, and run **Dev Containers: Rebuild Container**. |
| Devcontainer lost authentication or contexts | Confirm the named Azure, Kubernetes, Radius, and SSH volumes were not deleted. |
| Repeated `fatal: not a git repository` in a Windows worktree | Rebuild the container and open a new Bash terminal. Git operations require a normal clone; MicroHack commands do not require Git. |

Azure Cloud Shell can temporarily help with Azure resource inspection, but the K3s
kubeconfig and later local files still require a consistent participant workstation.

## Tips for coaches

- Send these instructions early and ask participants to return the verification output.
- Validate AKS and VM quota before the event.
- Agree on one Azure region and one lab resource-group naming convention.
- Confirm Azure Bastion Standard is allowed in the selected region and budget for its
  hourly cost until cleanup.
- Confirm delegated-network participants have Network Contributor plus VM Run Command
  and Bastion tunnel permissions.
- Decide who runs shared cluster deployment scripts; only one person should provision
  each shared environment.
- Encourage participants to use manual tutorials for learning. Automation is an
  optional shortcut, not the primary path.
- Keep Challenge 00 focused on verification. Challenge 01 contains the platform work.

## Expected outcome

After Challenge 00, participants can:

- Use Azure CLI and select the correct subscription.
- Run `kubectl`, Helm, and Radius CLI.
- Use Git, `curl`, SSH, `tar`, and the Azure CLI Bastion extension.
- Explain where their kubeconfig and Radius workspace configuration will be stored.
- Proceed to [Challenge 01](../challenge-01/solution-01.md) to provision AKS and K3s.
