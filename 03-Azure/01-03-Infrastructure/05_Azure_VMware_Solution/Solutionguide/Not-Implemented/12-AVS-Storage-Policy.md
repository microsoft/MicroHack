# Exercise 13: Configure storage policy

[Previous Challenge Solution](./12-AVS-ANF-Datastores.md) - **[Home](../Readme.md)** - [Next Challenge Solution](./14-AVS-Placement-Policy.md)

## List storage policies
You'll run the Get-StoragePolicy cmdlet to list the vSAN based storage policies available to set on a VM.

Sign in to the Azure portal.

Select Run command > Packages > Get-StoragePolicies.

![](./Images/13-AVS-Storage-Policy/run-command-overview-storage-policy.png) 

Provide the required values or change the default values, and then select Run.

![](./Images/13-AVS-Storage-Policy/run-command-get-storage-policy.png)

Check Notifications to see the progress.

## Set storage policy on VM

You'll run the Set-VMStoragePolicy cmdlet to modify vSAN-based storage policies on a default cluster, individual VM, or group of VMs sharing a similar VM name. For example, if you have three VMs named "MyVM1", "MyVM2", and "MyVM3", supplying "MyVM*" to the VMName parameter would change the StoragePolicy on all three VMs.

Select Run command > Packages > Set-VMStoragePolicy.

Provide the required values or change the default values, and then select Run.

Check Notifications to see the progress.

## Set storage policy on all VMs in a location

You'll run the Set-LocationStoragePolicy cmdlet to Modify vSAN based storage policies on all VMs in a location where a location is the name of a cluster, resource pool, or folder. For example, if you have 3 VMs in Cluster-3, supplying "Cluster-3" would change the storage policy on all 3 VMs.

Select Run command > Packages > Set-LocationStoragePolicy.

Provide the required values or change the default values, and then select Run.

Check Notifications to see the progress.

## Specify storage policy for a cluster

You'll run the Set-ClusterDefaultStoragePolicy cmdlet to specify default storage policy for a cluster,

Select Run command > Packages > Set-ClusterDefaultStoragePolicy.

Provide the required values or change the default values, and then select Run.

Check Notifications to see the progress.