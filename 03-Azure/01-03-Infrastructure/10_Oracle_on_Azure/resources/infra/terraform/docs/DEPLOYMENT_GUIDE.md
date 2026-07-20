# Deployment Guide - Oracle on Azure Infrastructure

## Overview

This Terraform configuration provisions isolated AKS environments across multiple Azure subscriptions with Oracle Database@Azure networking integration. The infrastructure supports **unlimited users** by using a two-step deployment process.

## Architecture Changes (v2.0)

**Previous limitation:** Helm provider constraint limited deployment to exactly 5 users (1:1 subscription-to-cluster mapping)

**New approach:** 
- Terraform manages infrastructure (AKS clusters, networking, RBAC)
- PowerShell script deploys ingress controllers post-provisioning
- **No limit on user count** - scale to 10, 20, 50+ users

## Prerequisites

### Required Tools
- **Terraform** v1.x or higher
- **Azure CLI** (for authentication only)
- **Helm** v3.x or higher
- **kubectl** CLI

### Authentication
```powershell
# Login to Azure
az login

# Set the subscription context (if needed)
az account set --subscription <subscription-id>
```

## Configuration

### 1. Configure Variables

Edit `terraform.tfvars`:

```hcl
# Number of users to provision (no limit!)
user_count = 10  # Change to any number

# Microhack event name
microhack_event_name = "mhtest1"

# Azure subscriptions for round-robin deployment
subscription_targets = [
  { subscription_id = "556f9b63-...", tenant_id = "f71980b2-..." },  # Slot 0
  { subscription_id = "a0844269-...", tenant_id = "f71980b2-..." },  # Slot 1
  { subscription_id = "b1658f1f-...", tenant_id = "f71980b2-..." },  # Slot 2
  { subscription_id = "9aa72379-...", tenant_id = "f71980b2-..." },  # Slot 3
  { subscription_id = "98525264-...", tenant_id = "f71980b2-..." },  # Slot 4
]

# ODAA subscription
odaa_subscription_id = "4aecf0e8-..."
odaa_tenant_id       = "f71980b2-..."

# Service principal credentials (for ODAA operations)
client_id     = "8a9f736e-..."
client_secret = "aW18Q~..."
```

### 2. User Scaling Guidelines

- **5 subscriptions**: Supports 5, 10, 15, 20... users (multiples of 5 recommended)
- **10 subscriptions**: Supports 10, 20, 30... users
- Users are distributed round-robin across subscriptions
- Each user gets an isolated AKS cluster with dedicated networking

## Deployment Steps

### Step 1: Initialize Terraform

```powershell
terraform init
```

### Step 2: Review Plan

```powershell
terraform plan
```

Expected resources (for 10 users):
- 10 AKS clusters
- 10 VNets with peering to ODAA shared network
- 40 Private DNS zones (4 per cluster)
- 10 Log Analytics workspaces
- 10 Entra ID users with RBAC assignments
- 1 shared ODAA network

### Step 3: Apply Infrastructure

```powershell
terraform apply -auto-approve
```

**Duration:** ~15-20 minutes for 10 clusters

### Step 4: Deploy Ingress Controllers

After Terraform completes successfully, run the deployment script:

```powershell
.\scripts\deploy-ingress-controllers.ps1
```

**What it does:**
- Reads cluster kubeconfig directly from Terraform output (no `az login` needed)
- Deploys ingress-nginx v4.14.0 to each cluster
- Configures Azure Load Balancer health probes
- Verifies deployment success
- Provides detailed progress output

**Duration:** ~2-3 minutes for 10 clusters

**Example output:**
```
╔══════════════════════════════════════════════════════════════════════════════╗
║                                                                              ║
║          AKS Ingress Controller Deployment Automation                        ║
║                                                                              ║
╚══════════════════════════════════════════════════════════════════════════════╝

==> Checking prerequisites...
  ✓ Helm CLI found: v3.15.0
  ✓ kubectl found
  ✓ Terraform found

==> Reading Terraform outputs...
  ✓ Found 10 AKS cluster(s)

==> Processing 10 cluster(s)...

  Processing cluster: user00
    → Testing cluster connectivity...
    ✓ Connected to cluster
    → Adding/updating ingress-nginx helm repository...
    → Deploying ingress-nginx v4.14.0...
    ✓ Ingress controller deployed successfully
    → Verifying deployment...
    ✓ Found 1 running pod(s) in namespace 'ingress-nginx'

  [... 8 more clusters ...]

═══════════════════════════════════════════════════════════════════════════════
Deployment Summary:
═══════════════════════════════════════════════════════════════════════════════

  Total clusters processed: 10
  Successful: 10

✓ All ingress controllers deployed successfully!
```

## Advanced Usage

### Custom Helm Version

```powershell
.\scripts\deploy-ingress-controllers.ps1 -HelmVersion "4.15.0"
```

### Custom Namespace

```powershell
.\scripts\deploy-ingress-controllers.ps1 -Namespace "my-ingress"
```

