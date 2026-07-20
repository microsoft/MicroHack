# 3. Modernize the Upgraded Apps and Deploy Them to Azure

[Previous Challenge](challenge-02.md) - **[Home](../Readme.md)** - [Next Challenge](finish.md)

## Goal

Take the two apps you upgraded in Challenge 2 and use the modernize CLI to create a cloud modernization plan, resolve cloud readiness issues, provision Azure infrastructure, and deploy both the Java and .NET applications to Azure.

## Actions

* Using the modernize CLI, create a **cloud modernization plan** that targets both repositories from your config file. Instruct the plan to:
  * Ignore any upgrade recommendations from the earlier assessment (the apps are already upgraded).
  * Focus on resolving cloud readiness issues, provisioning Azure infrastructure for each app, and deploying each app to Azure.
  * Migrate any OracleDB dependency to PostgreSQL if present.
* Review the generated plan and its tasks, then review and **merge the pull request** the agent produces.
* **Deploy the PhotoAlbum-Java app**: pull the latest plan branch, execute the plan with the modernize CLI, and wait for all tasks to finish. Validate the deployment by inspecting the created resource group in Azure and browsing to the Frontend Container App URL.
* **Deploy the PhotoAlbum (.NET) app**: pull the latest plan branch and execute the plan. If the plan does not provision infrastructure or deploy resources for this app, create a second, more explicit plan (for example, an "infra-setup-plan" that provisions Azure resources and deploys the app), then execute it.
* Validate the .NET deployment the same way — confirm the Azure resources and open the Frontend Container App URL.

> [!TIP]
> If a deployment step fails, use GitHub Copilot CLI to help diagnose and fix the error before retrying.

> [!NOTE]
> Plan generation and execution can each take a while (roughly 15–20 minutes per plan). This is a good point to take a break while the agent works.

## Success criteria

* A cloud modernization plan is generated for both repositories and its pull request is reviewed and merged.
* The PhotoAlbum-Java app is deployed to Azure, with its resources visible in a resource group and the Frontend Container App reachable.
* The PhotoAlbum (.NET) app is deployed to Azure — creating an explicit infrastructure/deployment plan where needed — with its resources visible and the Frontend Container App reachable.
* Both applications run successfully in Azure.

> Need the detailed, step-by-step walkthrough? See the [Challenge 3 Solution](../walkthrough/challenge-03/solution-03.md).

## Learning resources

* [GitHub Copilot App Modernization – create a modernization plan](https://learn.microsoft.com/azure/developer/github-copilot-app-modernization/modernization-agent/quickstart)
* [Azure Container Apps documentation](https://learn.microsoft.com/azure/container-apps/)
* [Migrate Oracle to Azure Database for PostgreSQL](https://learn.microsoft.com/azure/postgresql/migrate/)
* [GitHub Copilot CLI](https://docs.github.com/copilot/github-copilot-in-the-cli)
* [Azure deployment best practices](https://learn.microsoft.com/azure/architecture/)
