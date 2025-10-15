![image](img/1920x300_EventBanner_MicroHack_Arc_wText.jpg)

# MicroHack Azure Arc for Servers

- [**MicroHack introduction**](#microhack-introduction)
  - [What is Azure Arc?](#what-is-azure-arc)
- [**MicroHack context**](#microhack-context)
- [**Objectives**](#objectives)
- [**MicroHack Challenges**](#microhack-challenges)
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

Further resources

- [Azure Arc Overview Documentation](https://learn.microsoft.com/azure/azure-arc/overview)
- [Azure Arc Blog from Microsoft](https://techcommunity.microsoft.com/category/azure/blog/azurearcblog)
- [Azure Arc Enabled Extended Security Updates](https://learn.microsoft.com/windows-server/get-started/extended-security-updates-deploy)
- [Azure Arc Jumpstart Scenarios](https://jumpstart.azure.com/azure_arc_jumpstart)
- [Azure Arc Jumpstart LocalBox](https://jumpstart.azure.com/azure_jumpstart_localbox)
- [Azure Arc Jumpstart ArcBox](https://jumpstart.azure.com/azure_jumpstart_arcbox)
- [Azure Arc for Developers](https://techcommunity.microsoft.com/t5/itops-talk-blog/azure-arc-for-developers/ba-p/2561513)
- [Azure Arc for Cloud Solutions Architects](https://techcommunity.microsoft.com/t5/itops-talk-blog/azure-arc-for-cloud-solutions-architects/ba-p/2521928)
- [Azure Arc for IT Pros](https://techcommunity.microsoft.com/t5/itops-talk-blog/azure-arc-for-it-pros/ba-p/2347921)
- [Azure Arc for Security Engineers](https://techcommunity.microsoft.com/t5/itops-talk-blog/azure-arc-for-security-engineers/ba-p/2367830)
- [Learning Path Bring Azure innovation to your hybrid environments with Azure Arc](https://learn.microsoft.com/training/paths/manage-hybrid-infrastructure-with-azure-arc/)
- [Customer reference: Wüstenrot & Württembergische reduces patching time by 35 percent, leans into hybrid cloud management with Azure Arc](https://customers.microsoft.com/story/1538266003319018436-ww-azure-banking-and-capital-markets)
- [Introduction to Azure Arc landing zone accelerator for hybrid and multicloud](https://learn.microsoft.com/azure/cloud-adoption-framework/scenarios/hybrid/enterprise-scale-landing-zone)

💡 Optional: Read this after completing this lab to deepen what you have learned!

## Objectives

After completing this MicroHack you will:

- Know how to use Azure Arc in your environment, on-prem or Multi-cloud
- Understand use cases and possible scenarios in your hybrid world to modernize your infrastructure estate
- Get insights into real world challenges and scenarios

## MicroHack Challenges

### General prerequisites

This MicroHack has a few but important prerequisites to be understood before starting this lab!

- Your own Azure subscription with Owner RBAC rights at the subscription level
- You need to have 3 virtual machines ready and updated. One with a Linux operating system (tested with Ubuntu Server 24.04), one with Windows Server 2025 and one with Windows Server 2012 R2 (optional). You can use machines in Azure for this following this guide: [Azure Arc Jumpstart Servers](https://jumpstart.azure.com/azure_arc_jumpstart/azure_arc_servers/azure)
    > **Note**
    > When using the Jumpstart the virtual machines will already be onboarded to Azure Arc and therefore "Challenge 1 - Azure Arc prerequisites & onboarding" is not needed.
- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) (Hint: Make sure to use the lastest version)
- [Azure PowerShell Guest Configuration Cmdlets](https://learn.microsoft.com/azure/governance/machine-configuration/machine-configuration-create-setup#install-the-module-from-the-powershell-gallery)
  - It is not possible to run those commands from Azure Cloud Shell
  - Please make sure you have at least version 4.11.0 installed with the following Command: ```Install-Module -Name GuestConfiguration -RequiredVersion 4.11.0```
- [Visual Studio Code](https://code.visualstudio.com/)
- [Git SCM](https://git-scm.com/download/)


### Challenges

* [Challenge 1 - Azure Arc prerequisites & onboarding](challenges/challenge-01.md)  **<- Start here**
* [Challenge 2 - Azure Monitor integration](challenges/challenge-02.md)
* [Challenge 3 - Access Azure resources using Managed Identities from your on-premises servers](challenges/challenge-03.md)
* [Challenge 4 - Microsoft Defender for Cloud integration with Azure Arc](challenges/challenge-04.md)
* [Challenge 5 - Best Practices assessment for Windows Server](challenges/challenge-05.md)
* [Challenge 6 - Activate ESU for Windows Server 2012 R2 via Arc - optional](challenges/challenge-06.md)
* [Challenge 7 - Azure Automanage Machine Configuration - optional](challenges/challenge-07.md)



### Solutions - Spoilerwarning

* [Solution 1 - Azure Arc prerequisites & onboarding](./walkthrough/challenge-01/solution-01.md)
* [Solution 2 - Azure Monitor integration](./walkthrough/challenge-02/solution-02.md)
* [Solution 3 - Access Azure resources using Managed Identities from your on-premises servers](./walkthrough/challenge-03/solution-03.md)
* [Solution 4 - Microsoft Defender for Cloud integration with Azure Arc](./walkthrough/challenge-04/solution-04.md)
* [Solution 5 - Best Practices assessment for Windows Server](./walkthrough/challenge-05/solution-05.md)
* [Solution 6 - Activate ESU for Windows Server 2012 R2 via Arc - optional](./walkthrough/challenge-06/solution-06.md)
* [Solution 7 - Azure Automanage Machine Configuration - optional](./walkthrough/challenge-07/solution-07.md)


## Contributors

- Adrian Schöne [GitHub](https://github.com/adriandiver); [LinkedIn](https://www.linkedin.com/in/adrian-schoene//)
- Christian Thönes [Github](https://github.com/cthoenes); [LinkedIn](https://www.linkedin.com/in/christian-t-510b7522/)
- Nils Bankert [GitHub](https://github.com/nilsbankert); [LinkedIn](https://www.linkedin.com/in/nilsbankert/)
- Alexander Ortha [GitHub](https://github.com/alexor-ms/); [LinkedIn](https://www.linkedin.com/in/alexanderortha/)
- Christoph Süßer (Schmidt) [GitHub](https://github.com/TheFitzZZ); [LinkedIn](https://www.linkedin.com/in/suesser/)
- Jan Egil Ring [GitHub](https://github.com/janegilring); [LinkedIn](https://www.linkedin.com/in/janegilring/)