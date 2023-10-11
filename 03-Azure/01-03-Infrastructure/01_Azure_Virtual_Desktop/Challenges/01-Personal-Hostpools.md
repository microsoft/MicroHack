# Exercise 1: Create a host pool for personal desktops

[Previous Challenge](./00-Pre-Reqs.md) - **[Home](../Readme.md)** - [Next Challenge](./02-Create-a-custom-golden-image.md)

## Introduction
In this challenge we will be provisioning our first Host Pool and Session Hosts. You will need to create a personal Host Pool based on the Windows 11 Enterprise image. Once you created the Host Pool you will need to add Session Hosts, assign users to the Host Pool.

## Challenge 
- West Europe Region
- Personal Host Pool via the Azure Portal, with Windows 11 Enterprise from the Gallary
- Metadata located in West Europe
- Domain to join: Microsoft Entra ID (Enroll with Intune “No”)
- Users should be assigned directly to the session host.
- Change the friendly name of the Workspace
- Change the friendly name of the Application Group

## Success Criteria
- Host Pools are created and Session Hosts showing available
- Users are assigned to the appropriate application group of the host pool


## Learning Resources
[Create a host pool](https://learn.microsoft.com/en-us/azure/virtual-desktop/create-host-pools-azure-marketplace?tabs=azure-portal)

[Configure the personal desktop host pool assignment type](https://learn.microsoft.com/en-us/azure/virtual-desktop/configure-host-pool-personal-desktop-assignment-type)
