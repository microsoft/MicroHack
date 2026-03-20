# Challenge 5 - Resiliency Agent

**[Home](../Readme.md)** - [Previous Challenge](challenge-04.md) - [Next Challenge](challenge-06.md)

## Goal

The Resiliency Agent helps you ensure your Azure resources are **resilient and can recover from failures**. It can:

- Identify resources **missing zone resiliency** goals
- Find resources **vulnerable to outages** or cyber attacks
- Check **backup status** and identify resources lacking recent recovery points
- Provide **ready-to-deploy scripts** to configure zone resiliency
- Help manage **Azure Backup vaults** (create, delete, data copy, troubleshoot)
- Guide configuration of **Azure Site Recovery** and other recovery solutions
- Review **key alerts** and **failed backup jobs**

Use the Resiliency Agent in Azure Copilot to assess your cloud environment's resilience, identify gaps in zone resiliency and backup coverage, and implement solutions to protect against outages and data loss.

**Scenario:** Contoso Ltd. is preparing for an upcoming compliance audit. The auditors will check that all production resources have proper disaster recovery and business continuity configurations. Your task is to assess the current state, identify gaps, and implement resiliency improvements before the audit.

By the end of this challenge, you will be able to:

- Identify resources that are not zone-resilient
- Discover resources lacking backup protection
- Configure zone resiliency using Copilot-generated scripts
- Manage Azure Backup vaults through conversation
- Review failed backup jobs and key alerts
- Plan disaster recovery strategies with Azure Copilot guidance

## Actions

### Pre-Challenge Setup

> **Note:** The workshop deployment scripts have already created a VM with deliberate resiliency gaps. If you ran `lab/Deploy-Lab.ps1`, everything below is ready to use.

#### Workshop Resources (Pre-Deployed)

Resources in **`rg-copilot-<suffix>-ch04`** (in your chosen deployment region):

| Resource        | Name                      | SKU          | Resiliency Gaps                                |
| --------------- | ------------------------- | ------------ | ---------------------------------------------- |
| Virtual Machine | `vm-copilot-noresilience` | Standard_B2s | No zone redundancy, no Azure Backup configured |

> **Why these gaps?** The VM is intentionally deployed **without** availability zone configuration and **without** backup protection, so the Resiliency Agent will flag both issues and guide you through remediation.

#### Option A: Use the Pre-Deployed VM (Recommended)

1. Navigate to **`rg-copilot-<suffix>-ch04`** in the Azure portal
2. Note the VM name: **`vm-copilot-noresilience`**
3. Proceed to Task 1

#### Option B: Use Your Own Existing Resources

Ensure you have resources deployed that can be evaluated for resiliency. Ideal resources include:

- A Virtual Machine (any SKU)
- An App Service
- An Azure Database for PostgreSQL or MySQL (optional)
- A Storage Account (optional)

### Task 1: Assess Zone Resiliency Status (10 min)

1. Open Azure Copilot and **enable agent mode**
2. Check which resources lack zone resiliency:

   > _"Which resources aren't zone-resilient?"_

3. Then check at the service group level:

   > _"Which service groups are currently not zone-resilient?"_

4. For a specific resource, ask for details:

   > _"Is my VM `vm-copilot-noresilience` zone-resilient? If not, what steps are needed?"_

5. Review the findings:
   - Which resources are missing zone resiliency?
   - What is the risk of not having zone resiliency?
   - What changes are needed to enable it?

**Question to answer:** What percentage of your resources are zone-resilient? What are the most critical gaps?

### Task 2: Configure Zone Resiliency (10 min)

Pick a non-zone-resilient resource and configure it:

1. Ask Azure Copilot to help configure zone resiliency:

   > _"Configure zone resiliency for my VM `vm-copilot-noresilience`."_

2. Review the generated script:
   - What changes will it make?
   - Does it require downtime?
   - What are the prerequisites?

