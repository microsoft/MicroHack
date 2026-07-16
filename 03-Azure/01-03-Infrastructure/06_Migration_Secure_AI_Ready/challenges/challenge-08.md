# Challenge 8 - Replatform the selected migrated web workload to Azure App Service

[Previous Challenge](challenge-07.md) - **[Home](../Readme.md)** - [Finish](finish.md)

Duration: 40 minutes

## Goal

Replatform the web workload selected in Challenge 7 from an IaaS VM to a managed web app in Azure App Service. First discover what the site actually needs, then package and deploy it without a source repository integration.

Continue with the same track:

* **Track A:** Windows Server / IIS
* **Track B:** Ubuntu Linux / Apache

Teams complete only their selected track.

> [!IMPORTANT]
> Azure Migrate's agentless at-scale web-app migration supports ASP.NET applications on Windows IIS servers hosted in VMware environments. It does not support direct web-app migration from this Hack's Hyper-V source scenario or this Linux/Apache workload. This challenge therefore performs a deliberate manual replatform from the already migrated Azure VM.

## Prerequisites

* Challenge 7 is complete and the selected `W3SVC` or `apache2` service has been restored.
* You can connect to the selected migrated VM by using Azure Bastion.
* You can create an App Service plan and web app in `destination-rg`.
* The selected site content is available at `C:\inetpub\wwwroot` or `/var/www/html`.
* Track A has an interactive browser session available for Kudu ZIP upload, or can use the documented CLI alternative.
* Track B can make an interactive device-code sign-in from the migrated Linux VM and has permission to deploy the App Service resources.
* No GitHub repository, repository connection, Azure OpenAI deployment, or model quota is required.

## Actions

### Common actions

* Inspect the site's content, bindings or virtual hosts, runtime/modules, dependencies, and state requirements.
* Confirm the workload consists of portable static HTML, CSS, and image assets.
* Replace the VM-specific hostname displayed in `index.html` with a platform-neutral value.
* Create a ZIP package whose root contains `index.html`.
* Create a low-cost Windows App Service plan and web app in `destination-rg`.
* Deploy with the supported App Service ZIP deployment experience.
* Enforce HTTPS and validate the home page and referenced assets.
* Stop the original web service and prove that the App Service endpoint remains available.
* Compare App Service with Azure Storage static website hosting and Azure Static Web Apps for a production architecture decision.

### Track A - Windows Server / IIS

* Inventory IIS bindings, the application pool, runtime settings, and `C:\inetpub\wwwroot`.
* Create the package with PowerShell `Compress-Archive`.
* Deploy with the Kudu ZIP deploy UI or the documented Azure CLI alternative.

### Track B - Ubuntu Linux / Apache

* Inventory Apache virtual hosts, modules, configuration, and `/var/www/html`.
* Stage a user-owned copy, make it portable, and create and verify the ZIP with Linux tools.
* Install Azure CLI from Microsoft's Debian/Ubuntu repository only if it is missing, use interactive device-code sign-in, verify the subscription, deploy the local ZIP with `az webapp deploy --type zip`, and sign out.

> [!NOTE]
> Both tracks deploy the static artifact to the same pedagogical Windows App Service target. The source VM operating system does not dictate the App Service worker operating system when the artifact is portable static content.

## Success criteria

* The discovery record shows that the selected site has no required server-side runtime, database, machine-local dependency, or session state.
* The ZIP root contains `index.html` rather than a nested content directory.
* A Windows App Service web app serves the selected site's page and assets over HTTPS.
* The rendered page contains a platform-neutral hosting value.
* The App Service endpoint remains healthy after `W3SVC` or `apache2` is stopped.
* Track B signs out of Azure CLI after deployment.
* No Azure Load Balancer is placed in front of App Service and no GitHub integration is required.

## Architecture decision

App Service is the pedagogical target because it demonstrates replatforming to a managed web platform. For this purely static workload, an [Azure Storage static website](https://learn.microsoft.com/en-us/azure/storage/blobs/storage-blob-static-website) is likely the simplest and most cost-effective production target. [Azure Static Web Apps](https://learn.microsoft.com/en-us/azure/static-web-apps/overview) is another strong option when globally distributed static content, integrated authentication, APIs, and repository-driven delivery are desired. Treat the final production target as an architecture decision, not an assumption that App Service is always optimal.

## Learning resources

* [Azure Migrate web-app migration support matrix](https://learn.microsoft.com/en-us/azure/migrate/concepts-migration-webapps?view=migrate)
* [Deploy files to Azure App Service](https://learn.microsoft.com/en-us/azure/app-service/deploy-zip)
* [Azure CLI App Service plan reference](https://learn.microsoft.com/en-us/cli/azure/appservice/plan?view=azure-cli-latest#az-appservice-plan-create)
* [Azure CLI web app deployment reference](https://learn.microsoft.com/en-us/cli/azure/webapp?view=azure-cli-latest#az-webapp-deploy)
* [Install Azure CLI on Ubuntu or Debian](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli-linux?view=azure-cli-latest&pivots=apt)
* [Sign in interactively with Azure CLI](https://learn.microsoft.com/en-us/cli/azure/authenticate-azure-cli-interactively?view=azure-cli-latest)
* [Enforce HTTPS in Azure App Service](https://learn.microsoft.com/en-us/azure/app-service/configure-ssl-bindings#enforce-https)
* [Static Content Hosting pattern](https://learn.microsoft.com/en-us/azure/architecture/patterns/static-content-hosting)
