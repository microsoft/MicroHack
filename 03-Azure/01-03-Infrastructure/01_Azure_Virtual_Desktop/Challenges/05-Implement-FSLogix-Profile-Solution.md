# Exercise 5: Create FSLogix Profile Solution

[Previous Challenge](./04-multi-session-Hostpools.md) - **[Home](../Readme.md)** - [Next Challenge](./06-scaling-plan.md)

## Introduction
The Azure Virtual Desktop service recommends FSLogix profile containers as a user profile solution. FSLogix is designed to roam profiles in Azure Virtual Desktop, mostly needed for multi-session with floating user scenarios. It stores a complete user profile in a single container. At sign in, this container is dynamically attached to the computing environment using natively supported Virtual Hard Disk (VHD) and Hyper-V Virtual Hard disk (VHDX). The user profile is immediately available and appears in the system exactly like a native user profile. 

In this challenge, you'll learn how to:

Setup and configure an Azure storage account for authentication using Azure AD Kerberos.
Setup an Azure storage account
Assign access permissions to an identity
create a profile container with FSLogix for your session hosts in your multi-session Hostpool 

As a prerequisite for this Microhack, you've already set up hybrid identities. The users and groups must be sourced from a traditional Activate Directory domain.

### Task 1: Set up an Azure Storage account
- Setup an Azure Storage account and a File Share
- enable Azure Active Directory authentication for Azure files
    
### Task 2: Assign access permissions to an identity
- AVD users will nedd access permissions to access the file share. You need to assign each user a role with 
  the appropriate user access permissions

### Task 3: Create a profile container with FSLogix
In order to use profile containers, you'll need to configure FSLogix on your session host VMs. If you're using a custom image that doesn't have the FSLogix Agent already installed, follow the instructions in [Download and install FSLogix](https://docs.microsoft.com/en-us/fslogix/install-ht). 

- Login into your multi-session VMs
- mount your file share and configure NTFS permissions
- allow your Azure Virtual Desktop users to create their own profile container while blocking access to the profile containers from other users
- create a profile container with FSLogix     

## Success Criteria
- Storage Account and File share is setup correctly
- Azure AD Kerberos authentication is enabled on the File share
- Appropriate user access permissions are configured on the file share
- You are able to connect to your session hosts as an Administrator to configure FSLogix (you need to find a solution for this)
- A profile container with FS Logix is created successful
- Make sure your profile works

### Learning Resources
- [Create a storage account for Azure File Shares](https://learn.microsoft.com/en-us/azure/storage/files/storage-how-to-create-file-share?tabs=azure-portal#create-a-storage-account)
- [Create an Azure file share](https://learn.microsoft.com/en-us/azure/storage/files/storage-how-to-create-file-share?tabs=azure-portal)
- [Create a profile container with Azure Files and Azure AD DS](https://learn.microsoft.com/en-us/azure/virtual-desktop/fslogix-profile-container-configure-azure-files-active-directory?tabs=adds)
- [Configure FSLogix for the Enterprise](https://learn.microsoft.com/en-us/azure/architecture/example-scenario/wvd/windows-virtual-desktop-fslogix)
- [Circumvent port 445 issues](https://learn.microsoft.com/en-us/azure/storage/files/storage-files-networking-overview#azure-networking)

