# NSX DHCP

[Previous Challenge](./11-NSX-Firewall.md) - **[Home](../Readme.md)** - [Next Challenge](./13-AVS-Managed-SNAT.md)

## Introduction

In Azure VMware Solution, clusters in a private cloud are a managed resource. As a result, the CloudAdmin role can't make certain changes to the cluster from the vSphere Client, including the management of Distributed Resource Scheduler (DRS) rules.

The placement policy feature is available in all Azure VMware Solution regions. Placement policies let you control the placement of virtual machines (VMs) on hosts within a cluster through the Azure portal. When you create a placement policy, it includes a DRS rule in the specified vSphere cluster. It also includes additional logic for interoperability with Azure VMware Solution operations.

A placement policy has at least five required components:

Name - Defines the name of the policy and is subject to the naming constraints of Azure Resources.

Type - Defines the type of control you want to apply to the resources contained in the policy.

Cluster - Defines the cluster for the policy. The scope of a placement policy is a vSphere cluster, so only resources from the same cluster may be part of the same placement policy.

State - Defines if the policy is enabled or disabled. In certain scenarios, a policy might be disabled automatically when a conflicting rule gets created. For more information, see Considerations below.

Virtual machine - Defines the VMs and hosts for the policy. Depending on the type of rule you create, your policy may require you to specify some number of VMs and hosts. For more information, see Placement policy types below.

Prerequisite
You must have Contributor level access to the private cloud to manage placement policies.

Placement policy types
VM-VM policies
VM-VM policies specify if selected VMs should run on the same host or must be kept on separate hosts. In addition to choosing a name and cluster for the policy, VM-VM policies require that you select at least two VMs to assign. The assignment of hosts isn't required or permitted for this policy type.

VM-VM Affinity policies instruct DRS to try to keeping the specified VMs together on the same host. It's useful for performance reasons, for example.

VM-VM Anti-Affinity policies instruct DRS to try keeping the specified VMs apart from each other on separate hosts. It's useful in availability scenarios where a problem with one host doesn't affect multiple VMs within the same policy.

VM-Host policies
VM-Host policies specify if selected VMs can run on selected hosts. To avoid interference with platform-managed operations such as host maintenance mode and host replacement, VM-Host policies in Azure VMware Solution are always preferential (also known as "should" rules). Accordingly, VM-Host policies may not be honored in certain scenarios. For more information, see Monitor the operation of a policy below.

Certain platform operations dynamically update the list of hosts defined in VM-Host policies. For example, when you delete a host that is a member of a placement policy, the host is removed if more than one host is part of that policy. Also, if a host is part of a policy and needs to be replaced as part of a platform-managed operation, the policy is updated dynamically with the new host.

In addition to choosing a name and cluster for the policy, a VM-Host policy requires that you select at least one VM and one host to assign to the policy.

VM-Host Affinity policies instruct DRS to try running the specified VMs on the hosts defined.

VM-Host Anti-Affinity policies instruct DRS to try running the specified VMs on hosts other than those defined.

## Challenge 

## Success Criteria

## Learning resources

### Solution - Spoilerwarning

[Solution Steps](../Solutionguide/12-AVS-Placement-Policy.md)