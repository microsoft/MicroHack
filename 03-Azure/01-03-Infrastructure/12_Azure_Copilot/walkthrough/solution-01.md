# Walkthrough Challenge 1 - Azure Copilot Basics

**[Home](../Readme.md)** - [Next Challenge Solution](solution-02.md)

**Estimated Duration:** 30 minutes

> 💡 **Objective:** Learn the fundamentals of Azure Copilot — opening and navigating the interface, writing prompts, generating scripts, and managing conversations.

---

## Task 1: Open Azure Copilot and Explore the Interface

### Steps

1. **Sign in** to [portal.azure.com](https://portal.azure.com)
2. **Locate the Copilot icon** — It's in the **top header bar** of the Azure portal, typically appearing as a sparkle/star icon next to the search bar and other header items
3. **Click the icon** — The Copilot pane opens as a side panel on the right side of the portal
4. **Observe the interface elements:**
   - **Text input box** at the bottom where you type prompts
   - **Suggested prompts** displayed as clickable cards (vary based on your current portal context)
   - **Fullscreen icon** — a small expand icon in the top-right corner of the Copilot pane
   - **New conversation icon** — a "+" or page icon to start a fresh conversation
5. **Click the fullscreen icon** — The Copilot experience expands to fill the full browser window, providing more space for responses and the conversation list
6. **Click the minimize/exit fullscreen** button to return to the side pane

### Answer

The Copilot icon is located in the **top header/toolbar** of the Azure portal. It resembles a sparkle or star icon. Clicking it opens a side pane; fullscreen mode provides a larger, immersive experience.

---

## Task 2: Get Information About Azure Services

### Recommended Prompts and Expected Responses

**Prompt 1:** _"What is Azure App Service and when should I use it?"_

> **Expected:** Azure Copilot explains that App Service is a fully managed platform for building web apps, REST APIs, and mobile back ends. It recommends App Service when you need PaaS web hosting without managing infrastructure, with built-in scaling, CI/CD, and SSL.

**Prompt 2:** _"What are the differences between Azure Blob Storage and Azure File Storage?"_

> **Expected:** Azure Copilot compares the two services:
>
> - **Blob Storage** — Object storage for unstructured data (images, videos, documents), accessed via REST API
> - **File Storage** — Managed SMB/NFS file shares, mountable as network drives, suitable for lift-and-shift scenarios

**Prompt 3:** _"Which Azure compute service should I use for running containers without managing infrastructure?"_

> **Expected:** Azure Copilot recommends **Azure Container Instances (ACI)** for simple container workloads and **Azure Container Apps** for microservices at scale, both serverless options that don't require managing VMs or orchestrators.

### Answer

Azure Copilot provides **Azure-specific, contextual guidance** that is grounded in current Microsoft documentation. Unlike a web search, it synthesizes information and provides direct, tailored recommendations rather than a list of links.

---

## Task 3: Navigate Using Azure Copilot

> 💡 **Tip — reset between prompts:** before each navigation prompt, click the **Microsoft Azure** banner in the top-left to return to the portal home blade. Copilot replies with "you are already on that page" when the portal is already there, which is a valid outcome but harder to recognize as a navigation success.

### Steps

**Prompt 1:** _"Take me to the Virtual Machines page"_

> **Expected:** Azure Copilot either (a) provides a direct link to the Virtual Machines blade (clicking navigates you there), or (b) — if you are already on that blade — confirms you are already on the Virtual Machines page. Both are acceptable outcomes.

**Prompt 2:** _"Take me to the Azure Monitor overview page in the Azure portal."_

> - Azure Copilot navigates directly to Azure Monitor or returns a clickable portal link to the Azure Monitor overview page.
> - The Copilot pane may close or lose focus after navigation; participants may need to reopen it for the next step.
> - If direct navigation is not available in that moment, Copilot should still provide a clear portal link rather than a generic service explainer.
> - The key success signal is reaching the Azure Monitor blade, not receiving a long descriptive answer.

**Prompt 3:** _"Navigate to Cost Management"_

> **Expected:** Azure Copilot opens or links to the Cost Management + Billing blade.

**Prompt 4:** _"Take me to the Azure Advisor recommendations page in the Azure portal."_

> - Azure Copilot navigates to Azure Advisor recommendations or returns a direct portal link to that page.
> - The response should clearly target Azure Advisor, not Metrics Advisor or a generic recommendation explanation.
> - The Copilot pane may close or shift context after navigation, so reopening Copilot is acceptable for the next task.
> - The successful outcome is that the participant reaches the Advisor recommendations experience in the portal.

### Answer

When you ask Azure Copilot to navigate, it typically **provides a clickable link** within the chat response that takes you directly to the requested portal page. In some cases, it may open the page automatically.

---

## Task 4: Generate Scripts with Azure Copilot

### Steps

**Prompt 1:** _"Generate an Azure CLI script to create a storage account named 'stcopilotworkshop' in the resource group 'rg-copilot-<suffix>-ch00' in East US 2"_

> **Expected response (similar to):**
>
> ```bash
> az storage account create \
>   --name stcopilotworkshop \
>   --resource-group rg-copilot-<suffix>-ch00 \
>   --location eastus2 \
>   --sku Standard_LRS \
>   --kind StorageV2
> ```

**Prompt 2:** _"Convert the following Azure CLI command to PowerShell, keeping the same storage account name, resource group, and region: az storage account create --name stcopilotworkshop<suffix> --resource-group rg-copilot-<suffix>-ch00 --location eastus2 --sku Standard_LRS"_

> - Azure Copilot returns a starter PowerShell example using `New-AzStorageAccount` or an equivalent Azure PowerShell workflow.
> - The response keeps the same storage account name, resource group, and region from the restated command.
> - The answer may include prerequisite notes such as signing in with `Connect-AzAccount` or selecting the correct subscription.
> - Participants should expect better reliability when they restate critical context instead of relying on multi-turn memory alone.

**Prompt 3:** _"Generate a Bicep template that creates a Virtual Network named `vnet-copilot-workshop` with address space `10.0.0.0/16` and two subnets: `subnet-app` (`10.0.1.0/24`) and `subnet-data` (`10.0.2.0/24`). Include parameters for the VNet name and location."_

> - Azure Copilot returns a starter Bicep snippet for a VNet and two subnets in a single file or code block.
> - The template may be minimal and may require the participant to adjust address ranges, parameterization, or naming before deployment.
> - A concise example is acceptable; the response does not need to be a production-ready module set.
> - The main success criterion is that Copilot produces recognizable Bicep syntax for the requested network structure.

### Answer

Azure Copilot **retains context** across a conversation. When you ask "convert that to PowerShell," it knows you're referring to the storage account creation from the previous prompt. This multi-turn capability is one of its most powerful features.

---

## Task 5: Get Recommendations

### Steps

**Prompt 1:** _"List my top Azure Advisor cost recommendations for this subscription."_

> - Azure Copilot often starts by summarizing the highest-cost services or current spend drivers in your subscription.
> - If Azure Advisor cost recommendations are available, Copilot may surface some of them, but that is not guaranteed for every subscription.
> - A spend-oriented answer is still useful because it highlights where to investigate savings first.
> - Participants should treat this step as an entry point into cost analysis, not a guaranteed list of actionable Advisor recommendations.

**Prompt 2:** _"List my top Azure Advisor security recommendations for this subscription."_

> **Expected:** Azure Copilot lists security-related Advisor recommendations scoped to the current subscription — impacted resource, impact (High/Medium/Low), and a link to details for each item.

**Prompt 3:** _"List my top Azure Advisor reliability recommendations for this subscription."_

> - Copilot either lists Azure Advisor reliability recommendations inline, OR
> - Provides a link / navigates to the Advisor Reliability blade where recommendations are shown
> - If inline, each item shows impacted resource, impact, and a link to details
> - If the subscription has no qualifying workloads, Copilot may say "no reliability recommendations" — this is still a pass.

**Prompt 4:** _"What Azure services do you recommend for building a web application with a relational database backend? Compare App Service + Azure SQL Database vs App Service + Azure Database for PostgreSQL Flexible Server, and summarize when each is appropriate."_

> - Azure Copilot recommends a starter Azure web architecture such as App Service paired with Azure SQL Database, PostgreSQL, or Cosmos DB depending on workload needs.
> - The response explains trade-offs such as relational vs. NoSQL data models, managed hosting, and operational simplicity.
> - Copilot may also mention supporting services like Key Vault, Application Insights, Front Door, or networking controls.
> - The answer is conceptual guidance, not an environment-specific deployment plan.

### Answer

Azure Copilot provides **both** types of recommendations:

- **Environment-specific** — When querying Advisor recommendations, results are from YOUR actual Azure resources
- **General guidance** — When asking about architecture or service choices, it provides best-practice recommendations from Azure documentation

---

## Task 6: Add Context and Manage Conversations

### Steps

1. **Start a new conversation** — Click the new chat icon (looks like a page with a "+" sign)
2. **Add context** — Click the **Add icon** (usually a "+" or attach icon) in the chat input area
3. **Select a resource** — Choose from:
   - A subscription
   - A resource group (e.g., `rg-copilot-<suffix>-ch00`)
   - A specific resource
4. **Ask a contextual question** — e.g., _"What resources are in this resource group?"_
5. **View conversations** — Open the conversation navigation pane (left sidebar in fullscreen mode, or the conversation list icon)
6. **Rename** — Right-click or use the menu on a conversation to rename it (e.g., "My Workshop Exploration")
7. **Delete** — Use the menu on a conversation to delete it

### Answer

Adding context **dramatically improves** response quality because Azure Copilot:

- Scopes its analysis to the selected resources/subscriptions
- Can provide specific metrics, configurations, and recommendations
- Doesn't need you to specify resource names or IDs in every prompt
- Understands the relationships between your resources

---

## Summary

You've now mastered the fundamentals of Azure Copilot:

| Skill                                      | Status |
| ------------------------------------------ | ------ |
| Opening and navigating Azure Copilot       | ✅     |
| Writing informational prompts              | ✅     |
| Portal navigation via Copilot              | ✅     |
| Script generation (CLI, PowerShell, Bicep) | ✅     |
| Getting Advisor recommendations            | ✅     |
| Adding context to conversations            | ✅     |
| Managing multiple conversations            | ✅     |

You successfully completed challenge 1! 🚀🚀🚀
