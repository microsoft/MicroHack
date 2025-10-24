# 🚀 ODAA MH Environment Deployment Scripts

This directory contains PowerShell scripts to automate the deployment of ODAA MH environments on Azure, following the instructions from the original README.md.

## 📋 Scripts Overview

### 1. 🎯 Deploy-ODAAMHEnv.ps1

Main deployment script that automates all the manual steps from the original README.md:
- 📦 Creates Azure Resource Group
- ⚓ Deploys AKS cluster using Bicep template
- 🌐 Installs NGINX Ingress Controller
- 🔧 Configures health probes and external access

### 2. 🔄 Deploy-MultipleEnvironments.ps1

Batch deployment script for creating multiple team environments simultaneously with parallel processing capabilities.

### 3. ⚙️ Manage-Environments.ps1

Environment management script for cleanup, status checking, and maintenance operations.

## 📋 Prerequisites

Before running these scripts, ensure you have the following tools installed:
- **Azure CLI** - https://docs.microsoft.com/en-us/cli/azure/install-azure-cli
- **kubectl** - https://kubernetes.io/docs/tasks/tools/install-kubectl/
- **helm** - https://helm.sh/docs/intro/install/
- **jq** - https://stedolan.github.io/jq/download/
- **PowerShell 5.1 or later**

## Usage Examples

### Single Environment Deployment

```powershell
# Deploy a single team environment
.\Deploy-ODAAMHEnv.ps1 -ResourceGroupName "odaa-team1" -Prefix "ODAA" -Postfix "team1" -Location "germanywestcentral"

# Deploy with custom subscription
.\Deploy-ODAAMHEnv.ps1 -ResourceGroupName "odaa-prod" -Prefix "ODAA" -Postfix "prod" -Location "westeurope" -SubscriptionName "my-subscription"

# Skip login (useful when already authenticated)
.\Deploy-ODAAMHEnv.ps1 -ResourceGroupName "odaa-dev" -Prefix "ODAA" -Postfix "dev" -SkipLogin
```

### Multiple Environment Deployment

```powershell
# Deploy 5 predefined team environments
.\Deploy-MultipleEnvironments.ps1 -PredefinedTeams 5 -BaseResourceGroupName "odaa" -BasePrefix "ODAA" -Location "germanywestcentral"

# Deploy from configuration file
.\Deploy-MultipleEnvironments.ps1 -ConfigFile ".\team-configs.csv"

# Deploy with custom parallel job limit
.\Deploy-MultipleEnvironments.ps1 -PredefinedTeams 3 -BaseResourceGroupName "odaa" -BasePrefix "ODAA" -MaxParallelJobs 2
```

### Environment Management

```powershell
# List all environments
.\Manage-Environments.ps1 -Action List -ResourceGroupPattern "odaa-*"

# Check status of specific environments
.\Manage-Environments.ps1 -Action Status -ResourceGroupNames @("odaa-team1", "odaa-team2")

# Clean up all team environments
.\Manage-Environments.ps1 -Action Cleanup -ResourceGroupPattern "odaa-team*" -Confirm
```

## Configuration File Format

When using the batch deployment script with a configuration file, use the following CSV format:

```csv
ResourceGroupName,Prefix,Postfix,Location
odaa-team1,ODAA,team1,germanywestcentral
odaa-team2,ODAA,team2,germanywestcentral
odaa-team3,ODAA,team3,westeurope
odaa-workshop,ODAA,ws,northeurope
```

## Script Parameters

### Deploy-ODAAMHEnv.ps1

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| ResourceGroupName | Yes | - | Name of the Azure resource group |
| Prefix | Yes | - | Prefix for Azure resource names |
| Postfix | No | "" | Postfix for Azure resource names |
| Location | No | "germanywestcentral" | Azure region |
| SubscriptionName | No | "sub-cptdx-01" | Azure subscription name |
| SkipPrerequisites | No | False | Skip prerequisite checks |
| SkipLogin | No | False | Skip Azure login |

### Deploy-MultipleEnvironments.ps1

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| ConfigFile | Yes* | - | Path to CSV configuration file |
| PredefinedTeams | Yes* | - | Number of team environments (1-10) |
| BaseResourceGroupName | Yes* | - | Base name for resource groups |
| BasePrefix | Yes* | - | Base prefix for resources |
| Location | No | "germanywestcentral" | Azure region |
| SubscriptionName | No | "sub-cptdx-01" | Azure subscription name |
| MaxParallelJobs | No | 3 | Maximum parallel deployments |

*Either ConfigFile OR PredefinedTeams parameters are required

## Important Notes

1. **VNet CIDR Configuration**: After deployment, ensure that the CIDR of the created VNet is added to the Oracle NSG as mentioned in the original instructions.

2. **External IP Assignment**: The NGINX ingress controller external IP may take a few minutes to be assigned. The script will wait and retry, but you can check manually later if needed:
   ```powershell
   kubectl get service -n ingress-nginx
   ```

3. **Resource Naming**: The scripts use the pattern `{Prefix}{Postfix}` for AKS cluster names and other resources.

4. **Parallel Deployments**: When using the batch deployment script, be mindful of Azure subscription limits and quotas.

5. **Authentication**: The scripts handle Azure authentication automatically, but you can skip the login step if you're already authenticated.

## Troubleshooting

### Common Issues

1. **Prerequisites Not Found**: Install the required tools (Azure CLI, kubectl, helm, jq) before running the scripts.

2. **Authentication Errors**: Ensure you have proper permissions in the Azure subscription and that the subscription name is correct.

3. **Resource Quota Limits**: Check your Azure subscription quotas if deployments fail due to resource limits.

4. **Bicep Template Not Found**: Ensure you're running the scripts from the resources directory where the `infra/bicep/main.bicep` file is located.

### Getting Help

- Use the `-Verbose` parameter for detailed execution logs
- Check the Azure portal for resource deployment status
- Review AKS cluster logs if Kubernetes operations fail
- Verify network connectivity and firewall settings

## Cleanup

To clean up deployed resources:

```powershell
# Delete a single resource group
az group delete --name "odaa-team1" --yes --no-wait

# Use the management script for bulk cleanup
.\Manage-Environments.ps1 -Action Cleanup -ResourceGroupPattern "odaa-*"
```

**Warning**: Resource group deletion is irreversible and will remove all contained resources.
