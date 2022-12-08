# Exercise 6: Customize RDP Properties

[Previous Challenge](./05-scaling-plan.md) - **[Home](../Readme.md)** - [Next Challenge](./07-Configure-MFA.md)

## Introduction
Azure Virtual Desktop enables you to configure and customize Remote Desktop Protocol (RDP) properties for a host pool. 

Customizing a host pool's Remote Desktop Protocol (RDP) properties, such as multi-monitor experience and audio redirection, lets you deliver an optimal experience for your users based on their needs. 

If you'd like to change the default RDP file properties, you can customize RDP properties in Azure Virtual Desktop by either using the Azure portal or by using the -CustomRdpProperty parameter in the Update-AzWvdHostPool cmdlet.

## Challenge 

- Personal Host pool
    - Deny storage, networkdrive and printers redirection.
    - Allow Camera,  Microphone and Copy&Paste.
- Pooled (Remote App) Host pool 
    - Allow Multiple Displays
    - Smart Sizing should be enabled
    - Deny Camera, Microphone and Copy&Paste
    - Allow Storage, networkdrive and printer redirection.

## Success Criteria
- Host pools are created and Session Hosts showing available
- Users are assigned to the Host pools appropriate app group
- You can not access local or networkdrives redirected from the personal hostpool
- You can not Copy and Paste from you local devices to the Remote Applications.

## Learning Resources
- [Customize RDP Properties](https://learn.microsoft.com/en-us/azure/virtual-desktop/customize-rdp-properties)
- [Supported RDP Properties](https://learn.microsoft.com/en-us/windows-server/remote/remote-desktop-services/clients/rdp-files)
