# Challenge 7 - Backup and Restore with Azure Backup for AKS

[Previous Challenge](challenge-06.md) - **[Home](../Readme.md)** - [Next Challenge](challenge-08.md)

## Goal 

The goal of this exercise is to protect your AKS workloads using Azure Backup extension. You'll configure backup for your cluster, perform a backup of your application, and restore it to demonstrate disaster recovery capabilities.

## Actions

* Create an Azure Storage Account and Blob container for backup storage
* Create an Azure Backup Vault
* Install the Azure Backup extension on your AKS cluster
* Configure backup policy and perform an on-demand backup
* Simulate a disaster scenario by deleting resources
* Restore your application from the backup

## Success criteria

* You have created a Backup Vault and configured it for AKS
* You have successfully installed the Backup extension on your AKS cluster
* You have performed a successful backup of your application and namespace
* You can delete application resources to simulate a disaster
* You have successfully restored your application from the backup
* All application data and configurations are recovered after restore

## Learning resources
* [Azure Backup for AKS](https://learn.microsoft.com/en-us/azure/backup/azure-kubernetes-service-backup-overview)
* [Back up AKS using Azure Backup](https://learn.microsoft.com/en-us/azure/backup/azure-kubernetes-service-cluster-backup)
* [Restore AKS using Azure Backup](https://learn.microsoft.com/en-us/azure/backup/azure-kubernetes-service-cluster-restore)
