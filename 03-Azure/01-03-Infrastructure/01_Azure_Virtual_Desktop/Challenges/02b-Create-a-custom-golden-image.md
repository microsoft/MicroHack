# Exercise 2: Create a custom golden image

[Previous Challenge](./01-Personal-Hostpools.md) - **[Home](../Readme.md)** - [Next Challenge](./03-multi-session-Hostpools.md)

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
| Install Visual Studio Code and Notepad++ | Via own script |  

## Success Criteria
- Custom Image is available in the Azure Compute Gallery


## Learning Resources
[Create a golden image in Azure](https://learn.microsoft.com/en-us/azure/virtual-desktop/set-up-golden-image)

[Custom image templates in Azure Virtual Desktop (preview)](https://learn.microsoft.com/en-us/azure/virtual-desktop/custom-image-templates)
