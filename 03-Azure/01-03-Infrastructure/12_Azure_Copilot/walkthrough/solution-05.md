# Walkthrough Challenge 5 - Resiliency Agent

**[Home](../Readme.md)** - [Previous Challenge Solution](solution-04.md) - [Next Challenge Solution](solution-06.md)

**Estimated Duration:** 45 minutes

> 💡 **Objective:** Learn to assess and improve Azure resource resiliency using the Resiliency Agent in Azure Copilot — from zone resiliency assessment to backup management and disaster recovery planning.

---

## Task 1: Assess Zone Resiliency Status

### Steps

1. **Open Azure Copilot** and **enable agent mode**
2. **Enter the prompts** sequentially:

**Prompt 1:** _"Which resources aren't zone-resilient?"_

> **Expected response:**
>
> ```text
> Non-Zone-Resilient Resources in your environment:
>
> 1. vm-copilot-noresilience (Virtual Machine)
>    Region: France Central (or your chosen deployment region)
>    Current: No availability zone configured
>    Risk: Single point of failure in one datacenter
>
> 📊 Summary: 1 of 1 resources lack zone resiliency in rg-copilot-<suffix>-ch04
> ```
>
> **Note:** Your actual results will vary based on the resources in your subscription. The workshop VM `vm-copilot-noresilience` in `rg-copilot-<suffix>-ch04` is the key resource to focus on.

**Prompt 2:** _"Which service groups are currently not zone-resilient?"_

> **Expected:** A higher-level view grouping resources by service type and showing which service groups have gaps.

**Prompt 3:** _"Is my VM vm-copilot-noresilience zone-resilient? If not, what steps are needed?"_

> **Expected:** Detailed assessment of the specific VM, including:
>
> - Current zone configuration
> - Steps to migrate to a zonal deployment
> - Impact on availability and cost

### Answer

Typical findings:

- **VMs** created without specifying an availability zone are the most common gap
- **App Services** on non-zone-redundant plans lack zone resiliency
- Zone resiliency is a **critical pillar** of the Well-Architected Framework's reliability recommendations

---

## Task 2: Configure Zone Resiliency

### Steps

**Prompt:** _"Configure zone resiliency for my VM vm-copilot-noresilience."_

### Expected Script (for a VM)

```powershell
# Zone Resiliency Configuration for vm-copilot-noresilience
# NOTE: Migrating a VM to an availability zone requires redeployment
#
# Prerequisites:
# - The region must support availability zones
# - A maintenance window (VM will be stopped)

$resourceGroupName = "rg-copilot-<suffix>-ch04"
$vmName = "vm-copilot-noresilience"
$location = "francecentral"
$zone = "1"  # Target availability zone

# Step 1: Get current VM configuration
$vm = Get-AzVM -ResourceGroupName $resourceGroupName -Name $vmName

# Step 2: Create a snapshot of OS disk
$snapshotConfig = New-AzSnapshotConfig `
  -SourceUri $vm.StorageProfile.OsDisk.ManagedDisk.Id `
  -Location $location `
  -CreateOption Copy `
  -Zone $zone

$snapshot = New-AzSnapshot `
  -ResourceGroupName $resourceGroupName `
  -SnapshotName "$vmName-snapshot" `
  -Snapshot $snapshotConfig

# Step 3: Create new managed disk in the target zone
$diskConfig = New-AzDiskConfig `
  -SourceResourceId $snapshot.Id `
  -Location $location `
  -CreateOption Copy `
  -Zone $zone

$newDisk = New-AzDisk `
  -ResourceGroupName $resourceGroupName `
  -DiskName "$vmName-osdisk-zonal" `
  -Disk $diskConfig

# Step 4: Redeploy VM in the target zone
# (Additional steps for NIC, IP, and VM recreation)
# Azure Copilot provides the complete script
```

### Supported Resource Types for Automated Scripts

| Resource Type                 | Auto-Script | Notes                           |
| ----------------------------- | ----------- | ------------------------------- |
| Virtual Machines              | ✅ Yes      | Requires redeployment           |
| App Services                  | ✅ Yes      | Plan upgrade may be needed      |
| Azure Database for PostgreSQL | ✅ Yes      | Zone-redundant HA configuration |
| Azure Database for MySQL      | ✅ Yes      | Zone-redundant HA configuration |
| SQL Managed Instance          | ✅ Yes      | Zone-redundant configuration    |
| Azure Cache for Redis         | ✅ Yes      | Zone-redundant tier required    |
| Azure Firewall                | ✅ Yes      | Zone-spanning deployment        |
| Azure Site Recovery           | ❌ Manual   | Copilot provides guidance       |
| Multi-user authorization      | ❌ Manual   | Copilot provides guidance       |

### Answer

Automated scripts are available for **7 resource types**. For others, Azure Copilot provides detailed step-by-step guidance that you follow manually in the portal.

---

## Task 3: Review Backup Coverage and Health

### Steps and Expected Responses

**Prompt 1:** _"Which data sources don't have a recovery point within the last 7 days?"_

> **Expected:**
>
> ```text
> Resources without recent recovery points (>7 days):
>
> 1. vm-copilot-noresilience — Last backup: None (no backup policy configured)
> 2. vm-dev-server — Last backup: 12 days ago (backup job failing)
>
> ⚠️ These resources are at risk of data loss in a failure scenario.
> ```

**Prompt 2:** _"How many backup jobs failed in the last 24 hours?"_

