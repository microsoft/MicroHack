# Challenge 1 - Azure Arc prerequisites & onboarding

**[Home](../Readme.md)** - [Next Challenge Solution](challenge-02.md)

## Goal

In challenge 1 you will prepare your Azure environemnt for onboarding of existing Windows- and Linux servers and onboard them to Azure Arc.

## Actions

- Verify all necessary Azure resources are in place
  - Resource Group (Name: mh-arc-servers-rg)
  - Service Principal (Name: mh-arc-servers-sp)
- Service Principal (Name: LabUser-xx-arc-servers-sp)
- Enable required Resource Providers (if not already enabled)
- Prep existing servers` operating system on-prem
  - Hint: We are using Azure VMs to simulate on-prem servers
- Onboard existing servers to Azure Arc
  - win2012-vm may be skipped unless you plan to do the optional Challenge 6 (Extended Security Updates)

## Success criteria

- You created an Azure resource group
- You created an service principal with the required role membership
- Successfully prepared existing servers
- Onboarded servers which is visible in the Azure Arc machines blade in the Azure Portal

## Learning resources

- [Plan and deploy Azure Arc-enabled servers](https://learn.microsoft.com/azure/azure-arc/servers/plan-at-scale-deployment)
- [Prerequisites for Connect hybrid machines with Azure Arc-enabled servers](https://learn.microsoft.com/azure/azure-arc/servers/learn/quick-enable-hybrid-vm#prerequisites)
- [Connect hybrid machines with Azure Arc-enabled servers](https://learn.microsoft.com/azure/azure-arc/servers/learn/quick-enable-hybrid-vm#generate-installation-script)
- [Create a service principal for onboarding](https://learn.microsoft.com/azure/azure-arc/servers/onboard-service-principal#create-a-service-principal-for-onboarding-at-scale)
