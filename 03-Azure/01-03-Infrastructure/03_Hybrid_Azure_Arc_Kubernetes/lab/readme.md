# Environment Setup
When working through the challenges of this microhack, it's assumed that you have an onprem k8s cluster available which you can use to arc-enable it. Also, it's assumed that you have a container registry, which you can use for the gitops challenge.

In this folder you find terraform code to deploy a **K3s cluster**, a **Windows 11 workstation VM**, a **central Azure Bastion**, and a container registry in Azure for each participant of the microhack. It's intended that coaches create these resources for their participants before the microhack starts, so the participants can directly start with challenge 1 (onboarding/arc-enabling their cluster).

Participants connect via **Azure Bastion** (RDP) to their Windows 11 workstation, which comes pre-installed with **WSL2 + Ubuntu**, **VS Code**, **Azure CLI**, **kubectl**, **Helm**, and **git** — everything needed for the challenges.

## Architecture

This Terraform configuration deploys the following per participant:

### K3s Cluster (simulated on-premises)
- **1 Master Node**: K3s server with embedded etcd (10.{100+index}.1.10)
- **2 Worker Nodes**: K3s agents (10.{100+index}.1.11, 10.{100+index}.1.12)

### Windows 11 Workstation
- **1 Windows 11 VM**: Pre-configured dev workstation (10.{100+index}.2.10)
- Installed via Ansible: WSL2 + Ubuntu, VS Code (with WSL extension), Git, Azure CLI, kubectl, Helm
- Uses the same `admin_user` / `admin_password` credentials as the K3s nodes (defined in `fixtures.tfvars`)

### Shared Infrastructure (deployed once)
- **Azure Bastion** (Standard SKU): Central jump host in its own VNet (10.200.0.0/16)
- **VNet Peering**: Bastion VNet peered to every participant VNet for cross-VNet RDP/SSH access
- No management ports exposed to the internet

### Networking
- **Virtual Network** per participant: Isolated network (10.{100+index}.0.0/16)
  - `k3s-subnet` (10.{100+index}.1.0/24) — K3s master and worker nodes
  - `workstation-subnet` (10.{100+index}.2.0/24) — Windows 11 workstation
- **Network Security Groups**:
  - K3s nodes: SSH, K3s API, and NodePort restricted to `VirtualNetwork` (accessible from the workstation on the same VNet)
  - Workstation: RDP and WinRM restricted to the Bastion subnet only

## Resources to be deployed
2 resource groups per participant, 1 K3s cluster (3 VMs), 1 Windows workstation, 1 container registry per participant, plus shared Bastion infrastructure. `xy` represents the participant number:
```
subscription
|
├── mh-bastion (resource group — shared, deployed once)
│   ├── mh-bastion (Azure Bastion Host, Standard SKU)
│   ├── mh-bastion-vnet (Virtual Network 10.200.0.0/16)
│   └── mh-bastion-ip (Public IP)
|
├── <xy>-k8s-arc (resource group)
│   ├── <xy>mhacr (container registry)
│   └── <xy>-law (log analytics workspace)
|
└── <xy>-k8s-onprem (resource group)
    ├── <xy>-k8s-master (VM - K3s server)
    ├── <xy>-k8s-worker1 (VM - K3s agent)
    ├── <xy>-k8s-worker2 (VM - K3s agent)
    ├── <xy>-workstation (VM - Windows 11 Pro)
    ├── <xy>-k8s-vnet (Virtual Network, peered to Bastion VNet)
    │   ├── k3s-subnet
    │   └── workstation-subnet
    └── Associated NICs, NSGs (no public IPs on workstation)
```

## Prerequisites
* bash shell (tested with Ubuntu 22.04)
* Azure CLI
* terraform
* Ansible (with `ansible.windows` and `chocolatey.chocolatey` collections — see `ansible/requirements.yml`)
* clone this repo locally, so you can adjust the deployment files according to your needs
* Azure subscription
* User account with subscription owner permissions
* Sufficient quota limits to support creation of K3s VMs + Windows workstation VMs per participant

