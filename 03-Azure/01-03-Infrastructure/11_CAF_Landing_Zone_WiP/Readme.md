![image](img/1920x300_EventBanner_MicroHack_General_wText.jpg)

# **MicroHack - Azure Landing Zones with Microsoft Cloud Adoption Framework**

- [**MicroHack introduction**](#MicroHack-introduction)
- [**MicroHack context**](#microhack-context)
- [**Objectives**](#objectives)
- [**MicroHack Challenges**](#microhack-challenges)
- [**Contributors**](#contributors)

# MicroHack introduction

This MicroHack scenario walks through the use of Microsoft Cloud Adoption Framework and its Landing Zone Accelerators with a focus on the best practices and the design principles.

![image](Path to the high level architecture )

This lab is not a full explanation of setting up a Landing Zone and all involved technologies, please consider the following articles required pre-reading to build foundational knowledge.

- [Microsoft Cloud Adoption Framework for Azure](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/)
  - [What is a Landing Zone?](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/landing-zone/)
- [What is Bicep?](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/overview?tabs=bicep)

Optional (read this after completing this lab to take your learning even deeper!)

# MicroHack context

The foundation of a successful cloud journey is a structured approach to workload deplyoment and governance. For Microsoft Azure, these guiding principals are collected under the Microsoft Cloud Adoption Framework umbrella.

As the architect of such cloud journey it is imperative to understand the core requirements and the best practises of implementing those in order to create a clean foundation for scalable cloud deployments and flexibility, while maintaining guardrails and governance across the board.

We will follow the Microsoft Cloud Adoption Framework for Azure's methodology by using the Bicep Accelerator and its module strucutre.

![image](https://learn.microsoft.com/en-us/azure/architecture/landing-zones/bicep/images/high-level-deployment-flow.png#lightbox)

While green field scenariso would start with Module 1 (Management Groups Module), we have set up corresponding assets for each participant followng Module 1 through 3 and the hands-on activiteis will commence with Module 4 (Logging & Security Module).

# Objectives

After completing this MicroHack you will:

- Know how to conceptuallize a landing zone in Microsoft Azure
- Understand the best practise accelerators and how to use them
- Know how to customize the accelerators to build upon them to tailor the landing zone to your organizations specific needs

# MicroHack challenges

## General prerequisites

When using a predefined workshop environment, all prerequisites have been set up for you already and you should have been issued user credentials and an assigned resource group for running the challenges.

The accelerator can (and has to be) customized via parameters (and possible code changes). For this purpose make sure you clone the [ALZ-Bicep repository](https://github.com/Azure/ALZ-Bicep)

```bash
git clone https://github.com/Azure/ALZ-Bicep.git
```

If you want to run though the whole experience in your own environment, please refer to the [Prerequistes Section](https://github.com/Azure/ALZ-Bicep/wiki/DeploymentFlow#prerequisites) of the Azure Landing Zone Deployment Flow instructions.

### Learing Resources

- [Deployment Flow Wiki](https://github.com/Azure/ALZ-Bicep/wiki/DeploymentFlow)
- [Design Considerations of Azure Landing Zone concept](https://learn.microsoft.com/en-us/azure/architecture/landing-zones/bicep/landing-zone-bicep)

## Accelerator for Bicep - Deployment Flow

![image](https://learn.microsoft.com/en-us/azure/architecture/landing-zones/bicep/images/high-level-deployment-flow.png)

## Challenge 1 - Core Setup

### Goal

You should create a Management Group hierarchy in accordance with the Microsoft Cloud Adoption Framework for Azure. Please make sure you read the COMPLETE list of expected actions in order to plan accordingly from the get-go. Based on this hierarchy, the respective Custom Policy Definitions and Custom Role Definitiosn will be deployed to your landing zone.

### Actions

- Deploy a management group hierarchy in your tenant under the managment group assigned to you (to be assumed the Root Managment Group).
- Deploy the custom Azure Policy Definitions & Initiatives supplied by the Azure Landing Zones conceptual architecture and reference implementation defined [here](https://learn.microsoft.com/azure/cloud-adoption-framework/ready/enterprise-scale/architecture) to the specified Management Group. (Make sure you prefix all so the names become unique in this shared environment)
- Define custom roles based on the recommendations from the Azure Landing Zone Conceptual Architecture. The role definitions are defined in [Identity and access management](https://learn.microsoft.com/azure/cloud-adoption-framework/ready/enterprise-scale/identity-and-access-management) recommendations.

### Success criteria

- You feel confident in how to create a Management Group hierarchies in accordance with the Microsoft Cloud Adoption Framework for Azure
- You successfully deployed a corresponding Managemnt Group hierarchy within the Management Group branch assigned to you

### Learning resources

- https://learn.microsoft.com/en-us/azure/architecture/landing-zones/bicep/landing-zone-bicep
- https://github.com/Azure/ALZ-Bicep/wiki/DeploymentFlow#deployment-identity

### Solution

> [!warning]
> SPOILER - You can find pointers to a faster solution in the [solution document](./walkthrough/solution.md)

## Challenge 2 - Logging & Security

### Goal

Configures a centrally managed Log Analytics Workspace, Automation Account and Sentinel.

As optional content you can also look at Management Groups Diagnostic Settings to enable Diagnostic Settings for Management Groups to the Log Analytics Workspace created in the Logging subscription.

> [!NOTE]
> In the pre-defined workshop environment you need to apply Module 4.1 to the Management Group associated with your specific user.

### Actions

- Deploy Azure Log Analytics Workspace, Automation Account (linked together) & multiple Solutions to an existing Resource Group
- [optional] Enable Diagnostic Settings on the Management Group hierarchy that was defined during the deployment of the Management Group

### Success criteria

- You provisioned several data collection rules (VM Insights, Change Tracking, and Defender for SQL) as well as a user-assigned managed identity (UAMI).
- [optional] You have successfully enabled (and validated) Diagnostic Settings on the Management Group scope

### Learning resources

- [infra-as-code/bicep/modules/logging](https://github.com/Azure/ALZ-Bicep/tree/main/infra-as-code/bicep/modules/logging)
- [infra-as-code/bicep/orchestration/mgDiagSettingsAll](https://github.com/Azure/ALZ-Bicep/tree/main/infra-as-code/bicep/orchestration/mgDiagSettingsAll)]

### Solution

> [!warning]
> SPOILER - You can find pointers to a faster solution in the [solution document](./walkthrough/solution.md)

## Challenge 3 - Core Connectivity

### Goal

Create the core connectivity infrastructure (Hub vnet or vWAN Hub) correspoding to the best practises of Microsoft Cloud Adoption Framework for Azure.

### Actions

- Define hub networking based on the recommendations from the Azure Landing Zone Conceptual Architecture.
- Make sure you DO NOT deploy DDoS Protection during this step!
- [Alternative] Deploy the Virtual WAN network topology and its components according to the Azure Landing Zone conceptual architecture which can be found [here](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/virtual-wan-network-topology).

### Success criteria

- Your environment now contains a complete connectivity infrastructure, either based on Hub vNet or vWAN Hub.

### Learning resources

- [Netowrk Topoligy Considerations](https://github.com/Azure/ALZ-Bicep/wiki/DeploymentFlow#network-topology-deployment)

### Solution

> [!warning]
> SPOILER - You can find pointers to a faster solution in the [solution document](./walkthrough/solution.md)

## Challenge 4 - Role Assignments

### Goal

Role assignments are part of [Identity and Access Management (IAM)](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/enterprise-scale/identity-and-access-management), which is one of the critical design areas in Enterprise-Scale Architecture.

In this challenge you need to prepare a resource group for later workload deployment by creating it and assigning the appropriate roles.

> [!NOTE]
> For this challenge, and the deployment happening later in this workshop, you have been issued a separate set of user credentials, so the assignment exercise should be performed on this _deployment_ user.

### Actions

- Create resource group that will later hold a specific workload
- Ensure your user has the appropriate role on the created resource group for workload deployment assigned (In a later challenge we will use that user to deploy the demo workload)

### Success criteria

- Necessary RBAC-roles were assgined
- You can successfully log in as that user and access the resource group

### Learning resources

- [infra-as-code/bicep/modules/roleAssignments](https://github.com/Azure/ALZ-Bicep/tree/main/infra-as-code/bicep/modules/roleAssignments)

### Solution

> [!warning]
> SPOILER - You can find pointers to a faster solution in the [solution document](./walkthrough/solution.md)

## Challenge 5 - Subscription Placement

In proper production environments you would place subscriptions into their respective management groups in order to inherit the corresponding configurations, like RBAC roles, policy assignments, etc.

> [!NOTE]
> In this workshop environment we are using a shared subscription for all participants and therefore moving subscripitions is not part of the workshop.

### Learning resources

- [infra-as-code/bicep/orchestration/subPlacementAll](https://github.com/Azure/ALZ-Bicep/tree/main/infra-as-code/bicep/orchestration/subPlacementAll)

### Solution

> [!warning]
> SPOILER - You can find pointers to a faster solution in the [solution document](./walkthrough/solution.md)

## Challenge 6 - Built-In and Custom Policy Assignments

### Goal

To ensure consistent governance across the whole landing zone, Azure Policies are deployed across the management groups. As a result of this Challenge you should have a set of Policies and Initiatives assigned to your management group hierarchy.

### Actions

- Deploys the default Azure Landing Zone Azure Policy Assignments to the Management Group Hierarchy and also assigns the relevant RBAC for the system-assigned Managed Identities created for policies that require them (e.g DeployIfNotExist & Modify effect policies)
- Exclude "Storage Account must not have public access" from the default policies for assignment

- Add a custom policy which limits the resource deployment to Azure region "swedencentral"
- Assign this custom policy to the scope of your workload resource group
- Ensure that a policy prevents stroage accounts from using public endpoints, but scoped only to the Resource Group

### Success criteria

- You have a set of default policies assigned to your managmeent group hierarchy
- You have a custom policy and a default policy assinment for your workload resource group

### Learning resources

- [infra-as-code/bicep/modules/policy/assignments/alzDefaults](https://github.com/Azure/ALZ-Bicep/tree/main/infra-as-code/bicep/modules/policy/assignments/alzDefaults)
- [infra-as-code/bicep/modules/policy/assignments/workloadSpecific](https://github.com/Azure/ALZ-Bicep/tree/main/infra-as-code/bicep/modules/policy/assignments/workloadSpecific)

### Solution

> [!warning]
> SPOILER - You can find pointers to a faster solution in the [solution document](./walkthrough/solution.md)

## Challenge 7 - Workload Deployment to Landing Zone

### Goal

Now that the foundation is layed, you are ready to deploy your first workload. At the end of this challenge you should have a peered spoke vnet with an simple web application deployed in the valid deployment region

### Actions

- Create and configures a spoke network to deliver the Azure Landing Zone Hub & Spoke architecture based on the network toplogy you chose in Challegen 3
- Deploy the "Final" Web application (deployment scripts see below). In order to test the policy assignments, try to deploy the application to a region other than the one enforced by your policy
- Create a storage account and link the storage account to the Web application (details should be displayed for any app that is not configured yet)

### Success criteria

- Deployment is limited to the valid region
- Storage account creation with public endpoints is prevented
- Application shows the "Congratulations" screen

### Learning resources

- [Netowrk Topoligy Considerations](https://github.com/Azure/ALZ-Bicep/wiki/DeploymentFlow#network-topology-deployment)

### Solution

> [!warning]
> SPOILER - You can find pointers to a faster solution in the [solution document](./walkthrough/solution.md)

# Finish

Congratulations! You finished the MicroHack _Name_. We hope you had the chance to learn about the how to implement a successful...
If you want to give feedback please dont hesitate to open an Issue on the repository or get in touch with one of us directly.

Thank you for investing the time and see you next time!

## Contributors

- Stephan Niklas [GitHub](); [LinkedIn]()
- Philipp Weckerle [GitHub](https://github.com/phwecker); [LinkedIn](https://www.linkedin.com/in/philippweckerle/)