### Uninstall Ingress Controllers

```powershell
.\scripts\deploy-ingress-controllers.ps1 -Uninstall
```

## Verification

### Check AKS Clusters

```powershell
# View all clusters
terraform output aks_clusters

# Get specific cluster info
terraform output -json aks_clusters | ConvertFrom-Json | Select-Object -ExpandProperty user00
```

### Verify Ingress Controllers

```powershell
# Connect to a cluster (example: user00)
az aks get-credentials --name aks-user00 --resource-group aks-user00 --overwrite-existing

# Check ingress controller pods
kubectl get pods -n ingress-nginx

# Check ingress controller service
kubectl get svc -n ingress-nginx
```

### View User Credentials

```powershell
# Display all user credentials (sensitive output)
terraform output -json entra_id_deployment_users

# View credentials file
Get-Content user_credentials.txt
```

## Scaling Operations

### Scale Up (Add Users)

1. Update `terraform.tfvars`:
   ```hcl
   user_count = 15  # Increase from 10 to 15
   ```

2. Apply changes:
   ```powershell
   terraform apply -auto-approve
   ```

3. Deploy ingress to new clusters:
   ```powershell
   .\scripts\deploy-ingress-controllers.ps1
   ```

### Scale Down (Remove Users)

1. Update `terraform.tfvars`:
   ```hcl
   user_count = 8  # Decrease from 10 to 8
   ```

2. Apply changes:
   ```powershell
   terraform apply -auto-approve
   ```

The script automatically handles removed clusters.

## Cleanup

### Remove Ingress Controllers Only

```powershell
.\scripts\deploy-ingress-controllers.ps1 -Uninstall
```

### Destroy All Infrastructure

```powershell
terraform destroy -auto-approve
```

**Warning:** This will delete:
- All AKS clusters
- All VNets and peerings
- All Entra ID users
- All RBAC assignments
- ODAA shared network (if no other resources depend on it)

## Outputs

### Available Terraform Outputs

```powershell
# All AKS clusters with details
terraform output aks_clusters

# ODAA shared network info
terraform output odaa_network

# VNet peering connections
terraform output vnet_peering_connections

# Deployment summary
terraform output deployment_summary

# User credentials (sensitive)
terraform output entra_id_deployment_users

# Kubeconfigs for automation (sensitive)
terraform output aks_kubeconfigs
```

## Troubleshooting

### Terraform Issues

**Problem:** "Permission denied" errors during apply
```powershell
# Solution: Verify Azure CLI authentication
az account show
az account list
```

**Problem:** "Provider not found" errors
```powershell
# Solution: Reinitialize Terraform
terraform init -upgrade
```

### Script Issues

**Problem:** "Helm not found"
```powershell
# Solution: Install Helm
winget install Helm.Helm
```

**Problem:** "Cannot connect to cluster"
```powershell
# Solution: Verify AKS cluster is running
az aks show --name aks-user00 --resource-group aks-user00 --query provisioningState
```

**Problem:** Script fails on specific cluster
```powershell
# Solution: Check terraform output
terraform output -json aks_kubeconfigs | ConvertFrom-Json | Select-Object -ExpandProperty user00

# Manually deploy to that cluster
$env:KUBECONFIG = "path-to-kubeconfig.yaml"
helm upgrade --install nginx-quick ingress-nginx/ingress-nginx --version 4.14.0 --namespace ingress-nginx --create-namespace
```

## Security Notes

### Sensitive Files (Excluded from Git)

The `.gitignore` file excludes:
- `*.tfvars` (contains subscription IDs and secrets)
- `*.tfstate` (contains full infrastructure state)
- `kubeconfig*` (contains cluster credentials)
- `user_credentials.txt` (contains user passwords)
- `scripts/logs/` (may contain sensitive output)

**Important:** Never commit these files to version control!

### Kubeconfig Handling

The deployment script:
- Creates temporary kubeconfig files in `$env:TEMP`
- Uses unique filenames to avoid conflicts
- Automatically deletes temp files after use
- Never writes kubeconfig to the repo directory

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Terraform Apply                             │
│  Provisions: AKS Clusters, VNets, RBAC, DNS, Users                  │
└────────────────────────────┬────────────────────────────────────────┘
                             │
                             ▼
                    terraform output aks_kubeconfigs
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│              deploy-ingress-controllers.ps1                         │
│  Reads kubeconfig from Terraform → Deploys Helm charts              │
└─────────────────────────────────────────────────────────────────────┘
                             │
                             ▼
              ┌──────────────┴──────────────┐
              ▼                             ▼
    ┌─────────────────┐          ┌─────────────────┐
    │  AKS user00     │   ...    │  AKS user09     │
    │  + ingress-nginx│          │  + ingress-nginx│
    └─────────────────┘          └─────────────────┘
```

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Review Terraform/Helm logs in `scripts/logs/`
3. Validate Azure permissions and quotas
4. Consult the SCALING_PROPOSAL.md document for architecture details

## License

This project is licensed under the MIT License.
