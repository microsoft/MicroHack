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

### Steps

**Prompt 1:** _"Take me to the Virtual Machines page"_

> **Expected:** Azure Copilot provides a direct link to the Virtual Machines blade in the portal. Clicking the link navigates you there.

**Prompt 2:** _"Open Azure Monitor"_

> **Expected:** Azure Copilot provides a link or directly navigates to the Azure Monitor overview page.

**Prompt 3:** _"Navigate to Cost Management"_

> **Expected:** Azure Copilot opens or links to the Cost Management + Billing blade.

**Prompt 4:** _"Show me the Advisor recommendations page"_

> **Expected:** Azure Copilot provides a link to the Azure Advisor recommendations overview.

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

**Prompt 2:** _"Can you convert that to PowerShell?"_

> **Expected response (similar to):**
>
> ```powershell
> New-AzStorageAccount `
>   -ResourceGroupName "rg-copilot-<suffix>-ch00" `
>   -Name "stcopilotworkshop" `
>   -Location "eastus2" `
>   -SkuName "Standard_LRS" `
>   -Kind "StorageV2"
> ```

**Prompt 3:** _"Generate a Bicep template to create a virtual network with two subnets"_

> **Expected:** Azure Copilot generates a complete Bicep template with a VNet and two subnet resources, including parameters for names and address prefixes.

### Answer

Azure Copilot **retains context** across a conversation. When you ask "convert that to PowerShell," it knows you're referring to the storage account creation from the previous prompt. This multi-turn capability is one of its most powerful features.

---

## Task 5: Get Recommendations

### Steps

**Prompt 1:** _"Show me my top cost recommendations"_

> **Expected:** Azure Copilot returns a list of Azure Advisor cost recommendations for your subscriptions, including links to each recommendation.

**Prompt 2:** _"What are my security recommendations?"_

> **Expected:** Azure Copilot lists security-related Advisor recommendations.

**Prompt 3:** _"Show me my reliability recommendations"_

> **Expected:** Azure Copilot shows reliability-focused recommendations from Azure Advisor.

**Prompt 4:** _"What services do you recommend for building a web application with a database backend?"_

> **Expected:** Azure Copilot provides a recommended architecture, such as App Service + Azure SQL Database or App Service + Cosmos DB, with explanations for when each option is appropriate.

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
