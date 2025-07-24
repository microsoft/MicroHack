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

## Challenge 1 - Base Setup (Modules 1 thru 3)

### Goal

Familiarize yourself with Modules 1 thru 3 and how they were already set up for you in the worksup environemnt.

| #   | Module                    | Description                                                                                                                                         | Path                                                                                                                                                |
| --- | ------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | Management Groups         | Configures the management group hierarchy to support Azure Landing Zone reference implementation. Owner role assignment at / root management group. | [infra-as-code/bicep/modules/managementGroups](https://github.com/Azure/ALZ-Bicep/tree/main/infra-as-code/bicep/modules/managementGroups)           |
| 2   | Custom Policy Definitions | Configures Custom Policy Definitions at the organization management group. Management Groups.                                                       | [infra-as-code/bicep/modules/policy/definitions](https://github.com/Azure/ALZ-Bicep/tree/main/infra-as-code/bicep/modules/policy/definitions)       |
| 3   | Custom Role Definitions   | Configures custom roles based on Cloud Adoption Framework's recommendations at the organization management group. Management Groups.                | [infra-as-code/bicep/modules/customRoleDefinitions](https://github.com/Azure/ALZ-Bicep/tree/main/infra-as-code/bicep/modules/customRoleDefinitions) |

### Actions

- Familiarize yourself with the tasks implemented in each fo the three modules
- Study how those artifacts manifest themselves in Azure by looking at what was created for you (your worksop prefix will determine "your" assets)

### Success criteria

- You feel confident that you understand hwo Modules 1 thru 3 are used to set up the global landing zone foundation
- You feel confortable navigating and locating assets created by Module 1 thru 3 as they might be needed for the succesful completion of subsequent challenges.

### Learning resources

- https://learn.microsoft.com/en-us/azure/architecture/landing-zones/bicep/landing-zone-bicep
- https://github.com/Azure/ALZ-Bicep/wiki/DeploymentFlow#deployment-identity

### Solution - Spoilerwarning

[Solution Steps](./walkthrough/challenge-1/solution.md)

## Challenge 2 - Logging & Security (Module 4)

Configures a centrally managed Log Analytics Workspace, Automation Account and Sentinel in the Logging subscription.
As optional content you can also look at Module 4.1 (Management Groups Diagnostic Settings) which discusses how to enable Diagnostic Settings for Management Groups to the Log Analytics Workspace created in the Logging subscription.

> [!NOTE]
> In the pre-defined workshop environment you need to apply Module 4 to the Management Group associated with your specific user.

### Goal

- Deploy Azure Log Analytics Workspace, Automation Account (linked together) & multiple Solutions to an existing Resource Group
-

### Actions

- ...

### Success criteria

- ...

### Learning resources

- [infra-as-code/bicep/modules/logging](https://github.com/Azure/ALZ-Bicep/tree/main/infra-as-code/bicep/modules/logging)
- [infra-as-code/bicep/orchestration/mgDiagSettingsAll](https://github.com/Azure/ALZ-Bicep/tree/main/infra-as-code/bicep/orchestration/mgDiagSettingsAll)]

### Solution - Spoilerwarning

[Solution Steps](./walkthrough/challenge-2/solution.md)

## Challenge 3 - Hub Networking (Module 5)

### Goal

...

### Actions

- ...

### Success criteria

- ...

### Learning resources

- [Netowrk Topoligy Considerations](https://github.com/Azure/ALZ-Bicep/wiki/DeploymentFlow#network-topology-deployment)

## Challenge 4 - Role Assignments (Module 6)

### Goal

...

### Actions

- ...

### Success criteria

- ...

### Learning resources

- [infra-as-code/bicep/modules/roleAssignments](https://github.com/Azure/ALZ-Bicep/tree/main/infra-as-code/bicep/modules/roleAssignments)

## Challenge 5 - Subscription Placement (Module 7)

ONLY Study, DO NOT execute.

### Goal

...

### Actions

- ...

### Success criteria

- ...

### Learning resources

- [infra-as-code/bicep/orchestration/subPlacementAll](https://github.com/Azure/ALZ-Bicep/tree/main/infra-as-code/bicep/orchestration/subPlacementAll)

## Challenge 6 - Built-In and Custom Policy Assignments (Module 8)

    - Workload Specific Policy Assignments (Module 8.1)

### Goal

...

### Actions

- ...

### Success criteria

- ...

### Learning resources

- [infra-as-code/bicep/modules/policy/assignments/alzDefaults](https://github.com/Azure/ALZ-Bicep/tree/main/infra-as-code/bicep/modules/policy/assignments/alzDefaults)
- [infra-as-code/bicep/modules/policy/assignments/workloadSpecific](https://github.com/Azure/ALZ-Bicep/tree/main/infra-as-code/bicep/modules/policy/assignments/workloadSpecific)

## Challenge 7 - Spoke Networking (Module 9)

### Goal

...

### Actions

- ...

### Success criteria

- ...

### Learning resources

- [Netowrk Topoligy Considerations](https://github.com/Azure/ALZ-Bicep/wiki/DeploymentFlow#network-topology-deployment)

# Finish

Congratulations! You finished the MicroHack _Name_. We hope you had the chance to learn about the how to implement a successful...
If you want to give feedback please dont hesitate to open an Issue on the repository or get in touch with one of us directly.

Thank you for investing the time and see you next time!

## Contributors

- Philipp Weckerle [GitHub](https://github.com/phwecker); [LinkedIn](https://www.linkedin.com/in/philippweckerle/)

---

TEMPLATE (delete once content completed)

## Challenge xx - ...

### Goal

The goal of this exercise is to deploy...

### Actions

- Write down the first 3 steps....
- Set up and enable...
- Perform and monitor....

### Success criteria

- You have deployed ....
- You successfully enabled ...
- You have successfully setup ....
- You have successfully ....

### Learning resources

- Link to https://learn.microsoft.com/en-us/azure/....

### Solution - Spoilerwarning

[Solution Steps](./walkthrough/challenge-2/solution.md)
