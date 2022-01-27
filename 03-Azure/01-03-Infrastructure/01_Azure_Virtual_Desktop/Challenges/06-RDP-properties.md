# Exercise 6: RDP Properties

[Previous Challenge](./05-scaling-plan.md) - **[Home](../readne.md)** - [Next Challenge](./xxx.md)

## Introduction
Azure Virtual Desktop enables you to configure and customize Remote Desktop Protocol (RDP) properties for a host pool. This 

Customizing a host pool's Remote Desktop Protocol (RDP) properties, such as multi-monitor experience and audio redirection, lets you deliver an optimal experience for your users based on their needs. If you'd like to change the default RDP file properties, you can customize RDP properties in Azure Virtual Desktop by either using the Azure portal or by using the -CustomRdpProperty parameter in the Update-AzWvdHostPool cmdlet.

## Challenge 
- Personal Hostpool
    - Deny Storage, networkdrive and printers redirection.
    - Allow Camera,  Microphone and Copy&Paste.
- Remote App Pool 
    - Allow Multiple Displays
    - Smart Sizing should be enabled
    - Deny Camera, Microphone and Copy&Paste
    - Allow Storage and networkdrive and printer redirection.

## Success Criteria
- Host Pools are created and Session Hosts showing available
- Users are assigned to the HostPool's appropriate app group
- You can not access local or networkdrives redirected from the personal hostpool
- You can not Copy and Paste from you local devices to the Remote Applications.

## Learning Resources
- [Customize RDP Properties](https://docs.microsoft.com/en-us/azure/virtual-desktop/customize-rdp-properties)
- [Supported RDP Properties](https://docs.microsoft.com/en-us/windows-server/remote/remote-desktop-services/clients/rdp-files?context=%2fazure%2fvirtual-desktop%2fcontext%2fcontext)