3. For resources where scripts aren't auto-generated, ask for guidance:

   > _"How do I configure zone resiliency for my Azure Cache for Redis?"_
   > _"What are the steps to make my App Service zone-redundant?"_

4. Understand the cost implications:

   > _"What is the cost impact of enabling zone resiliency for my resources?"_

**Question to answer:** Which resource types support automated zone resiliency scripts? Which require manual configuration?

### Task 3: Review Backup Coverage and Health (10 min)

1. Check for resources without backup:

   > _"Which data sources don't have a recovery point within the last 7 days?"_

2. Check for failed backup jobs:

   > _"How many backup jobs failed in the last 24 hours?"_

3. Review key alerts:

   > _"What are the key alerts raised since the past 24 hours?"_

4. Identify unprotected resources:

   > _"Which VMs don't have Azure Backup configured?"_

5. For any identified gaps, ask for remediation:

   > _"How do I configure backup for my unprotected VMs?"_

**Question to answer:** What backup gaps exist in your environment? How could these gaps impact business continuity?

### Task 4: Manage Backup Vaults (10 min)

Use the Resiliency Agent to manage backup infrastructure:

1. **Create a vault:**

   > _"Help me create a Recovery Services vault named `rsv-copilot-workshop` in my resource group `rg-copilot-<suffix>-ch04`."_

2. **Enhance vault security:**

   > _"Increase the security level of this vault."_

3. **Explore vault operations:**

   > _"What backup policies are configured in this vault?"_
   > _"How can I set up a backup policy for daily backups with 30-day retention?"_

4. **Plan disaster recovery:**

   > _"How can I define a recovery plan?"_
   > _"What are the steps to define a drill?"_

**Question to answer:** What security features does Azure Copilot recommend for backup vaults? Why are they important?

### Task 5: Create a Resiliency Improvement Plan (5 min)

Bring it all together with a comprehensive assessment:

1. Ask for an overall resiliency summary:

   > _"Give me a summary of the resiliency posture of my resources in `rg-copilot-<suffix>-ch04`."_

2. Request a prioritized improvement plan:

   > _"What are the top resiliency improvements I should make, prioritized by risk?"_

3. Document the findings in a format suitable for the compliance audit:

   > _"Help me create a resiliency report for my compliance audit, covering zone resiliency, backup coverage, and disaster recovery readiness."_

**Question to answer:** How would you present this resiliency assessment to auditors or management?

## Success criteria

- You identified resources lacking zone resiliency
- You configured or reviewed a script for zone resiliency
- You checked backup coverage and identified gaps
- You reviewed failed backup jobs and key alerts
- You managed a backup vault (create, view policies, or enhance security)
- You created a resiliency improvement plan

## Learning resources

- The Resiliency Agent provides a **comprehensive view** of your environment's resilience posture
- It can generate **ready-to-deploy scripts** for zone resiliency on supported resource types
- **Backup coverage gaps** are identified proactively, including resources without recent recovery points
- **Vault management** capabilities streamline backup infrastructure operations
- Azure Copilot guides you through **manual configurations** when automation isn't available (e.g., Azure Site Recovery, multi-user authorization)
- [Resiliency Agent documentation](https://learn.microsoft.com/en-us/azure/copilot/resiliency-agent)

**Limitations to Note:**

- Ready-to-deploy zone resiliency scripts are supported only for: **VMs, App Services, Azure Database for PostgreSQL, Azure Database for MySQL, SQL Managed Instance, Azure Cache for Redis, and Azure Firewall**
- Configuration of advanced capabilities like **multi-user authorization** and **Azure Site Recovery** requires manual intervention — Azure Copilot provides guidance
- The agent **assesses and recommends** but does not automatically apply changes without your confirmation

## Solution

> [!TIP]
> We encourage you to try solving the challenge on your own before looking at the solution. This will help you learn and understand the concepts better.

<details>
<summary>Click here to view the solution</summary>

[Solution for Challenge 5](../walkthrough/solution-05.md)

</details>
