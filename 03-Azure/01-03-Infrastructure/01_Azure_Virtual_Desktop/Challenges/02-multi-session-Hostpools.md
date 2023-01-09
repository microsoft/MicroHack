# Exercise 2: Create a host pool for multi-session
[Previous Challenge](./01-Personal-Hostpools.md) - **[Home](../Readme.md)** - [Next Challenge](./03-Implement-FSLogix-Profile-Solution.md)

## Introduction
In this challenge you will create Azure AD joined pooled desktops. After deployment you will connect to the session host, deploy Notepad, create an Image and upload the image to the Image gallery. You will deploy a new hostpool and deploy 2 Session hosts from this image. Then you can provide remote apps to your users.

## Challenge
Create multi-session Hostpool joined in Azure Active Directory
- West Europe Region
- Metadata located in West Europe
- Mark as Validation environment
- Host Pool type: Pooled
- Add 1 Virtual machine with a Windows 11 Enterprise multi-session Version + Microsoft 365 Apps Gallery image  
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

## Success Criteria
1.	Host Pools are created and Session Hosts are showing available
2.	Users are assigned to the appropriate application group of the host pool
3.	Able to show the Host Pool settings configured.
4.	VMs are joined to Azure AD
5.	Users can sign in to the VM.
6.	Notepad++ is installed on all VMs within the pooled Hostpool and can be accessed via RemoteApp

## Learning Resources
- [Create Azure Virtual Desktop Hostpool](https://learn.microsoft.com/en-us/azure/virtual-desktop/create-host-pools-azure-marketplace)
- [Capture an image of a VM using the portal](https://learn.microsoft.com/en-us/azure/virtual-machines/capture-image-portal)
- [Manage app groups for Azure Virtual Desktop portal](https://learn.microsoft.com/en-us/azure/virtual-desktop/manage-app-groups)
- [Connect to Azure Virtual Desktop with the Remote Desktop client for Windows](https://learn.microsoft.com/en-us/azure/virtual-desktop/users/connect-windows?tabs=subscribe#install-the-windows-desktop-client)








