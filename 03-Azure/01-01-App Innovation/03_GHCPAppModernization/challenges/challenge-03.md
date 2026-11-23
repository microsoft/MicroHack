# 3. Modernize the Upgraded Apps and Deploy Them to Azure

[Previous Challenge](challenge-02.md) - **[Home](../Readme.md)** - [Next Challenge](finish.md)

## Goal

Take the two apps you upgraded in Challenge 2 and use the modernize CLI to create a cloud modernization plan, resolve cloud readiness issues, provision Azure infrastructure, and deploy both the Java and .NET applications to Azure.

## Actions

* Using the modernize CLI, create a **cloud modernization plan** for both repositories: select **Plan**, choose **From a config file** (the `repos.json` you created in Challenge 2), select both apps, and choose **Keep the plan local**. Name the plan `cloud-modernization-plan` and instruct it to:
  * Ignore any upgrade recommendations from the earlier assessment (the apps are already upgraded).
  * Focus on resolving cloud readiness issues, provisioning Azure infrastructure for each app, and deploying each app to Azure.
  * Migrate any OracleDB dependency to PostgreSQL if present.
* Review each generated plan at `.github/modernize/cloud-modernization-plan/plan.md` inside the respective repository and adjust it if needed — plans are local files in each repository's working tree (the CLI keeps them out of git); nothing is committed or pushed.
* **Deploy the PhotoAlbum-Java app**: from `repos/PhotoAlbum-Java`, execute the plan with the modernize CLI and wait for all tasks to finish. Validate the deployment by inspecting the created resource group in Azure and browsing to the Frontend Container App URL.
* **Deploy the PhotoAlbum (.NET) app**: execute the plan from `repos/PhotoAlbum`. If the plan does not provision infrastructure or deploy resources for this app, create a second, more explicit plan (for example, an `infra-setup-plan` that provisions Azure resources and deploys the app), then execute it.
* Validate the .NET deployment the same way — confirm the Azure resources and open the Frontend Container App URL.

> [!NOTE]
> You have Owner rights on the lab subscription, and the agent typically provisions into a resource group it creates. To deploy into your pre-created lab resource group instead, add `resource group: <your-resource-group>` to the plan prompt.

> [!TIP]
> If the .NET container build fails with a **Six Labors (ImageSharp) license** error: Release builds of ImageSharp 3.2+ require a license key. Get a free community key from <https://licensing.sixlabors.com/> and set the `SixLaborsLicenseKey` build property — or instruct the agent to publish a Debug build for this lab.

> [!TIP]
> If a deployment step fails, use GitHub Copilot CLI to help diagnose and fix the error before retrying — the Azure MCP server you configured in Challenge 1 (`.github/mcp.json`) gives it the tools to inspect your Azure resources.

> [!NOTE]
> Plan generation and execution can each take a while (roughly 15-20 minutes per plan). This is a good point to take a break while the agent works.

## Success criteria

* A cloud modernization plan is generated locally for both repositories, and you have reviewed each plan.
* The PhotoAlbum-Java app is deployed to Azure, with its resources visible in a resource group and the Frontend Container App reachable.
* The PhotoAlbum (.NET) app is deployed to Azure — creating an explicit infrastructure/deployment plan where needed — with its resources visible and the Frontend Container App reachable.
* Both applications run successfully in Azure.

> Need the detailed, step-by-step walkthrough? See the [Challenge 3 Solution](../walkthrough/challenge-03/solution-03.md).

## Learning resources

* [GitHub Copilot App Modernization – create a modernization plan](https://learn.microsoft.com/azure/developer/github-copilot-app-modernization/modernization-agent/quickstart)
* [Batch plan across multiple repositories](https://learn.microsoft.com/azure/developer/github-copilot-app-modernization/modernization-agent/batch-plan)
* [Prepare infrastructure and deploy applications](https://learn.microsoft.com/azure/developer/github-copilot-app-modernization/modernization-agent/infra-deployment)
* [Azure Container Apps documentation](https://learn.microsoft.com/azure/container-apps/)
* [Migrate Oracle to Azure Database for PostgreSQL](https://learn.microsoft.com/azure/postgresql/migrate/)
* [GitHub Copilot CLI](https://docs.github.com/en/copilot/concepts/agents/about-copilot-cli)
* [Azure deployment best practices](https://learn.microsoft.com/azure/architecture/)
