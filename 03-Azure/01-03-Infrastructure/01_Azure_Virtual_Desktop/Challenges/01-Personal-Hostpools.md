# Exercise 1: RDP Personal Hostpools

[Previous Challenge](./00-Pre-Reqs.md) - **[Home](../readme.md)** - **[Next Challenge](02-multi-session-Hostpools.md)**

## Introduction
In this challenge we will be provisioning our first Host Pools and Session Hosts. You will need to create a personal Host Pools based on the Windows 10 Enterprise image. Once you created the Host Pools you will need to add Session Hosts, assign users to the Host Pools.

## Challenge 
- West Europe Region
- Personal Host Pool via the Azure Portal, with Windows 10 Enterprise from the Gallary
- Metadata located in West Europe
- Users should be assigned directly to the session host.
- Change the friendly name of the Workspace
- Change the friendly name of the Application Group

## Success Criteria
- Host Pools are created and Session Hosts showing available
- Users are assigned to the HostPool's appropriate app group

## Disclaimer
##### Azure AD joined virtual machines currently supported configurations *(public preview Feature)*

The following configurations are currently supported with Azure AD-joined VMs:
- Personal desktops with local user profiles.
- Pooled desktops used as a jump box. In this configuration, users first access the Azure Virtual Desktop VM before connecting to a different PC on the network. Users shouldn't save data on the VM.
- Pooled desktops or apps where users don't need to save data on the VM. For example, for applications that save data online or connect to a remote database. User accounts can be cloud-only or hybrid users from the same Azure AD tenant.

## Learning Resources
[Customize RDP Properties](https://docs.microsoft.com/en-us/azure/virtual-desktop/customize-rdp-properties)
