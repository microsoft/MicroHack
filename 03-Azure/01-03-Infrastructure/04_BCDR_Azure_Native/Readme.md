![image](img/1920x300_EventBanner_MicroHack_BusinessContinuity_wText.jpg)

# MicroHack - Business Continuity on Azure

- [**MicroHack introduction**](#microhack-introduction)
  - [What is Business Continuity?](#what-is-business-continuity)
- [**MicroHack context**](#microhack-context)
- [**Objectives**](#objectives)
- [**MicroHack Challenges**](#microhack-challenges)
  - [General prerequisites](#general-prerequisites)
  - [Challenge 0 - Understand the Disaster Recovery terms and define a strategy](#contoso-ltd---business-continuity-and-disaster-recovery-bcdr-strategy)
    - [General Prerequisites & Setup](./challenges/00_challenge.md)
  - [Challenge 1 - Prerequisites and landing zone preparation](./challenges/01_challenge.md)
  - [Challenge 2 - Protect in Azure - Backup / Restore](./challenges/02_challenge.md)
  - [Challenge 3 - Protect in Azure with Disaster Recovery](./challenges/03_challenge.md)
  - [Challenge 4 - Protect to Azure with Azure Backup & Restore](./challenges/04_challenge.md)
  - [Challenge 5 - Protect to Azure with Disaster Recovery](./challenges/05_challenge.md)
- [**Contributors**](#contributors)

## MicroHack introduction

### What is Business Continuity?

When you design for resiliency, you must understand your availability requirements.
- How much downtime is acceptable? 
- How much will potential downtime cost your business?
- How much should you invest in making the application highly available?
- You also must define what it means for the application to be available.

💡 For instance, would you consider the application to be ‘unavailable’ if it allows you to place an order, but fails to process it within the usual time period? Also, it’s crucial to evaluate the likelihood of a system failure. Is implementing a countermeasure strategy financially justifiable? Remember, effective resilience planning is rooted in the business’s needs. Here are some strategies to guide your thinking when planning for system resiliency.

The following picture describes in detail the individual levels / disaster recovery tier levels and also provides an overview of which topics we should deal with when talking about disaster recovery. The individual terms, terminologies and categories will be discussed in this microhack which will also provide one approach and a few tips on how to define them in your own company.

![image](./img/drcontinuum.png)

## MicroHack context

This MicroHack scenario walks through the use of building a Business Continuity Strategy with a focus on best practices and the design principles, as well as some interesting challenges for real world scenarios. Specifically, it builds up to include working with an existing infrastructure in your datacenter.

Further resources: 

* [Azure Business Continuity & Disaster Recovery](https://learn.microsoft.com/en-us/azure/site-recovery/site-recovery-overview#what-does-site-recovery-provide)
* [How does Microsoft ensure business continuity](https://learn.microsoft.com/en-us/compliance/assurance/assurance-resiliency-and-continuity)
* [Common questions about Azure Site Recovery](https://learn.microsoft.com/en-us/azure/site-recovery/site-recovery-faq)

💡 Optional: Once you’ve completed this lab, consider reading the following material to further enhance your understanding!

* [Overview of the reliability pillar](https://learn.microsoft.com/en-us/azure/architecture/framework/resiliency/overview)
* [Whitepaper - Resiliency in Azure](https://azure.microsoft.com/en-us/resources/resilience-in-azure-whitepaper/)

## Objectives

After completing this MicroHack you will:

* Know how to use the right business continuity strategy for your infrastructure or your particular workload.
* Understand use cases and possible scenarios in your own business continuity & disaster recovery strategy.
* Get insights into real world challenges and scenarios.

## MicroHack Challenges

### General prerequisites

This MicroHack has a few but important prerequisites to be understood before starting this lab!

* Your own Azure subscription with Owner RBAC rights at the subscription level
  * [Azure Evaluation free account](https://azure.microsoft.com/en-us/free/search/?OCID=AIDcmmzzaokddl_SEM_0fa7acb99db91c1fb85fcfd489e5ca6e:G:s&ef_id=0fa7acb99db91c1fb85fcfd489e5ca6e:G:s&msclkid=0fa7acb99db91c1fb85fcfd489e5ca6e)


<img src="./img/azure_copilot.png" alt="Azure Copilot" width="600">

Azure Copilot is a new tool that helps you manage and optimize your Azure resources with the help of AI. In this Hack Azure Copilot can guide you and help answer some of your questions.

<img src="./img/azure_copilot_bar.png" alt="Azure Copilot Bar" width="600">

In this section, you will:
- Learn how to use Azure Copilot
- Explore key features and capabilities

### References
- [What is Microsoft Copilot in Azure?](https://learn.microsoft.com/en-us/azure/copilot/overview)
- [📄 Microsoft Copilot in Azure - Documentation](https://docs.microsoft.com/en-us/azure/copilot/)


## Understand the Disaster Recovery (DR) terms and define a DR strategy

# Contoso Ltd - Business Continuity and Disaster Recovery (BCDR) Strategy

## Background
Contoso Ltd is a global company that relies on advanced technology to manage its operations efficiently. Their business applications, all hosted in the Azure cloud, are crucial to their daily functions and overall success. These applications power a wide range of essential business processes:
- **App 1:** Fabric Robot Automation
- **App 2:** Customer Help Desk Services
- **App 3:** Archive Service

Leaders at Contoso Ltd understand that any downtime can result in significant financial losses and operational disruptions. Therefore, the company has mandated a thorough review of its Business Continuity and Disaster Recovery (BCDR) strategies to strike a balance between business continuity, customer satisfaction, and operational costs. The goal is to design and implement recovery plans that can swiftly restore services and minimize downtime in the event of unforeseen disasters.

## Scenario Overview
A natural disaster struck the region hosting Contoso applications on Azure one Friday evening, causing outages in many services and leading to a cascading failure of all Contoso applications. The sudden disruption impacted essential business functions, leaving the company to grapple with significant financial losses and operational chaos. Customers and stakeholders were left in a state of uncertainty as they awaited updates on service restoration. The IT team faced immense pressure to rapidly deploy recovery strategies to minimize downtime, restore critical operations, and ensure that such an incident would not recur in the future.

Participants must design and implement recovery strategies to meet business targets while considering costs for high availability.

## Application Overview
| Application | Business Function | Criticality | SLA | RTO | RPO | Downtime Cost |
|-------------|-------------------|-------------|-----|-----|-----|---------------|
| App1        | TBD               | Critical    | 99.995% | 1 hour | 10 minutes | $50,000/hour |
| App2        | TBD               | High        | 99.95%  | 2 hours | 15 minutes | $25,000/hour |
| App3        | TBD               | Medium      | 99.9%   | 6 hours | 4 hours    | $10,000/hour |

## Recovery Costs for High Availability
| Application | Cost of RTO Compliance | Cost of RPO Compliance | Cost of SLA Compliance | Fully Highly Available Cost |
|-------------|------------------------|------------------------|------------------------|-----------------------------|
| App1        | $100,000               | $50,000                | $75,000                | $200,000                    |
| App2        | $75,000                | $35,000                | $50,000                | $125,000                    |
| App3        | $50,000                | $20,000                | $25,000                | $75,000                     |

## Challenge Objective
### Actions
Participants must:
1. Prioritize recovery of applications based on their criticality and business impact.
2. Decide which parts of the system to make highly available (HA) based on financial constraints.
3. Calculate the trade-offs between downtime costs and HA investments.

### Success criteria

* Understood the different terms from BCDR.
* Thought about the last successful disaster recovery of daily used applications.
* Identified the responsibilities and roles within your current company in respect to BCDR.
* Defined four levels of disaster recovery categories, including availability SLA.

### Learning resources

* [Business continuity and disaster recovery - Cloud Adoption Framework | Microsoft Learn](https://learn.microsoft.com/azure/cloud-adoption-framework/ready/landing-zone/design-area/management-business-continuity-disaster-recovery)
* [Build high availability into your BCDR strategy - Azure Architecture Center | Microsoft Learn](https://learn.microsoft.com/azure/architecture/solution-ideas/articles/build-high-availability-into-your-bcdr-strategy)
* [Disaster recovery with Azure Site Recovery - Azure Solution Ideas | Microsoft Learn](https://learn.microsoft.com/azure/architecture/solution-ideas/articles/disaster-recovery-smb-azure-site-recovery)

### Solution - Spoilerwarning

[Solution Steps](./walkthrough/challenge-0/solution.md)

Let's get started with the **[challenges](./challenges/01_challenge.md)** and dive into the world of Azure! 🌐

By the end of this MicroHack, you'll be equipped with the knowledge and skills to design and implement effective Business Continuity and Disaster Recovery strategies using Azure services. 

Happy hacking! 🚀

### Azure Business Continuity Guide (ABC Guide)
The Azure Business Continuity Guide provides a comprehensive set of recommendations to help customers define what BCDR looks like for their applications.

[Azure Business Continuity Guide](https://github.com/Azure/BusinessContinuityGuide)

## Contributors 
* Hengameh Bigdeloo
* Nils Bankert [GitHub](https://github.com/nilsbankert); [LinkedIn](https://www.linkedin.com/in/nilsbankert/)
* Herman Diessongo
* Demir Senturk
* Andressa Jendreieck
* Sebastian Pfaller