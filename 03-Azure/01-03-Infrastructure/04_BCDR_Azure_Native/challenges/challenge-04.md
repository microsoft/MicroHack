# Challenge 4 - Regional Disaster Recovery (DR)

[Previous Challenge](challenge-03.md) - **[Home](../Readme.md)** - [Next Challenge](challenge-04.md)

### Goal 🎯

* Enable **Disaster Recovery (DR)** in Azure by protecting workloads within a region across multiple Availability Zones (AZs).

In this challenge, you will learn how to protect VM's with Azure Site Recovery and Azure Recovery Services Vaults. You will also practice simulating a regional failover between two Availability Zones (AZ) to handle a regional failure, such as a datacenter outage.

![Azure Site Recovery Architecture - zone-to-zone](../img/c4-azure-site-recovery-cross-az.png)

## Actions

### Enable Disaster Recover (DR) in Azure within an Azure Region across Availability Zones.
1. Set up disaster recovery for the Linux VM in the primary region.
2. Simulate a zone-to-zone failover in the primary region.

### Success Criteria ✅

- You have successfully enabled disaster recovery between availability zones of an Azure VM.
- You have successfully simulated a failover of the VM to another Availability Zone within the Region, using Azure Site Recovery.

### 📚 Learning Resources

- [Setup Azure VM disaster recovery between availability zones](https://learn.microsoft.com/en-us/azure/site-recovery/azure-to-azure-how-to-enable-zone-to-zone-disaster-recovery)