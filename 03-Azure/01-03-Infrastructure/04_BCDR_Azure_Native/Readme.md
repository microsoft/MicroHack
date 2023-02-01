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

💡 For example, is the application "down" if you can submit an order but the system cannot process it within the normal timeframe? Also consider the probability of an outage occurring and whether a mitigation strategy is cost-effective. Resilience planning starts with business requirements. Here are some approaches for thinking about resiliency in those terms

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

If you have already worked at the senior level or have been working in IT for many years, you may be able to skip this intro challenge. These standards should be defined in every organization and the most important thing is that the Business Continuity Management and the necessary steps for disaster recovery are regularly tested.

### Goal

The goal from this challenge is to understand the challenges in business continuity management and the most important terms. Second dimension is to define strategy and to put yourself into different roles to view the area from different perspectives.

1. What exactly is the difference between Disaster Recovery & Business Continuity?
2. Who is responsible for BCDR?
3. Is there a difference between High availability & Disaster Recovery?
4. Do I really need Backup & Disaster Recovery?

### Actions

* Write down the first 3 steps you would go for if your company got attacked by ransomware
* Think about if you ever participated in a business continuity test scenario
* Put yourself in the position of an application owner and define the necessary steps to make sure your application stays available in case of a disaster
* Who defines the requirements for Business Continuity and what are the necessary KPI´s for an application to reach a good SLA in terms of availability?
* Define and write down four different categories of Disaster Recovery Tier Levels that applications can use incl. the availability SLA
* Plan the different geographic regions you need to use for reaching the highest availability SLA (can also include your datacenter locations)

### Success criteria

* Understood the different terms from BCDR
* Noted the first three steps after ransomware attack in you company
* Thought about the last successful disaster recovery of the daily used applications
* Noted the responsibilities and the roles in the company you are working
* Defined four level of disaster recovery categories incl. availability SLA

### Learning resources

* [Business continuity and disaster recovery - Cloud Adoption Framework | Microsoft Learn](https://learn.microsoft.com/azure/cloud-adoption-framework/ready/landing-zone/design-area/management-business-continuity-disaster-recovery)
* [Build high availability into your BCDR strategy - Azure Architecture Center | Microsoft Learn](https://learn.microsoft.com/azure/architecture/solution-ideas/articles/build-high-availability-into-your-bcdr-strategy)
* [SMB disaster recovery with Azure Site Recovery - Azure Solution Ideas | Microsoft Learn](https://learn.microsoft.com/azure/architecture/solution-ideas/articles/disaster-recovery-smb-azure-site-recovery)

### Solution - Spoilerwarning

[Solution Steps](./walkthrough/challenge-0/solution.md)

## Challenge 1 - Prerequisites and landing zone preparation

### Goal

In challenge 1 you will understand and prepare your environment for onboarding of the infrastructure to enable business continuity with Cloud Native / PaaS Services on Azure.

### Actions

Create all necessary Azure resources
* Region 1: West Europe
  * Resource Group: mh-bcdr-weu-rg
  * Recovery Services Vault: mh-rsv-weu
  * Storage Account with GRS (geo-redundant storage) redundancy option: mhstweu\<Suffix\>
* Region 2: North Europe
  * Resource Group: mh-bcdr-neu-rg
  * Recovery Services Vault: mh-rsv-neu


### Success criteria

* You've created Resource Groups in both regions (North & West Europe)
* Recovery Services Vaults have been created in both regions
* Geo-redundant Storage Account has been created

### Learning resources

* [Manage resource groups - Azure Portal - Azure Resource Manager | Microsoft Learn](https://learn.microsoft.com/azure/azure-resource-manager/management/manage-resource-groups-portal)
* [Create a storage account - Azure Storage | Microsoft Learn](https://learn.microsoft.com/azure/storage/common/storage-account-create)
* [Create and configure Recovery Services vaults - Azure Backup | Microsoft Learn](https://learn.microsoft.com/azure/backup/backup-create-recovery-services-vault)


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


