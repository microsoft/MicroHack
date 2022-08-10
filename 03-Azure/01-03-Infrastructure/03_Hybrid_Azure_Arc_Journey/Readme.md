# **MicroHack Azure Arc - Part I**

[toc]

## MicroHack introduction

What is Azure Arc?

For customers who want to simplify complex and distributed environments across on-premises, edge, and multi-cloud, [Azure Arc](https://azure.microsoft.com/services/azure-arc/) enables deployment of Azure services anywhere and extends Azure management to any infrastructure. Azure Arc helps you accelerate innovation across hybrid and multi-cloud environments and provides the following benefits to your organization:

![image](./IMG/AzureArc-01.png)

- Gain central visibility, operations, and compliance Standardize visibility, operationsand compliance across a wide range of resources and locations by extending the Azure control plane. Right from Azure, you can easily organize, govern, and secure Windows, Linux, SQL Servers and Kubernetes clusters across datacenters, edge, and multi-cloud.

- Build Cloud native apps anywhere, at scale Centrally code and deploy applications confidently to any Kubernetes distribution in any location. Accelerate development by using best in class applications services with standardized deployment, configuration, security, and observability.

- Run Azure services anywhere Flexibly use cloud innovation where you need it by deploying Azure services anywhere. Implement cloud practices and automation to deploy faster, consistently, and at scale with always-up-to-date Azure Arc enabled services.

## MicroHack context

This MicroHack scenario walks through the use of Azure Arc with a focus on the best practices and the design principles and some interesting challenges for real world scenarios. Specifically, this builds up to include working with an existing infrastructure in your datacenter.

Further resources - Thomas Maurer & Lior links


![image](./img/0_azure-stack-hci-solution.png)

This lab is not a full explanation of Azure Stack HCI as a technology, please consider the following articles required pre-reading to build foundational knowledge.

* [What is Azure Stack HCI?](https://docs.microsoft.com/en-us/azure-stack/hci/overview)
* [Watch a video to see a high level overview of the features from Azure Stack HCI](https://youtu.be/fw8RVqo9dcs)
* [eBook: Five Hybrid Cloud Use Cases for Azure Stack HCI](https://aka.ms/technicalusecaseswp)
* [What's new for Azure Stack HCI at Microsoft Ignite 2021](https://techcommunity.microsoft.com/t5/azure-stack-blog/what-s-new-for-azure-stack-hci-at-microsoft-ignite-2021/ba-p/2897222)
* [Azure Stack HCI Solutions](https://hcicatalog.azurewebsites.net/#/)
* [Plan your solution with the sizer tool](https://hcicatalog.azurewebsites.net/#/sizer)
* [Azure Stack HCI FAQ](https://docs.microsoft.com/en-us/azure-stack/hci/faq)

💡 Optional: Read this after completing this lab to deepen the learned!

## Objectives

After completing this MicroHack you will:

* Know how to use Azure Arc in your environment, on-prem or Multi-cloud
* Understand use cases and possible scenarios in your hybrid world to modernize your infrastructure estate
* Get insights into real world challenges and scenarios

## Prerequisites

This MicroHack has a few but very important prerequisites to be understood before starting this lab!

For Arc enabled Servers

* Have an server, windows or linux ready
For windows, pls use if possible Windows Server 2019 or 2022 with the latest patch level

  [Supported operating systems @ Connected Machine agent prerequisites - Azure Arc | Microsoft Docs](https://docs.microsoft.com/en-us/azure/azure-arc/servers/prerequisites#supported-operating-systems)
	
  This Server OS could be hosted as a VM on VMware, Hyper-V, Nutanix, AWS, GCP or bare metal.
	
Additional:
  * These servers should be able to reach the internet and Azure.
  * You need to have full access and admin or root permissions on these Server OS
	

For Arc enabled Kubernetes
	
* Prepare your familiar kubernetes distribution. To check if this distribution is valid for [Azure Arc enbaled Kubernetes, please check here Azure Arc-enabled Kubernetes validation - Azure Arc | Microsoft Docs](https://docs.microsoft.com/en-us/azure/azure-arc/kubernetes/validation-program)


* If you need to install and deploy your own server OS from scratch, then, download the following ISO files and save them on your own PC / Environment with your prefered Hypervisor e.g. Hyper-V or Virtualization Client (Windows 10/11 Hyper-V or Virtual Box).
  * [Ubuntu](https://ubuntu.com/download)
  * [Windows Server 2022](https://www.microsoft.com/en-us/evalcenter/download-windows-server-2022)

Install from the downloaded ISO your prefered OS. 

With these prerequisites in place, we can focus on building the differentiated knowledge in the hybrid world with Azure Arc to enable your on-prem, Multi-Cloud environment for the Cloud operations model.

## Lab environment for this MicroHack

## Architecture

The [Azure Stack HCI Evaluation Guide](https://github.com/Azure/AzureStackHCI-EvalGuide) will help you to deploy the foundation for this MicroHack. After successfully completing the guide you will have a two-node Azure Stack HCI cluster running on an Azure VM with nested virtualization enabled. This two-node cluster will represent your on-premises location and is tightly integrated with Azure.

![image](./img/architecture.jpg)

As you can see, the target architecture is missing a lot of things. You are tasked to complete all challenges to finish the MicroHack.

## MicroHack Challenges

Before you dive into the challenges, please make sure that the prerequisites are fulfilled. [Jump directly to prerequisites to verify](#prerequisites)

## Challenge 1 - Preparing the environment
Setup Azure Subscription
Create AAD Service principal
Prep Azure resources (Resource Group)

Screenshot von Azure Portal & Azure Arc -- empty 

## Challenge 2 - Onboard Server to Azure Arc enabled Servers

Windows Server 2022
Login Admin account
Connect via RDP
Copy script from Azure Arc to onboard via RDP
Screenshot Azure Portal with onboarded Windows Server

Linux Ubuntu
Login root
remote ssh
execute bash script
screenshot Azure Portal with onbaorded Linux Server


## Challenge 3 - Add Azure Monitor

Create Log analytics workspace
copy workspace ID and Key
Onboard Windows & Linux to Log Analytics workspace

## Challenge 4 - Integrate with Microsoft Defender for Cloud

Enable Azure Arc Defender for Cloud

## Challenge 5 - Unsing Azure Policy with Arc enabled Server

Enable Azure Policies
Use Azure Policies

## Challenge 1 - Create virtual machines on Azure Stack HCI

### Challenge 1 Goal

The goal of this exercise is to deploy the first virtual machines on your Azure Stack HCI cluster. We will use these virtual machines in the following challenges for different purposes.

### Actions

* Create three virtual machines running on your Azure Stack HCI cluster via Windows Admin Center
  * Basic VM configuration: 2 vCPU, 8 GB RAM, 1 disk with 128 GB storage
  * win-app, win-file based on Windows Server 2022
  * lin-app based on Ubuntu 22.04 LTS (or your preferred Linux distro)
* Join the Windows-based Virtual Machines to Active Directory

### Success criteria

* You have two Windows-based Virtual Machines running on your Azure Stack HCI cluster
* You have one Linux-based Virtual Machine running on your Azure Stack HCI cluster
* The Windows-based Virtual Machines are domain-joined and successfully activated
* You can access the Virtual Machines via RDP/SSH

### Learning resources

* [Get started with Azure Stack HCI and Windows Admin Center](https://docs.microsoft.com/en-us/azure-stack/hci/get-started)
* [Manage VMs with Windows Admin Center](https://docs.microsoft.com/en-us/azure-stack/hci/manage/vm)
* [License Windows Server VMs on Azure Stack HCI](https://docs.microsoft.com/en-us/azure-stack/hci/manage/vm-activate)

### Solution - Spoilerwarning

[Solution Steps](./Walkthrough/challenge1/solution.md)

## Challenge 2 - Management / control plane fundamentals at the beginning

### Challenge 2 Goal

At the beginning it is always a good approach setting up the stage, onboard the necessary infrastructure and management components to have the right focus and support for the next challenges. In this section the focus will be on onboarding the servers we have created in the first challenge and integrate them in the necessary control plane & management tools. 

### Actions

* Create all necessary Azure Resources
  * Azure Resource group (Name: AzStackHCI-MicroHack-Azure)
  * Azure Automation Account (Name: mh-automation)
  * Log Analytics Workspace (Name: mh-la)
* Configure Log Analytics to collect Windows event logs and Linux syslog
* Deploy Azure Policy initiative for automatic onboarding of Azure Arc enabled Servers
* Configure Azure Arc environment

## Success criteria

* You have one Azure resource group containing the Azure Automation Account and Log Analytics Workspace
* You successfully linked the necessary Azure Policy initiative to the Azure resource group
* You have the onboarding scripts for both Windows and Linux servers

## Learning resources

* [Manage Azure resource groups by using the Azure portal](https://docs.microsoft.com/en-us/azure/azure-resource-manager/management/manage-resource-groups-portal)
* [Create an Automation account using the Azure portal](https://docs.microsoft.com/en-us/azure/automation/quickstarts/create-account-portal)
* [Create a Log Analytics workspace in the Azure portal](https://docs.microsoft.com/en-us/azure/azure-monitor/logs/quick-create-workspace)
* [Collect Windows event log data sources with Log Analytics agent](https://docs.microsoft.com/en-us/azure/azure-monitor/agents/data-sources-windows-events#configuring-windows-event-logs)
* [Collect Syslog data sources with Log Analytics agent](https://docs.microsoft.com/en-us/azure/azure-monitor/agents/data-sources-syslog#configure-syslog-in-the-azure-portal)
* [Understand deployment options for the Log Analytics agent on Azure Arc-enabled servers](https://docs.microsoft.com/en-us/azure/azure-arc/servers/concept-log-analytics-extension-deployment)
* [Azure Policy built-in definitions for Azure Arc-enabled servers](https://docs.microsoft.com/en-us/azure/azure-arc/servers/policy-reference)

### Solution - Spoilerwarning

[Solution Steps](./Walkthrough/challenge2/solution.md)

# Challenge 3 - Onboard your servers to Azure Arc

## Goal

In challenge 3 you will successfully onboard your servers to Azure Arc and leverage Azure native services like Update Management, Inventory and VM Insights for your Azure Stack HCI Virtual Machines.

## Actions

* Onboard your three Virtual Machines to Azure Arc using the onboarding scripts
* Enable and configure Update Management
* Enable Inventory
* Enable VM Insights
* Setup a Policy that checks if the user "FrodoBaggins" is part of the local administrators group

## Success Criteria

* All Virtual Machines are connected to Azure Arc and visible in the Azure Portal
* All Virtual Machines have the latest Windows and Linux updates installed
* You can browse through the software inventory of your Virtual Machines
* You can use VM Insights to get a detailed view of your Virtual Machines
* You can view the compliance state of the Administrator Group Policy

## Learning resources

* [Connect hybrid machines with Azure Arc-enabled servers](https://docs.microsoft.com/en-us/azure/azure-arc/servers/learn/quick-enable-hybrid-vm)
* [Enable Update Management from an Automation account](https://docs.microsoft.com/en-us/azure/automation/update-management/enable-from-automation-account)
* [How to deploy updates and review results](https://docs.microsoft.com/en-us/azure/automation/update-management/deploy-updates)
* [Enable Change Tracking and Inventory from an Automation account](https://docs.microsoft.com/en-us/azure/automation/change-tracking/enable-from-automation-account)
* [Monitor a hybrid machine with VM insights](https://docs.microsoft.com/en-us/azure/azure-arc/servers/learn/tutorial-enable-vm-insights)
* [Understand the guest configuration feature of Azure Policy](https://docs.microsoft.com/en-us/azure/governance/policy/concepts/guest-configuration)

### Solution - Spoilerwarning

[Solution Steps](./Walkthrough/challenge4/solution.md)