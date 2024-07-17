# Exercise 1: Create a host pool for personal desktops

[Previous Challenge](./00-Pre-Reqs.md) - **[Home](../Readme.md)** - [Next Challenge](./02-Create-a-custom-golden-image.md)

## Introduction
In this challenge we will be provisioning our first Host Pool and Session Hosts. You will need to create a personal Host Pool based on the Windows 11 Enterprise image. Once you created the Host Pool you will need to add Session Hosts, assign users to the Host Pool.

## Challenge 
- Region: Sweden Central 
- Personal Host Pool via the Azure Portal, with Windows 11 Enterprise from the Gallary
- Metadata located in West Europe
- Domain to join: Microsoft Entra ID (Enroll with Intune “No”)
- Users should be assigned directly to the session host.
- Change the friendly name of the Workspace
- Change the friendly name of the Desktop Application

## Success Criteria
- Host Pools are created and Session Hosts showing available
- Users are assigned to the appropriate application group of the host pool

## 💡 Pro Tipps 💡
> **1.** We are deploying an EntraID only host pool. In this case you have to set IAM (RBAC) rights on the resource group level. [More information here](https://learn.microsoft.com/en-us/azure/virtual-desktop/azure-ad-joined-session-hosts#assign-user-access-to-host-pools)

> **2.** If you are trying to access your virtual desktop from **Windows devices or other devices that are not connected to the same Entra ID tenant**, add **targetisaadjoined:i:1** as a custom RDP property to the host pool. [More information here](https://learn.microsoft.com/en-us/azure/virtual-desktop/deploy-azure-ad-joined-vm#access-azure-ad-joined-vms)

## Learning Resources
- [Create a host pool](https://learn.microsoft.com/en-us/azure/virtual-desktop/create-host-pools-azure-marketplace?tabs=azure-portal)
- [Configure the personal desktop host pool assignment type](https://learn.microsoft.com/en-us/azure/virtual-desktop/configure-host-pool-personal-desktop-assignment-type)
- [Deploy Microsoft Entra joined VMs](https://learn.microsoft.com/en-us/azure/virtual-desktop/azure-ad-joined-session-hosts#deploy-microsoft-entra-joined-vms)
- [Connect to Azure Virtual Desktop with the Remote Desktop client for Windows](https://learn.microsoft.com/en-us/azure/virtual-desktop/users/connect-windows?tabs=subscribe&pivots=remote-desktop-msi#install-the-windows-desktop-client)
