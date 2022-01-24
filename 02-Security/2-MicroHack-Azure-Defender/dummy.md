# **Security baseline? (Azure Defender)**

# Contents

[MicroHack introduction and context](#microhack-introduction-and-context)

[Objectives](#objectives)

[Prerequisites](#prerequisites)

[Lab environment for this MicroHack](#lab-environment-for-this-microhack)

[Challenge 1: Deploy the Lab environment](#challenge-1---deploy-the-lab-environment) 

[Challenge 2: ](#)

[Challenge 3: ]

[Challenge 4: ]

[Challenge 5: ]

[Challenge 6: ]

[Challenge 7 :]

# MicroHack introduction and context

This MicroHack scenario walks through the use of ... with a focus on the best practices and the design principles. Specifically, this builds up to include working with an existing infrastructure.

![image](Path to the architecture )

This lab is not a full explanation of .... as a technology, please consider the following articles required pre-reading to build foundational knowledge.

Optional (read this after completing this lab to take your learning even deeper!

Describe the scenario here...

# Objectives

After completing this MicroHack you will:

- Know how to build a Azure Defender Deployment...
- Understand default behaviour ..
- Understand how to configure Azure Defender ..
- How use ASC from Application Layer perspective ..
- 

# Prerequisites

In order to use the MicroHack time most effectively, the following tasks should be completed prior to starting the session.

With these pre-requisites in place, we can focus on building the differentiated knowledge in Azure LogAnalytics that is required when working with the product, rather than spending hours repeating relatively simple tasks such as setting up Log Analytics 

At the end of this section your base lab build looks as follows:

![image](Path to the architecture )

In summary:

- Azure Subscription 
- Resource Group 

Permissions for the deployment: 
- Contributor on your Resource Group

# Lab environment for this MicroHack

Explain the lab ..

- Check: Log Analytics Workspace
- Check: 2x Virtual Machine (Linux / Windows) (Agent onboarding / Agent COnfig Relevant Logs / )
- Check: Storage Account Archive / Linked Storage Accounts (Immutable Storage)
- Check: Storage Account 
- Check: Advanced settings / Custom Logs / Securtiy Logs / Syslog 
- Check: Link to Automation Account Transfer 
- Check: Azure Activity Logs / Azure AD Logs 
- Check: Azure Policy (Optional)
- Azure Security Center (Dependency with Hack 2 / Auto onboard)

## Architecture

Description

![image](Path to the architecture )

# MicroHack Challenges 

# Challenge 1 - Deploy the Lab environment

## Goal 

The goal of this exercise is to deploy a simple Azure Sentinel Connector and observe the default behaviour when connecting to it. 

### Task 1: Deploy Storage Accounts

#### Centralized / Archive

#### Attacker / Victim Playground


### Task 2: Deploy centralized Log Analytics Workspace

Azure CLI / Klicky Bunti

### Task 3: Deploy Virtual Machines (Variable IP reminder ARM)

We are going to use a predefined ARM template to deploy the base environment. It will be deployed in to *your* Azure subscription, with resources running in the your specified Azure region.

To start the ARM deployment, follow the steps listed below:

- Login to Azure cloud shell [https://shell.azure.com/](https://shell.azure.com/)
- Ensure that you are operating within the correct subscription via:

**Wichtig Storage Account zu haben wenn erstes Mal**

`az account show`

- Clone the following GitHub repository 

`git clone Link to Github Repo `

### Task 4: First login to the virtual machines 

Now that we have the base lab deployed, we can progress to the ... challenges!


# Challenge 2 : Collect logs from Windows VM

## Goal

## Task 1: 

## Task 2: 

## Task 3: 

**Explain the background...**

## Task 4: 

Before proceeding to challenge 3, ...

# Challenge 3: Collect logs from Linux VM 

## Goal

## Task 1: 

## Task 2: 

## Task 3: 

**Explain the background...**

## Task 4: 

Before proceeding to challenge 4, ...

# Challenge 4: First query with KQL

## Goal

## Task 1: Linux VM

## Task 2: Correlation query between Windows and Linux 



# Challenge 5: Onboard storage account to Log Analytics Workspace

## Goal

## Task 1: 

## Task 2: 

## Task 3: Immutable Storage for long term archive

**Explain the background...**

## Task 4: 

Before proceeding to challenge 6, ...

# Challenge 6: Onboard Activity Logs / Azure AD Logs to LA

## Goal

## Task 1: 

## Task 2: 

## Task 3: 

**Explain the background...**

## Task 4: 

Before proceeding to challenge 7, ...
 
# Challenge 7: Link Automation Account to LA Workspace

## Goal

## Task 1: 

## Task 2: 

## Task 3: 

**Explain the background...**

## Task 4: 

Before proceeding to challenge 8, ...

# Challenge 8: (Optional) Govern everything with Azure Policy 

## Goal

## Task 1: 

## Task 2: 

## Task 3: 

**Explain the background...**

## Task 4: 

Before proceeding to challenge 8, ...

# Finished? Delete your lab

Thank you for participating in this MicroHack!
