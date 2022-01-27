# Challenge 2: Multi-Session Hostpools
[Previous Challenge](./01-Personal-Hostpools.md) - **[Home](../readme.md)** - [Next Challenge](./xxx.md)

## Introduction
In this challenge you will create Azure Active Directory joined pooled desktops used as a jump box. After deployment you will connect to the jumpbox, deploy Notepad, 
create an Image and upload the image to the Image gallery. You will deploy a new hostpool and deploy 2 Session hosts from this image. 
Then you will provide Remote Apps to user

## Challenge
Create multi-session Hostpool joined in Azure AD
- West Europe Region
- Metadata located in West Europe
- Mark as Validation environment
- Host Pool type: Pooled
- Add 1 Virtual machine with a Windows 10 Enterprise multi-session Version 20H2 + Microsoft 365 Apps Gallery image  
- Domain to join: Azure Active Directory (Enroll with Intune “No”)
- Register desktop app group to new workspace
- Assign users

Login to the session host and create image
- Login as a user with local administrative privileges (Assign user access to Host Pools)
- Install Notepad++
- Create Image with generalized option and upload it to the shared image gallery

Deploy session host with recently created image
- Add 2 new virtual machines to the Host Pool
- Choose your recently created image
- Deploy Notepad++ as Remote App

NOTE: ALL HOST POOLS MUST BE CONFIGURED AS VALIDATION POOLS

## Success Criteria
1.	Host Pools are created and Session Hosts are showing available
2.	Users are assigned to the HostPool's appropriate app group
3.	Able to show the Host Pool settings configured.
4.	VMs are joined to AAD
5.	users can sign in to the VM.
6.	Notepad++ is installed on all VMs within the pooled Hostpool and can be accessed via RemoteApp

## Learning Resources
- [Create Azure Virtual Desktop Hostpool](https://docs.microsoft.com/de-de/azure/virtual-desktop/create-host-pools-azure-marketplace?tabs=azure-portal)
- [Deploy Azure AD joined VMs in Azure Virtual Desktop](https://docs.microsoft.com/en-us/azure/virtual-desktop/deploy-azure-ad-joined-vm)
- [Capture an image of a VM using the portal](https://docs.microsoft.com/en-us/azure/virtual-machines/capture-image-portal)
- [Manage app groups for Azure Virtual Desktop portal](https://docs.microsoft.com/en-us/azure/virtual-desktop/manage-app-groups)
- [Connect with the Windows Desktop Client](https://docs.microsoft.com/en-us/azure/virtual-desktop/user-documentation/connect-windows-7-10#install-the-windows-desktop-client)

## Disclaimer
##### Azure AD joined virtual machines currently supported configurations *(public preview Feature)*

The following configurations are currently supported with Azure AD-joined VMs:
- Personal desktops with local user profiles.
- Pooled desktops used as a jump box. In this configuration, users first access the Azure Virtual Desktop VM before connecting to a different PC on the network. Users shouldn't save data on the VM.
- Pooled desktops or apps where users don't need to save data on the VM. For example, for applications that save data online or connect to a remote database. User accounts can be cloud-only or hybrid users from the same Azure AD tenant.






