# **MicroHack AppService to ContainerApps **

- [**MicroHack introduction**](#MicroHack-introduction)
  - [What is the next generation of modernization and why does it matter](#what-is-the-next-generation-of-modernization-and-why-does-it-matter)
- [**MicroHack context**](#microhack-context)
- [**Objectives**](#objectives)
- [**MicroHack Challenges**](#microhack-challenges)
  - [General prerequisites](#general-prerequisites)
  - [Challenge 1 - Understand the migratable estate](#challenge-1---understand-the-migratable-estate)
  - [Challenge 2 - Prepare the deployment worklfow](#challenge-2---prepare-the-deployment-workflow)
  - [Challenge 3 - Set up the landing zone](#challenge-3---set-up-and-configure-the-landing-zone)
  - [Challenge 4 - Post deployment actions and ToDo´s](#challenge-4---post-deployment-tasks-and-todo´s)
  - [Challenge 5 - Bring it to the end user with secure authentication](#challenge-5---bring-it-to-the-end-usern)
- [**Contributors**](#contributors)

## MicroHack introduction

### What is the next generation of modernization and why does it matter? 

## MicroHack context

This MicroHack scenario walks through the modernization from an application what was hosted in virtual machine or in an Azure App Service to completely managed container based infrastructure, with a focus on the best practices and the design principles and some interesting challenges for real world scenarios. Specifically, this builds up to include working with an existing infrastructure in your datacenter.

Further resources:_

* [tbd](link)


💡 Optional: Read this after completing this lab to deepen the learned!

## Objectives

After completing this MicroHack you will:

* Know how to use the right tools for containerization from an existing application / workload in your environment, on-prem or Multi-cloud
* Understand use cases and possible scenarios in your particular inrastructure to modernize your infrastructure estate 
* Get insights into real world challenges and scenarios

## MicroHack Challenges

### General prerequisites

This MicroHack has a few but important prerequisites to be understood before starting this lab!

* Your own Azure subscription with Owner RBAC rights at the subscription level
  * [Azure Evaluation free account](https://azure.microsoft.com/en-us/free/search/?OCID=AIDcmmzzaokddl_SEM_0fa7acb99db91c1fb85fcfd489e5ca6e:G:s&ef_id=0fa7acb99db91c1fb85fcfd489e5ca6e:G:s&msclkid=0fa7acb99db91c1fb85fcfd489e5ca6e)
* [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) (Hint: Make sure to use the lastest version)
* [Azure PowerShell Guest Configuration Cmdlets](https://learn.microsoft.com/en-us/azure/governance/machine-configuration/machine-configuration-create-setup#install-the-module-from-the-powershell-gallery)
  * It is not possible to run those commands from Azure Cloud Shell
  * Please make sure you have at least Version 3.4.2 installes with the following Command: ```Install-Module -Name GuestConfiguration -RequiredVersion 3.4.2```
* [Visual Studio Code](https://code.visualstudio.com/)
* [Git SCM](https://git-scm.com/download/)

## Challenge 1 - Understand the migratable estate 

### Goal

In challenge 1 you will prepare ....

### Actions

* Create all necessary Azure Resources..

### Success criteria

* You created an Azure Resource Group
* You created an Service Principal with the required role membership
* .....

### Learning resources

* [Plan and deploy](Link)

### Solution - Spoilerwarning

[Solution Steps](./walkthrough/challenge-1/solution.md)

## Challenge 2 - Prepare the deployment workflow

### Goal

In challenge 2 you will successfully ...

### Actions

* Create all necessary ...


### Success criteria

* You have a ...

### Learning resources


### Solution - Spoilerwarning

[Solution Steps](./walkthrough/challenge-2/solution.md)

## Challenge 3 - Set up and configure the landing zone

### Goal

Managing secrets, credentials or certificates...

### Actions

* Create ..

### Success Criteria

* You successfully output ...

### Learning resources

### Solution - Spoilerwarning

[Solution Steps](./walkthrough/challenge-3/solution.md)

## Challenge 4 - Post-deployment tasks and todo´s

### Goal

* In this challenge, we will ..
### Actions

* Enable M...

### Success criteria

* Open ...

### Learning resources

...

### Solution - Spoilerwarning

[Solution Steps](./walkthrough/challenge-4/solution.md)

## Challenge 5 - Bring it to the end user 

### Goal

Challenge 5 is all about interacting with...

### Actions

* Create all ...`

### Success criteria

* You ca...
### Learning resources

### Solution - Spoilerwarning

[Solution Steps](./walkthrough/challenge-5/solution.md)

## Finish

Congratulations! You finished ....

Thank you for investing the time and see you next time!


## Contributors
* Nils Bankert [GitHub](https://github.com/nilsbankert); [LinkedIn](https://www.linkedin.com/in/nilsbankert/)
* Arne Decker [GitHub](https://github.com/placeholder/); [LinkedIn](https://www.linkedin.com/in/arne-decker-918ba618b/)

