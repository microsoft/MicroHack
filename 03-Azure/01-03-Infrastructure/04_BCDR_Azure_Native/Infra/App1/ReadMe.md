# Deploy App1 - BCDR MicroHack Infrastructure

## Quick Start (Recommended)

Use the automated setup script for the easiest deployment experience:

```bash
# Interactive mode - prompts for all required values
./setup.sh

# Non-interactive with all parameters
./setup.sh -p mh01 -w 'YourSecureP@ssw0rd123!' -y
```

## Setup Script Options

```
Usage: ./setup.sh [OPTIONS]

OPTIONS:
    -p, --prefix PREFIX         Deployment prefix (e.g., mh01, mh02)
    -w, --password PASSWORD     VM admin password
    -s, --source-location LOC   Source region (default: germanywestcentral)
    -t, --target-location LOC   Target region (default: swedencentral)
    --skip-validation           Skip prerequisites validation
    --use-arm                   Use ARM template instead of Bicep
    -y, --yes                   Auto-approve deployment (no confirmation)
    --verify-only               Only verify an existing deployment
    --cleanup                   Delete all deployed resources
    -h, --help                  Show help message
```

## What the Setup Script Does

1. **Prerequisites Validation** - Checks Azure CLI, authentication, RBAC permissions, and resource providers
2. **Parameter Configuration** - Validates and collects deployment prefix and VM password
3. **Infrastructure Deployment** - Deploys all resources using Bicep/ARM templates
4. **Post-Deployment Verification** - Confirms all resources were created successfully

## Manual Deployment Options

### Option 1: PowerShell (Bicep)

```powershell
New-AzSubscriptionDeployment `
    -Name "MH-Demo-Env-Deployment" `
    -Location "germanywestcentral" `
    -TemplateFile ".\deploy.bicep" `
    -parDeploymentPrefix "mh" `
    -TemplateParameterFile ".\main.parameters.json" `
    -WarningAction Ignore
```

### Option 2: Azure CLI (Bicep)

```bash
az deployment sub create \
    --name "MH-Demo-Env-Deployment" \
    --location "germanywestcentral" \
    --template-file deploy.bicep \
    --parameters @main.parameters.json \
    --parameters parDeploymentPrefix=mh01 vmAdminPassword='YourPassword!'
```

### Option 3: Azure CLI (ARM)

```bash
az deployment sub create \
    --name "MH-Demo-Env-Deployment" \
    --location "germanywestcentral" \
    --template-file deploy.json \
    --parameters @main.parameters.json \
    --parameters parDeploymentPrefix=mh01 vmAdminPassword='YourPassword!'
```

## Cleanup

To remove all deployed resources:

```bash
./setup.sh --cleanup -p mh01
```

Or manually:

```bash
az group delete --name mh01-source-germanywestcentral-rg --yes
az group delete --name mh01-target-swedencentral-rg --yes
```