## Default Configuration
- **K3s VM Size**: Standard_D4ds_v6 (sufficient for K3s and Arc data services)
- **Workstation VM Size**: Standard_D4ds_v6
- **K3s OS**: Ubuntu 22.04 LTS
- **Workstation OS**: Windows 11 24H2 Pro
- **K3s Version**: v1.33.6+k3s1
- **Admin User**: Set via `admin_user` in `fixtures.tfvars` (shared by K3s and workstation VMs)
- **Password**: Set via `admin_password` in `fixtures.tfvars` (shared by K3s and workstation VMs)
- **VMs per participant**: 4 (1 K3s master + 2 K3s workers + 1 Windows workstation)
- **Bastion**: 1 Azure Bastion (Standard SKU), shared across all participants

If you don't change the default value of parameter "vm_size" in variables.tf, three Standard_D4ds_v6 VMs per cluster plus one Standard_D4ds_v6 workstation VM per participant are used. If you have many participants you need to ensure that the quota limit in your subscription is sufficient to support the required cores (4 VMs × participants). The terraform code will distribute the participant VNets across multiple regions. This setting can be adjusted via the parameter "onprem_resources" (variables.tf) value.

You can check this limit via Azure Portal (subscription > settings > Usage & Quotas):

![alt text](img/image.png)



## Installation instructions
As a microhack coach, you will be given a subscription in the central microhack tenant. Terraform expects the subscription id within the azurerm provider. Therefore, you need to to create the provider.tf file in this folder. To achieve this

* Copy the provider-template.txt and rename the copy to 'provider.tf'.
* Login to Azure CLI and run the "start_here.sh" script located in this folder
```bash
az logout # only if you were logged in with a different user already
az login  # in the browser popup, provide the user credentials you got from your microhack coach

./start_here.sh # sets the subscription_id in the provider.tf file
```

The terraform code deploys **K3s clusters** on Azure VMs which will be used as onprem k8s clusters. We chose K3s as it provides a true "on-premises" experience compared to AKS, making Arc enablement more realistic and meaningful for learning purposes.

## How K3s Setup Works

The K3s installation is **fully automated** during VM provisioning using cloud-init:

1. **k3s-master-setup.sh**: Automatically runs on the master VM during boot
   - Installs Docker and required packages
   - Downloads and installs K3s server with embedded etcd
  - Configures kubeconfig for the configured `admin_user`
   - Creates a script to retrieve the node token for workers

2. **k3s-worker-setup.sh**: Automatically runs on worker VMs during boot
   - Installs Docker and required packages
   - Waits for the master to be ready
   - Downloads and installs K3s agent
   - Connects to the master using the shared cluster token

The scripts are executed via Terraform's `custom_data` parameter, so **no manual intervention is required**. The cluster will be ready approximately 5-10 minutes after VM deployment completes.

The K3s deployment uses VM managed identities and doesn't require service principals like AKS deployments.

* Create a file called fixtures.tfvars and set the admin password for the VMs:

* All resources which are created by this terraform code will get a two-digit numeric prefix. It's intended that each user easily finds "his" resources. If a user i.e. got assigned the account "LabUser-37" he should work with the resources with the prefix "37". The central microhack team precreates the user accounts and assigns them to the different microhacks (which ususally run in parallel on the same day). So the users probably do not start with "01". Depending on what user accounts you got provided, you can use the start_index and end_index in the fixtures.tfvars file to adjust the prefixes to match your user numbers. Example: You receive the users LabUser-50 to LabUser-59, set the start_index value to 50 and the end_index value to 59. Make sure you saved your changes.

