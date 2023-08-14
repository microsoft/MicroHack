# **MicroHack Azure Arc for Servers**

- [**MicroHack introduction**](#MicroHack-introduction)
  - [What is Azure Arc?](#what-is-azure-arc)
- [**MicroHack context**](#microhack-context)
- [**Objectives**](#objectives)
- [**MicroHack Challenges**](#microhack-challenges)
  - [General prerequisites](#general-prerequisites)
  - [Challenge 1 - Azure Arc prerequisites & onboarding](#challenge-1---azure-arc-prerequisites--onboarding)
  - [Challenge 2 - Azure Monitor integration](#challenge-2---azure-monitor-integration)
  - [Challenge 3 - Access Azure resources using Managed Identities from your on-premises servers](#challenge-3---access-azure-resources-using-managed-identities-from-your-on-premises-servers)
  - [Challenge 4 - Microsoft Defender for Cloud integration with Azure Arc](#challenge-4---microsoft-defender-for-cloud-integration-with-azure-arc)
  - [Challenge 5 - Azure Automanage Machine Configuration](#challenge-5---azure-automanage-machine-configuration)
- [**Contributors**](#contributors)

## MicroHack introduction

### What is Azure Arc?

For customers who want to simplify complex and distributed environments across on-premises, edge, and multi-cloud, [Azure Arc](https://azure.microsoft.com/services/azure-arc/) enables deployment of Azure services anywhere and extends Azure management to any infrastructure. Azure Arc helps you accelerate innovation across hybrid and multi-cloud environments and provides the following benefits to your organization:

![image](./img/AzureArc-01.png)

- Gain central visibility, operations, and compliance Standardize visibility, operationsand compliance across a wide range of resources and locations by extending the Azure control plane. Right from Azure, you can easily organize, govern, and secure Windows, Linux, SQL Servers and Kubernetes clusters across datacenters, edge, and multi-cloud.

- Build Cloud native apps anywhere, at scale Centrally code and deploy applications confidently to any Kubernetes distribution in any location. Accelerate development by using best in class applications services with standardized deployment, configuration, security, and observability.

- Run Azure services anywhere Flexibly use cloud innovation where you need it by deploying Azure services anywhere. Implement cloud practices and automation to deploy faster, consistently, and at scale with always-up-to-date Azure Arc enabled services.

## MicroHack context

This MicroHack scenario walks through the use of Azure Arc with a focus on the best practices and the design principles and some interesting challenges for real world scenarios. Specifically, this builds up to include working with an existing infrastructure in your datacenter.

Further resources - Thomas Maurer & Lior Kamrat links

* [Azure Arc Overview Documentation](https://learn.microsoft.com/en-us/azure/azure-arc/overview)
* [Azure Arc Blog from Microsoft](https://techcommunity.microsoft.com/t5/azure-arc-blog/bg-p/AzureArcBlog)
* [Azure Arc Enabled Extended Security Updates](https://learn.microsoft.com/en-us/windows-server/get-started/extended-security-updates-deploy)
* [Azure Arc Jumpstart Scenarios](https://azurearcjumpstart.io/azure_arc_jumpstart/)
* [Azure Arc Jumpstart HCIBox](https://azurearcjumpstart.io/azure_jumpstart_hcibox/)
* [Azure Arc Jumpstart ArcBox](https://azurearcjumpstart.io/azure_jumpstart_arcbox/)
* [Azure Arc for Developers](https://techcommunity.microsoft.com/t5/itops-talk-blog/azure-arc-for-developers/ba-p/2561513)
* [Azure Arc for Cloud Solutions Architects](https://techcommunity.microsoft.com/t5/itops-talk-blog/azure-arc-for-cloud-solutions-architects/ba-p/2521928)
* [Azure Arc for IT Pros](https://techcommunity.microsoft.com/t5/itops-talk-blog/azure-arc-for-it-pros/ba-p/2347921)
* [Azure Arc for Security Engineers](https://techcommunity.microsoft.com/t5/itops-talk-blog/azure-arc-for-security-engineers/ba-p/2367830)
* [Learning Path Bring Azure innovation to your hybrid environments with Azure Arc](https://learn.microsoft.com/en-us/training/paths/manage-hybrid-infrastructure-with-azure-arc/)
* [Customer reference: Wüstenrot & Württembergische reduces patching time by 35 percent, leans into hybrid cloud management with Azure Arc](https://customers.microsoft.com/en-us/story/1538266003319018436-ww-azure-banking-and-capital-markets)
* [Introduction to Azure Arc landing zone accelerator for hybrid and multicloud](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/scenarios/hybrid/enterprise-scale-landing-zone)

💡 Optional: Read this after completing this lab to deepen the learned!

## Objectives

After completing this MicroHack you will:

* Know how to use Azure Arc in your environment, on-prem or Multi-cloud
* Understand use cases and possible scenarios in your hybrid world to modernize your infrastructure estate
* Get insights into real world challenges and scenarios

## MicroHack Challenges

### General prerequisites

This MicroHack has a few but important prerequisites to be understood before starting this lab!

* Your own Azure subscription with Owner RBAC rights at the subscription level
  * [Azure Evaluation free account](https://azure.microsoft.com/en-us/free/search/?OCID=AIDcmmzzaokddl_SEM_0fa7acb99db91c1fb85fcfd489e5ca6e:G:s&ef_id=0fa7acb99db91c1fb85fcfd489e5ca6e:G:s&msclkid=0fa7acb99db91c1fb85fcfd489e5ca6e)
* You need to have 2 Virtual Machines ready and updated. One with a Linux Operating System (tested with Ubuntu Server 22.04) and one with Windows Server Operating System (tested with Windows Server 2022). You can use Machines in Azure for this following this Guide: [Azure Arc Jumpstart Servers](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_servers/azure/)
    > **Note**  
    >  When using the Jumpstart the Virtual Machines will already be onboarded to Azure Arc and therefore "Challenge 1 - Azure Arc prerequisites & onboarding" is not needed.
* [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) (Hint: Make sure to use the lastest version)
* [Azure PowerShell Guest Configuration Cmdlets](https://learn.microsoft.com/en-us/azure/governance/machine-configuration/machine-configuration-create-setup#install-the-module-from-the-powershell-gallery)
  * It is not possible to run those commands from Azure Cloud Shell
  * Please make sure you have at least Version 3.4.2 installes with the following Command: ```Install-Module -Name GuestConfiguration -RequiredVersion 3.4.2```
* [Visual Studio Code](https://code.visualstudio.com/)
* [Git SCM](https://git-scm.com/download/)

## Challenge 1 - Azure Arc prerequisites & onboarding

### Goal

In challenge 1 you will prepare your Azure Environemnt for onboarding of existing Windows- and Linux Servers and onboard them to Azure Arc.

### Actions

* Create all necessary Azure Resources
  * Resource Group (Name: mh-arc-servers-rg)
  * Service Principal (Name: mh-arc-servers-sp)
* Enable required Resource Provider
* Prep existing Server Operating System on-prem
* Onboard existing Server to Azure Arc

### Success criteria

* You created an Azure Resource Group
* You created an Service Principal with the required role membership
* Prepared successfully an existing Server OS
* Onboarded Server OS is visible in the Azure Arc plane in the Azure Portal

### Learning resources

* [Plan and deploy Azure Arc-enabled servers](https://learn.microsoft.com/en-us/azure/azure-arc/servers/plan-at-scale-deployment) 
* [Prerequisites for Connect hybrid machines with Azure Arc-enabled servers](https://learn.microsoft.com/en-us/azure/azure-arc/servers/learn/quick-enable-hybrid-vm#prerequisites) 
* [Connect hybrid machines with Azure Arc-enabled servers](https://learn.microsoft.com/en-us/azure/azure-arc/servers/learn/quick-enable-hybrid-vm#generate-installation-script) 
* [Create a service principal for onboarding](https://learn.microsoft.com/en-us/azure/azure-arc/servers/onboard-service-principal#create-a-service-principal-for-onboarding-at-scale) 

### Solution - Spoilerwarning

[Solution Steps](./walkthrough/challenge-1/solution.md)

## Challenge 2 - Azure Monitor integration

### Goal

In challenge 2 you will successfully onboard your Windows and Linux Virtual Machines to Azure Monitor using the Azure Monitoring Agent to leverage Azure Update Management, Change Tracking, Inventory and more. Be aware that Microsoft curently shifts from the retiering Log Analytics Agent to Azure Monitoring Agent. By that some of the features used in challange 2 are currently in preview.

### Actions

* Create all necessary Azure Resources
  * Log Analytics Workspace (Name: mh-arc-servers-kv-law)
* Configure Data Collection Rules in Log Analytics to collect Windows event logs and Linux syslog
* Enable Azure Monitor for Azure Arc enabled Servers with Azure Policy initiative
* Enable and configure Update Management
* Enable Change Tracking and Inventory
* Enable VM Insights


### Success criteria

* You have a Log Analytics Workspace
* You successfully linked the necessary Azure Policy initiative to the Azure resource group
* You can query the Log Analytics Workspace for events of your Virtual Machines
* All Virtual Machines have the latest Windows and Linux updates installed
* You can browse through the software inventory of your Virtual Machines
* You can use VM Insights to get a detailed view of your Virtual Machines

### Learning resources

* [Create a Log Analytics workspace in the Azure portal](https://docs.microsoft.com/en-us/azure/azure-monitor/logs/quick-create-workspace)
* [Deployment options for Azure Monitor agent on Azure Arc-enabled servers](https://learn.microsoft.com/en-us/azure/azure-arc/servers/concept-log-analytics-extension-deployment)
* [Data collection rules in Azure Monitor](https://learn.microsoft.com/en-us/azure/azure-monitor/essentials/data-collection-rule-overview)
* [Azure Policy built-in definitions for Azure Arc-enabled servers](https://docs.microsoft.com/en-us/azure/azure-arc/servers/policy-reference)
* [Azure Update Management Center](https://learn.microsoft.com/en-us/azure/update-center/overview)
* [Enable Change Tracking and Inventory using Azure Monitoring Agent (Preview)](https://learn.microsoft.com/en-us/azure/automation/change-tracking/enable-vms-monitoring-agent?tabs=singlevm)
* [Monitor a hybrid machine with VM insights](https://docs.microsoft.com/en-us/azure/azure-arc/servers/learn/tutorial-enable-vm-insights)


### Solution - Spoilerwarning

[Solution Steps](./walkthrough/challenge-2/solution.md)

## Challenge 3 - Access Azure resources using Managed Identities from your on-premises servers

### Goal

Managing secrets, credentials or certificates to secure communication between different services is a main challenge for developers and administrators. Managed Identities is Azure's answer to all these challenges and eliminates the need to manage and securely store secrets, credentials or certificates on the Virtual Machine. In challenge 3 you will leverage Managed Identities via Azure Arc to securely access an Azure Key Vault secret from your Azure Arc enabled servers without the need of managing any credential. 

### Actions

* Create an Azure Key Vault in your Azure resource group
* Create a secret in the Azure Key Vault and assign permissions to your Virtual Machine microhack-arc-servers-lin01
* Access the secret via Bash script

### Success Criteria

* You successfully output the secret in the terminal on your Linux server without providing any credentials (except for your SSH login 😊).

### Learning resources

* [Create a key vault using the Azure portal](https://docs.microsoft.com/en-us/azure/key-vault/general/quick-create-portal)
* [Set and retrieve a secret from Azure Key Vault using the Azure portal](https://docs.microsoft.com/en-us/azure/key-vault/secrets/quick-create-portal)
* [Use a Linux VM system-assigned managed identity to access Azure Key Vault](https://docs.microsoft.com/en-us/azure/active-directory/managed-identities-azure-resources/tutorial-linux-vm-access-nonaad)
* [Authenticate against Azure resources with Azure Arc-enabled servers](https://docs.microsoft.com/en-us/azure/azure-arc/servers/managed-identity-authentication)

### Solution - Spoilerwarning

[Solution Steps](./walkthrough/challenge-3/solution.md)

## Challenge 4 - Microsoft Defender for Cloud integration with Azure Arc

### Goal

* In this challenge, we will integrate your Azure Arc connected machines with Azure Security Center (ASC). After completing the previous challenges, you should now have an Azure subscription with one or more Azure Arc managed servers. You should also have an available Log Analytics workspace and have deployed the Log Analytics agent to your server(s).

### Actions

* Enable Microsoft Defender for Cloud with Azure Security Center on your Azure Arc connected machines.

### Success criteria

* Open Microsoft Defender for Cloud with Azure Security Center and view the Secure Score for your Azure Arc connected machine.

### Learning resources

* [What is Microsoft Defender for Cloud?](https://learn.microsoft.com/en-us/azure/defender-for-cloud/defender-for-cloud-introduction)
* [Quickstart: Connect your non-Azure machines to Microsoft Defender for Cloud](https://learn.microsoft.com/en-us/azure/defender-for-cloud/quickstart-onboard-machines?pivots=azure-arc)
* [Connect Azure Arc-enabled servers to Microsoft Defender for Cloud](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/manage/hybrid/server/best-practices/arc-security-center)
* [Protect non-Azure resources using Azure Arc and Microsoft Defender for Cloud](https://techcommunity.microsoft.com/t5/microsoft-defender-for-cloud/protect-non-azure-resources-using-azure-arc-and-microsoft/ba-p/2277215)
* [Deploy the Azure Monitor Agent to protect your servers with Microsoft Defender for Cloud](https://learn.microsoft.com/en-us/azure/defender-for-cloud/auto-deploy-azure-monitoring-agent)


### Solution - Spoilerwarning

[Solution Steps](./walkthrough/challenge-4/solution.md)

## Challenge 5 - Azure Automanage Machine Configuration

### Goal

Challenge 5 is all about interacting with the Client Operating System. We will have a look at Machine Configurations as the final step of this journey.

### Actions

* Create all necessary Azure Resources
  * Azure Storage Account
* Setup a Policy that checks if the user "FrodoBaggins" is part of the local administrators group
* Setup a Custom Machine Configuration, for the Windows Server, that creates a registry key in ``` HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment\ ```

### Success criteria

* You can view the compliance state of the Administrator Group Policy
* You can show the registry key being present on the Windows Server

### Learning resources

* [Understand the machine configuration feature of Azure Automanage](https://learn.microsoft.com/en-us/azure/governance/machine-configuration/overview)
* [How to setup a machine configuration authoring environment](https://learn.microsoft.com/en-us/azure/governance/machine-configuration/machine-configuration-create-setup)
* [How to create custom machine configuration package artifacts](https://learn.microsoft.com/en-us/azure/governance/machine-configuration/machine-configuration-create)
* [How to create custom machine configuration policy definitions](https://learn.microsoft.com/en-us/azure/governance/machine-configuration/machine-configuration-create-definition)
* [Create SAS tokens for storage containers](https://learn.microsoft.com/en-us/azure/applied-ai-services/form-recognizer/create-sas-tokens)

### Solution - Spoilerwarning

[Solution Steps](./walkthrough/challenge-5/solution.md)

## Finish

Congratulations! You finished the MicroHack Azure Arc for Servers. We hope you had the chance to learn about the Hybrid capabilities of Azure.  
If you want to give feedback please dont hesitate to open an Issue on the repository or get in touch with one of us directly.

Thank you for investing the time and see you next time!


## Contributors
* Adrian Schöne [GitHub](https://github.com/adriandiver); [LinkedIn](https://www.linkedin.com/in/adrian-schoene//)
* Christian Thönes [Github](https://github.com/cthoenes); [LinkedIn](https://www.linkedin.com/in/christian-t-510b7522/)
* Nils Bankert [GitHub](https://github.com/nilsbankert); [LinkedIn](https://www.linkedin.com/in/nilsbankert/)
* Alexander Ortha [GitHub](https://github.com/alexor-ms/); [LinkedIn](https://www.linkedin.com/in/alexanderortha/)
