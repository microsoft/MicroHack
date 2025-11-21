# Walkthrough Challenge 4 - Regional Disaster Recovery (DR)

[Previous Challenge Solution](../challenge-03/solution-03.md) - **[Home](../../Readme.md)** - [Next Challenge Solution](../challenge-05/solution-05.md)

⏰ Duration: 1 hour

## Solution Overview

This challenge focuses on implementing zone-to-zone disaster recovery within a single Azure region using Azure Site Recovery. You will configure replication between Availability Zones in Germany West Central and simulate a failover to demonstrate DR capabilities within the same region.

## Prerequisites

Ensure the lab environment from Challenge 2 is successfully deployed with:
- Linux VM (`mh-linux`) deployed in Germany West Central in a specific Availability Zone
- Recovery Services Vault in Germany West Central

## Task 1: Set up disaster recovery for the Linux VM across Availability Zones

### Enable Zone-to-Zone Disaster Recovery

1. Navigate to the Linux VM in Germany West Central
2. Go to **Disaster recovery** in the left menu
3. Configure zone-to-zone disaster recovery:
   - Source: Current Availability Zone
   - Target: Different Availability Zone in Germany West Central
   - Select the Recovery Services Vault in Germany West Central

4. Review and start replication

5. Monitor the replication status until it completes
   - Initial replication may take 15-30 minutes
   - Verify replication health shows as "Healthy"

> **Note:** Zone-to-zone DR protects against datacenter-level failures within a region by replicating your VM to a different Availability Zone in the same region.

## Task 2: Simulate a zone-to-zone failover

### Perform Test Failover

1. Navigate to the Linux VM's Disaster Recovery blade
2. Select **Test failover** from the top menu
3. Choose a recovery point (typically "Latest" is selected by default)
4. Select the target virtual network in the same region
5. Start the test failover

### Monitor Failover Progress

1. Navigate to **Site Recovery jobs** in the Recovery Services Vault
2. Monitor the test failover job
3. Verify a test VM is created in the target Availability Zone

### Validate the Test VM

1. Check the Virtual Machines list
2. Verify the test VM is running in a different Availability Zone
3. Optional: Connect to the test VM to validate functionality

### Cleanup Test Failover

1. Return to the Disaster Recovery blade
2. Select **Cleanup test failover**
3. Add notes about the test results
4. Complete the cleanup to remove the test VM

## Success Criteria Validation ✅

Confirm you have completed:
- ✅ Enabled disaster recovery for the Linux VM between Availability Zones
- ✅ Successfully performed a test failover to another Availability Zone
- ✅ Validated the test VM functionality
- ✅ Cleaned up the test failover resources

You have successfully completed Challenge 4! 🚀

## Additional Notes

**Zone-to-Zone DR Benefits:**
- Protection against datacenter-level failures
- Lower latency than region-to-region replication
- Same-region data residency compliance
- Faster failover and failback operations

**Best Practices:**
- Regularly test failover to ensure DR readiness
- Monitor replication health continuously
- Document recovery procedures
- Update recovery plans as infrastructure changes

