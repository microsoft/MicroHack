# MicroHack AppService to ContainerApps

- [**MicroHack Introduction**](#MicroHack-introduction)
  - [What is the next generation of modernization and why does it matter](#what-is-the-next-generation-of-modernization-and-why-does-it-matter)
- [**MicroHack Context**](#microhack-context)
- [**MicroHack Objectives**](#objectives)
- [**MicroHack Challenges**](#microhack-challenges)
  - [General prerequisites](#general-prerequisites)
  - [Challenge 1 - Understand the migratable estate](#challenge-1---understand-the-migratable-estate)
  - [Challenge 2 - Prepare the deployment worklfow](#challenge-2---prepare-the-deployment-workflow)
  - [Challenge 3 - Set up the landing zone](#challenge-3---set-up-and-configure-the-landing-zone)
  - [Challenge 4 - Post deployment actions and ToDo´s](#challenge-4---post-deployment-tasks-and-todo´s)
  - [Challenge 5 - Bring it to the end user with secure authentication](#challenge-5---bring-it-to-the-end-usern)
- [**Contributors**](#contributors)

## MicroHack Introduction

### What is the next generation of modernization and why does it matter? 

## MicroHack Context

This MicroHack scenario walks through the modernization from an application what was hosted on [Azure Virtual Machines](https://azure.microsoft.com/en-us/products/virtual-machines) or in an [Azure App Service](https://azure.microsoft.com/en-us/products/app-service) to completely managed container based infrastructure, with a focus on the best practices and the design principles and some interesting challenges for real world scenarios. Specifically, this builds up to include working with an existing infrastructure in your datacenter.

Further resources:_

* [tbd](link)


💡 Optional: Read this after completing this lab to deepen the learned!

## MicroHack Objectives

After completing this MicroHack you will:

* Understand containerization and hosting options on Azure
* Know how to use the right tools for containerization from an existing application / workload in your environment, on-prem or Multi-cloud
* Understand use cases and possible scenarios in your particular inrastructure to modernize your infrastructure estate 
* Get insights into real world challenges and scenarios

## MicroHack Challenges

### General prerequisites

This MicroHack has a few but important prerequisites to be understood before starting this lab!

* Your own Azure subscription with Owner RBAC rights at the subscription level
  * [Azure Evaluation free account](https://azure.microsoft.com/en-us/free/search/?OCID=AIDcmmzzaokddl_SEM_0fa7acb99db91c1fb85fcfd489e5ca6e:G:s&ef_id=0fa7acb99db91c1fb85fcfd489e5ca6e:G:s&msclkid=0fa7acb99db91c1fb85fcfd489e5ca6e)
* Your own [GitHub account](https://github.com/)
* [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) (Hint: Make sure to use the lastest version)
* [Azure PowerShell Guest Configuration Cmdlets](https://learn.microsoft.com/en-us/azure/governance/machine-configuration/machine-configuration-create-setup#install-the-module-from-the-powershell-gallery)
  * It is not possible to run those commands from Azure Cloud Shell
  * Please make sure you have at least Version 3.4.2 installes with the following Command: ```Install-Module -Name GuestConfiguration -RequiredVersion 3.4.2```
* [Visual Studio Code](https://code.visualstudio.com/)
* [Git SCM](https://git-scm.com/download/)

## Challenge 1 - Understand the migratable estate 

### Goal

Before a migration can start you need to first understand what needs to be migrated and why. The first challenge is therefore about analyzing the current application and hosting environment. You will compare classic deployments (like the Azure App Service) with containerized deployments to understand the differences and advantages of both approaches.

### Actions

Have a look in the Git repository of the application and the App Service resource in Azure to familiarize yourself with the current environment. Then answer these questions:

* In which framework and version is the application written?
* On which operating system (Windows or Linux) is the application currently running?
* What message does the application state when you open in the browser?

Read through the learning resources and answer the following questions:

* What is containerization and what is a container?
* What are typical advantages of containerization?
* Why would a migration from a PaaS hosting to containerization make sense?
* Which container services are available on Azure?

Bonus question:

When migrating from the App Service to a containerized hosting, which service would be most suitable from you point of view?

### Success criteria

* You answered all questions from above
* You have an overview of containerization and PaaS (and respective Azure services)
* You successfully started the web app in your browser

### Learning resources

* [Container introduction](https://resources.github.com/devops/containerization/)
* [Docker introduction](https://learn.microsoft.com/en-us/training/modules/intro-to-docker-containers/)
* [Containerization vs. PaaS](https://www.techtarget.com/searchcloudcomputing/feature/PaaS-and-containers-Key-differences-similarities-and-uses)
* [Azure Services](https://learn.microsoft.com/en-us/azure/container-apps/compare-options)

### Solution - Spoilerwarning

[Solution Steps](./walkthrough/challenge-1/solution.md)

## Challenge 2 - Containerize the Application

### Goal
Before the application can be deployed to a Container App, it needs to be containerized. As you already know, this means encapsulating the application code with all dependencies and required software into a container image. The images are typically stored ("pushed") in a container registry, from which they can loaded ("pulled") to be deployed into a container hosting service.

### Actions

* Create an Azure Container Registry
* Setup a new GitHub Actions workflow in the repository to build the application <br> While we will stick to the GitHub terminology and call it a workflow, in CI/CD and DevOps terms this is also known as a pipeline
* Create a Dockerfile and add it into the repository
* Add steps to the GitHub Actions workflow to containerize the application and push the image into the container registry

### Success criteria

* You have created the Azure Container Registry
* You created a new GitHub Actions workflow
* The workflow that pushes a deployable container image to the registry

### Learning resources

* [Creating an Azure Container Registry](https://learn.microsoft.com/en-us/azure/container-registry/container-registry-get-started-portal?tabs=azure-cli)
* [Creating a GitHub Actions pipeline](https://docs.github.com/en/actions/automating-builds-and-tests/building-and-testing-net)
* [Docker and .NET](https://learn.microsoft.com/en-us/dotnet/core/docker/introduction)
* [Azure Container Registry Build](https://github.com/marketplace/actions/azure-container-registry-build)

### Solution - Spoilerwarning

[Solution Steps](./walkthrough/challenge-2/solution.md)

## Challenge 3 - Create the Container App

### Goal

Now that you have a deployable container image, you can setup the Container App to host you web app. As described above, you will use the Container Apps because it is a simple, scalable and straight-forward service that is perfectly suitable for this use case. However, the container image is highly portable and could be deployed into other container services as well.

### Actions

* Create an Azure Container App and the Environment
* Automate the deployment with GitHub Actions
* Make a change and deploy it

Hint: Use this workflow task to get the latest container image tag from the registry. You can insert the task after the login to Azure and then use the variable `image_tag`:

      - name: Get Latest Container Image Tag
        id: get_tag
        run: |
          TAG=$(az acr repository show-tags --name microhackregistry --repository microhackapp --orderby time_desc --output tsv --detail | head -n 1 | awk '{print $4}')
          NUMERIC_TAG=$(echo "$TAG" | grep -oE '[0-9]+')
          INCREMENTED_TAG=$((NUMERIC_TAG + 1))
          UPDATED_TAG=$(echo "$TAG" | sed "s/$NUMERIC_TAG/$INCREMENTED_TAG/")
          echo "::set-output name=image_tag::$UPDATED_TAG"

### Success Criteria

* You successfully deployed the container image to the Container App
* You can access the newly hosted web app
* You can make changes to the web app and deploy them into the Container App

### Learning resources

* [Creating an Azure Container App](https://learn.microsoft.com/en-us/azure/container-apps/quickstart-portal)
* [Assigning GitHub Actions workflows permissions on Azure](https://learn.microsoft.com/en-us/azure/developer/github/connect-from-azure?tabs=azure-portal%2Cwindows)
* [Deploying Azure Container Apps with GitHub 1](https://learn.microsoft.com/en-us/azure/container-apps/github-actions)
* [Deploying Azure Container Apps with GitHub 2](https://github.com/Azure/container-apps-deploy-action)

### Solution - Spoilerwarning

[Solution Steps](./walkthrough/challenge-3/solution.md)

## Challenge 4 - Make the Container App Production Ready

### Goal

Now that the app is up and running and you can deploy changes quickly, it is time to make some enhancements to make your application ready for production.

### Actions

* Enable authentication with Azure Entra ID
* Enable monitoring and logging

### Success criteria

* You have enabled authentication with Azure Entra ID
* You can check the logs in the Log Analytics workspace

### Learning resources

*[Enable Authentication on Azure Container Apps](https://learn.microsoft.com/en-us/azure/container-apps/authentication-azure-active-directory)
*[Monitoring with Azure Container Apps](https://learn.microsoft.com/en-us/azure/container-apps/log-monitoring?tabs=bash)
*[Loggin with Azure Container Apps](https://learn.microsoft.com/en-us/azure/container-apps/log-options)

### Solution - Spoilerwarning

[Solution Steps](./walkthrough/challenge-4/solution.md)

## Finish

Congratulations! You finished ....

Thank you for investing the time and see you next time!

## Contributors
* Nils Bankert [GitHub](https://github.com/nilsbankert); [LinkedIn](https://www.linkedin.com/in/nilsbankert/)
* Arne Decker [GitHub](https://github.com/placeholder/); [LinkedIn](https://www.linkedin.com/in/arne-decker-918ba618b/)