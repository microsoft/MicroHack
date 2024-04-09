# Exercise 5: Create FSLogix Profile Solution

[Previous Challenge](./04-multi-session-Hostpools.md) - **[Home](../Readme.md)** - [Next Challenge](./06-scaling-plan.md)

# Introduction

The Azure Virtual Desktop service recommends FSLogix profile containers as a user profile solution. FSLogix is designed to roam profiles in Azure Virtual Desktop, mostly needed for multi-session with floating user scenarios.

It stores a complete user profile in a single container. At sign in, this container is dynamically attached to the computing environment using natively supported Virtual Hard Disk (VHD) and Hyper-V Virtual Hard disk (VHDX). The user profile is immediately available and appears in the system exactly like a native user profile. 

In this challenge, you'll learn how to:

- Setup and configure an Azure storage account for authentication using Microsoft Entra Kerberos
- Assign access permissions to an identity
- Create a profile container with FSLogix for your session hosts in your multi-session Hostpool 

> **Note**: Hybrid identities are needed for this challenge. The users and groups must come from a traditional Active Directory domain.

### Task 1: Set up an Azure Storage account
- Setup an Azure Storage account and a File Share
- Enable Microsoft Entra Kerberos for Azure files
    
### Task 2: Assign access permissions to an identity
- AVD users will need access permissions to access the file share. You need to assign each user a role with the appropriate user access permissions

### Task 3: Create a profile container with FSLogix
In order to use profile containers, you'll need to configure FSLogix on your session host VMs. 

>**Note:** If you're using a custom image that doesn't have the FSLogix Agent already installed, follow the instructions in [Download and install FSLogix](https://docs.microsoft.com/en-us/fslogix/install-ht). 

>**Note:** The FSLogix agent is already installed on the Windows 10 or 11 Enterprise Multisession Gallery images provided by Microsoft.

- Enable FSLogix profile settings via a script
- Delete local profiles when a VHD profile is applied
- Create a profile container with FSLogix during user login
  
----------------
## Success Criteria

- Storage Account and File share is setup correctly
- Microsoft Entra Kerberos is enabled on the File share
- Appropriate user access permissions are configured on the file share
- A profile container with FSLogix is successfully created 
- Check that your profiles are working as expected

### Learning Resources
- [Create a profile container with Azure Files and Microsoft Entra ID](https://learn.microsoft.com/en-us/azure/virtual-desktop/create-profile-container-azure-ad)
- [Configure FSLogix for the Enterprise](https://learn.microsoft.com/en-us/azure/architecture/example-scenario/wvd/windows-virtual-desktop-fslogix)
- [Configuration Setting Reference](https://learn.microsoft.com/en-us/fslogix/reference-configuration-settings?tabs=profiles)

