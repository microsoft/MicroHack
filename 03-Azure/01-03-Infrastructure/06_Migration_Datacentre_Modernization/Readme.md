# **Migration & Datacentre Modernization MicroHack**

- [**MicroHack introduction**](#MicroHack-introduction)
- [**MicroHack context**](#microhack-context)
- [**Objectives**](#objectives)
- [**MicroHack Challenges**](#microhack-challenges)
- [**Contributors**](#contributors)

# MicroHack introduction

This MicroHack scenario walks through the process how to optimize and modernize you datacentre. The assessment, the tooling and processes are global best practices and with a focus on the real world scenarios, cost optimization and the best customer recommended design principles. Specifically, this builds up to include working with an existing infrastructure.

![image](./img/azuremigratebusinesscase.png)
![image](./img/migration-assessment-architecture.png)

This lab is not a full explanation of building up a migration factory or a program to modernize your processes and dependencies. Please consider the following articles required pre-reading to build foundational knowledge.

* [Understand the security baseline from Azure Migrate](https://learn.microsoft.com/en-us/security/benchmark/azure/baselines/azure-migrate-security-baseline?context=%2Fazure%2Fmigrate%2Fcontext%2Fmigrate-context)
* [Build a migration plan](https://learn.microsoft.com/en-us/azure/migrate/concepts-migration-planning)
* [Assessment overview VM´s](https://learn.microsoft.com/en-us/azure/migrate/concepts-assessment-calculation)
* [Assessment overview App Service](https://learn.microsoft.com/en-us/azure/migrate/concepts-azure-webapps-assessment-calculation)
* [Assessment overview SQL](https://learn.microsoft.com/en-us/azure/migrate/concepts-azure-sql-assessment-calculation)

Optional (read this after completing this lab to take your learning even deeper!)
* [Web apps migration support](https://learn.microsoft.com/en-us/azure/migrate/concepts-migration-webapps)
* [Support matrix for vSphere migration](https://learn.microsoft.com/en-us/azure/migrate/migrate-support-matrix-vmware-migration)
* [VMWare agentless migration architecture](https://learn.microsoft.com/en-us/azure/migrate/concepts-vmware-agentless-migration)
* [Support matrix for Hyper-V migration](https://learn.microsoft.com/en-us/azure/migrate/migrate-support-matrix-hyper-v-migration)
* [Hyper-V migration architecture](https://learn.microsoft.com/en-us/azure/migrate/hyper-v-migration-architecture)
* [Troubleshooting guide](https://learn.microsoft.com/en-us/azure/migrate/troubleshoot-general)

# MicroHack context
This MicroHack scenario walks through the use of Azure Migrate to support the process and the different phases of datacentre modernization: 

- Discover
- Decide
- Assess
- Migrate
- Modernize

# Objectives

After completing this MicroHack you will:

- Know how to build a an assessment & business case for you datecentre transformation 
- Understand the default and best practices how to quickly migrate workloads and safe with right sizing
- Understand how to use the tools and best practices to optimize and safe time
- Know how to not only use the tools to Lift & Shift, you will also understand how to modernize to cloud native services

# MicroHack challenges

## General prerequisites (Christian)

This MicroHack has a few but important prerequisites

In order to use the MicroHack time most effectively, the following tasks should be completed prior to starting the session.

* External Tenant Setup 

With these pre-requisites in place, we can focus on building the differentiated knowledge in ... that is required when working with the product, rather than spending hours repeating relatively simple tasks such as setting up....

## Challenge 1 - Prerequisites and landing zone preparation (Nico)

### Goal 

* Deploy at least two VM´s with Bicep
* One Linux Ubuntu / Windows VM 
* Use a script to simulate CPU utilization 
* IIS / Apache as a simple approach to simulate

### Actions

* A1
* A2
* A3

### Success criteria

* You have deployed Azure Migrate in you subscription
* You successfully downloaded, installed and connected you infrastructure to Azure Migrate
* You have understood the concept and architecture for the MicroHack

### Learning resources
* [Create and managed Azure Migrate projects](https://learn.microsoft.com/en-us/azure/migrate/create-manage-projects)
* [Setup and appliance on VMWare](https://learn.microsoft.com/en-us/azure/migrate/how-to-set-up-appliance-vmware)
* [Setup and appliance on Hyper-V](https://learn.microsoft.com/en-us/azure/migrate/how-to-set-up-appliance-hyper-v)
* [Steup an appliance via script](https://learn.microsoft.com/en-us/azure/migrate/deploy-appliance-script)
* [Before you start / general prerequisites](https://learn.microsoft.com/en-us/azure/migrate/how-to-discover-applications#before-you-start)

### Solution - Spoilerwarning

[Solution Steps](./walkthrough/challenge-1/solution.md)

## Challenge 1 - Discover VM´s for the migration

### Goal 

The goal of this exercise is to deploy...

### Actions

* A1
* A2
* A3

### Success criteria

* You have deployed ....
* You successfully enabled ...
* You have successfully setup ....
* You have successfully ....

### Learning resources
* [Create an assessment on Hyper-V]([You have successfully verified servers in the portal](https://learn.microsoft.com/en-us/azure/migrate/how-to-set-up-appliance-hyper-v#verify-servers-in-the-portal))

### Solution - Spoilerwarning

[Solution Steps](./walkthrough/challenge-2/solution.md)

## Challenge 2 - Create a Business Case 

### Goal 

The goal of this exercise is to deploy...

### Actions

* A1
* A2
* A3

### Success criteria

* You have deployed ....
* You successfully enabled ...
* You have successfully setup ....
* You have successfully ....

### Learning resources
* [Create a Business Case](https://learn.microsoft.com/en-us/azure/migrate/how-to-build-a-business-case)


### Solution - Spoilerwarning

[Solution Steps](./walkthrough/challenge-2/solution.md)


## Challenge 3 - Assess VM´s for the migration

### Goal 

The goal of this exercise is to deploy...

### Actions

* A1
* A2
* A3

### Success criteria

* You have deployed ....
* You successfully enabled ...
* You have successfully setup ....
* You have successfully ....

### Learning resources
* [Create an assessment on Hyper-V](https://learn.microsoft.com/en-us/azure/migrate/tutorial-assess-hyper-v)
* [Create an assessment on VMWare](https://learn.microsoft.com/en-us/azure/migrate/tutorial-assess-vmware-azure-vm)
* [Create an assessment for SQL](https://learn.microsoft.com/en-us/azure/migrate/tutorial-assess-sql)
* [Create an assessment for AWS Instances](https://learn.microsoft.com/en-us/azure/migrate/tutorial-assess-aws)

## Challenge 4 - Migrate VM´s

### Goal 

### Actions

### Success criteria

### Learning resources
* [Migrate Hyper-V VM´s to Azure](https://learn.microsoft.com/en-us/azure/migrate/tutorial-migrate-hyper-v)
* [Migrate options for VMWare to Azure](https://learn.microsoft.com/en-us/azure/migrate/server-migrate-overview)
* [Migrate Physical Servers](https://learn.microsoft.com/en-us/azure/migrate/tutorial-migrate-physical-virtual-machines)
* [Migrate AWS Instances to Azure](https://learn.microsoft.com/en-us/azure/migrate/tutorial-migrate-aws-virtual-machines)
* [Migrate GCP Instances to Azure](https://learn.microsoft.com/en-us/azure/migrate/tutorial-migrate-gcp-virtual-machines)

## Finish

Congratulations! You finished the MicroHack for Migration and Modernization. We hope you had the chance to learn about the how to implement a successful...
If you want to give feedback please dont hesitate to open an Issue on the repository or get in touch with one of us directly.

Thank you for investing the time and see you next time!


## Contributors
* Nils Bankert [GitHub](https://github.com/nilsbankert); [LinkedIn](https://www.linkedin.com/in/nilsbankert/)
