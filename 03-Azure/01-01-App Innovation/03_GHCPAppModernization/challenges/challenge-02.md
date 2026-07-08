# Modernize a .NET Application

[Previous Challenge](challenge-01.md) - **[Home](../Readme.md)** - [Next Challenge](challenge-03.md)

## Goal

Modernize the Contoso University .NET Framework application to .NET 9 and deploy it to Azure App Service using GitHub Copilot’s AI-assisted tooling.

## Actions

* Fork `https://github.com/crgarcia12/migrate-modernize-lab`, clone your fork in Visual Studio 2022, and confirm the ContosoUniversity project builds.
* Use the Visual Studio “Modernize” flow to sign in to GitHub Copilot, select Claude Sonnet 4.5, and run the guided upgrade to .NET 9 until `dotnet-upgrade-report.md` is produced.
* Rerun “Modernize” to start “Migrate to Azure,” review the cloud readiness assessment, and resolve authentication findings by migrating from Windows AD to Microsoft Entra ID.
* Approve Copilot’s Azure App Service deployment workflow, wait for completion, and validate the site in Azure.

## Success criteria

* ContosoUniversity solution is forked, cloned, and builds locally.
* The application is upgraded from .NET Framework to .NET 9 with a generated upgrade report.
* Mandatory cloud readiness issues, including authentication migration to Microsoft Entra ID, are fully resolved.
* Azure App Service deployment completes successfully and the modernized app runs in Azure.

## Learning resources

* https://learn.microsoft.com/visualstudio/ide/visual-studio-github-copilot-extension
* https://learn.microsoft.com/dotnet/architecture/modernize-with-azure-containers/
* https://learn.microsoft.com/dotnet/core/migration/
* https://learn.microsoft.com/azure/app-service/quickstart-dotnetcore
* https://learn.microsoft.com/azure/active-directory/develop/quickstart-v2-aspnet-core-webapp
