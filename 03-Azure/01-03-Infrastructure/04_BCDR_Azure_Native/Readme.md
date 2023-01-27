# **MicroHack Business Continuity / Disaster Recovery**

- [**MicroHack introduction**](#MicroHack-introduction)
  - [What is Business Continuity?]()
- [**MicroHack context**](#microhack-context)
- [**Objectives**](#objectives)
- [**MicroHack Challenges**](#microhack-challenges)
  - [General prerequisites](#general-prerequisites)
  - [Challenge 0 - Understand the Disaster Recovery terms and define a strategy](#challenge-0---understand-the-disaster-recovery-terms-and-define-a-strategy)
  - [Challenge 1 - Prerequisites and landing zone preperation](#challenge-1---prerequisites-and-landing-zone-preperation)
  - [Challenge 2 - Protect in Azure - Backup / Restore](#challenge-2---protect-in-azure---backup--restore)
  - [Challenge 3 - Protect in Azure with Disaster Recovery](#challenge-3---protect-in-azure-with-disaster-recovery)
  - [Challenge 4 - Protect to Azure with Azure Backup & Restore](#challenge-4---protect-to-azure-with-azure-backup--restore)
  - [Challenge 5 - Protect to Azure with Disaster Recovery](#challenge-5---protect-to-azure-with-disaster-recovery)
- [**Contributors**](#contributors)

## MicroHack introduction

### What is Business Continuity?

When you design for resiliency, you must understand your availability requirements. 
- How much downtime is acceptable? 
- How much will potential downtime cost your business? 
- How much should you invest in making the application highly available? 
- You also must define what it means for the application to be available. 

💡 For example, is the application "down" if you can submit an order but the system cannot process it within the normal timeframe? Also consider the probability of an outage occurring and whether a mitigation trategy is cost-effective. Resilience planning starts with business requirements. Here are some approaches for thinking about resiliency in those terms

The following picture describes very well the individual levels / disaster recovery tier levels and gives an overview of which topics we should deal with when talking about disaster recovery. The individual terms, terminologies and categories are explained and this microhack also gives an approach and a few tips on how to deal with them in your own company.

![image](./img/drcontinuum.png)

## MicroHack context

This MicroHack scenario walks through the use of building a Business Continuity Strategy with a focus on the best practices and the design principles and some interesting challenges for real world scenarios. Specifically, this builds up to include working with an existing infrastructure in your datacenter.

Further resources: 

* [Azure Business Continuity & Disaster Recovery](https://learn.microsoft.com/en-us/azure/site-recovery/site-recovery-overview#what-does-site-recovery-provide)
* [How does Microsoft ensure business continuity](https://learn.microsoft.com/en-us/compliance/assurance/assurance-resiliency-and-continuity)
* [Common questions about Azure Site Recovery](https://learn.microsoft.com/en-us/azure/site-recovery/site-recovery-faq)

💡 Optional: Read this after completing this lab to deepen the learned!

* [Overview of the reliability pillar](https://learn.microsoft.com/en-us/azure/architecture/framework/resiliency/overview)
* [Whitepaper - Resiliency in Azure ](https://azure.microsoft.com/en-us/resources/resilience-in-azure-whitepaper/)


## Objectives

After completing this MicroHack you will:

* Know how to use the right business continuity strategy for your infrastructure or your particular workload
* Understand use cases and possible scenarios in your business continuity & disaster recovery strategy 
* Get insights into real world challenges and scenarios

## MicroHack Challenges

### General prerequisites

This MicroHack has a few but important prerequisites to be understood before starting this lab!

* Your own Azure subscription with Owner RBAC rights at the subscription level
  * [Azure Evaluation free account](https://azure.microsoft.com/en-us/free/search/?OCID=AIDcmmzzaokddl_SEM_0fa7acb99db91c1fb85fcfd489e5ca6e:G:s&ef_id=0fa7acb99db91c1fb85fcfd489e5ca6e:G:s&msclkid=0fa7acb99db91c1fb85fcfd489e5ca6e)
* More will be added later if needed

## Challenge 0 - Understand the Disaster Recovery terms and define a strategy

### Goal

In challenge 0 to understand the terms and strategy behind BCDR. 

💡  Protect resources across multiple regions globally: If your organization has global operations across North America, Europe, and Asia, and your resources are deployed in East-US, UK West, and East Asia. One of the requirements of Azure Backup is that the vaults are required to be present in the same region as the resource to be backed-up. 

--> Therefore, you should create three separate vaults for each region to protect your resources.

### Actions

* 

### Success criteria

* 

### Learning resources

* 

## Challenge 1 - Prerequisites and landing zone preperation 

### Goal

In challenge 1 you will understand and prepare your environemnt for onboarding of the infrastructure to enable business continuity with Cloud Native / PaaS Services on Azure.

### Actions

* Create all necessary Azure resources 
* Region 1 West Europe 
* Resource Group: Name: mh-bcdr-weu-rg
* Recovery Services Vault: mh-rsv-weu
* Region 2 North Europe 
* Resource Group: Name: mh-bcdr-neu-rg
* Recovery Services Vault: mh-rsv-neu
* 
* Storage Account with GRS 
* Recovery Services Vault 

### Success criteria

* You created Azure Resource Groups 
* 

### Learning resources

* 


### Solution - Spoilerwarning

[Solution Steps](./walkthrough/challenge-1/solution.md)

## Challenge 2 - Protect in Azure - Backup / Restore 

### Goal

In challenge 2 you will successfully onboard your Windows and Linux Virtual Machines to a centralized Recovery Services Vault and leverage Azure Backup Center to Protect with Backup in Azure. 

### Actions

* Create all necessary Azure Resources
*


### Success criteria

* You have an Recovery Services Vault
* You successfully enabled Azure Backup on two virtual machines
* 

### Learning resources

* 


### Solution - Spoilerwarning

[Solution Steps](./walkthrough/challenge-2/solution.md)

## Challenge 3 - Protect in Azure with Disaster Recovery 

### Goal

### Actions

* Use Azure Site Recovery to...

### Success Criteria

* You successfully initiated a Testfailover and a production failover from Azure Region West Europe to North Europe with a near zero downtime requirement 

### Learning resources

* 

### Solution - Spoilerwarning

[Solution Steps](./walkthrough/challenge-3/solution.md)

## Challenge 4 - Protect to Azure with Azure Backup & Restore 

### Goal

* 

### Actions

* 

### Success criteria

* You successfully installed Azure backup Server in you on prem infrastructure and enabled it for two virtual machines 

### Learning resources

* 

### Solution - Spoilerwarning

[Solution Steps](./walkthrough/challenge-4/solution.md)

## Challenge 5 - Protect to Azure with Disaster Recovery 

### Actions

* 

### Success criteria

*

### Learning resources

* 

### Solution - Spoilerwarning

[Solution Steps](./walkthrough/challenge-5/solution.md)

## Finish

Congratulations! You finished the MicroHack Business Continuity / Disaster Recovery. We hope you had the chance to learn about the how to implement a successful DR strategy to protect resources in Azure and to Azure. 
If you want to give feedback please dont hesitate to open an Issue on the repository or get in touch with one of us directly.

Thank you for investing the time and see you next time!


## Contributors
* Markus Klein 
* Bernd Loehlein 
*Hengameh 
* Tara
* Nils Bankert [GitHub](https://github.com/nilsbankert); [LinkedIn](https://www.linkedin.com/in/nilsbankert/)


