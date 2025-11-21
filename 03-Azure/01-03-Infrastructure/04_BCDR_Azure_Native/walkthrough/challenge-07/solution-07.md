# Walkthrough Challenge 7 - Failback to the Primary Region (Germany West Central)

[Previous Challenge Solution](../challenge-06/solution-06.md) - **[Home](../../Readme.md)** - [Next Challenge Solution](../challenge-08/solution-08.md)

⏰ Duration: 1 hour 30 minutes

## Solution Overview

This challenge focuses on failing back the web application and storage account from Sweden Central (secondary) to Germany West Central (primary) after a disaster recovery event. You will reprotect VMs, perform failback, verify Traffic Manager, and restore the storage account to the primary region.

## Prerequisites

Ensure Challenges 5 and 6 are completed with:
- Web VMs (`mh-web1` and `mh-web2`) running in Sweden Central after DR failover
- Recovery Services Vault in both regions
- Traffic Manager configured
- Storage Account failed over to secondary region

## Task 1: Failback Web Application VMs to Germany West Central

### Step 1: Reprotect the VMs

Before you can fail back, you must reprotect the VMs to enable reverse replication from Sweden Central back to Germany West Central.

1. Navigate to the **Recovery Services Vault** in Sweden Central
2. Go to **Protected Items** > **Replicated Items**
3. Select each web VM (`mh-web1`, `mh-web2`)
4. Click **Re-protect** from the top menu
5. Review the automatically configured settings:
   - Azure Site Recovery automatically configures the target as the original source location
   - Target region will be Germany West Central (the original source)
   - Target resource group, VNet, and other settings are auto-selected based on original configuration
6. Click **OK** to start reprotection

### Monitor Reprotection Progress

1. Navigate to **Site Recovery jobs**
2. Monitor the reprotection job for each VM
3. Wait until synchronization reaches 100%
   - This may take 30-60 minutes depending on data changes
4. Verify replication health shows as "Healthy"

> **Important:** You cannot fail back until reprotection is complete and synchronization is at 100%.

### Step 2: Perform Failback

Once reprotection is complete:

1. Navigate to the **Recovery Plan** or individual VM's disaster recovery blade
2. Click **Failover** from the top menu
3. Configure failover settings:
   - **Failover direction**: From Sweden Central to Germany West Central
   - **Recovery point**: Select the latest recovery point
   - **Shut down machines**: Check this option to minimize data loss
4. Confirm and start the failover

### Monitor Failback Progress

1. Navigate to **Site Recovery jobs**
2. Monitor the failover job progress
3. Wait for completion (typically 15-30 minutes)
4. Verify VMs are running in Germany West Central

### Step 3: Commit the Failback

After verifying the VMs are operational in Germany West Central:

1. Return to the disaster recovery blade or recovery plan
2. Click **Commit** to finalize the failback
3. This completes the failback operation

### Step 4: Re-enable DR Protection

After failback and commit, the VMs are in Germany West Central but not yet protected:

1. Navigate to each VM in Germany West Central
2. Go to **Disaster recovery**
3. Click **Enable disaster recovery** to reconfigure replication to Sweden Central
4. Follow the replication setup process to protect the VMs again
5. Wait for initial replication to complete

> **Note:** After failback and commit, replication is not automatically re-enabled. You must manually configure DR protection again to ensure business continuity.

## Task 2: Verify Traffic Manager and Web Application

### Check Traffic Manager Endpoint Status

1. Navigate to **Traffic Manager profile** in the Azure Portal
2. Go to **Endpoints**
3. Verify the Germany West Central endpoint status:
   - Status should show as "Online"
   - Health probe should be passing
4. Check that traffic is being routed to the primary region

### Test Web Application Connectivity

1. Access the web application using the Traffic Manager DNS name
2. Verify the application is responding correctly
3. Confirm the application shows it's running from Germany West Central
4. Test multiple times to ensure consistent routing to the primary region

> **Success!** The web application is now operational in the primary region with Traffic Manager routing traffic correctly.

