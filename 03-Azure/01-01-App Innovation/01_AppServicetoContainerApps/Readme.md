# MicroHack AppService to ContainerApps

- [**MicroHack Introduction**](#MicroHack-introduction)
  - [What is the next generation of modernization and why does it matter](#what-is-the-next-generation-of-modernization-and-why-does-it-matter)
- [**MicroHack Context**](#microhack-context)
- [**MicroHack Objectives**](#objectives)
- [**MicroHack Challenges**](#microhack-challenges)
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


### Challenges

* [Challenge 1 - Understand the migratable estate](challenges/challenge-01.md)  **<- Start here**
* [Challenge 2 - Containerize the Application](challenges/challenge-02.md)
* [Challenge 3 - Create the Container App](challenges/challenge-03.md)
* [Challenge 4 - Make the Container App Production Ready](challenges/challenge-04.md)
* [Challenge 5 - Host Your Own AI Models](challenges/challenge-05.md)

### Solutions - Spoilerwarning

* [Solution 1 - Prerequisites and Landing Zone](./walkthrough/challenge-01/solution-01.md)
* [Solution 2 - Containerize the Application](./walkthrough/challenge-02/solution-02.md)
* [Solution 3 - Create the Container App](./walkthrough/challenge-03/solution-03.md)
* [Solution 4 - Make the Container App Production Ready](./walkthrough/challenge-04/solution-04.md)
* [Solution 5 - Host Your Own AI Models](./walkthrough/challenge-05/solution-05.md)


## Contributors
* Nils Bankert [GitHub](https://github.com/nilsbankert); [LinkedIn](https://www.linkedin.com/in/nilsbankert/)
* Arne Decker [GitHub](https://github.com/placeholder/); [LinkedIn](https://www.linkedin.com/in/arne-decker-918ba618b/)
