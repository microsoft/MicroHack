# Walkthrough Challenge 01 - Prerequisites: ready, set, go

**[Home](https://github.com/microsoft/MicroHack/blob/main/03-Azure/01-01-App%20Innovation/04-adaptive-apps/Readme.md)** - [Next Solution](https://github.com/microsoft/MicroHack/blob/main/03-Azure/01-01-App%20Innovation/04-adaptive-apps/walkthrough/challenge-02/solution-02.md)

## Choose one environment

Choose **exactly one** of these setup paths. GitHub Codespaces and a local Dev
Container are the two recommended options; both supply the Adaptive Apps toolchain.

| Setup path | Choose it when |
| --- | --- |
| [GitHub Codespaces (recommended)](#recommended-environment-github-codespaces) | You want VS Code in your browser without installing a local container runtime or tools. |
| [Local Dev Container (recommended)](#recommended-devcontainer) | You want to work in local VS Code and can run containers on your workstation. |
| [Manual setup](#manual-installation-instructions) | You need to install and maintain the tools yourself. |

Complete only your selected section, then go to
[Required access and capacity](#required-access-and-capacity) and the
[Verification checklist](#verification-checklist). **Codespaces and Dev Container
users should skip manual installation and manual workstation verification.**

## Recommended environment: GitHub Codespaces

Use **GitHub Codespaces with the Azure / App Innovation / Adaptive Apps
devcontainer** for the workshop command-line tasks. It provides VS Code in your
browser with Azure CLI, PowerShell 7, Bicep, `kubectl`, Helm, Radius CLI, and the
supporting lab tools, without requiring local installations. Continue to use the
Azure portal for portal-based tasks. No Kubernetes cluster or Docker daemon runs
inside this container; the lab platforms run in Azure.

### Set up Codespaces (recommended)

1. Sign in with a **personal GitHub account**. Optionally set **Settings >
   Codespaces > Default idle timeout** at
   [github.com/settings/codespaces](https://github.com/settings/codespaces)
   **before creating the Codespace**. The default is 30 minutes; you can choose
   5-240 minutes, subject to organization policy. The setting applies to new
   Codespaces.
2. Open the **repository home page**, [microsoft/MicroHack](https://github.com/microsoft/MicroHack),
   while signed in to GitHub. Above the file list, select the green **Code**
   button, then the **Codespaces** tab. This is the repository's Code menu, not
   a menu inside VS Code.

   <a href="https://docs.github.com/assets/images/help/codespaces/who-will-pay.png"><img src="https://docs.github.com/assets/images/help/codespaces/who-will-pay.png" alt="GitHub documentation example of the Code menu with the Codespaces tab selected" width="420"></a>

   In the **top-right corner of the Codespaces tab**, select **...**, then **New
   with options**. Do not use the quick-create button: this repository has
   multiple devcontainers, and you must choose **walkthrough/challenge-01/solution-01.md**

   <a href="https://docs.github.com/assets/images/help/codespaces/default-machine-type.png"><img src="https://docs.github.com/assets/images/help/codespaces/default-machine-type.png" alt="GitHub documentation example showing the Codespaces three-dot menu and New with options" width="420"></a>

   These screenshots are examples from
   [GitHub's Codespaces documentation](https://docs.github.com/en/codespaces/developing-in-a-codespace/creating-a-codespace-for-a-repository#creating-a-codespace-for-a-repository);
   repository names and existing Codespaces may differ. If the **Codespaces**
   tab is missing, check that you are signed in. Alternatively, open
   [Create a codespace](https://github.com/codespaces/new), select
   **microsoft/MicroHack**, and continue with the options below.
3. Select branch **main**, devcontainer configuration
   **Azure / App Innovation / Adaptive Apps**, and a **2-core** machine, then
   **Create codespace**. The configuration file is
   [`.devcontainer/03-azure-01-01-app-innovation-04-adaptive-apps/devcontainer.json`](../../../../../.devcontainer/03-azure-01-01-app-innovation-04-adaptive-apps/devcontainer.json).
   Wait for the post-create setup to finish before using the terminal. If this
   configuration is not offered, use the local Dev Container path instead of
   the default Codespace.
4. In **Terminal > New Terminal**, open **Bash**, sign in to Azure with your
   workshop account, and select your assigned lab subscription:

   ```bash
   az login --use-device-code
   az account set --subscription "<subscription-id>"
   az account show --query "{Account:user.name,Subscription:name,Tenant:tenantId}" --output table
   ```

   Open the device-login URL printed by Azure CLI and enter its **device code**.
   For hosted events, use the account and, if supplied, the Temporary Access
   Pass (TAP) from the Console. The TAP and device code are different; never
   save either in files or commands. Use a private browser window if necessary
   to avoid signing in with your normal work account. For bring-your-own-
   subscription labs, use your own Azure identity. Confirm that the displayed
   account and subscription match your lab details.
5. Use this same Codespace for subsequent challenges. The repository is already
   cloned, and Explorer should open
   `03-Azure/01-01-App Innovation/04-adaptive-apps`. Run the workshop commands
   from that directory in **Bash**; run `pwsh` when PowerShell 7 is needed.
   Check the installed tools with the commands in
   [Verify and troubleshoot](#verify-and-troubleshoot), then skip the remaining
   environment setup sections and continue at
   [Required access and capacity](#required-access-and-capacity).

### Terminals, breaks and saved work

- **Multiple terminals:** use **Terminal > New Terminal** or the terminal panel's
  **+** button. Leave Bastion tunnels and port-forwards running in their own
  terminals. Terminals share files and networking, **not shell variables**;
  initialize the required variables in each terminal as directed.
- **After a restart:** saved files persist when a Codespace stops, but processes,
  tunnels, and shell variables do not. Save only non-secret variable assignments
  in a file such as `~/adaptive-apps-env.sh`, then reload it with
  `source ~/adaptive-apps-env.sh` in each new Bash terminal. For PowerShell, use
  a `.ps1` file and dot-source it. Recheck Azure sign-in and restart tunnels.
  Do not save TAPs, tokens, passwords, private keys, or kubeconfig files in the
  repository.
- **Browser access:** use the Ports view's forwarded HTTPS URLs, not browser
  `localhost`. Organizers must validate the Bastion connection and the frontend,
  Keycloak, and identity redirect URLs before the event; see
  [Console setup](../../docs/console-setup.md#optional-extensions-and-hosted-browsers).
  Challenge 10's GitHub Copilot app / Radius Canvas work still requires a host
  installation, not just a Codespace.
- **Finish for the day:** use **Codespaces: Stop Codespace** in the Command
  Palette, or stop it at [github.com/codespaces](https://github.com/codespaces).
  Closing the browser tab alone does not stop it immediately. When the event
  is over, download any work you want to keep and delete the Codespace. Stopped
  Codespaces still consume storage and are subject to automatic deletion after
  their retention period.

**Included usage:** GitHub Free personal accounts include **120 core-hours per
month**, equivalent to **60 hours (3,600 minutes) on a 2-core machine**, plus
**15 GB-months of storage**. Larger machines consume compute allowance faster.
Check your allowance and current billing terms before the event: container images
and persisted state also consume storage, and a longer idle timeout uses more
compute. Azure resource costs are separate; stopping the Codespace does not stop
Azure resources.

Sources: [Codespaces timeout](https://docs.github.com/en/codespaces/setting-your-user-preferences/setting-your-timeout-period-for-github-codespaces)
and [Included usage and billing](https://docs.github.com/en/billing/concepts/product-billing/github-codespaces).

## Recommended devcontainer

The MicroHack includes a repository-level devcontainer at
`.devcontainer/03-azure-01-01-app-innovation-04-adaptive-apps/devcontainer.json`. It is
the recommended **local** option for participants who can run containers because
it keeps Challenges 01-05 on one tested Linux toolchain. Follow this section only
if you did not choose Codespaces; do not also perform the manual installation.

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
Local VS Code Dev Containers remain the validated path. Codespaces connections
and forwarded identity URLs need organizer validation as described in
[Console setup](https://github.com/microsoft/MicroHack/blob/main/03-Azure/01-01-App%20Innovation/04-adaptive-apps/docs/console-setup.md#optional-extensions-and-hosted-browsers).

### Start the container

```bash
git clone --branch main https://github.com/microsoft/MicroHack.git
cd MicroHack
code .
```

In VS Code:

1. Confirm the Explorer root is the MicroHack repository and make sure Docker or
   WSL is running.
2. Press **Ctrl+Shift+P** and select **Dev Containers: Reopen in Container**.
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
commands in Challenges 01-05 start in the MicroHack directory even though VS Code
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
devcontainer are intentionally omitted. Challenges 01-06 use Bash and PowerShell 7,
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

<a id="windows-git-worktrees"></a>

### Troubleshooting: Windows Git worktrees

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
--expose-token` flow documented in Solution 05 when publishing the recipes. The
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

Radius CLI state is separate. Challenge 03 creates `ws-azure-prod` and
`ws-local-prod` under `~/.rad/config.yaml`; it also configures the workload identity
used by the Radius control plane on AKS. Rebuilding the container preserves those
local workspace definitions.

### Kubeconfig, tunnel, and SSH-key behavior

> **Challenge 02 only:** This step is only needed for Challenge 02. If you are using
> the lab environment, skip this step and continue to
> [Challenge 03](../challenge-03/solution-03.md).

Challenge 02 writes:

- AKS credentials to the default `~/.kube/config`
- K3s credentials and Bastion tunnel state under `~/.kube`
- The generated VM SSH key under `~/.ssh` for optional Bastion-only troubleshooting

The named volumes preserve this state. The tunnel process itself does not survive a
container restart; Challenge 02 documents its `connect` mode. Participants must still
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

- Challenge 02 creates AKS and an Azure VM, then installs K3s on that VM.
- Challenge 03 installs separate Radius control planes into AKS and K3s.
- Challenge 04 installs the portfolio and registers resource types remotely.
- Challenge 05 publishes the teaching recipe and two corrected PostgreSQL recipes to a
  Standard ACR, then registers pinned recipes with both Radius environments. Anonymous
  pull applies only to those non-secret recipe artifacts.

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

After verification succeeds, skip manual installation and continue at
[Required access and capacity](#required-access-and-capacity).

## Manual installation instructions

Follow this section **only if you chose manual setup**. Codespaces and local Dev
Container users already have these tools and should skip to
[Required access and capacity](#required-access-and-capacity).

### Required tools

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
available. Follow the instructions for **one** operating system below, then
complete [Manual workstation verification](#manual-workstation-verification).

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

### Manual workstation verification

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

## Required access and capacity

This section and the verification checklist apply to **all three environments**.
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

**Hosted Console participants:** after preparing your chosen environment, follow
[Console setup](../../docs/console-setup.md) to sign in and connect from Bash.
Your platforms are supplied: validate them in Challenge 02 instead of provisioning
them, then continue with Challenges 03-06. Organizers confirm the infrastructure
permissions and capacity above for the supplied lab.

## Verification checklist

### Azure access

- `az account show` returns the intended subscription.
- The participant can create resources in the lab resource group.
- The coach can create Entra applications or has arranged an identity in advance.
- AKS and VM quota are sufficient in the selected region.

### Kubernetes tooling

- `kubectl version --client` succeeds.
- No cluster connection is required yet; Challenge 02 creates the clusters.

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

- Challenge 01 verifies prerequisites. Unblock environment issues so teams can
  proceed to Challenge 02 to provision or explore AKS and K3s.
- Share these instructions one or two weeks before the MicroHack when possible.
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
- Keep Challenge 01 focused on verification. Challenge 02 contains the platform work.

## Expected outcome

After Challenge 01, participants can:

- Use Azure CLI and select the correct subscription.
- Run `kubectl`, Helm, and Radius CLI.
- Use Git, `curl`, SSH, `tar`, and the Azure CLI Bastion extension.
- Explain where their kubeconfig and Radius workspace configuration will be stored.
- Proceed to [Challenge 02](https://github.com/microsoft/MicroHack/blob/main/03-Azure/01-01-App%20Innovation/04-adaptive-apps/walkthrough/challenge-02/solution-02.md) to provision AKS and K3s.
