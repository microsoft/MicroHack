# **MicroHack Azure Stack HCI**

- [**MicroHack Azure Stack HCI**](#microhack-azure-stack-hci)
- [MicroHack introduction and context](#microhack-introduction-and-context)
- [Objectives](#objectives)
- [Prerequisites](#prerequisites)
- [Lab environment for this MicroHack](#lab-environment-for-this-microhack)
  - [Architecture](#architecture)
- [MicroHack Challenges](#microhack-challenges)
  - [Challenge 1 - First virtual machines on Azure Stack HCI](#challenge-1---first-virtual-machines-on-azure-stack-hci)
    - [Goal](#goal)
    - [Task 1: Create virtual machines on Cluster Manager via Windows Admin Center](#task-1-create-virtual-machines-on-cluster-manager-via-windows-admin-center)
    - [Task 2: Create necessary Azure Resources](#task-2-create-necessary-azure-resources)
    - [Task 3: Prepare the Azure Arc environment](#task-3-prepare-the-azure-arc-environment)
    - [Task 4: Domainjoin](#task-4-domainjoin)
- [Challenge 2 : Management / control plane fundamentals at the beginning](#challenge-2--management--control-plane-fundamentals-at-the-beginning)
    - [Goal](#goal-1)
    - [Task 1: Onboard your servers to Azure Arc](#task-1-onboard-your-servers-to-azure-arc)
    - [Task 2:](#task-2)
    - [Task 3:](#task-3)
    - [Goal](#goal-2)
    - [Task 1:](#task-1)
    - [Task 4:](#task-4)
- [Finished? Delete your lab](#finished-delete-your-lab)


# MicroHack introduction and context

This MicroHack scenario walks through the use of Azure Stack HCI with a focus on the best practices and the design principles and some interesting challenges for real world scenarios. Specifically, this builds up to include working with an existing infrastructure in your datacenter. 

![image](./img/0_azure-stack-hci-solution.png)

This lab is not a full explanation of Azure Stack HCI as a technology, please consider the following articles required pre-reading to build foundational knowledge.

- [What is Azure Stack HCI?](https://docs.microsoft.com/en-us/azure-stack/hci/overview)
- [Watch a video to see an high level overview of the features from Azure Stack HCI](https://youtu.be/fw8RVqo9dcs)
- [eBook: Five Hybrid Cloud Use Cases for Azure Stack HCI](https://aka.ms/technicalusecaseswp)
- [What´s new for Azure Stack HCI at Microsoft Ignite 2021](https://techcommunity.microsoft.com/t5/azure-stack-blog/what-s-new-for-azure-stack-hci-at-microsoft-ignite-2021/ba-p/2897222)
- [Azure Stack HCI Solutions](https://hcicatalog.azurewebsites.net/#/)
- [Plan your solution with the sizer tool](https://hcicatalog.azurewebsites.net/#/sizer)
- [Azure Stack HCI FAQ](https://docs.microsoft.com/en-us/azure-stack/hci/faq)

💡 Optional: Read this after completing this lab to take your learning even deeper!

# Objectives

After completing this MicroHack you will:

- Know how to build or use Azure Stack HCI
- Understand use cases and possible scenarios in your hybrid world to modernize your infrastructure estate. 
- Get insights into real world challenges and scenarios

# Prerequisites

For this MicroHack we have a few prerequisites they are very important to be successful in this MicroHack. Normally, for the use of Azure Stack HCI, validated hardware is required from selected partners and such hardware can of course be used for the MicroHack. The alternative is the Azure Stack HCI Evaluation Lab, which allows to convert Azure Stack HCI to Hyper-V with Nested Virtualization.

In order to use the MicroHack time most effectively, the following tasks should be completed prior to starting the session.

- If you do not have own hardware then you need to go through the [Azure Stack HCI Evaluation Lab](https://github.com/Azure/AzureStackHCI-EvalGuide?msclkid=44e04d5fb4e811eca429547b3ced494b) 

- Download ISO FIles on Azure Stack HCI to location for example Cluster Shared Volumes: 
  - [Ubuntu](https://ubuntu.com/download)
  - [Windows Server 2022](https://software-static.download.prss.microsoft.com/sg/download/888969d5-f34g-4e03-ac9d-1f9786c66749/SERVER_EVAL_x64FRE_en-us.iso)

With these pre-requisites in place, we can focus on building the differentiated knowledge in the hybrid world on Azure Stack HCI to modernize your hybrid estate. 

# Lab environment for this MicroHack

Explain the lab ..

## Architecture

Description

![image](./img/Architecture.png)


Naming standards / taxonomie: 
- https://docs.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/resource-naming

MicroHack Series - Hybrid Stack HCI / Arc


MicroHack Series - Hybrid Stack HCI AKS / 
- 4 Challenge: AKS 
- 4 Challenge: Azure Arc Bridge 
- 5 Challenge: Arc enabled Data
- 6 Challenge: Arc enabled App Service

MicroHack Series - Hybrid AVD on Stack HCI
- 99 Challenge: Azure Virtual Desktop


# MicroHack Challenges 

Before you dive into the challenges please make sure that the pre-requisites are fulfilled otherwise move on with the challenges. [Jump directly to prerequisites to verify](#prerequisites)

## Challenge 1 - First virtual machines on Azure Stack HCI

### Goal 

The goal of this exercise is to deploy the first virtual machines on your Azure Stack HCI. We will use this virtual machines in the next challenges and all other challenges are directly connected this this challenge. 

### Task 1: Create virtual machines on Cluster Manager via Windows Admin Center

![image](./img/1_Admin_Center_New_VM.png)

![image](./img/2_Admin_Center_New_VM.png)

![image](./img/3_Admin_Center_New_VM.png)

![image](./img/4_Admin_Center_New_VM_win-app.png)

![image](./img/5_Admin_Center_New_VM_lin-app-mi.png)

![image](./img/6_Admin_Center_VM_lin-app-mi-Securitysettings.png)

![image](./img/7_Admin_Center_load_balancing_High.png)

![image](./img/8_Admin_Center_New_Start_All_VMs.png)

### Task 2: Create necessary Azure Resources 

![image](./img/9_CreateResourceGroup.png)

![image](./img/10_CreateAutomationAccount.png)

![image](./img/11_CreateAutomationAccount.png)

![image](./img/12_CreateAutomationAccount.png)

![image](./img/13_CreateLAW.png)

![image](./img/14_CreateLAW.png)

### Task 3: Prepare the Azure Arc environment

![image](./img/15_Arc_Page.png)

![image](./img/16_Arc_Add.png)

![image](./img/17_Arc_GenerateScript.png)

![image](./img/18_Arc_GenerateScript.png)

![image](./img/19_Arc_GenerateScript.png)

![image](./img/20_Arc.png)

![image](./img/21_Serviceprincipal.png)

![image](./img/22_Serviceprincipal_secret.png)

![image](./img/23_Add_Servers_Arc.png)

![image](./img/24_Add_Servers_Download.png)

### Task 4: Domainjoin


!! Summarize the challenge !!

# Challenge 2 : Management / control plane fundamentals at the beginning

### Goal

At the beginning it is always a good approach setting up the stage, onboard the necessary infrastructure and management components to have the right focus and support for the next challenges. In this section the focus will be on onboarding the servers we have created in the first challenge and integrate them in the necessary control plane & management tools. 

### Task 1: Onboard your servers to Azure Arc



### Task 2: 

### Task 3: 
- 2 Challenge: Readiness Automation Account / Log Analytics
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

### Goal

### Task 1: 

**Explain the background...**

### Task 4: 

Before proceeding to challenge 3, ...

# Finished? Delete your lab


Thank you for participating in this MicroHack!
