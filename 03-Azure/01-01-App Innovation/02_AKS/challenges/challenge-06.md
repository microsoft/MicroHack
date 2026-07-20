# Challenge 6 - Persistent Storage in AKS

[Previous Challenge](challenge-05.md) - **[Home](../Readme.md)** - [Next Challenge](challenge-07.md)

## Goal 

The goal of this exercise is to configure persistent storage for your applications using Azure Disks and Azure Files. You'll understand the difference between ephemeral and persistent storage, and when to use each Azure storage option.

## Actions

* Test the ephemeral nature of pod storage by deleting and recreating a pod
* Create a PersistentVolumeClaim (PVC) using Azure Disk
* Update your deployment to use the persistent volume
* Verify that data persists across pod deletions
* Understand the differences between Azure Disks and Azure Files

## Success criteria

* You have demonstrated that data is lost when pods are deleted without persistent storage
* You have created a PersistentVolumeClaim using Azure Disk
* You have updated your application deployment to mount the persistent volume
* You can verify that application data persists after pod deletion and recreation
* You understand when to use Azure Disk vs Azure Files for different scenarios

## Learning resources
* [Persistent volumes in AKS](https://learn.microsoft.com/en-us/azure/aks/concepts-storage)
* [Dynamically create Azure Disks PV](https://learn.microsoft.com/en-us/azure/aks/azure-disk-csi)
* [Azure Files for AKS](https://learn.microsoft.com/en-us/azure/aks/azure-files-csi)
