# Exercise 7: Customize RDP Properties

[Previous Challenge](./06-scaling-plan.md) - **[Home](../Readme.md)** - [Next Challenge](./08-Configure-MFA.md)

## Introduction
Azure Virtual Desktop enables you to configure and customize Remote Desktop Protocol (RDP) properties for a host pool. 

Customizing a host pool's Remote Desktop Protocol (RDP) properties, such as multi-monitor experience and audio redirection, lets you deliver an optimal experience for your users based on their needs. 

If you'd like to change the default RDP file properties, you can customize RDP properties in Azure Virtual Desktop by either using the Azure portal or by using the -CustomRdpProperty parameter in the Update-AzWvdHostPool cmdlet.

## Challenge 

- Personal Host pool
    - Deny storage, networkdrive and printers redirection.
    - Allow Camera, Microphone and Copy&Paste.
    - Configure single sign-on using Azure AD Authentication
- Pooled (Remote App) Host pool 
    - Allow Multiple Displays
    - Smart Sizing should be enabled
    - Deny Camera, Microphone and Copy&Paste
    - Allow Storage, networkdrive and printer redirection.
    - Configure single sign-on using Azure AD Authentication

## Success Criteria
- Users are assigned to the Host pools appropriate app group
- You can not access local or networkdrives redirected from the personal hostpool
- You can not Copy and Paste from you local devices to the Remote Applications.
- You can automatically log in to your AVD session host thanks to Azure AD authentication.

## Learning Resources
- [Customize RDP Properties](https://learn.microsoft.com/en-us/azure/virtual-desktop/customize-rdp-properties)
- [Supported RDP Properties](https://learn.microsoft.com/en-us/windows-server/remote/remote-desktop-services/clients/rdp-files)
- [Configure single sign-on for Azure Virtual Desktop using Azure AD Authentication](https://learn.microsoft.com/en-us/azure/virtual-desktop/configure-single-sign-on)
