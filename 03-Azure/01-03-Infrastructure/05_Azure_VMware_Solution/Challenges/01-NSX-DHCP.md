# NSX DHCP

[Previous Challenge](./00-Pre-Reqs.md) - **[Home](../Readme.md)** - [Next Challenge](./02-NSX-Add-Segment.md)

## Introduction

In this challenge we will configure a NSX-T DHCP server.

## Challenge

In this challenge, you will perform the following tasks:

1. Create a DHCP server
2. Check the DHCP configuration in NSX-T

As a part of this challenge you are expected to <u>log on to the AVS Private cloud within Azure Portal</u> assigned to your team and to deploy a DHCP server, such that we can provide dynamic IPs to VMs when they need.  

### Use Case Tip 

VMs within the AVS environment will recieve IP from various sources 

1. Some VMs may be migrated and they will retain their IPs from On-Prem to AVS if they are on an extended L2 stretch
2. Some VMs may be migrated and they will need new IP from AVS if they are on a non-extended VLAN. in such cases the VM will get a new IP (DHCP based) or static IP
3. Some VMs may be created locally within AVS and thats then they will either be provided static or dynamic IP

Feel free to reach out to your facilitator in case you have any questions regarding the tabs within the AVS Private Cloud. 

Please carefully follow the instructions provided by your facilitator. 

Work with the instructor to ensure your VMware environment has the required permissions to access your AVS vCenter Server and the NSX Manager.

Applications and workloads running in an Azure VMware Solution private cloud environment require name resolution and DHCP services (optionally) for lookup and IP address assignments. A proper DHCP and DNS infrastructure are required to provide these services. You can configure a virtual machine to provide these services in your private cloud environment.

## Success Criteria

When you login to the NSX Manager in AVS the DHCP server should be configured and running. It should be attached to the Tier 1 gateway.

## Learning resources

[Configure DHCP for Azure VMware Solution](https://learn.microsoft.com/en-us/azure/azure-vmware/configure-dhcp-azure-vmware-solution)

### Solution - Spoilerwarning

[Solution Steps](../Solutionguide/01-NSX-DHCP.md)