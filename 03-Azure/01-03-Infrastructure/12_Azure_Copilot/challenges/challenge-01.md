# Challenge 1 - Azure Copilot Basics

**[Home](../Readme.md)** - [Next Challenge](challenge-02.md)

## Goal

You are a new cloud engineer at Contoso Ltd. Your team lead has asked you to familiarize yourself with Azure Copilot so you can use it to accelerate your daily Azure operations. Before working with the specialized agents, you need to master the fundamentals.

Get familiar with Azure Copilot in the Azure portal — learn how to open it, navigate its interface, write effective prompts, and understand its core capabilities before diving into the specialized agents.

By the end of this challenge, you will be able to:

- Open and navigate Azure Copilot in the Azure portal
- Write effective prompts using best practices
- Use Azure Copilot to get information about Azure services
- Ask Azure Copilot to navigate to specific services
- Use Azure Copilot to get Azure Advisor recommendations
- Generate Azure CLI and PowerShell scripts
- Add context (resources/subscriptions) to conversations
- Manage multiple conversations

## Actions

### Workshop Resources (Pre-Deployed)

The deployment scripts have created resources in **`rg-copilot-<suffix>-ch00`** (in your chosen deployment region) for you to explore with Azure Copilot:

| Resource               | Name                        | Purpose                                                |
| ---------------------- | --------------------------- | ------------------------------------------------------ |
| Storage Account        | `stcopilotworkshop<suffix>` | Sample resource for querying and navigation tasks      |
| Virtual Network        | `vnet-copilot-workshop`     | VNet with 2 subnets (`snet-frontend`, `snet-backend`)  |
| Network Security Group | `nsg-copilot-workshop`      | NSG for exploration (not yet associated with a subnet) |

> **Note:** `<suffix>` is a random 4-character string generated during deployment. Check your `rg-copilot-<suffix>-ch00` resource group to find the actual name.

> **Tip:** Use these resources to practice adding context to conversations (Task 6) and generating scripts (Task 4).

### Task 1: Open Azure Copilot and Explore the Interface (5 min)

1. Sign in to the [Azure portal](https://portal.azure.com)
2. Locate and click the **Copilot icon** in the top header bar
3. Explore the Copilot pane:
   - Notice the text input area at the bottom
   - Notice the suggested prompts (if any)
   - Locate the **fullscreen mode** icon
   - Locate the **new conversation** icon
4. Switch to **fullscreen mode** and explore the larger interface
5. Return to the side pane mode

**Question to answer:** Where is the Copilot icon located in the Azure portal, and what does it look like?

### Task 2: Get Information About Azure Services (5 min)

Use Azure Copilot to answer the following questions. Write your prompts and note the responses.

1. Ask: _"What is Azure App Service and when should I use it?"_
2. Ask: _"What are the differences between Azure Blob Storage and Azure File Storage?"_
3. Ask: _"Which Azure compute service should I use for running containers without managing infrastructure?"_

**Question to answer:** How does Azure Copilot's response differ from a generic web search? Does it provide Azure-specific, tailored guidance?

### Task 3: Navigate Using Azure Copilot (5 min)

Use Azure Copilot to navigate to different services and pages in the portal:

1. Ask: _"Take me to the Virtual Machines page"_
2. Ask: _"Open Azure Monitor"_
3. Ask: _"Navigate to Cost Management"_
4. Ask: _"Show me the Advisor recommendations page"_

**Question to answer:** What happens when you ask Azure Copilot to navigate? Does it open the page directly or provide a link?

### Task 4: Generate Scripts with Azure Copilot (5 min)

Ask Azure Copilot to generate scripts for common tasks:

1. Ask: _"Generate an Azure CLI script to create a storage account named 'stcopilotworkshop' in the resource group 'rg-copilot-<suffix>-ch00' in East US 2"_
2. Ask: _"Can you convert that to PowerShell?"_
3. Ask: _"Generate a Bicep template to create a virtual network with two subnets"_

**Question to answer:** How does Azure Copilot handle multi-turn conversations? Does it remember context from your previous prompts?

### Task 5: Get Recommendations (5 min)

Explore Azure Advisor integration:

1. Ask: _"Show me my top cost recommendations"_
2. Ask: _"What are my security recommendations?"_
3. Ask: _"Show me my reliability recommendations"_
4. Ask: _"What services do you recommend for building a web application with a database backend?"_

**Question to answer:** Does Azure Copilot provide generic recommendations or ones tailored to your actual Azure environment?

### Task 6: Add Context and Manage Conversations (5 min)

1. Start a new conversation using the **new chat** icon
2. Click the **Add** icon (context icon) in the chat input area
3. Select a resource group, subscription, or specific resource to add as context
4. Ask a question about the selected resource, such as: _"What resources are in this resource group?"_ or _"Summarize this subscription's usage"_
5. Open the **conversation navigation pane** and view all your conversations
6. Rename one of your conversations
7. Delete a conversation you no longer need

**Question to answer:** How does adding context to a conversation improve the quality of Azure Copilot's responses?

## Success criteria

- You can open Azure Copilot from the Azure portal header
- You've asked at least 3 informational questions and received relevant responses
- You've used Azure Copilot to navigate to at least 2 Azure services
- You've generated at least one script (CLI, PowerShell, or Bicep)
- You've added context to a conversation
- You've managed multiple conversations (create, rename, delete)

## Learning resources

- Azure Copilot is accessible from **any page** in the Azure portal via the header icon
- It provides **Azure-specific**, context-aware responses grounded in current documentation
- **Multi-turn conversations** preserve context so you can iterate on requests
- **Adding context** (resources, subscriptions) significantly improves response quality
- Scripts and recommendations are **tailored to your environment** when context is provided
- [Azure Copilot overview](https://learn.microsoft.com/en-us/azure/copilot/overview)

## Solution

> [!TIP]
> We encourage you to try solving the challenge on your own before looking at the solution. This will help you learn and understand the concepts better.

<details>
<summary>Click here to view the solution</summary>

[Solution for Challenge 1](../walkthrough/solution-01.md)

</details>
