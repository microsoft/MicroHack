# **MicroHack Azure Arc for Servers**

- [**MicroHack introduction**](#MicroHack-introduction)
  - [**What is Azure Arc?**](#what-is-azure-arc)
- [**MicroHack context**](#microhack-context)
- [**Objectives**](#objectives)
- [**Lab environment for this MicroHack**](#lab-environment-for-this-microHack)
  - [Architecture](#architecture)
- [**MicroHack Challenges**](#microhack-challenges)
  - [General prerequisites](#general-prerequisites)
  - [Challenge-1 - Azure Arc prerequisites & onboarding](#challenge-1---azure-arc-prerequisites-&-onboarding)
  - [Challenge 2 - Azure Monitor integration](#challenge-2---azure-monitor-integration)
  - [Challenge 3 - Access Azure resources using Managed Identities from your on-premises servers](#challenge-3---access-azure-resources-using-managed-identities-from-your-on-premises-servers)
  - [Challenge 4 - Microsoft Defender for Cloud integration with Azure Arc](#challenge-4---microsoft-defender-for-cloud-integration-with-azure-arc)
  - [Challenge 5 - Azure Policy](#Challenge-5---azure-policy)
- [**Contributors**](#contributors)

## MicroHack introduction

What is Azure Arc?

For customers who want to simplify complex and distributed environments across on-premises, edge, and multi-cloud, [Azure Arc](https://azure.microsoft.com/services/azure-arc/) enables deployment of Azure services anywhere and extends Azure management to any infrastructure. Azure Arc helps you accelerate innovation across hybrid and multi-cloud environments and provides the following benefits to your organization:

![image](./img/AzureArc-01.png)

- Gain central visibility, operations, and compliance Standardize visibility, operationsand compliance across a wide range of resources and locations by extending the Azure control plane. Right from Azure, you can easily organize, govern, and secure Windows, Linux, SQL Servers and Kubernetes clusters across datacenters, edge, and multi-cloud.

- Build Cloud native apps anywhere, at scale Centrally code and deploy applications confidently to any Kubernetes distribution in any location. Accelerate development by using best in class applications services with standardized deployment, configuration, security, and observability.

- Run Azure services anywhere Flexibly use cloud innovation where you need it by deploying Azure services anywhere. Implement cloud practices and automation to deploy faster, consistently, and at scale with always-up-to-date Azure Arc enabled services.

## MicroHack context

This MicroHack scenario walks through the use of Azure Arc with a focus on the best practices and the design principles and some interesting challenges for real world scenarios. Specifically, this builds up to include working with an existing infrastructure in your datacenter.

Further resources - Thomas Maurer & Lior links

* [Azure Arc Overview Documentation](https://learn.microsoft.com/en-us/azure/azure-arc/overview)
* [Azure Arc Blog from Microsoft](https://techcommunity.microsoft.com/t5/azure-arc-blog/bg-p/AzureArcBlog)
* [Azure Arc Jumpstart Scenarios](https://azurearcjumpstart.io/azure_arc_jumpstart/)
* [Azure Arc Jumpstart ArcBox](https://azurearcjumpstart.io/azure_jumpstart_arcbox/)
* [Azure Arc for Developers](https://techcommunity.microsoft.com/t5/itops-talk-blog/azure-arc-for-developers/ba-p/2561513)
* [Azure Arc for Cloud Solutions Architects](https://techcommunity.microsoft.com/t5/itops-talk-blog/azure-arc-for-cloud-solutions-architects/ba-p/2521928)
* [Azure Arc for IT Pros](https://techcommunity.microsoft.com/t5/itops-talk-blog/azure-arc-for-it-pros/ba-p/2347921)
* [Azure Arc for Security Engineers](https://techcommunity.microsoft.com/t5/itops-talk-blog/azure-arc-for-security-engineers/ba-p/2367830)
* [Learning Path Bring Azure innovation to your hybrid environments with Azure Arc](https://learn.microsoft.com/en-us/training/paths/manage-hybrid-infrastructure-with-azure-arc/)
* [Customer reference: Wüstenrot & Württembergische reduces patching time by 35 percent, leans into hybrid cloud management with Azure Arc](https://customers.microsoft.com/en-us/story/1538266003319018436-ww-azure-banking-and-capital-markets)

💡 Optional: Read this after completing this lab to deepen the learned!

## Objectives

After completing this MicroHack you will:

* Know how to use Azure Arc in your environment, on-prem or Multi-cloud
* Understand use cases and possible scenarios in your hybrid world to modernize your infrastructure estate
* Get insights into real world challenges and scenarios

## Lab environment for this MicroHack
Adrian

### Architecture
Adrian

## MicroHack Challenges

### General prerequisites

* Your own Azure subscription with Owner RBAC rights at the subscription level
* [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) 
* [Visual Studio Code](https://code.visualstudio.com/)
* [Git SCM](https://git-scm.com/download/) 

## Challenge 1 - Azure Arc prerequisites & onboarding

This MicroHack has a few but very important prerequisites to be understood before starting this lab!

### For Arc enabled Servers

* Have a server, windows or linux ready
For windows, pls use if possible Windows Server 2019 or 2022 with the latest patch level

  [Supported operating systems @ Connected Machine agent prerequisites - Azure Arc | Microsoft Docs](https://docs.microsoft.com/en-us/azure/azure-arc/servers/prerequisites#supported-operating-systems)
	
  This Server OS could be hosted as a VM on VMware, Hyper-V, Nutanix, AWS, GCP or bare metal.
	
#### Additional:
  * These servers should be able to reach the internet and Azure.
  * You need to have full access and admin or root permissions on these Server OS

* If you need to install and deploy your own server OS from scratch, then, download the following ISO files and save them on your own PC / Environment with your prefered Hypervisor e.g. Hyper-V or Virtualization Client (Windows 10/11 Hyper-V or Virtual Box).
  * [Ubuntu](https://ubuntu.com/download)
  * [Windows Server 2022](https://www.microsoft.com/en-us/evalcenter/download-windows-server-2022)

* Install from the downloaded ISO your prefered OS. 

#### Using Azure Arc with Azure VMs
* In case you want to use an Azure VM for this MicroHack, you need to follow the guidance 
  * [Evaluate Azure Arc-enabled servers on an Azure virtual machine](https://learn.microsoft.com/en-us/azure/azure-arc/servers/plan-evaluate-on-azure-virtual-machine)

With these prerequisites in place, we can focus on building the differentiated knowledge in the hybrid world with Azure Arc to enable your on-prem, Multi-Cloud environment for the Cloud operations model.

## Challenge 2 - Azure Monitor integration

2. Azure Monitor / Log Analytics --> Adrian
   Pre Requisits - AA Account & Log Analytics WS
   Deployment Agent via Policy
   Update Management
   Inventory
   Change Tracking

### Goal

In challenge 2 you will successfully onboard your Windows and Linux Virtual Machines to a centralized Log Analytics Workspace to leverage Azure Monitor, Azure Update Management, Change Tracking and Inventory. 

### Actions

* Create all necessary Azure Resources
  * Azure Automation Account (Name: mh-arc-servers-automation)
  * Log Analytics Workspace (Name: mh-arc-servers-kv-law)
* Configure Log Analytics to collect Windows event logs and Linux syslog
* Enable Azure Monitor for Azure Arc enabled Servers with Azure Policy initiative
* Enable and configure Update Management
* Enable Change Tracking and Inventory
* Enable VM Insights


### Success criteria

* You have an Azure Automation Account and a Log Analytics Workspace
* You successfully linked the necessary Azure Policy initiative to the Azure resource group
* You can query the Log Analytics Workspace for events of your Virtual Machines
* All Virtual Machines have the latest Windows and Linux updates installed
* You can browse through the software inventory of your Virtual Machines
* You can use VM Insights to get a detailed view of your Virtual Machines

### Learning resources

* [Create an Automation account using the Azure portal](https://docs.microsoft.com/en-us/azure/automation/quickstarts/create-account-portal)
* [Create a Log Analytics workspace in the Azure portal](https://docs.microsoft.com/en-us/azure/azure-monitor/logs/quick-create-workspace)
* [Collect Windows event log data sources with Log Analytics agent](https://docs.microsoft.com/en-us/azure/azure-monitor/agents/data-sources-windows-events#configuring-windows-event-logs)
* [Collect Syslog data sources with Log Analytics agent](https://docs.microsoft.com/en-us/azure/azure-monitor/agents/data-sources-syslog#configure-syslog-in-the-azure-portal)
* [Understand deployment options for the Log Analytics agent on Azure Arc-enabled servers](https://docs.microsoft.com/en-us/azure/azure-arc/servers/concept-log-analytics-extension-deployment)
* [Azure Policy built-in definitions for Azure Arc-enabled servers](https://docs.microsoft.com/en-us/azure/azure-arc/servers/policy-reference)
* [Enable Update Management from an Automation account](https://docs.microsoft.com/en-us/azure/automation/update-management/enable-from-automation-account)
* [How to deploy updates and review results](https://docs.microsoft.com/en-us/azure/automation/update-management/deploy-updates)
* [Enable Change Tracking and Inventory from an Automation account](https://docs.microsoft.com/en-us/azure/automation/change-tracking/enable-from-automation-account)
* [Monitor a hybrid machine with VM insights](https://docs.microsoft.com/en-us/azure/azure-arc/servers/learn/tutorial-enable-vm-insights)


### Solution - Spoilerwarning

[Solution Steps](./walkthrough/challenge-2/solution.md)

## Challenge 3 - Access Azure resources using Managed Identities from your on-premises servers

## Goal

Managing secrets, credentials or certificates to secure communication between different services is a main challenge for developers and administrators. Managed Identities is Azure's answer to all these challenges and eliminates the need to manage and securely store secrets, credentials or certificates on the Virtual Machine. In challenge 4 you will leverage Managed Identities via Azure Arc to securely access an Azure Key Vault secret from your Azure Arc enabled servers without the need of managing any credential. 

## Actions

* Create an Azure Key Vault in your Azure resource group
* Create a secret in the Azure Key Vault and assign permissions to your Virtual Machine microhack-arc-servers-lin01
* Access the secret via Bash script

## Success Criteria

* You successfully output the secret in the terminal on microhack-arc-servers-lin01 without providing any credentials (except for your SSH login 😊).

## Learning resources

* [Create a key vault using the Azure portal](https://docs.microsoft.com/en-us/azure/key-vault/general/quick-create-portal)
* [Set and retrieve a secret from Azure Key Vault using the Azure portal](https://docs.microsoft.com/en-us/azure/key-vault/secrets/quick-create-portal)
* [Use a Linux VM system-assigned managed identity to access Azure Key Vault](https://docs.microsoft.com/en-us/azure/active-directory/managed-identities-azure-resources/tutorial-linux-vm-access-nonaad)
* [Authenticate against Azure resources with Azure Arc-enabled servers](https://docs.microsoft.com/en-us/azure/azure-arc/servers/managed-identity-authentication)

### Solution - Spoilerwarning

[Solution Steps](./walkthrough/challenge-3/solution.md)

## Challenge 4 - Microsoft Defender for Cloud integration with Azure Arc

4. Defender
   Pre requisits - Enable Defender for Sub
   Check / verify - Recommendations

### Goal

* In this challenge, we will integrate your Azure Arc connected machines with Azure Security Center (ASC). After completing the previous challenges, you should now have an Azure subscription with one or more Azure Arc managed servers. You should also have an available Log Analytics workspace and have deployed the Log Analytics agent to your server(s).

### Actions

* Enable Microsoft Defender for Cloud with Azure Security Center on your Azure Arc connected machines.

### Success criteria

* Open Microsoft Defender for Cloud with Azure Security Center and view the Secure Score for your Azure arc connected machine.

### Learning resources

* [Quickstart: Connect your non-Azure machines to Microsoft Defender for Cloud](https://learn.microsoft.com/en-us/azure/defender-for-cloud/quickstart-onboard-machines?pivots=azure-arc)
* [Connect Azure Arc-enabled servers to Microsoft Defender for Cloud](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/manage/hybrid/server/best-practices/arc-security-center)
* [Protect non-Azure resources using Azure Arc and Microsoft Defender for Cloud](https://techcommunity.microsoft.com/t5/microsoft-defender-for-cloud/protect-non-azure-resources-using-azure-arc-and-microsoft/ba-p/2277215)


### Solution - Spoilerwarning

[Solution Steps](./walkthrough/challenge-4/solution.md)

## Challenge 5 - Azure Policy

```
Info
5. Policy --> Christian
   Guest Config Policy -> Not Named Azure Automanage Machine Configuration
   Check for local admin/user -> Still valid. Will be kept
   Machine Configuration - Create Config to update local file / create folder 
```

### Goal


Challenge 5 is all about interacting with the Client Operating System. We will have a look at Machine Configurations as the final step of this journey.

### Actions

* Setup a Policy that checks if the user "FrodoBaggins" is part of the local administrators group

### Success criteria

* You can view the compliance state of the Administrator Group Policy

### Learning resources

* [Understand the machine configuration feature of Azure Automanage](https://learn.microsoft.com/en-us/azure/governance/machine-configuration/overview)

* [Understand the guest configuration feature of Azure Policy](https://docs.microsoft.com/en-us/azure/governance/policy/concepts/guest-configuration)

### Solution - Spoilerwarning

[Solution Steps](./walkthrough/challenge-5/solution.md)

## **Contributors**
* Adrian Schöne [GitHub](https://github.com/adriandiver); [LinkedIn](https://www.linkedin.com/in/adrian-schoene//)
* Christian Thönes [GitHub](https://github.com/alexor-ms/guest-configuration); [LinkedIn](https://www.linkedin.com/in/alexanderortha/)
* Nild Bankert [GitHub](https://github.com/nilsbankert); [LinkedIn](https://www.linkedin.com/in/nilsbankert/)
* Alexander Ortha [GitHub](https://github.com/alexor-ms/); [LinkedIn](https://www.linkedin.com/in/alexanderortha/)

