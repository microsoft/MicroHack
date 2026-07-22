# Challenge 8 - Replatform a migrated web workload to Azure App Service

[Previous Challenge](challenge-07.md) - **[Home](../Readme.md)** - [Finish](finish.md)

Duration: 45 minutes

## Goal

Select either the migrated Windows/IIS workload or the Ubuntu/Apache workload for a guided manual replatform to Azure App Service. Inspect what the site needs, package its portable static content, deploy it to the appropriate managed App Service platform, and prove that the new endpoint operates independently of the source VM.

## Select a path

| Path | Source | Guided target |
| --- | --- | --- |
| A | Windows Server / IIS | Windows App Service |
| B | Ubuntu Linux / Apache | Linux App Service with a supported Node.js LTS runtime |

Complete one path during the standard challenge time. If time permits, you may complete both. Use a distinct App Service plan and a distinct globally unique web-app name for each path because Windows and Linux apps require plans for their respective operating systems.

> [!IMPORTANT]
> Azure Migrate's agentless at-scale web-app migration supports ASP.NET applications on Windows IIS servers hosted in VMware environments. It doesn't directly modernize this Hack's Hyper-V-hosted IIS site or its Linux/Apache site. This challenge therefore performs a deliberate manual replatform from an already migrated Azure VM.

## Prerequisites

* Challenge 7 is complete and both `W3SVC` and `apache2` have been restored.
* You can connect to the source VM for your chosen path through Azure Bastion.
* You know the Hack subscription ID and can create App Service resources in it.
* You know the exact destination resource group. The Bicep deployment names it `MHBox-<UserSuffix>-destination-rg`, where `<UserSuffix>` is the deployer's user principal name before `@`.
* The selected site content is available at `C:\inetpub\wwwroot` or `/var/www/html`.
* Path A can use Azure Cloud Shell and an interactive browser session for Kudu ZIP upload, or the documented CLI alternative.
* Path B can make an interactive device-code sign-in from the migrated Linux VM and has permission to deploy App Service resources.
* No GitHub repository, repository connection, Azure OpenAI deployment, or model quota is required.

## Actions

### Common actions

* Select Path A or Path B and inspect the site's content, bindings or virtual host, runtime/modules, dependencies, and state requirements.
* Confirm that the site is portable static HTML, CSS, and image content. No additional Azure Migrate portal action is required at this stage.
* Replace the VM-specific hostname, platform, and web-server values in the package by using the page's stable metadata attributes.
* Create a ZIP package whose root contains `index.html`.
* Set and display the intended Azure subscription, tenant, and user before any resource operation. Stop if they don't identify the Hack subscription.
* Replace the destination resource-group placeholder with the exact `MHBox-<UserSuffix>-destination-rg` name and verify that it exists.
* Create a low-cost App Service plan for the selected operating system and a globally unique web app.
* Deploy with supported App Service ZIP deployment, enforce HTTPS, and validate the page and assets.
* Stop the source web service, prove that App Service remains available, and restore the source service.
* Compare App Service with Azure Storage static website hosting and Azure Static Web Apps for a production architecture decision.

### Path A - Windows Server / IIS

* Inventory IIS bindings, the application pool, runtime settings, and `C:\inetpub\wwwroot`.
* Create the package with PowerShell `Compress-Archive`.
* Create a Windows App Service plan and deploy through Kudu ZIP deploy or the documented Azure CLI alternative.

### Path B - Ubuntu Linux / Apache

* Inventory Apache virtual hosts, modules, configuration, and `/var/www/html`.
* Stage a user-owned copy, make it portable, and create and verify the ZIP with Linux tools.
* Use device-code authentication, deterministically select the newest advertised Node.js LTS runtime, create a Linux App Service plan, and configure PM2 to serve the static ZIP.
* Sign out of Azure CLI after deployment.

## Success criteria

* The selected site's inspection shows no required server-side runtime, database, machine-local dependency, or session state.
* The active subscription, tenant, user, and exact destination resource group are displayed and verified before deployment.
* The ZIP root contains `index.html` rather than a nested content directory.
* The chosen Windows or Linux App Service app serves the selected site's page and assets over HTTPS.
* A Path B app uses a runtime returned by `az webapp list-runtimes --os-type linux` and a PM2 static-content startup command.
* The rendered page identifies the hostname as Azure App Service, the platform as managed PaaS, and the web server as Azure App Service.
* The App Service endpoint remains healthy while the selected source service is stopped, and the source service is restored afterward.
* Path B signs out of Azure CLI after deployment.
* No Azure Load Balancer is placed in front of App Service and no GitHub integration is required.

## Architecture decision

App Service is the pedagogical target because it demonstrates replatforming to a managed web platform. For this purely static workload, an [Azure Storage static website](https://learn.microsoft.com/en-us/azure/storage/blobs/storage-blob-static-website) is likely the simplest and most cost-effective production target. [Azure Static Web Apps](https://learn.microsoft.com/en-us/azure/static-web-apps/overview) is another strong option when globally distributed static content, integrated authentication, APIs, and repository-driven delivery are desired. Treat the final production target as an architecture decision, not an assumption that App Service is always optimal.

## Learning resources

* [Azure Migrate web-app migration support matrix](https://learn.microsoft.com/en-us/azure/migrate/concepts-migration-webapps?view=migrate)
* [Deploy files to Azure App Service](https://learn.microsoft.com/en-us/azure/app-service/deploy-zip)
* [Azure CLI App Service plan reference](https://learn.microsoft.com/en-us/cli/azure/appservice/plan?view=azure-cli-latest#az-appservice-plan-create)
* [Azure CLI web app reference](https://learn.microsoft.com/en-us/cli/azure/webapp?view=azure-cli-latest)
* [Configure Node.js in App Service](https://learn.microsoft.com/en-us/azure/app-service/configure-language-nodejs)
* [Install Azure CLI on Ubuntu or Debian](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli-linux?view=azure-cli-latest&pivots=apt)
* [Sign in interactively with Azure CLI](https://learn.microsoft.com/en-us/cli/azure/authenticate-azure-cli-interactively?view=azure-cli-latest)
* [Enforce HTTPS in Azure App Service](https://learn.microsoft.com/en-us/azure/app-service/configure-ssl-bindings#enforce-https)
* [Static Content Hosting pattern](https://learn.microsoft.com/en-us/azure/architecture/patterns/static-content-hosting)
