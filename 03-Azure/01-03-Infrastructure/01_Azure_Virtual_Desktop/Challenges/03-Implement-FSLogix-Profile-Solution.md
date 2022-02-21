# Exercise 3: FSLogix Profile Solution

[Previous Challenge](./02-multi-session-Hostpools.md) - **[Home](../readme.md)** - **[Next Challenge](04-start-VM-on-connect.md)**

## Introduction
The Azure Virtual Desktop service recommends FSLogix profile containers as a user profile solution. FSLogix is designed to roam profiles in Azure Virtual Desktop, mostly needed for multi-session with floating user scenarios. It stores a complete user profile in a single container. At sign in, this container is dynamically attached to the computing environment using natively supported Virtual Hard Disk (VHD) and Hyper-V Virtual Hard disk (VHDX). The user profile is immediately available and appears in the system exactly like a native user profile. 

In this challenge, you'll learn how to:

Setup and configure an Azure storage account for authentication using Azure ADDS.
Setup an Azure storage account
Assign access permissions to an identity
create a profile container with FSLogix for your session hosts in your multi-session Hostpool 

As a prerequisite for this Microhack, you've already set up an Azure AD DS instance. 

### Task 1: Set up an Azure Storage account
    
### Task 2: Assign access permissions to an identity

### Task 3: Create a profile container with FSLogix

       

## Success Criteria





### Learning Resources
- [Create a profile container with Azure Files and Azure Active Directory (preview)](https://docs.microsoft.com/en-us/azure/virtual-desktop/create-profile-container-azure-ad)
- [Create a storage account for Azure File Shares](https://docs.microsoft.com/en-us/azure/storage/files/storage-how-to-create-file-share?tabs=azure-portal#create-a-storage-account)
- [Configure FSLogix for the Enterprise](https://docs.microsoft.com/en-us/azure/architecture/example-scenario/wvd/windows-virtual-desktop-fslogix)

