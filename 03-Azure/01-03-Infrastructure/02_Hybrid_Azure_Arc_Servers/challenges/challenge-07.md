# Challenge 7 - Azure Automanage Machine Configuration - optional

[Previous Challenge Solution](challenge-06.md) - **[Home](../Readme.md)** - [Next Challenge Solution](finish.md)

## Goal

This challenge is about interacting with the client operating system. We will have a look at Machine Configurations as the final step of this journey.

## Actions

- Create all necessary Azure resources
  - Azure Storage account
- Setup a Policy that checks if the user "FrodoBaggins" is part of the local administrators group
- Setup a Custom Machine Configuration, for the Windows Server, that creates a registry key in ``` HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment\ ```

## Success criteria

- You can view the compliance state of the Administrator Group Policy
- You can show the registry key being present on the Windows Server

## Learning resources

- [Understand the machine configuration feature of Azure Automanage](https://learn.microsoft.com/azure/governance/machine-configuration/overview)
- [How to setup a machine configuration authoring environment](https://learn.microsoft.com/azure/governance/machine-configuration/machine-configuration-create-setup)
- [How to create custom machine configuration package artifacts](https://learn.microsoft.com/azure/governance/machine-configuration/machine-configuration-create)
- [How to create custom machine configuration policy definitions](https://learn.microsoft.com/azure/governance/machine-configuration/machine-configuration-create-definition)
- [Create SAS tokens for storage containers](https://learn.microsoft.com/azure/applied-ai-services/form-recognizer/create-sas-tokens)

