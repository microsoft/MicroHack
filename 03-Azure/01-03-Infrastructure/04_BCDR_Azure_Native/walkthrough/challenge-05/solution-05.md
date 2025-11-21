# Walkthrough Challenge 5 - Disaster Recovery (DR) across Azure Regions

[Previous Challenge Solution](../challenge-04/solution-04.md) - **[Home](../../Readme.md)** - [Next Challenge Solution](../challenge-06/solution-06.md)

⏰ Duration: 1 hour

## Solution Overview

This challenge focuses on implementing cross-region disaster recovery using Azure Site Recovery. You will replicate web VMs from Germany West Central (primary) to Sweden Central (secondary) and perform both test and production failovers to demonstrate DR capabilities across Azure regions.

## Prerequisites

Ensure the lab environment from Challenge 2 is successfully deployed with:
- Web VMs (`mh-web1` and `mh-web2`) in Germany West Central
- Recovery Services Vault in Sweden Central (`mh-swedencentral-asrvault`)
- Target resource group in Sweden Central

## Task 1: Set up and enable disaster recovery with Azure Site Recovery

### Enable Replication for Web VMs

**Method 1: From Recovery Services Vault**

1. Navigate to the Recovery Services Vault in Sweden Central (`mh-swedencentral-asrvault`)
2. Under **Protected Items**, select **Replicated Items**
3. Click **+ Replicate** and select **Azure virtual machines**
4. Configure replication settings:
   - **Source region**: Germany West Central
   - **Source resource group**: Select the resource group containing web VMs
   - **Virtual machines**: Select `mh-web1` and `mh-web2`
   - **Target location**: Sweden Central
   - **Target resource group**: Select the target resource group in Sweden Central
5. Review replication settings and enable replication

**Method 2: From Virtual Machine (Alternative)**

1. Navigate to a web VM (e.g., `mh-web1`)
2. Select **Disaster recovery** from the left menu
3. Configure the target region as Sweden Central
4. Review and enable replication

### Monitor Replication Progress

1. Navigate to **Site Recovery jobs** in the Recovery Services Vault
2. Monitor the initial replication progress
   - This may take 15-30 minutes to complete
3. Once complete, verify replication status shows as "Healthy" for both VMs

## Task 2: Create a recovery plan and run a test failover

### Create a Recovery Plan

1. Navigate to the Recovery Services Vault in Sweden Central
2. Under **Manage**, select **Recovery Plans (Site Recovery)**
3. Click **+ Recovery plan**
4. Configure the recovery plan:
   - **Name**: Enter a descriptive name (e.g., `web-app-recovery-plan`)
   - **Source**: Germany West Central
   - **Target**: Sweden Central
   - **Select items**: Choose `mh-web1` and `mh-web2`
5. Click **OK** to create the plan

### Run a Test Failover

1. Navigate to the recovery plan created above
2. Click **Test failover** from the top menu
3. Configure test failover settings:
   - **Recovery point**: Select the latest available recovery point
   - **Azure virtual network**: Select a test virtual network in Sweden Central
4. Click **OK** to start the test failover

### Monitor Test Failover Progress

1. Navigate to **Site Recovery jobs**
2. Monitor the test failover job progress
3. Once complete, verify test VMs are created in Sweden Central

### Cleanup Test Failover

1. Return to the recovery plan
2. Click **Cleanup test failover**
3. Add notes documenting the test results
4. Click **Complete** to remove test resources

## Task 3: Run a production failover

### Initiate Production Failover

1. Navigate to the recovery plan
2. Click **Failover** from the top menu
3. Configure failover settings:
   - **Failover direction**: From Germany West Central to Sweden Central
   - **Recovery point**: Select the desired recovery point
   - **Shut down machines before beginning failover**: Check this option if possible (recommended)
4. Confirm and start the failover


### Verify Failover Completion

1. Navigate to **Virtual Machines** in the Azure Portal
2. Verify the web VMs are now running in Sweden Central
3. Check the VM status and confirm they are operational

### Commit the Failover

After verifying the failover was successful:

1. Return to the recovery plan
2. Click **Commit** to finalize the failover
3. This removes the ability to fail back to alternative recovery points

## Success Criteria Validation ✅

Confirm you have completed:
- ✅ Enabled replication for `mh-web1` and `mh-web2` to Sweden Central
- ✅ Created a recovery plan for the web application
- ✅ Successfully performed a test failover with zero production impact
- ✅ Cleaned up test failover resources
- ✅ Completed a production failover to Sweden Central
- ✅ Verified VMs are running in the secondary region

You have successfully completed Challenge 5! 🚀

## Additional Notes

**Cross-Region DR Best Practices:**
- Test failover regularly to ensure DR readiness
- Document RTO (Recovery Time Objective) and RPO (Recovery Point Objective)
- Keep recovery plans up to date with infrastructure changes
- Consider network connectivity and dependencies during failover
- Plan for failback procedures after regional recovery

**Important Considerations:**
- Production failover will stop the source VMs (if shutdown option is selected)
- After failover, you may need to reconfigure networking, DNS, and load balancers
- Commit the failover only after thorough validation in the target region
- Plan for reprotection if you want to enable failback capability