* your fixtures.tfvars file should now look like this:
```terraform
# Deployment range
start_index = 37
end_index = 39

# Security - REQUIRED
admin_user     = "<replace-with-your-own-user-name>"
admin_password = "<replace-with-your-own-secure-password>"
cluster_token  = "<replace-with-your-own-secure-cluster-token>"   # Simple string for K3s
```

```bash
terraform init # download terraform providers

terraform plan -var-file=fixtures.tfvars -out=tfplan

# have a look at the resources which will be created. There should be resource groups per participant, K3s VMs, and Azure container registry.
# after validation:

terraform apply tfplan
``` 

### Step 2: Install Ansible collections and configure workstations

After Terraform provisioning completes, run the Ansible playbook to install all prerequisite tools on the Windows workstations. Since the workstations have no public IPs, Ansible connects through **Bastion tunnels** that forward the remote WinRM port to localhost. Terraform auto-generates both the inventory (`inventory.yml`) and a helper script (`open-bastion-tunnels.sh`).

```bash
# Install required Ansible collections
cd ansible
ansible-galaxy collection install -r requirements.yml

# Open Bastion tunnels for all workstations (runs in background)
./open-bastion-tunnels.sh

# Run the Ansible playbook (via tunnels on localhost)
ansible-playbook -i inventory.yml playbook-workstation.yml \
    --extra-vars "ansible_password=<admin_password>"

# When done, stop the tunnels
./open-bastion-tunnels.sh --stop
cd ..
```

The Ansible playbook installs:
- **Git** and **Visual Studio Code** (with WSL extension) on Windows via Chocolatey
- **WSL2** runtime via Chocolatey (`wsl2` package) + **Ubuntu** distribution via `wsl --install -d Ubuntu`
- **Azure CLI**, **kubectl**, and **Helm** inside WSL Ubuntu

### What Happens After Deployment

1. **VMs are created** — K3s nodes with Ubuntu 22.04 LTS, workstation with Windows 11 24H2 Pro
2. **K3s setup scripts run automatically** via cloud-init:
   - Master node: Installs K3s server, configures networking, sets up kubeconfig
   - Worker nodes: Wait for master, then join the cluster as K3s agents
3. **Windows workstation** gets WinRM HTTPS enabled via CustomScriptExtension (for Ansible)
4. **Azure Bastion** is deployed and peered to all participant VNets
5. **Coach runs Ansible playbook** to install prerequisites on workstations (see Step 2 above)
6. **K3s cluster becomes ready** in ~5-10 minutes after VM deployment
7. **Participants connect** via Azure Bastion (RDP) to their Windows workstation

The expected output looks approximately like this depending on the start_index and end_index parameters:
```bash
Outputs:

acr_names = {
  "37" = "37mhacr"
  "38" = "38mhacr"
}
bastion_name = "mh-bastion"
bastion_resource_group = "mh-bastion"
k3s_cluster_info = {
  "37" = {
    "kubeconfig_setup" = "mkdir -p ~/.kube && scp <admin_user>@x.x.x.x:/home/<admin_user>/.kube/config ~/.kube/config && sed -i 's/127.0.0.1/x.x.x.x/g' ~/.kube/config"
    "master_ssh" = "ssh <admin_user>@x.x.x.x"
    "worker1_ssh" = "ssh <admin_user>@y.y.y.y"
    "worker2_ssh" = "ssh <admin_user>@z.z.z.z"
  }
  "38" = { ... }
}
workstation_info = {
  "37" = {
    "bastion_rdp" = "az network bastion rdp --name mh-bastion --resource-group mh-bastion --target-resource-id /subscriptions/.../37-workstation"
    "private_ip" = "10.137.2.10"
    "vm_id" = "/subscriptions/.../37-workstation"
  }
  "38" = { ... }
}
law = {
  "37" = "/subscriptions/.../resourceGroups/37-k8s-arc/providers/Microsoft.OperationalInsights/workspaces/37-law"
  "38" = "/subscriptions/.../resourceGroups/38-k8s-arc/providers/Microsoft.OperationalInsights/workspaces/38-law"
}
rg_names_arc = {
  "37" = "37-k8s-arc"
  "38" = "38-k8s-arc"
}
rg_names_onprem = {
  "37" = "37-k8s-onprem"
  "38" = "38-k8s-onprem"
}
```

