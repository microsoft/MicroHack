# **MicroHack Azure Stack HCI**

# Contents 

[MicroHack introduction and context]()

[Objectives](#objectives)

[Prerequisites](#prerequisites)

[Lab environment for this MicroHack](#lab-environment-for-this-microhack)

[Challenge 1: ](#challenge-1) 

[Challenge 2: ]

[Challenge 3: ]

[Challenge 4: ]

[Challenge 5: ]

[Challenge 6: ]

[Challenge 7 :]

# MicroHack introduction and context

This MicroHack scenario walks through the use of ... with a focus on the best practices and the design principles. Specifically, this builds up to include working with an existing infrastructure.

![image](./img/Architecture.png)

This lab is not a full explanation of .... as a technology, please consider the following articles required pre-reading to build foundational knowledge.

Optional (read this after completing this lab to take your learning even deeper!

Describe the scenario here...

# Objectives

After completing this MicroHack you will:

- Know how to build a ...
- Understand default ..
- Understand how ..

# Prerequisites

!!Eval Lab or own hardware from validated vendors --> See here

!! Hybrid Connectivity !! 

In order to use the MicroHack time most effectively, the following tasks should be completed prior to starting the session.

- Azure Stack HCI Deployment done (Link Eval Lab)
- Download ISO FIles on Azure Stack HCI to location: C:
  - Ubuntu --> Link to ISO for download
  - Windows Server 2019 Link to ISO - https://software-download.microsoft.com/download/pr/17763.737.190906-2324.rs5_release_svc_refresh_SERVER_EVAL_x64FRE_en-us_1.iso
- 

With these pre-requisites in place, we can focus on building the differentiated knowledge in ... that is required when working with the product, rather than spending hours repeating relatively simple tasks such as setting up Log Analytics 

At the end of this section your base lab build looks as follows:

![image](Path to the architecture )

Permissions for the deployment: 
- Contributor on your Resource Group

# Lab environment for this MicroHack

Explain the lab ..

## Architecture

Description

![image](Path to the architecture )


Naming standards / taxonomie: 
- https://docs.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/resource-naming

MicroHack Series - Hybrid Stack HCI / Arc
- 1 Challenge: Readiness Automation Account / Log Analytics
    - Change Tracking, Patch und das andere
    - Policy / guest Policys
    - Windows Admin center
    - Monitoring / Azure Monitor / Cluster Monitoring
  - Task 1 VM Deployment (setting up the basic lab environment)
    - 2 x Windows --> win-file / win-app
    - Linux --> lin-app-mi
  - Onboarding Arc - Interactively / At Scale
- 2 Challenge: Arc / MSI Access Secret in KeyVault / SQL 
- 3 Challenge: Fileserver / FileSync
- 4 Challenge: Backup 
- 5 Challenge: Site recovery
- 6 Challenge: Scale out storage - Storage Spaces Direct 

MicroHack Series - Hybrid Stack HCI AKS / 
- 4 Challenge: AKS 
- 4 Challenge: Azure Arc Bridge 
- 5 Challenge: Arc enabled Data
- 6 Challenge: Arc enabled App Service

MicroHack Series - Hybrid AVD on Stack HCI
- 99 Challenge: Azure Virtual Desktop


# MicroHack Challenges 

-- Link and some words about prereqs 

## Challenge 1 - Create you first virtual machines on HCI

### Goal 

The goal of this exercise is to deploy the first virtual machines on your Azure Stack HCI. We will use this virtual machines in the next challenges and all other challenges are directly connected this this challenge. 

### Task 1: Create virtual machines on Cluster Manager via Windows Admin Center



- Login to Azure cloud shell [https://shell.azure.com/](https://shell.azure.com/)
- Ensure that you are operating within the correct subscription via:

`az account show`

- Clone the following GitHub repository 

`git clone Link to Github Repo `

### Task 2: Verify baseline

Now that we have the base lab deployed, we can progress to the ... challenges!


# Challenge 2 : Name..

### Goal

### Task 1: 

### Task 2: 

### Task 3: 

**Explain the background...**

### Task 4: 

Before proceeding to challenge 3, ...

# Challenge 3 : Name ...

### Goal

### Task 1: 

### Task 2: 

### Task 3: 

**Explain the background...**

### Task 4: 

# Finished? Delete your lab


Thank you for participating in this MicroHack!
