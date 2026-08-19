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
- Permission to create a Microsoft Entra application and service principal
- Sufficient regional quota for:
  - A two-node AKS cluster using `Standard_D4s_v5` by default
  - One K3s VM using `Standard_D4s_v5` by default
  - Standard public IP addresses
- A known public egress CIDR for secure K3s management access

The default scripts assign the Radius identity `Owner` at the lab resource-group
scope because later exercises can create role assignments. Use a dedicated lab
subscription or resource group.

## Required tools

- Azure CLI
- `kubectl`
- Helm
- Radius CLI (`rad`)
- Git
- `curl`
- OpenSSH client
- `tar`
- Visual Studio Code
- Bash for the optional automation scripts

Windows participants should use WSL 2 for the Bash automation scripts. Manual
instructions can also be followed from PowerShell 7 where equivalent commands are
available.

## Installation instructions

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
brew install git curl
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
sudo apt-get install --yes git curl openssh-client tar
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
winget install Microsoft.VisualStudioCode
winget install Microsoft.PowerShell
```

> [!IMPORTANT]
> Keep a toolchain together. If automation runs in WSL, install Azure CLI, `kubectl`,
> Helm, `rad`, Git, SSH, and `tar` inside WSL and keep kubeconfig files there.

## Verify the workstation

Run:

```bash
az --version
kubectl version --client
helm version
rad version
git --version
curl --version
ssh -V
tar --version
code --version
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

## Troubleshooting

| Tool or symptom | Guidance |
| --- | --- |
| `az: command not found` | Reinstall Azure CLI, restart the shell, and inspect `PATH`. |
| `kubectl: command not found` | Reinstall `kubectl` and inspect `PATH`. |
| `rad: command not found` | Add `$HOME/.local/bin` to `PATH` or reinstall from the Radius releases page. |
| Helm permission error | Verify the Helm binary and local cache ownership; do not default to running Helm as root. |
| Wrong Azure subscription | Run `az account set --subscription "<subscription-id>"`. |
| Azure authorization error | Confirm the participant's role and scope before troubleshooting scripts. |
| AKS or VM quota error | Select another VM size or region, or request quota before the event. |
| WSL cannot see native Windows tools | Install the complete toolchain inside WSL rather than mixing environments. |

Azure Cloud Shell can temporarily help with Azure resource inspection, but the K3s
kubeconfig and later local files still require a consistent participant workstation.

## Tips for coaches

- Send these instructions early and ask participants to return the verification output.
- Validate AKS and VM quota before the event.
- Agree on one Azure region and one lab resource-group naming convention.
- Determine the workshop's public egress CIDR for the K3s network rules.
- Decide who runs shared cluster deployment scripts; only one person should provision
  each shared environment.
- Encourage participants to use manual tutorials for learning. Automation is an
  optional shortcut, not the primary path.
- Keep Challenge 00 focused on verification. Challenge 01 contains the platform work.

## Expected outcome

After Challenge 00, participants can:

- Use Azure CLI and select the correct subscription.
- Run `kubectl`, Helm, and Radius CLI.
- Use Git, `curl`, SSH, and `tar`.
- Explain where their kubeconfig and Radius workspace configuration will be stored.
- Proceed to [Challenge 01](../challenge-01/solution-01.md) to provision AKS and K3s.