**Important**: Wait 5-10 minutes after terraform completes before trying to access the K3s cluster to allow the setup scripts to finish.

## Post-Deployment - Accessing Your Environment

### 1. Connect to your Windows workstation via Bastion

Participants connect to their Windows workstation via Azure Bastion in the Azure Portal:

1. Navigate to the Azure Portal → search for **Bastion**
2. Open **mh-bastion** → click **Connect** → select your workstation VM (`<xy>-workstation`)
3. Enter the credentials provided by your coach (same `admin_user` / `admin_password` as the K3s nodes)
4. A browser-based RDP session opens to your Windows workstation

Alternatively, use the Azure CLI native client:
```bash
az network bastion rdp --name mh-bastion --resource-group mh-bastion \
    --target-resource-id <workstation-vm-resource-id>
```

### 2. Access your K3s cluster from the workstation

Once connected to the workstation, open **VS Code** → open a **WSL terminal** (Terminal → New Terminal). The K3s master node is reachable via its private IP from the workstation (same VNet):

```bash
# Set admin username (must match the admin_user value provided by your coach)
admin_user="<replace-with-admin-user>"

# The master node private IP follows the pattern 10.{100+user_number}.1.10
# For user 37: 10.137.1.10, for user 38: 10.138.1.10, etc.
master_ip="10.<100+your_number>.1.10"

# Create .kube directory if it doesn't exist
mkdir -p ~/.kube

# Copy the kubeconfig (via private IP — no public IP needed)
scp $admin_user@$master_ip:/home/$admin_user/.kube/config ~/.kube/config

# Replace localhost address with the master's private IP
sed -i "s/127.0.0.1/$master_ip/g" ~/.kube/config

# Verify
kubectl get nodes
```

### 3. Verify K3s Installation

SSH into the K3s master via Bastion tunnel (coach) or from the workstation WSL terminal:
```bash
# On master node
kubectl get nodes
systemctl status k3s

# On worker nodes
systemctl status k3s-agent
```

## Troubleshooting

### Check K3s Logs
```bash
# On master node
kubectl get nodes

systemctl status k3s

sudo journalctl -u k3s -f

# On worker nodes
systemctl status k3s-agent

sudo journalctl -u k3s-agent -f
```

### Verify Network Connectivity
```bash
# From worker to master (port 6443 should be open)
telnet <master_private_ip> 6443
```

### Reset K3s Installation (if needed)
```bash
# On master
sudo /usr/local/bin/k3s-uninstall.sh

# On worker nodes
sudo /usr/local/bin/k3s-agent-uninstall.sh
```

## Security Notes
- **RDP** access to the workstation is routed through **Azure Bastion** — no management ports are exposed to the internet
- **SSH** to K3s nodes is restricted to `VirtualNetwork` — participants SSH from the workstation (same VNet), not from the internet
- **WinRM** on the workstation is restricted to the Bastion subnet (used by the coach for Ansible provisioning via Bastion tunnels)
- VMs use password authentication (consider using SSH keys for production)
- K3s API and NodePort access is restricted to `VirtualNetwork`
- K3s runs without Traefik (disabled for flexibility)
- Docker is installed for container runtime and additional workloads

## Clean Up - After Microhack

When done with the microhack, call terraform destroy to clean up.

```bash
terraform destroy -var-file=fixtures.tfvars

# if there are remaining resources after terraform delete, use this script to remove the rest:

```

This will remove all created resources including VMs, networks, Bastion, and VNet peerings.

[To challenge 01](../challenges/challenge-01.md)

