# Exercise 2: Create a custom golden image

[Previous Challenge](./01-Personal-Hostpools.md) - **[Home](../Readme.md)** - [Next Challenge](./03-start-VM-on-connect.md)

## Introduction
In this challenge we will create a custom golden image from a plain Azure VM. Before we generalize the Azure VM you will connect to it from your personal host pool as it sits in the same vnet and access over the private IP should be possible. Afterwards applications are installed and configuration changes are made. Then you will generalize the image and upload the image to the Azure Compute Gallery from which you can deploy new host pools in the following challenges.

## Challenge 
- West Europe Region
- Create a standard Azure VM with a multi-session marketplace image
- Login as a user with local administrative privileges
- Install Notepad++ and VSCode
- Create Image with generalized option and upload it to the shared image gallery

## Success Criteria
- Custom Image is available in the Azure Compute Gallery


## Learning Resources
[Create a golden image in Azure](https://learn.microsoft.com/en-us/azure/virtual-desktop/set-up-golden-image)

[Capture an image of a VM using the portal](https://learn.microsoft.com/en-us/azure/virtual-machines/capture-image-portal)
