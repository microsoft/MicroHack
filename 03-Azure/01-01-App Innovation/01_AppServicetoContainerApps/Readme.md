# MicroHack AppService to ContainerApps

- [**MicroHack Introduction**](#MicroHack-introduction)
  - [What is the next generation of modernization and why does it matter](#what-is-the-next-generation-of-modernization-and-why-does-it-matter)
- [**MicroHack Context**](#microhack-context)
- [**MicroHack Objectives**](#objectives)
- [**MicroHack Challenges**](#microhack-challenges)
  - [General prerequisites](#general-prerequisites)
  - [Challenge 1 - Understand the migratable estate](#challenge-1---understand-the-migratable-estate)
  - [Challenge 2 - Containerize the Application](#challenge-2---containerize-the-application)
  - [Challenge 3 - Create the Container App](#challenge-3---create-the-container-app)
  - [Challenge 4 - Make the Container App Production Ready](#challenge-4---make-the-container-app-production-ready)
- [**Contributors**](#contributors)

## MicroHack Introduction

### What is the next generation of modernization and why does it matter? 

## MicroHack Context

This MicroHack scenario walks through the modernization from an application what was hosted on [Azure Virtual Machines](https://azure.microsoft.com/en-us/products/virtual-machines) or in an [Azure App Service](https://azure.microsoft.com/en-us/products/app-service) to completely managed container based infrastructure, with a focus on the best practices and the design principles and some interesting challenges for real world scenarios. Specifically, this builds up to include working with an existing infrastructure in your datacenter.

## MicroHack Objectives

After completing this MicroHack you will:

* Understand containerization and hosting options on Azure
* Know how to use the right tools for containerization from an existing application / workload in your environment, on-prem or Multi-cloud
* Understand use cases and possible scenarios in your particular infrastructure to modernize your infrastructure estate 
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
  * Please make sure you have at least Version 3.4.2 installs with the following Command: ```Install-Module -Name GuestConfiguration -RequiredVersion 3.4.2```
* [Visual Studio Code](https://code.visualstudio.com/)
* [Git SCM](https://git-scm.com/download/)

You need to execute this script in the Azure Cloud Shell to deploy the initial App Service resource that we will start with in a resource group named "MicroHack-AppServiceToContainerApp"

`az group create --name "MicroHack-AppServiceToContainerApp" --location "westeurope"`

`az appservice plan create --name "microhack-appserviceplan" --resource-group "MicroHack-AppServiceToContainerApp" --location "westeurope" --is-linux --sku "FREE"`

To create the web app, you need to run this command. Web app names must be globally unique, since the name will be used in the URL. You can name the web app something like "microhack-webapp-" and then append a name or some random characters, e.g. "microhack-webapp-johndoe22" or "microhack-webapp-jdkas":

`az webapp create --name "<your_globally_unique_webapp_name>" --resource-group "MicroHack-AppServiceToContainerApp" --plan "microhack-appserviceplan" --runtime "DOTNETCORE:8.0" --deployment-source-url "https://github.com/ArneDecker3v08mk/MicroHack-AppServiceToContainerAppStart" --deployment-source-branch "main"`

 **Troubleshooting:**
 If you see this error, then the name of the web app was already used and you need to try another name:

`Error Message: Webapp 'microhack-webapp-...' already exists. The command will use the existing app's settings. Unable to retrieve details of the existing app 'microhack-webapp-...'. Please check that the app is a part of the current subscription`

It may take up to 5 minutes for the web app to start in the background.

You also need to fork this GitHub repository that you will work with: https://github.com/ArneDecker3v08mk/MicroHack-AppServiceToContainerAppStart 

## Challenge 1 - Understand the migratable estate 

### Goal

Before a migration can start you need to first understand what needs to be migrated and why. The first challenge is therefore about analyzing the current application and hosting environment. You will compare classic deployments (like the Azure App Service) with containerized deployments to understand the differences and advantages of both approaches.

### Actions

Have a look in the Git repository of the application and the App Service resource in Azure to familiarize yourself with the current environment. Then answer these questions:

* In which framework and version is the application written?
* On which operating system (Windows or Linux) is the application currently running?
* What message does the application state when you open in the browser?


**!!!Important: You can ignore the text fields and the button for now, the functionality behind it will be added in the last challenge!!!**

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
* You created a workflow that pushes a deployable container image to the registry

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
        echo "image_tag=$UPDATED_TAG" >> $GITHUB_OUTPUT

### Success Criteria

* You successfully deployed the container image to the Container App
* You can access the newly hosted web app
* You can make changes to the web app and deploy them into the Container App

### Learning resources

* [Creating an Azure Container App](https://learn.microsoft.com/en-us/azure/container-apps/quickstart-portal)
* [Connection Azure and GitHub (use option 2)](https://learn.microsoft.com/en-us/azure/developer/github/connect-from-azure-openid-connect)
* [Deploying Azure Container Apps with GitHub 1](https://learn.microsoft.com/en-us/azure/container-apps/github-actions)
* [Deploying Azure Container Apps with GitHub 2](https://github.com/Azure/container-apps-deploy-action)

### Solution - Spoilerwarning

[Solution Steps](./walkthrough/challenge-3/solution.md)

## Challenge 4 - Make the Container App Production Ready

### Goal

Now that the app is up and running and you can deploy changes quickly, it is time to make some enhancements to make your application ready for production.

### Actions

* Enable authentication with Azure Entra ID
* Configure Autoscaling to 200 concurrent connections with 1 to 10 replicas
* Enable monitoring and logging
* Configure encryption

### Success criteria

* You have enabled authentication with Azure Entra ID
* You have configured the autoscaling rules
* You can check the logs in the Log Analytics workspace
* All traffic to/from the Container App is encrypted

### Learning resources

* [Enable Authentication on Azure Container Apps](https://learn.microsoft.com/en-us/azure/container-apps/authentication-azure-active-directory)
* [Scaling Azure Container Apps](https://learn.microsoft.com/en-us/azure/container-apps/scale-app?pivots=azure-portal)
* [Monitoring with Azure Container Apps](https://learn.microsoft.com/en-us/azure/container-apps/log-monitoring?tabs=bash)
* [Loggin with Azure Container Apps](https://learn.microsoft.com/en-us/azure/container-apps/log-options)

### Solution - Spoilerwarning

[Solution Steps](./walkthrough/challenge-4/solution.md)

## Challenge 5 - Host Your Own AI Models

### Goal

Your production-ready Container App is still missing one thing, you cannot really use it for anything, yet. Time to host your own small AI model that you can chat with via the app.

### Actions

* Host an Ollama container image in a second Container App (or any other model)
* Start an Ollama model in the Container App
* Add the URL of the AI app to your main app via an environment variable

### Success criteria

* You can chat with an AI model via your app

### Learning resources

* [Ollama documentation](https://github.com/ollama/ollama)
* [Ollama on Docker Hub](https://hub.docker.com/r/ollama/ollama)

### Solution - Spoilerwarning

[Solution Steps](./walkthrough/challenge-5/solution.md)

## Finish

Congratulations! You finished!
As you saw, containerizing and deploying an application is no rocket science. The Azure Container Apps will take over most of the work so you can focus on your application instead of the hosting.

Thank you for investing the time and see you next time!

## Contributors
* Nils Bankert [GitHub](https://github.com/nilsbankert); [LinkedIn](https://www.linkedin.com/in/nilsbankert/)
* Arne Decker [GitHub](https://github.com/placeholder/); [LinkedIn](https://www.linkedin.com/in/arne-decker-918ba618b/)