> **Expected:**
>
> ```text
> Backup Job Summary (Last 24 hours):
>
> ✅ Successful: 15 jobs
> ❌ Failed: 2 jobs
>   - vm-dev-server: VSS snapshot failed (Error: VMSnapshotProviderFailed)
>   - sqldb-reports: Connection timeout during backup
>
> Recommendations:
> 1. For vm-dev-server: Restart the VSS service and retry the backup
> 2. For sqldb-reports: Check network connectivity and retry
> ```

**Prompt 3:** _"What are the key alerts raised since the past 24 hours?"_

> **Expected:** A list of alerts with severity, resource, and brief description.

**Prompt 4:** _"Which VMs don't have Azure Backup configured?"_

> **Expected:** A list of unprotected VMs with recommendations to enable backup.

**Prompt 5:** _"How do I configure backup for my unprotected VMs?"_

> **Expected:** Step-by-step instructions for:
>
> 1. Selecting/creating a Recovery Services vault
> 2. Choosing a backup policy
> 3. Enabling backup for the VMs
> 4. Verifying the initial backup

### Answer

Common backup gaps include:

- **New VMs** deployed without backup policies
- **Dev/test resources** overlooked in backup planning
- **Failed backup jobs** due to agent issues, networking, or capacity

These gaps directly impact business continuity — even one unprotected VM with critical data can cause significant data loss.

---

## Task 4: Manage Backup Vaults

### Steps

**Prompt 1:** _"Help me create a Recovery Services vault named rsv-copilot-workshop in my resource group rg-copilot-<suffix>-ch04."_

> **Expected:** Azure Copilot guides you through vault creation:
>
> 1. Selects the region matching your resource group
> 2. Creates the vault with default settings
> 3. Confirms creation with vault details

**Prompt 2:** _"Increase the security level of this vault."_

> **Expected recommendations:**
>
> ```text
> Security Enhancements for rsv-copilot-workshop:
>
> 1. ✅ Enable Soft Delete (14+ day retention for deleted backups)
>    Status: Enabled by default — verify it's not disabled
>
> 2. ✅ Enable Multi-User Authorization (MUA)
>    Prevents any single admin from disabling security features
>    Requires: Azure Resource Guard setup
>
> 3. ✅ Enable Immutable Vaults
>    Prevents backup data from being deleted before expiry
>
> 4. ✅ Enable Cross-Region Restore
>    Allows restoration in the paired region during regional outages
>
> 5. ✅ Configure Private Endpoints
>    Restricts vault access to your virtual network only
> ```

**Prompt 3:** _"How can I set up a backup policy for daily backups with 30-day retention?"_

> **Expected:** Step-by-step guidance including:
>
> - Navigate to the vault → Backup policies
> - Create new policy
> - Schedule: Daily at specific time
> - Retention: 30 days for daily, optional weekly/monthly/yearly
> - Assign to resources

**Prompt 4:** _"What are the steps to define a drill?"_

> **Expected:** Guidance on testing disaster recovery:
>
> - Define a test failover plan
> - Select resources to test
> - Create an isolated test network
> - Perform test failover
> - Validate application functionality
> - Clean up test resources

### Answer

Azure Copilot recommends key vault security features:

- **Soft Delete** — Prevents accidental or malicious deletion of backup data
- **Multi-User Authorization** — Requires multiple admins to approve destructive actions
- **Immutable Vaults** — Protects backup data from being deleted before retention period expires
- **Cross-Region Restore** — Enables recovery even during regional outages

These features are critical for **ransomware protection** and **compliance requirements**.

---

## Task 5: Create a Resiliency Improvement Plan

### Steps

**Prompt:** _"Give me a summary of the resiliency posture of my resources in rg-copilot-<suffix>-ch04."_

> **Expected:**
>
> ```text
> Resiliency Posture Summary: rg-copilot-<suffix>-ch04
>
> Zone Resiliency:     ⚠️ 2 of 4 resources zone-resilient (50%)
> Backup Coverage:     ⚠️ 1 of 3 VMs backed up (33%)
> Backup Health:       ✅ No failed jobs in last 24h
> Site Recovery:       ❌ Not configured
> Vault Security:      ⚠️ Basic — MUA and immutability not enabled
>
> Overall Score: ⚠️ Moderate Risk
> ```

**Prompt:** _"What are the top resiliency improvements I should make, prioritized by risk?"_

> **Expected prioritized plan:**
>
> ```text
> Priority 1 (Critical):
>   - Enable backup for unprotected VMs
>   - Configure zone resiliency for production VMs
>
> Priority 2 (High):
>   - Enable vault security features (MUA, immutability)
>   - Configure Azure Site Recovery for critical workloads
>
> Priority 3 (Medium):
>   - Enable zone redundancy for App Service and database
>   - Set up cross-region restore
>
> Priority 4 (Low):
>   - Configure DR drills schedule
>   - Document recovery procedures
> ```

### Answer

For auditors and management, present:

1. **Current state** — Percentage scores for each resiliency category
2. **Identified gaps** — Specific resources and missing configurations
3. **Remediation plan** — Prioritized actions with timelines
4. **Evidence** — Screenshots of Copilot assessments and scripts for planned changes

---

## Summary

| Skill                              | Status |
| ---------------------------------- | ------ |
| Assess zone resiliency status      | ✅     |
| Generate zone resiliency scripts   | ✅     |
| Review backup coverage             | ✅     |
| Identify failed backup jobs        | ✅     |
| Manage backup vaults               | ✅     |
| Plan disaster recovery             | ✅     |
| Create resiliency improvement plan | ✅     |

You successfully completed challenge 5! 🚀🚀🚀
