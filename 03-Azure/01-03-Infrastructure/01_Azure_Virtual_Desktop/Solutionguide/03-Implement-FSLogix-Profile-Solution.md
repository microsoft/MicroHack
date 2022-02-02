## Exercise 3: Create FSLogix Profile Solution

Duration: 45 minutes


[Previous Challenge Solution](./02-multi-session-Hostpools-solution.md) - **[Home](../readme.md)** - **[Next Challenge Solution](04-start-VM-on-connect-solution.md)**

**Additional Resources**

  |              |            |  
|----------|:-------------:|
| Description | Links |
| Create an Azure file share | https://docs.microsoft.com/en-us/azure/storage/files/storage-how-to-create-file-share?tabs=azure-portal |
|Create a profile container with Azure Files and Azure Active Directory  |  https://docs.microsoft.com/en-us/azure/virtual-desktop/create-profile-container-azure-ad   | 
  |              |            | 


### Task 1: Create a storage account
Azure file shares are deployed into storage accounts, which are top-level objects that represent a shared pool of storage. This pool of storage can be used to deploy multiple file shares.

Azure supports multiple types of storage accounts for different storage scenarios customers may have, but there are two main types of storage accounts for Azure Files. Which storage account type you need to create depends on whether you want to create a standard file share or a premium file share:

General purpose version 2 (GPv2) storage accounts: GPv2 storage accounts allow you to deploy Azure file shares on standard/hard disk-based (HDD-based) hardware. In addition to storing Azure file shares, GPv2 storage accounts can store other storage resources such as blob containers, queues, or tables. File shares can be deployed into the transaction optimized (default), hot, or cool tiers.

FileStorage storage accounts: FileStorage storage accounts allow you to deploy Azure file shares on premium/solid-state disk-based (SSD-based) hardware. FileStorage accounts can only be used to store Azure file shares; no other storage resources (blob containers, queues, tables, etc.) can be deployed in a FileStorage account.To create a storage account via the Azure portal, select + Create a resource from the dashboard. In the resulting Azure Marketplace search window, search for storage account and select the resulting search result. This will lead to an overview page for storage accounts; select Create to proceed with the storage account creation wizard.

03-create-storage-account-0.png
03-files-create-smb-share-performance-premium.png
