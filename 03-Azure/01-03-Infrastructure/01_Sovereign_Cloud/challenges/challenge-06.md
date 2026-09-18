# Challenge 6 - Operating a Sovereign Hybrid Cloud with Azure Arc & Azure Local

[Previous Challenge](challenge-05.md) - **[Home](../Readme.md)** - [Next Challenge](challenge-07.md)

## Goal

The goal of this challenge is to operate a sovereign hybrid cloud environment by combining Microsoft Sovereign Public Cloud and Sovereign Private Cloud components. You will work with Azure Local, simulated via Azure Arc Jumpstart LocalBox, and provision your own VM. You will use Azure Arc to manage that VM through Azure, review its security posture with Microsoft Defender for Cloud, and assess its OS updates with Azure Update Manager.

## Scenario

Your organization must run workloads in a sovereign cloud while still leveraging Azure's management and governance capabilities. Azure Local represents your sovereign on-premises infrastructure, and Azure Arc enables you to apply consistent governance across your hybrid estate.

## Actions

* Explore the LocalBox hybrid infrastructure in the Azure Portal
* Deploy your own VM on Azure Local using Azure Arc VM management and verify that guest management is connected
* Verify Microsoft Defender for Cloud coverage and review security recommendations for the VM you provisioned
* Use Azure Update Manager to assess OS updates on the VM you provisioned

## Success criteria

* You can navigate and understand the LocalBox hybrid environment in the Azure Portal
* You have deployed your own VM on Azure Local via the Azure Portal and verified that guest management is Enabled (Connected)
* You have verified Defender for Servers coverage for your VM and reviewed its available recommendations, or identified that its assessment is still pending
* You have completed an Azure Update Manager assessment for your VM and reviewed the results, including when no updates are pending
* You understand how Azure Arc provides a unified control plane for sovereign hybrid scenarios

## Learning resources

* [Azure Arc-enabled Servers overview (background for guest management)](https://learn.microsoft.com/azure/azure-arc/servers/overview)
* [Azure Local hybrid capabilities](https://learn.microsoft.com/azure/azure-local/hybrid-capabilities-with-azure-services-23h2)
* [Create Azure Local VMs](https://learn.microsoft.com/azure/azure-local/manage/create-arc-virtual-machines)
* [Enable guest management on Azure Local VMs](https://learn.microsoft.com/azure/azure-local/manage/manage-arc-virtual-machines#enable-guest-management)
* [Microsoft Defender for Cloud with Arc-enabled servers](https://learn.microsoft.com/azure/defender-for-cloud/quickstart-onboard-machines)
* [Azure Update Manager overview](https://learn.microsoft.com/azure/update-manager/overview)
* [Azure Arc Jumpstart - LocalBox](https://jumpstart.azure.com/azure_jumpstart_localbox)

## Solution

> [!TIP]
> We encourage you to try solving the challenge on your own before looking at the solution. This will help you learn and understand the concepts better.

<details>
<summary>Click here to view the solution</summary>

[Solution for Challenge 6](../walkthrough/challenge-06/solution-06.md)

</details>
