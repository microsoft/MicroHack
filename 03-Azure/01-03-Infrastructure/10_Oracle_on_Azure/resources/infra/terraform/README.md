# Oracle on Azure - Terraform Configuration

This directory contains Terraform configurations that correspond to the Bicep templates for deploying Oracle Database on Autonomous Azure (ODAA) infrastructure.

## Overview

The Terraform configuration creates the following resources across multiple Azure subscriptions with automatic VNet peering:

### Multi-Subscription Architecture
- **AKS Subscription**: Contains AKS cluster and related resources
- **ODAA Subscription**: Contains Oracle Database resources
- **Cross-Subscription VNet Peering**: Automatic bidirectional peering between AKS and ODAA networks

### AKS Module (`modules/aks/`)
- **Resource Group**: Container for AKS resources (AKS subscription)
- **Log Analytics Workspace**: Monitoring and logging for AKS
- **Virtual Network**: Network infrastructure for AKS
- **Subnet**: Dedicated subnet for AKS with proper delegation
- **AKS Cluster**: Managed Kubernetes cluster with:
  - System node pool (2 nodes, auto-scaling 1-2)
  - User node pool (2 nodes, auto-scaling 1-2)
  - Azure CNI networking
  - Workload Identity enabled
  - Azure Policy addon
  - Container monitoring enabled
- **RBAC Assignments**: Automatic role assignments for deployment group

### Entra ID Module (`modules/entra-id/`)
- **Security Group**: Entra ID group for users with AKS deployment rights
- **RBAC Integration**: Automatic assignment of Azure roles for AKS access

### VNet Peering Module (`modules/vnet-peering/`)
- **Cross-Subscription Peering**: Bidirectional VNet peering between AKS and ODAA
- **Network Connectivity**: Enables communication between AKS pods and Oracle Database
- **Automatic Configuration**: Handles cross-subscription peering complexities

### ODAA Module (`modules/odaa/`)
- **Resource Group**: Container for ODAA resources
- **Virtual Network**: Network infrastructure for ODAA
- **Subnet**: Dedicated subnet with Oracle delegation
- **Oracle Autonomous Database**: Oracle Database on Azure with:
  - 2 ECPU compute
  - 20GB storage
  - Enterprise Edition
  - 23ai database version
  - OLTP workload

### DNS Module (`modules/dns/`)

- **Private DNS Zone**: For main ODAA FQDN
- **Private DNS Zone**: For ODAA applications FQDN
- **DNS A Records**: Pointing to the specified IP address
- **VNet Links**: Linking DNS zones to the AKS virtual network

### Ingress NGINX Module (`modules/ingress-nginx/`)
- **Helm Deployment**: Installs the upstream ingress-nginx chart in each AKS cluster
- **Namespace Management**: Creates the `ingress-nginx` namespace when needed
- **Azure Load Balancer Annotation**: Sets the health probe path expected by Azure (`/healthz`)
- **Service Discovery**: Exposes the controller Service external IP via Terraform outputs

## Prerequisites

### 1. Install Required Tools

```powershell
# Install Terraform
winget install Hashicorp.Terraform

# Install Azure CLI (if not already installed)
winget install Microsoft.AzureCLI
```

### 2. Azure Authentication

```powershell
# Login to Azure
az login

# Set the subscription (if you have multiple)
az account set --subscription "your-subscription-id"
```

### 3. Register Required Resource Providers

```powershell
# Register Oracle Database provider
az provider register --namespace Oracle.Database

# Check registration status
az provider show --namespace Oracle.Database --query "registrationState"
```

## Configuration

### 1. Copy and Configure Variables

```powershell
# Copy the example variables file
Copy-Item terraform.tfvars.example terraform.tfvars

# Edit the terraform.tfvars file with your specific values
```

### 2. Required Variables

Update `terraform.tfvars` with your values:

```hcl
# Environment Configuration
environment = "dev"
location    = "Germany West Central"

# AKS Configuration
aks_prefix   = "aks-oracle"
aks_postfix  = "001"
aks_cidr     = "10.1.0.0"
aks_vm_size  = "Standard_D8ds_v5"

# ODAA Configuration
odaa_prefix   = "odaa"
odaa_postfix  = "1"
odaa_location = "Germany West Central"
odaa_cidr     = "10.0.0.0"

# Security Configuration
adb_admin_password = "YourSecurePassword123!"  # Must be 12-30 characters

# DNS Configuration
fqdn_odaa      = "eqsmjgp2.adb.eu-frankfurt-1.oraclecloud.com"
fqdn_odaa_app  = "eqsmjgp2.adb.eu-frankfurt-1.oraclecloudapps.com"
fqdn_odaa_ipv4 = "10.0.1.165"
```

