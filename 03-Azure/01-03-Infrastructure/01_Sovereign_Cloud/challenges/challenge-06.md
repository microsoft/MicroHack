# Challenge 6 (optional) - Operating a Sovereign Hybrid Cloud with Azure Arc & Azure Local

[Previous Challenge Solution](challenge-05.md) - **[Home](../Readme.md)** - [Next Challenge Solution](finish.md)

## Goal

The goal of this challenge is to operate a sovereign hybrid cloud environment by combining Microsoft Sovereign Public Cloud and Sovereign Private Cloud components. You will work with Azure Local (simulated via LocalBox) as a sovereign on-premises cloud environment and use Azure Arc to bridge on-premises resources with Azure for unified governance, security, and management.

## Scenario

Your organization must run workloads in a sovereign cloud while still leveraging Azure's management and governance capabilities. Azure Local represents your sovereign on-premises infrastructure, and Azure Arc enables you to apply consistent governance across your hybrid estate.

## Actions

* Explore the ArcBox and LocalBox hybrid infrastructure in the Azure Portal
* Navigate Arc-enabled servers and understand their Azure resource representation
* Assign Azure Policy with Machine Configuration to audit/enforce OS settings on Arc-enabled Linux servers
* Deploy a VM on Azure Local using Azure Arc VM management
* Enable and review Microsoft Defender for Cloud security posture for Arc-enabled resources
* Explore Azure Update Manager for hybrid patching across Arc-connected machines

## Success criteria

* You can navigate and understand the ArcBox/LocalBox hybrid environment in the Azure Portal
* You have successfully assigned an Azure Policy (e.g., SSH security baseline) to Arc-enabled servers
* You can verify the compliance status of Arc-enabled servers in the Azure Policy dashboard
* You have deployed a VM on Azure Local via the Azure Portal
* You have enabled Microsoft Defender for Cloud and reviewed security recommendations for hybrid resources
* You understand how Azure Arc provides a unified control plane for sovereign hybrid scenarios

## Learning resources

* [Azure Arc-enabled Servers overview](https://learn.microsoft.com/azure/azure-arc/servers/overview)
* [Azure Local hybrid capabilities](https://learn.microsoft.com/azure/azure-local/hybrid-capabilities-with-azure-services-23h2)
* [Azure Machine Configuration (Guest Configuration)](https://learn.microsoft.com/azure/governance/machine-configuration/overview)
* [Azure Policy built-in definitions for Arc-enabled servers](https://learn.microsoft.com/azure/azure-arc/servers/policy-reference)
* [Microsoft Defender for Cloud with Arc-enabled servers](https://learn.microsoft.com/azure/defender-for-cloud/quickstart-onboard-machines)
* [Azure Arc Jumpstart - LocalBox](https://jumpstart.azure.com/azure_jumpstart_localbox)
* [Govern Azure Arc-enabled servers (Microsoft Learn Training)](https://learn.microsoft.com/training/modules/govern-azure-arc-enabled-servers/)

