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

### Actions

### Success criteria

### Learning resources

### Solution - Spoilerwarning

## Challenge 3 - Access Azure resources using Managed Identities from your on-premises servers

## Goal

Managing secrets, credentials or certificates to secure communication between different services is a main challenge for developers and administrators. Managed Identities is Azure's answer to all these challenges and eliminates the need to manage and securely store secrets, credentials or certificates on the Virtual Machine. In challenge 4 you will leverage Managed Identities via Azure Arc to securely access an Azure Key Vault secret from your Azure Arc enabled servers without the need of managing any credential. 

## Actions

* Create an Azure Key Vault in your Azure resource group
* Create a secret in the Azure Key Vault and assign permissions to your Virtual Machine lin-app
* Access the secret via Bash script

## Success Criteria

* You successfully output the secret in the terminal on lin-app without providing any credentials (except for your SSH login 😊).

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
