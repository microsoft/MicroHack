# Deploy Azure Arc Jumpstart Lab Environments

This folder contains scripts to deploy lab environments for the Sovereign Cloud MicroHack using Azure Arc Jumpstart.

## Overview

For Challenge 6 (Operating a Sovereign Hybrid Cloud with Azure Arc & Azure Local), we leverage the official Azure Arc Jumpstart environments rather than creating custom templates. This ensures:

- **Maintained templates** - Arc Jumpstart is actively maintained by Microsoft
- **Latest features** - Always uses the newest Azure Arc and Azure Local capabilities
- **Validated configurations** - Tested and proven deployment patterns
- **Comprehensive documentation** - Extensive guides available

## Available Environments

### 1. ArcBox for IT Pros
A pre-packaged Azure Arc sandbox environment with nested VMs onboarded to Azure Arc.

**Features:**
- Multiple Arc-enabled servers (Windows and Linux)
- Pre-configured Azure Arc extensions
- Log Analytics workspace integration
- Azure Policy integration

**Requirements:**
- 8 vCPUs
- ~30 minutes deployment time

**Deployment:**
```powershell
.\deploy-arcbox.ps1 -ResourceGroupName "rg-arcbox-shared" -Location "swedencentral"
```

**Cost**

ArcBox for ITPro cost is approximately 7 USD per day. We recommend setting it up the week before the event, so for example 5 days before the event would result in a cost between 30-40 USD.

### 2. LocalBox
Azure Local environment simulating an on-premises private cloud.

**Features:**
- Virtualized Azure Local cluster
- Arc Resource Bridge integration
- VM deployment capabilities via Azure Portal
- AKS on Azure Local support

**Requirements:**
- 32 vCPUs (Standard_E32s_v6 recommended)
- ~4-6 hours deployment time

**Deployment:**
```powershell
.\deploy-localbox.ps1 -ResourceGroupName "rg-localbox-shared" -Location "swedencentral"
```

**Cost**

LocalBox cost is approximately 100-110 USD per day. We recommend setting it up the week before the event, so for example 5 days before the event would result in a cost between 5-600 USD.

## Arc Jumpstart Resources

- **ArcBox Documentation**: https://jumpstart.azure.com/azure_jumpstart_arcbox
- **LocalBox Documentation**: https://jumpstart.azure.com/azure_jumpstart_localbox
- **GitHub Repository**: https://github.com/microsoft/azure_arc

## Usage Instructions

### Step 1: Verify Prerequisites
Before deploying, ensure you have:
1. Sufficient vCPU quotas (run `../subscription-preparations/2-vcpu-quotas.ps1`)
2. Required resource providers registered (run `../subscription-preparations/1-resource-providers.ps1`)
3. Azure CLI and Az PowerShell modules installed

### Step 2: Deploy Environment
Choose the appropriate deployment script:

```powershell
# For Arc-enabled servers challenge
.\deploy-arcbox.ps1 -ResourceGroupName "rg-arcbox-shared" -Location "swedencentral"

# For Azure Local challenge
.\deploy-localbox.ps1 -ResourceGroupName "rg-localbox-shared" -Location "swedencentral"
```

### Step 3: Wait for Deployment
Deployments can take 2-6 hours depending on the environment. Monitor progress in:
- Azure Portal > Resource Groups > Deployments
- The deployment script output

### Step 4: Access the Environment
Once deployed:
- Use Azure Bastion to connect to the Client VM
- All Arc resources will be visible in the Azure Portal
- Follow Challenge 6 walkthrough for lab exercises

## Notes

- **Shared Environment**: For MicroHack events, typically one ArcBox and one LocalBox instance is shared among participants
- **Resource Costs**: These environments consume significant Azure resources; clean up after the event
- **Deployment Time**: Plan for deployment time when scheduling your MicroHack