## Task 3: Failback Storage Account to Germany West Central

### Understand Storage Account Failback

After a storage account failover, the account is converted to LRS in the new primary region (formerly secondary). To fail back:

> **Important:** Storage account failover is intended for disaster recovery scenarios. After failover, the account becomes LRS and the original primary region becomes the secondary after reconfiguration.

### Reconfigure Storage Redundancy

1. Navigate to the **Storage Account** (now primary in the secondary region)
2. Go to **Redundancy** settings
3. Change redundancy from LRS to GRS or GZRS
   - This re-establishes geo-replication
   - The original primary region (Germany West Central) becomes the new secondary
4. Wait for initial synchronization to complete
5. Monitor the **Last sync time** to verify replication is active

> **Note:** Once reconfigured to GRS, data begins replicating to Germany West Central (now the secondary region).

### Initiate Storage Account Failover (Back to Original Primary)

1. After GRS synchronization is complete and stable:
   - Go to **Redundancy** blade
2. Click **Prepare for failover** to fail over to Germany West Central
3. Review the warnings:
   - This will make Germany West Central the primary region again
   - Data loss is possible if last sync is not recent
   - The failover takes approximately 1 hour
4. Confirm the failover

### Monitor Storage Failback

1. Monitor the failover progress (typically takes 30-60 minutes)
2. Wait for completion notification
3. Verify the storage account is now primary in Germany West Central

### Verify Data Integrity

After failback completes:

1. Navigate to storage account containers
2. List blobs/files and verify all data is present
3. Test read/write operations to confirm functionality
4. Compare file counts and sizes with pre-disaster records
5. Validate that applications can access storage successfully

### Reconfigure Storage Redundancy (Post-Failback)

1. After failover completes, the storage account is LRS in Germany West Central
2. Go to **Redundancy** settings
3. Change from LRS to GRS or GZRS
4. This re-establishes geo-redundant protection
5. The paired region will again serve as the secondary for geo-replication

> **Important:** Each time you perform a storage account failover, the redundancy reverts to LRS. You must reconfigure geo-redundancy after each failover.

## Success Criteria Validation ✅

Confirm you have completed:
- ✅ Reprotected web VMs for reverse replication to Germany West Central
- ✅ Successfully failed back VMs from Sweden Central to Germany West Central
- ✅ Verified VMs are operational in the primary region
- ✅ Re-enabled disaster recovery protection with Sweden Central as secondary
- ✅ Traffic Manager shows Germany West Central endpoint as "Online"
- ✅ Web application is accessible and routing through Traffic Manager to primary region
- ✅ Storage Account has been failed back to Germany West Central
- ✅ Verified data integrity and accessibility after storage failback
- ✅ Reconfigured GRS for continued geo-redundant protection

You have successfully completed Challenge 7! 🚀

## Additional Notes

**Failback Best Practices:**
- Always reprotect VMs before attempting failback
- Wait for 100% synchronization before initiating failback
- Test thoroughly in the primary region before committing
- Plan for a maintenance window as failback requires VM shutdown
- Document the entire failback procedure for future reference

**Storage Account Failback Considerations:**
- After initial failover, the account becomes LRS in the new primary region
- Reconfigure to GRS to re-establish replication (original primary becomes new secondary)
- Monitor last sync time before initiating the second failover
- Second failover back to original primary takes approximately 1 hour
- After failover completes, the account is always LRS - must reconfigure to GRS again
- Test data integrity thoroughly after failover
- Consider the impact: two failovers means extended period of LRS (no geo-redundancy)

**Post-Failback Actions:**
- Reconfigure all disaster recovery protections
- Update documentation with lessons learned
- Review and optimize recovery time objectives (RTO)
- Schedule regular DR drills
- Verify all dependent services and applications are functioning
- Update runbooks based on actual failback experience

**Important Reminders:**
- After failback, you must re-enable replication to maintain DR capability
- Monitor replication health continuously
- Keep recovery plans updated with infrastructure changes
- Ensure Traffic Manager health probes are properly configured
- Document any issues encountered during failback for future improvements