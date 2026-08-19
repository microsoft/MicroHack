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

### Task 2: Install the workstation tools

Install the following tools in one consistent shell environment:

- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli)
- [`kubectl`](https://kubernetes.io/docs/tasks/tools/)
- [Helm 3](https://helm.sh/docs/intro/install/)
- [Radius CLI (`rad`)](https://docs.radapp.io/getting-started/install/)
- [Git](https://git-scm.com/downloads)
- `curl`, OpenSSH client, and `tar`
- [Visual Studio Code](https://code.visualstudio.com/)

Windows participants should use WSL 2 for the Bash automation supplied with this
MicroHack. Install the complete toolchain inside WSL rather than mixing WSL and native
Windows executables or configuration files.

### Task 3: Verify the toolchain

Run the appropriate version command for every required tool:

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

Resolve missing commands and `PATH` problems before continuing.

### Task 4: Select and validate the Azure subscription

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

### Task 5: Agree on local configuration locations

Before sharing access with teammates, decide:

- Which shell environment will run the MicroHack commands
- Where the default kubeconfig will be stored
- Where the dedicated K3s kubeconfig will be stored
- Who will provision each shared platform
- How the team will transfer kubeconfig files securely

No cluster connection is required yet. Challenge 01 creates the default platforms.

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

## Hints

- If a command is not found immediately after installation, restart the shell and
  inspect `PATH`.
- If Azure CLI uses the wrong subscription, list the available subscriptions and set
  the intended subscription explicitly.
- Azure Cloud Shell can help inspect Azure resources, but it does not replace the
  consistent local environment needed for K3s kubeconfig files and later authoring.
- Resolve quota or role-assignment blockers before the event; they are difficult to
  fix within a timed MicroHack.

## Learning resources

- [Azure CLI installation](https://learn.microsoft.com/cli/azure/install-azure-cli)
- [Install and set up kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Helm installation](https://helm.sh/docs/intro/install/)
- [Install the Radius CLI](https://docs.radapp.io/getting-started/install/)
- [Install WSL](https://learn.microsoft.com/windows/wsl/install)
