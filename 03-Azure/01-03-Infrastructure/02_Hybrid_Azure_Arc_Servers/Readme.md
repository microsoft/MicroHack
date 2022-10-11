# **MicroHack Azure Arc for Servers**

[toc]

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

* [Secure, develop, and operate infrastructure, apps, and Azure services anywhere](https://azure.microsoft.com/en-us/products/azure-arc/#product-overview)
* [Secure, develop, and operate infrastructure, apps, and Azure services anywhere](https://azure.microsoft.com/en-us/products/azure-arc/#product-overview)
* [Secure, develop, and operate infrastructure, apps, and Azure services anywhere](https://azure.microsoft.com/en-us/products/azure-arc/#product-overview)




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
Alexander

## Challenge 1

1. Pre requisits --> Nils, Alexander
   OS / VM deploy , 1 WS, 1 LX Ubuntu 22.04
   Service Principal
   Resource Group
   Onboard WS / LX

### Goal

### Actions

### Success criteria

### Learning resources

### Solution - Spoilerwarning

## Challenge 2

2. Azure Monitor / Log Analytics --> Adrian
   Pre Requisits - AA Account & Log Analytics WS
   Deployment Agent via Policy
   Update Management
   Inventory
   Change Tracking

### Goal

In challenge 3 you will successfully onboard your servers to Azure Arc and leverage Azure native services like Update Management, Inventory and VM Insights for your Azure Stack HCI Virtual Machines.
At the beginning it is always a good approach setting up the stage, onboard the necessary infrastructure and management components to have the right focus and support for the next challenges. In this section the focus will be on onboarding the servers we have created in the first challenge and integrate them in the necessary control plane & management tools. 

### Actions

* Create all necessary Azure Resources
  * Azure Automation Account (Name: mh-arc-servers-automation)
  * Log Analytics Workspace (Name: mh-arc-servers-kv-law)
* Configure Log Analytics to collect Windows event logs and Linux syslog
* Enable Azure Monitor for Azure Arc enabled Servers with Azure Policy initiative
* Enable and configure Update Management
* Enable Inventory
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

## Challenge 4

4. Defender
   Pre requisits - Enable Defender for Sub
   Check / verify - Recommendations

### Goal

### Actions

### Success criteria

### Learning resources

### Solution - Spoilerwarning

## Challenge 5

```
Info
5. Policy --> Christian
   Guest Config Policy
   Check for local admin/user
   Machine Configuration test
```

### Goal
``` ok ```

Challenge 5 is all about interacting with the Client Operating System. We will have a look at Guest Configuration Policies and Machine Configurations as the final step of this journey.

### Actions

* Setup a Policy that checks if the user "FrodoBaggins" is part of the local administrators group

### Success criteria

* You can view the compliance state of the Administrator Group Policy

### Learning resources

* [Understand the guest configuration feature of Azure Policy](https://docs.microsoft.com/en-us/azure/governance/policy/concepts/guest-configuration)

### Solution - Spoilerwarning

[Solution Steps](./walkthrough/challenge-5/solution.md)
