# Exercise 2: Create a custom golden image

[Previous Challenge](./01-Personal-Hostpools.md) - **[Home](../Readme.md)** - [Next Challenge](./03-start-VM-on-connect.md)

## Introduction
In this challenge, you will learn about creating a customized Azure Virtual Desktop image using the Azure VM Image Builder and then offering that image through the Azure Compute Gallery. There are several ways to create a custom golden image. This can be done manually by first creating an Azure VM and then generalizing and capturing it. Alternatively, PowerShell commands, ARM templates, or the Custom Image Template feature accessible from the Azure Portal GUI can be used. This feature guides you through the prerequisites and process of using Azure Image Builder. You should use the Custom Image Template in this challenge. 


## Challenge 
- Region: West Europe 
- Create a managed identity that has enough privileges to create a custom image
- Create new Azure Compute Gallery 
- Create a Custom Image Template with the followingen requirements

| Field | Value | Notes
|:---------|:---------|:---------|
| Source Image | Windows 11 Multi-Session 22H2 + M365 Apps Gen 2 |
| Replication Region | West Europe |
| Time zone redirection | Enabled |
| Remove Appx packages | Microsoft.GamingApp; Microsoft.XboxApp; Microsoft.Xbox.TCUI; Microsoft.XboxGameOverlay; Microsoft.XboxGamingOverlay; Microsoft.XboxIdentityProvider; Microsoft.XboxSpeechToTextOverlay; Microsoft.ZuneMusic; Microsoft.ZuneVideo |
| Install Visual Studio Code and Notepad++ | Via own automation script |  [Example](https://raw.githubusercontent.com/microsoft/MicroHack/main/03-Azure/01-03-Infrastructure/01_Azure_Virtual_Desktop/modules/InstallApps.ps1)

## Success Criteria
- Custom Image is available in the Azure Compute Gallery


## Learning Resources
- [Create an Azure Virtual Desktop image by using VM Image Builder and PowerShell](https://learn.microsoft.com/en-us/azure/virtual-machines/windows/image-builder-virtual-desktop)
- [Custom image templates in Azure Virtual Desktop (preview)](https://learn.microsoft.com/en-us/azure/virtual-desktop/custom-image-templates)
- [Use Custom image templates to create custom images in Azure Virtual Desktop (preview)](https://learn.microsoft.com/en-us/azure/virtual-desktop/create-custom-image-templates)
- [Manage user-assigned managed identities](https://learn.microsoft.com/en-us/azure/active-directory/managed-identities-azure-resources/how-manage-user-assigned-managed-identities?pivots=identity-mi-methods-azp)
- [Create or update Azure custom roles using the Azure portal](https://learn.microsoft.com/en-us/azure/role-based-access-control/custom-roles-portal)
- [Azure VM Image Builder overview](https://learn.microsoft.com/en-us/azure/virtual-machines/image-builder-overview?tabs=azure-powershell)
