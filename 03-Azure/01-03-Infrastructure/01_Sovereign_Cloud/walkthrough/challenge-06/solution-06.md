# Walkthrough Challenge 6 - Operating a Sovereign Hybrid Cloud with Azure Arc & Azure Local

[Previous Challenge Solution](../challenge-05/solution-05.md) - **[Home](../../Readme.md)**

Duration: 60-90 minutes

💡 **In this challenge, you will operate a sovereign hybrid cloud environment combining Azure Local and Azure Arc. You'll learn how to apply consistent governance, security, and management across on-premises sovereign infrastructure and Azure.**

This challenge uses the Azure Arc Jumpstart environments:
- **ArcBox for IT Pros** - Provides Arc-enabled servers in a sandbox environment
- **LocalBox** - Simulates an Azure Local on-premises environment

---

## Prerequisites

Please ensure that you successfully verified the [General prerequisites](../../README.md#general-prerequisites) before continuing with this challenge.

**Additional requirements for this challenge:**
- Access to a pre-deployed ArcBox/LocalBox environment (shared lab or individual deployment)
- Azure CLI installed and logged in (`az login`)
- Contributor or Owner permissions on the resource group containing the hybrid resources

> [!NOTE]
> ArcBox and LocalBox are typically deployed by the workshop facilitator due to resource requirements and deployment time. If deploying yourself, see the [LocalBox deployment guide](https://jumpstart.azure.com/azure_jumpstart_localbox).

---

## Lab Environment Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Azure Cloud                                  │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────────┐  │
│  │   Azure Policy  │  │   Defender for  │  │   Azure Monitor     │  │
│  │   & Machine     │  │   Cloud         │  │   & Log Analytics   │  │
│  │   Configuration │  │                 │  │                     │  │
│  └────────┬────────┘  └────────┬────────┘  └──────────┬──────────┘  │
│           │                    │                      │             │
│  ┌────────┴────────────────────┴──────────────────────┴──────────┐  │
│  │                    Azure Resource Manager                      │  │
│  └────────┬────────────────────────────────────────────┬─────────┘  │
│           │                                            │            │
│  ┌────────┴────────┐                          ┌────────┴─────────┐  │
│  │  Arc-enabled    │                          │  Azure Local     │  │
│  │  Servers        │                          │  Instance        │  │
│  │  (ArcBox)       │                          │  (LocalBox)      │  │
│  └────────┬────────┘                          └────────┬─────────┘  │
└───────────┼────────────────────────────────────────────┼────────────┘
            │              Azure Arc                      │
┌───────────┴────────────────────────────────────────────┴────────────┐
│                    On-Premises / Sovereign Private Cloud             │
│  ┌─────────────────────────┐    ┌───────────────────────────────┐   │
│  │  Nested VMs             │    │  Azure Local Cluster          │   │
│  │  - Windows Server       │    │  - Arc Resource Bridge        │   │
│  │  - Ubuntu Linux         │    │  - Custom Location            │   │
│  │  - SQL Server           │    │  - VM Gallery Images          │   │
│  └─────────────────────────┘    └───────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Task 1: Explore Hybrid Resources in Azure Portal

💡 **Familiarize yourself with the ArcBox and LocalBox resources in Azure Portal to understand the hybrid architecture.**

### 1.1 Navigate to the ArcBox Resource Group

1. Sign in to the [Azure Portal](https://portal.azure.com)
2. Navigate to **Resource groups**
3. Locate and select the ArcBox resource group (e.g., `rg-arcbox`)
4. Review the resources deployed:
   - **Arc-enabled servers** - Machines connected to Azure via the Connected Machine Agent
   - **Log Analytics workspace** - Central logging for all hybrid resources
   - **Virtual Network** - Network infrastructure for the sandbox

💥 **Explore the Arc-enabled servers:**

1. In the resource group, filter by type **Azure Arc machines** (or search for "Machine - Azure Arc")
2. Click on one of the Arc-enabled servers (e.g., `ArcBox-Ubuntu-01`)
3. Review the **Overview** blade:
   - Operating system and version
   - Agent status and version
   - Resource location (Azure region for metadata)
   - Machine location (actual physical location)
4. Navigate to **Properties** to see detailed machine information
5. Check **Extensions** to see installed Azure extensions

🔑 **Key insight:** Arc-enabled servers appear as Azure resources with resource IDs, allowing you to apply Azure management constructs (tags, RBAC, policies) to on-premises machines.

### 1.2 Explore LocalBox Resources (if available)

1. Navigate to the LocalBox resource group (e.g., `rg-localbox`)
2. Locate the **Azure Local** instance resource
3. Review the following connected resources:
   - **Arc Resource Bridge** - Connects Azure Local to Azure
   - **Custom Location** - Represents the on-premises location for VM deployment
   - **Gallery Images** - VM images available for deployment

> [!IMPORTANT]
> Azure Local uses Arc Resource Bridge to enable Azure Arc VM management. This allows you to deploy and manage VMs on Azure Local directly from the Azure Portal.

---

## Task 2: Governance via Azure Policy and Machine Configuration

💡 **Assign and verify an Azure Policy that uses Machine Configuration to audit security settings on Arc-enabled Linux servers.**

### 2.1 Understanding Machine Configuration

Azure Machine Configuration (formerly Guest Configuration) extends Azure Policy inside the operating system. It uses Desired State Configuration (DSC) to:
- **Audit** OS-level settings (passwords, services, registry, files)
- **Enforce/Remediate** configurations when non-compliant

This provides "policy as code" governance across your hybrid environment, similar to Group Policy but managed through Azure.

### 2.2 Assign the Linux Security Baseline Policy

💥 **Assign a built-in policy to audit Linux security baseline compliance:**

**Option A: Azure Portal**

1. Navigate to **Azure Policy** in the Azure Portal
2. Select **Definitions** in the left menu
3. Search for: `Linux machines should meet requirements for the Azure compute security baseline`
4. Click on the policy definition to view details
5. Click **Assign**
6. Configure the assignment:
   - **Scope**: Select the resource group containing your Arc-enabled servers
   - **Assignment name**: `Linux Security Baseline - Arc Servers`
   - **Policy enforcement**: Enabled
7. Click **Review + create**, then **Create**

**Option B: Azure CLI**

```bash
# Set variables
RESOURCE_GROUP="rg-arcbox"
SUBSCRIPTION_ID=$(az account show --query id -o tsv)

# Get the policy definition ID
POLICY_DEFINITION_ID="/providers/Microsoft.Authorization/policyDefinitions/fc9b3da7-8347-4380-8e70-0a0361d8dedd"

# Assign the policy to the resource group
az policy assignment create \
  --name "linux-security-baseline-arc" \
  --display-name "Linux Security Baseline - Arc Servers" \
  --policy $POLICY_DEFINITION_ID \
  --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP" \
  --mi-system-assigned \
  --location "westeurope"
```

### 2.3 Assign SSH Security Policy

💥 **Assign a policy to audit SSH key authentication:**

```bash
# SSH key authentication policy
POLICY_DEFINITION_ID="/providers/Microsoft.Authorization/policyDefinitions/630c64f9-8b6b-4c64-b511-6544ceff6fd6"

az policy assignment create \
  --name "linux-ssh-key-auth" \
  --display-name "Linux SSH Key Authentication Required" \
  --policy $POLICY_DEFINITION_ID \
  --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP" \
  --mi-system-assigned \
  --location "westeurope"
```

### 2.4 Verify Policy Compliance

1. Wait 15-30 minutes for the initial compliance scan (or trigger manually)
2. Navigate to **Azure Policy** > **Compliance**
3. Filter by the scope (your resource group)
4. Review the compliance state:
   - **Compliant** - Resource meets the policy requirements
   - **Non-compliant** - Resource fails one or more checks
   - **Not started** - Evaluation hasn't completed yet

💥 **To trigger an on-demand compliance scan:**

```bash
# Trigger policy evaluation for the resource group
az policy state trigger-scan --resource-group $RESOURCE_GROUP
```

5. Click on a non-compliant resource to view detailed compliance reasons
6. Navigate to the Arc-enabled server > **Machine Configuration** to see individual configuration status

🔑 **Key insight:** Azure Policy with Machine Configuration provides unified compliance visibility across Azure VMs and Arc-enabled servers. This is essential for maintaining sovereign compliance requirements across hybrid environments.

---

## Task 3: Deploy a VM on Azure Local via Azure Portal

💡 **Use Azure Arc VM management to deploy a virtual machine on your Azure Local cluster directly from the Azure Portal.**

> [!NOTE]
> This task requires access to a LocalBox environment with Arc Resource Bridge configured. If you don't have access, review the steps to understand the process.

### 3.1 Navigate to Azure Local VM Management

1. In the Azure Portal, navigate to your **Azure Local** instance
2. Select **Virtual machines** in the left menu
3. Click **+ Create** to start the VM creation wizard

### 3.2 Configure the Virtual Machine

💥 **Basic settings:**

1. **Subscription**: Select your subscription
2. **Resource group**: Create new or use existing
3. **Virtual machine name**: `sovereign-vm-01`
4. **Custom location**: Select the custom location for your Azure Local cluster
5. **Image**: Select an available gallery image (e.g., Windows Server 2022)
6. **Virtual processor count**: 2
7. **Memory (GB)**: 4

💥 **Administrator account:**

1. **Username**: `localadmin`
2. **Password**: Create a strong password

💥 **Networking:**

1. **Network interface**: Create or select existing logical network
2. Configure as needed for your environment

### 3.3 Review and Create

1. Review all settings
2. Click **Create** to deploy the VM

💥 **Monitor the deployment:**

```bash
# Check VM deployment status (if using CLI)
az stack-hci-vm show \
  --name "sovereign-vm-01" \
  --resource-group $RESOURCE_GROUP
```

### 3.4 Validate VM Deployment

1. Navigate to the VM resource in Azure Portal
2. Verify the VM is running
3. Check that the VM appears under the **Custom Location**
4. Review the VM properties and available operations

🔑 **Key insight:** Azure Arc VM management enables self-service VM provisioning on Azure Local using familiar Azure tools and RBAC. This allows organizations to maintain data sovereignty by keeping workloads on-premises while benefiting from Azure management capabilities.

---

## Task 4: Security Monitoring with Microsoft Defender for Cloud

💡 **Enable Microsoft Defender for Cloud and review security recommendations for your Arc-enabled resources.**

### 4.1 Enable Defender for Servers

💥 **Enable Defender for Servers on your subscription:**

**Option A: Azure Portal**

1. Navigate to **Microsoft Defender for Cloud**
2. Select **Environment settings** in the left menu
3. Expand your tenant and select your subscription
4. Under **Defender plans**, locate **Servers**
5. Toggle to **On** (select Plan 1 or Plan 2 based on requirements)
6. Click **Save**

**Option B: Azure CLI**

```bash
# Enable Defender for Servers Plan 1
az security pricing create \
  --name VirtualMachines \
  --tier Standard

# Or enable Plan 2 for additional features
az security pricing create \
  --name VirtualMachines \
  --tier Standard \
  --subplan P2
```

### 4.2 Review Security Posture

1. Navigate to **Microsoft Defender for Cloud** > **Overview**
2. Review the **Secure Score** for your environment
3. Click on **Recommendations** to see security recommendations

💥 **Filter for Arc-enabled servers:**

1. In **Recommendations**, use filters:
   - **Resource type**: `Microsoft.HybridCompute/machines`
   - **Environment**: All
2. Review recommendations specific to your Arc-enabled servers

### 4.3 Explore Common Recommendations for Arc-enabled Servers

You may see recommendations such as:

| Recommendation | Severity | Description |
|----------------|----------|-------------|
| Guest configuration extension should be installed | High | Required for Machine Configuration policies |
| System updates should be installed | High | OS patches are available |
| Endpoint protection should be installed | High | Antimalware solution needed |
| Log Analytics agent should be installed | Medium | Required for advanced monitoring |
| Vulnerabilities should be remediated | Varies | Software vulnerabilities detected |

💥 **Investigate a recommendation:**

1. Click on a recommendation to see affected resources
2. Review the remediation steps provided
3. For quick fixes, use the **Fix** button if available

### 4.4 Review Security Alerts (if any)

1. Navigate to **Security alerts** in Defender for Cloud
2. Review any active alerts for your hybrid resources
3. Click on an alert to see:
   - Attack description
   - Affected resources
   - Recommended actions

🔑 **Key insight:** Microsoft Defender for Cloud provides unified security management across Azure and Arc-enabled resources. This enables consistent security posture management for sovereign hybrid deployments.

---

## Task 5: Explore Azure Update Manager for Hybrid Patching

💡 **Use Azure Update Manager to assess and manage OS updates across your Arc-connected machines.**

### 5.1 Navigate to Azure Update Manager

1. In the Azure Portal, search for **Azure Update Manager**
2. Or navigate via: **Home** > **Update Manager**
3. Review the dashboard overview showing:
   - Machines pending updates
   - Compliance status
   - Recent update deployments

### 5.2 Assess Update Compliance

💥 **Check update status for Arc-enabled servers:**

1. Select **Machines** in the left menu
2. Filter by:
   - **Machine type**: `Arc-enabled servers`
   - **Resource group**: Your ArcBox resource group
3. Review the update status for each machine

### 5.3 Trigger an Update Assessment

```bash
# Trigger update assessment for an Arc-enabled server
az maintenance configuration assignment create \
  --maintenance-configuration-id "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Maintenance/maintenanceConfigurations/default" \
  --name "update-assessment" \
  --resource-group $RESOURCE_GROUP \
  --resource-name "ArcBox-Ubuntu-01" \
  --resource-type "Microsoft.HybridCompute/machines" \
  --provider-name "Microsoft.HybridCompute"
```

Or via Portal:
1. Select the Arc-enabled server
2. Click **Check for updates**
3. Wait for the assessment to complete

### 5.4 Review Available Updates

1. Click on a machine to see detailed update status
2. Review:
   - **Critical and security updates** - High priority
   - **Other updates** - Feature and quality updates
   - **Definition updates** - Antimalware definitions

🔑 **Key insight:** Azure Update Manager provides centralized patch management across Azure VMs and Arc-enabled servers. This is critical for maintaining security compliance in sovereign environments where you need to control when and how updates are applied.

---

## Task 6: Wrap-up and Discussion

### 6.1 Review Key Learnings

After completing this challenge, you should understand:

✅ **Azure Arc as the Hybrid Bridge**
- Arc-enabled servers represent on-premises machines as Azure resources
- Enables unified management through Azure Resource Manager
- Supports Azure RBAC, tags, and policies for hybrid resources

✅ **Sovereign Hybrid Governance**
- Azure Policy with Machine Configuration extends compliance to the OS level
- Provides consistent governance across cloud and on-premises
- Essential for meeting sovereign regulatory requirements

✅ **Azure Local as Sovereign Private Cloud**
- Azure Local enables sovereign on-premises cloud infrastructure
- Arc Resource Bridge connects Azure Local to Azure management plane
- Self-service VM provisioning using Azure Portal and CLI

✅ **Security and Compliance**
- Microsoft Defender for Cloud provides unified security posture management
- Azure Update Manager enables centralized patch management
- Consistent security monitoring across hybrid estate

### 6.2 Real-World Applications

Consider how these capabilities apply to sovereign cloud scenarios:

| Scenario | Azure Arc Capability |
|----------|---------------------|
| Data residency requirements | Keep data on-premises with Azure Local, manage from Azure |
| Regulatory compliance | Apply consistent policies across hybrid estate |
| Security monitoring | Unified threat detection with Defender for Cloud |
| Operational efficiency | Single control plane for hybrid management |
| Disaster recovery | Azure Site Recovery integration for failover |

### 6.3 Further Exploration

For additional learning, explore:
- [Azure Arc Jumpstart Scenarios](https://jumpstart.azure.com/)
- [Azure Local documentation](https://learn.microsoft.com/azure/azure-local/)
- [Microsoft Sovereign Cloud documentation](https://learn.microsoft.com/industry/sovereignty/sovereignty-capabilities)

---

## Validation Checklist

Before completing this challenge, verify:

- [ ] You can identify Arc-enabled servers in the Azure Portal
- [ ] You have assigned at least one Machine Configuration policy
- [ ] You can view policy compliance status for Arc-enabled servers
- [ ] You understand how to deploy VMs on Azure Local (conceptually or hands-on)
- [ ] You have enabled or verified Defender for Cloud coverage
- [ ] You can navigate Azure Update Manager for hybrid patching

---

You successfully completed Challenge 6! 🚀🚀🚀

**[Home](../../README.md)** - [Previous Challenge Solution](../challenge-05/solution-05.md)
