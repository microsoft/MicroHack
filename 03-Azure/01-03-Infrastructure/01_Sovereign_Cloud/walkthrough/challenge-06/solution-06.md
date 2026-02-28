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
- **Reader** and **Azure Stack HCI VM Contributor** role permissions on the resource group containing the hybrid resources

> [!NOTE]
> ArcBox and LocalBox are typically deployed by the workshop facilitator due to resource requirements and deployment time. If deploying yourself, see the [ArcBox and LocalBox deployment guide](https://github.com/microsoft/MicroHack/blob/main/03-Azure/01-03-Infrastructure/01_Sovereign_Cloud/resources/demo-vm-creator/README.md).

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

1. In the Azure portal, navigate to **Azure Arc** by using the search bar at the top, and then navigate to the **Machines** menu option under **Infrastructure**
![ArcBox](./images/arcbox_01.jpg)
2. Click on one of the Arc-enabled servers (e.g., `ArcBox-Win2k25`)
3. Review the **Overview** blade:
   - Operating system and version
   - Agent status and version
   - Resource location (Azure region for metadata)
   - Machine location (actual physical location)
4. Check **Settings -> Extensions** to see installed Azure extensions
5. Navigate through other menu items such as **Monitoring** and **Operations** to see available features and functionality.

🔑 **Key insight:** Arc-enabled servers appear as Azure resources with resource IDs, allowing you to apply Azure management constructs (tags, RBAC, policies) to on-premises machines.

### 1.2 Explore LocalBox resources (if available)

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

### 2.2 Assign the Linux SSH Posture Control

💥 **Assign a built-in policy to audit Linux SSH Posture compliance:**

For background and conceptual reference, review the article [What is SSH Posture Control?](https://learn.microsoft.com/azure/osconfig/overview-ssh-posture-control-mc) before proceeding.

#### Azure Portal

1. Navigate to **Azure Policy** in the Azure Portal
2. Select **Definitions** in the left menu
3. Search for: `Configure SSH security posture`
![ArcBox](./images/ssh_posture_04.jpg)
4. Click on the policy definition **Configure SSH security posture for Linux (powered by OSConfig)** to view details
5. Click **Assign policy**
6. Configure the assignment:
   - **Scope**: Select the resource group containing Arc-enabled servers (e.g. **rg-arcbox**)
   - **Assignment name**: `labuserXX - Configure SSH security posture for Linux (powered by OSConfig)` (change XX to your suffix)
   - ![ArcBox](./images/ssh_posture_01.jpg)
   - Click **Next**
   - Change **Include Arc connected servers** to **true** and click **Next**
   - ![ArcBox](./images/ssh_posture_02.jpg)
7. Click **Next** on the remaining tabs without making any changes to default values, then **Review + create**
8. ![ArcBox](./images/ssh_posture_03.jpg)
9. After 15 minutes, navigate to the Arc-enabled server **Arcbox-Ubuntu-01** -> **Operations** -> **Machine Configuration** to see individual configuration status
10. Click on the **SetLinuxSshServerSecurityBaseline** Configuration Name
11. ![ArcBox](./images/ssh_posture_06.jpg)
12. Enable the checkbox **Compliant** to view both compliant and non-compliant SSH settings
13. ![ArcBox](./images/ssh_posture_07.jpg)

🔑 **Key insight:** Azure Policy with Machine Configuration provides unified compliance visibility across Azure VMs and Arc-enabled servers. This is essential for maintaining sovereign compliance requirements across hybrid environments.

---

## Task 3: Deploy a VM on Azure Local via Azure Portal

💡 **Use Azure Arc VM management to deploy a virtual machine on your Azure Local cluster directly from the Azure Portal.**

> [!NOTE]
> This task requires access to a LocalBox environment with Arc Resource Bridge configured. If you don't have access, review the steps to understand the process.

### 3.1 Navigate to Azure Local VM Management

1. In the Azure portal, navigate to **Azure Arc** by using the search bar at the top, and then navigate to the **Azure Local** menu option under **Supported environments**. Click on **All systems**.
![Azure Local](./images/localbox_01.jpg)
2. Click on the **localboxcluster** Azure Local instance
3. Explore the available features and services under **Resources**
4. Select **Virtual machines** option
5. Click **+ Create VM** to start the VM creation wizard

### 3.2 Configure the Virtual Machine

💥 **Basic settings:**

1. **Subscription**: Select your subscription (e.g. **Micro-Hack-1**)
2. **Resource group**: Select the same resource group as the Azure Local instance (e.g. **rg-localbox**)
3. **Virtual machine name**: `labuserXX-vm-01` (replace XX with your own suffix)
4. **Security type**: Select **Standard**

![Azure Local](./images/localbox_02.jpg)

5. **Image**: Select an available gallery image (e.g., Windows Server 2025)
6. **Virtual processor count**: 2
7. **Memory (MB)**: 4096

![Azure Local](./images/localbox_03.jpg)

💥 **Administrator account:**

1. **Username**: `localadmin`
2. **Password**: Create a strong password and make a note of it

![Azure Local](./images/localbox_04.jpg)

Do not opt-in for domain join at this time, and select **Next**

![Azure Local](./images/localbox_05.jpg)

Click **Next** without creating any data disks.

![Azure Local](./images/localbox_05.jpg)

💥 **Networking:**

Click **+ Add network interface**

![Azure Local](./images/localbox_06.jpg)

For **Name** use the same value as for **Virtual machine name**: `labuserXX-vm-01` (replace XX with your own suffix)
For **Network** choose **localbox-vm-lnet-vlan200**
Select **Add** and then **Next**

![Azure Local](./images/localbox_07.jpg)

Click **Next** twice

![Azure Local](./images/localbox_08.jpg)

Click **Create**

![Azure Local](./images/localbox_09.jpg)

### 3.3 Review and Create

1. Review all settings
2. Click **Create** to deploy the VM


### 3.4 Validate VM Deployment

1. Click **Go to resource** when the deployment is finished
2. Verify the VM is running
3. Review the VM properties and available operations

![Azure Local](./images/localbox_10.jpg)

🔑 **Key insight:** Azure Arc VM management enables self-service VM provisioning on Azure Local using familiar Azure tools and RBAC. This allows organizations to maintain data sovereignty by keeping workloads on-premises while benefiting from Azure management capabilities.

#### **Bonus tip**

By appending **--rdp** to the Azure CLI command generated on the **Connect** blade for the VM, it is possible to connect to Windows machines running on Azure Local (and any Arc-enabled Windows machine) via Remote Desktop when running the command from Azure CLI on your local computer:

![Azure Local](./images/localbox_11.jpg)

![Azure Local](./images/localbox_12.jpg)

To learn more, see [SSH access to Azure Arc-enabled servers](https://learn.microsoft.com/azure/azure-arc/servers/ssh-arc-overview).

---

## Task 4: Security Monitoring with Microsoft Defender for Cloud

💡 **Enable Microsoft Defender for Cloud and review security recommendations for your Arc-enabled resources.**

### 4.1 Enable Defender for Servers

💥 **Enable Defender for Servers on your subscription:**

**Azure Portal**

1. Navigate to **Microsoft Defender for Cloud**
2. Select **Environment settings** in the left menu
3. Expand your tenant and select your subscription
4. Under **Defender plans**, locate **Servers**
5. Toggle to **On** (select Plan 1 or Plan 2 based on requirements)
6. Click **Save**

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
   - **Resource group**: Your ArcBox resource group (e.g. **rg-arcbox**)
3. Review the update status for each machine

### 5.3 Trigger an Update Assessment

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
