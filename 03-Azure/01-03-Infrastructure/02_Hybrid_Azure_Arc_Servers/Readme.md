# **MicroHack Azure Arc for Servers**

## MicroHack introduction
Allgemein --> Alexander

## MicroHack context

## Objectives

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

5. Policy --> Christian
   Guest Config Policy
   Check for local admin/user
   Machine Configuration test

### Goal

### Actions

### Success criteria

### Learning resources

### Solution - Spoilerwarning