## Deployment

### 1. Initialize Terraform

```powershell
terraform init
```

### 2. Validate Configuration

```powershell
terraform validate
```

### 3. Plan Deployment

```powershell
terraform plan
```

### 4. Apply Configuration

```powershell
terraform apply -auto-approve
```

## Post-Deployment

After successful deployment, you can:

### 1. Add Users to Deployment Group

```powershell
# Get the group object ID from Terraform outputs
$GroupId = (terraform output -json entra_id_deployment_group | ConvertFrom-Json).object_id

# Add users to the deployment group (replace with actual user object IDs)
az ad group member add --group $GroupId --member-id <USER_OBJECT_ID>
```

### 2. Connect to AKS Cluster

```powershell
# Get AKS credentials (user must be in deployment group)
az aks get-credentials --resource-group <aks-resource-group> --name <aks-cluster-name>

# Verify connection
kubectl get nodes
kubectl auth can-i "*" "*" --all-namespaces
```

### 3. Verify Private DNS Resolution

```powershell
# Test DNS resolution from AKS pods
kubectl run dns-test --image=busybox --rm -it --restart=Never -- nslookup <fqdn-odaa>
```

## Outputs

The configuration provides the following outputs:

- `aks_cluster_id`: The ID of the AKS cluster
- `aks_cluster_name`: The name of the AKS cluster
- `aks_vnet_id`: The ID of the AKS virtual network
- `odaa_adb_id`: The ID of the Oracle Autonomous Database
- `odaa_vnet_id`: The ID of the ODAA virtual network
- `private_dns_zones`: Information about created private DNS zones
- `ingress_nginx_controllers`: Release name, namespace, annotations, and external IP for each ingress controller

## Troubleshooting

### Common Issues

1. **Oracle.Database provider not registered**
   ```powershell
   az provider register --namespace Oracle.Database
   ```

2. **Insufficient permissions**
   - Ensure you have Contributor or higher permissions
   - Ensure you can register resource providers

3. **AKS node provisioning issues**
   - Check regional availability for the specified VM size
   - Verify subnet CIDR doesn't conflict with existing networks

### Cleanup

To destroy all resources:

```powershell
terraform destroy -auto-approve
```

## Module Structure

```
terraform/
├── main.tf                    # Main configuration
├── variables.tf               # Variable definitions
├── providers.tf              # Provider configuration
├── versions.tf               # Terraform version constraints
├── terraform.tfvars.example  # Example variable values
├── README.md                 # This file
└── modules/
    ├── aks/                  # AKS module
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── odaa/                 # ODAA module
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    └── dns/                  # DNS module
        ├── main.tf
        ├── variables.tf
        ├── data.tf
        └── outputs.tf
```

## Security Considerations

- The `adb_admin_password` is marked as sensitive
- Store the `terraform.tfvars` file securely and don't commit it to version control
- Consider using Azure Key Vault for sensitive values
- Review and adjust network security groups as needed

## Correspondence with Bicep Templates

This Terraform configuration mirrors the functionality of the original Bicep templates:

| Bicep File | Terraform Module | Purpose |
|------------|------------------|---------|
| `bicep/aks/main.bicep` | `modules/aks/` | AKS cluster deployment |
| `bicep/aks/aks.bicep` | `modules/aks/main.tf` | AKS resources |
| `bicep/odaa/main.bicep` | `modules/odaa/` | ODAA deployment |
| `bicep/odaa/adb.bicep` | `modules/odaa/main.tf` | Oracle DB resources |
| `bicep/dns.bicep` | `modules/dns/` | Private DNS zones |

## Support

For issues related to:
- **Terraform**: Check [Terraform documentation](https://developer.hashicorp.com/terraform/docs)
- **Azure Provider**: Check [AzureRM Provider documentation](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- **Oracle Database on Azure**: Check [Oracle Database on Azure documentation](https://docs.oracle.com/en/cloud/paas/database-dbaas-cloud/database-on-azure/)