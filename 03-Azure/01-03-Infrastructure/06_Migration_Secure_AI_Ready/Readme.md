![image](img/1920x300_EventBanner_MicroHack_Migrate_wText.jpg)

# MicroHack - Migrate and Secure to be AI Ready

- [**MicroHack introduction**](#MicroHack-introduction)
- [**MicroHack context**](#microhack-context)
- [**Objectives**](#objectives)
- [**MicroHack Challenges**](#microhack-challenges)
- [**Contributors**](#contributors)

# MicroHack introduction

This MicroHack scenario walks through the process how to optimize and modernize you datacenter. The assessment, the tooling and processes are global best practices and with a focus on the real world scenarios, cost optimization and the best customer recommended design principles. Specifically, this builds up to include working with an existing infrastructure.

This lab is not a full explanation of building up a migration factory or a program to modernize your processes and dependencies. Please consider the following articles required pre-reading to build foundational knowledge.

* [Understand the security baseline from Azure Migrate](https://learn.microsoft.com/en-us/security/benchmark/azure/baselines/azure-migrate-security-baseline?context=%2Fazure%2Fmigrate%2Fcontext%2Fmigrate-context)
* [Build a migration plan](https://learn.microsoft.com/en-us/azure/migrate/concepts-migration-planning)
* [Assessment overview VM´s](https://learn.microsoft.com/en-us/azure/migrate/concepts-assessment-calculation)
* [Assessment overview App Service](https://learn.microsoft.com/en-us/azure/migrate/concepts-azure-webapps-assessment-calculation)
* [Assessment overview SQL](https://learn.microsoft.com/en-us/azure/migrate/concepts-azure-sql-assessment-calculation)
* [Azure Arc Enabled Extended Security Updates](https://learn.microsoft.com/en-us/windows-server/get-started/extended-security-updates-deploy)

Optional (read this after completing this lab to take your learning even deeper!)
* [Web apps migration support](https://learn.microsoft.com/en-us/azure/migrate/concepts-migration-webapps)
* [Support matrix for vSphere migration](https://learn.microsoft.com/en-us/azure/migrate/migrate-support-matrix-vmware-migration)
* [VMWare agentless migration architecture](https://learn.microsoft.com/en-us/azure/migrate/concepts-vmware-agentless-migration)
* [Support matrix for Hyper-V migration](https://learn.microsoft.com/en-us/azure/migrate/migrate-support-matrix-hyper-v-migration)
* [Hyper-V migration architecture](https://learn.microsoft.com/en-us/azure/migrate/hyper-v-migration-architecture)
* [Troubleshooting guide](https://learn.microsoft.com/en-us/azure/migrate/troubleshoot-general)

# MicroHack context
This MicroHack scenario walks through the use of Azure Migrate to support the process and the different phases of datacenter modernization: 

- Discover
- Decide
- Assess
- Migrate
- Modernize

As part of the MicroHack, we will simulate the discovery and migration of virtualized servers on Hyper-V to Azure. We will create the source systems as nested guest-VMs on top of a Hyper-V host within a dedicated source Resource Group in Azure to simulate the on-prem datacenter. We will use Azure Migrate to discover, assess and migrate the systems into a destination Resource Group that simulates the target Azure environment.

The concept behind physical server discovery and migration is described in detail under the following links:
* [Hyper-V server discovery](https://learn.microsoft.com/en-us/azure/migrate/migrate-support-matrix-hyper-v?view=migrate)
* [Hyper-V server migration](https://learn.microsoft.com/en-us/azure/migrate/tutorial-migrate-hyper-v?view=migrate&tabs=UI)

# Objectives

After completing this MicroHack you will:

- Know how to build an assessment & business case for you datacenter transformation 
- Understand the default and best practices how to quickly migrate workloads and safe with right sizing
- Understand how to use the tools and best practices to optimize and safe time
- Know how to not only use the tools to Lift & Shift, you will also understand how to modernize to cloud native services

# MicroHack challenges

## General prerequisites

This MicroHack has a few but important prerequisites

In order to use the MicroHack time most effectively, the following prerequisites should be completed prior to starting the session.

* Entra ID Tenant
* At least one Azure Subscription
* Entra ID user with Contributor or Owner permissions on the Azure Subscription

With these pre-requisites in place, we can focus on building the differentiated knowledge in Azure Migrate that is required when working with the product.



## Challenges

* [Challenge 1 - Prerequisites and landing zone preparation](challenges/challenge-01.md)  **<- Start here**
* [Challenge 2 - titDiscover physical servers for the migrationle](challenges/challenge-02.md)
* [Challenge 3 - Create a Business Case](challenges/challenge-03.md)
* [Challenge 4 - Assess VMs for the migration](challenges/challenge-04.md)
* [Challenge 5 - Migrate machines to Azure](challenges/challenge-05.md)
* [Optional Challenge 6 - Secure on Azure](challenges/challenge-06.md)
* [Optional Challenge 7 - Modernize with Azure](challenges/challenge-07.md)
* [Optional Challenge 8 - Deploy AI chat in App Service](challenges/challenge-08.md)

## Solutions - Spoilerwarning

* [Solution 1 - Prerequisites and landing zone preparation](./walkthrough/challenge-01/solution-01.md)
* [Solution 2 - Discover physical servers for the migration](./walkthrough/challenge-02/solution-02.md)
* [Solution 3 - Create a Business Case](./walkthrough/challenge-03/solution-03.md)
* [Solution 4 - Assess VMs for the migration](./walkthrough/challenge-04/solution-04.md)
* [Solution 5 - Migrate machines to Azure](./walkthrough/challenge-05/solution-05.md)
* [Optional Solution 6 - Secure on Azure](./walkthrough/challenge-06/solution-06.md)
* [Optional Solution 7 - Modernize with Azure](./walkthrough/challenge-07/solution-07.md)
* [Optional Solution 8 - Deploy AI chat in App Service](./walkthrough/challenge-08/solution-08.md)



## Contributors
* Nils Bankert [GitHub](https://github.com/nilsbankert); [LinkedIn](https://www.linkedin.com/in/nilsbankert/)
* Andreas Schwarz [LinkedIn](https://www.linkedin.com/in/andreas-schwarz-7518a818b/)
* Christian Thönes [Github](https://github.com/cthoenes); [LinkedIn](https://www.linkedin.com/in/christian-t-510b7522/)
* Stefan Geisler [Github](https://github.com/StefanGeislerMS); [LinkedIn](https://www.linkedin.com/in/stefan-geisler-7b7363139/)
