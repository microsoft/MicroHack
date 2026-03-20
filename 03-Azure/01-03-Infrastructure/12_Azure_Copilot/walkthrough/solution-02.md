# Walkthrough Challenge 2 - Deployment Agent

**[Home](../Readme.md)** - [Previous Challenge Solution](solution-01.md) - [Next Challenge Solution](solution-03.md)

**Estimated Duration:** 45 minutes

> 💡 **Objective:** Learn to deploy infrastructure using the Deployment Agent in Azure Copilot — from describing a workload in natural language to generating Terraform configurations and exploring deployment options.

---

## Task 1: Enable Agent Mode and Describe Your Workload

### Steps

1. **Open Azure Copilot** — Click the Copilot icon in the Azure portal header
2. **Enable agent mode** — Click the agent mode icon (toggle icon) in the chat input area. You should see a visual indicator that agent mode is active
3. **Enter the prompt:**

   > _"Deploy a Python Flask web app on Azure App Service with a PostgreSQL Flexible Server backend, secure secrets in Azure Key Vault, and enable monitoring with Application Insights."_

4. **Wait for the response** — Click **"Show activity"** to watch Azure Copilot's reasoning process in real time

### Expected Behavior

Azure Copilot will:

1. **Analyze your request** and identify the required components
2. **May ask clarifying questions**, such as:
   - What region do you prefer?
   - What pricing tier (Basic, Standard, Premium)?
   - Do you need auto-scaling?
   - What size database do you need?
3. **Generate an infrastructure plan** that typically includes:

   | Component         | Azure Service                                 | Purpose                            |
   | ----------------- | --------------------------------------------- | ---------------------------------- |
   | Web Application   | Azure App Service (Linux)                     | Host the Python Flask app          |
   | Database          | Azure Database for PostgreSQL Flexible Server | Relational data storage            |
   | Secret Management | Azure Key Vault                               | Store connection strings, API keys |
   | Monitoring        | Application Insights                          | Application performance monitoring |
   | Logging           | Log Analytics Workspace                       | Centralized logging                |
   | Resource Group    | Azure Resource Group                          | Logical container                  |

4. **Document trade-offs** — For example:
   - App Service vs. Container Apps vs. AKS for hosting
   - Single-server vs. Flexible Server for PostgreSQL
   - Pricing tier implications

### Answer

The plan aligns with the **Well-Architected Framework** pillars:

- **Reliability** — Managed services with built-in redundancy
- **Security** — Key Vault for secrets, managed identities suggested
- **Cost Optimization** — Flexible Server for right-sized database
- **Operational Excellence** — Application Insights and Log Analytics for monitoring
- **Performance** — App Service auto-scaling capabilities

---

## Task 2: Refine the Architecture Plan

### Steps and Expected Responses

**Prompt 1:** _"Can you add a Virtual Network with subnets for the App Service and the database?"_

> **Expected:** Azure Copilot updates the plan to include:
>
> - A VNet (e.g., `10.0.0.0/16`)
> - App Service subnet (e.g., `10.0.1.0/24`) with VNet integration
> - Database subnet (e.g., `10.0.2.0/24`) with delegated subnet for PostgreSQL

**Prompt 2:** _"I want the PostgreSQL server to use private endpoints instead of public access."_

> **Expected:** Azure Copilot adjusts the plan to:
>
> - Disable public access on the PostgreSQL Flexible Server
> - Add a Private Endpoint in the database subnet
> - Configure a Private DNS Zone for `privatelink.postgres.database.azure.com`

**Prompt 3:** _"Add a Network Security Group to restrict traffic to the App Service subnet."_

> **Expected:** Azure Copilot adds:
>
> - An NSG with rules allowing only HTTP/HTTPS inbound
> - Association of the NSG to the App Service subnet

**Prompt 4:** _"What would be the estimated monthly cost for this setup at a basic tier?"_

> **Expected:** Azure Copilot provides a cost estimate breakdown by resource. Note that these estimates are approximate and may vary.

### Answer

The Deployment Agent **incrementally updates** the plan. It doesn't start over — it adds the new components while keeping the existing ones. This is the power of multi-turn conversations.

---

## Task 3: Generate Terraform Configurations

### Plan Approval (Required Before Code Generation)

Before Terraform code is generated, you must explicitly approve the infrastructure plan:

1. **Review the plan summary** — Verify that all components, SKUs, networking, and security settings match your requirements
2. **Click "I approve the plan"** to proceed to Terraform generation, **or** click **"Review the plan and make edits"** to return to the refinement conversation and request further changes
3. Azure Copilot will **not** generate Terraform configurations until you approve the plan

> **Note:** If you are iterating via prompts rather than buttons, you can also explicitly ask: _"Generate the Terraform configurations for this plan."_ — this serves as implicit approval.

### Steps

1. **Approve the plan** by clicking **"I approve the plan"**, or enter the prompt: _"Generate the Terraform configurations for this plan."_
2. **Wait for generation** — Azure Copilot will show a progress indicator
3. **Click the maximize icon** on the artifact pane to see the full files
4. Note that the artifact pane is **read-only** — you can review the generated files but cannot edit them directly. To make edits, export the files first using one of the deployment options in Task 4

### Expected Files Generated

```text
├── main.tf              # Primary resource definitions
├── variables.tf         # Input variables (region, names, SKUs)
├── outputs.tf           # Output values (URLs, connection strings)
├── providers.tf         # Provider configuration (azurerm)
└── terraform.tfvars     # Default variable values (optional)
```

### Example: Key Sections in `main.tf`

```hcl
# Resource Group
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
}

# Virtual Network
resource "azurerm_virtual_network" "main" {
  name                = "${var.prefix}-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}

# App Service with VNet Integration
resource "azurerm_linux_web_app" "main" {
  name                = "${var.prefix}-webapp"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  service_plan_id     = azurerm_service_plan.main.id

  site_config {
    application_stack {
      python_version = "3.11"
    }
  }

  app_settings = {
    "KEY_VAULT_URI" = azurerm_key_vault.main.vault_uri
  }
}

# PostgreSQL Flexible Server with Private Endpoint
resource "azurerm_postgresql_flexible_server" "main" {
  name                   = "${var.prefix}-psql"
  resource_group_name    = azurerm_resource_group.main.name
  location               = azurerm_resource_group.main.location
  sku_name               = "B_Standard_B1ms"
  delegated_subnet_id    = azurerm_subnet.database.id
  private_dns_zone_id    = azurerm_private_dns_zone.postgres.id
  # ... additional configuration
}

# Application Insights
resource "azurerm_application_insights" "main" {
  name                = "${var.prefix}-appinsights"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  application_type    = "web"
}
```

### Answer

The generated files are **a strong starting point** but typically need customization for production:

- Review default SKUs and sizing
- Add tags for resource management
- Verify naming conventions match your organization standards
- Add any missing security hardening (e.g., TLS versions, firewall rules)
- Add state backend configuration (`backend "azurerm" {}`)

---

## Task 4: Explore Deployment Options

### Option A: Open in VS Code (Web)

1. In the artifact pane, click **"Open in VS Code (Web)"**
2. A new browser tab opens with VS Code for the Web
3. The generated files are loaded in a **temporary workspace** for reviewing and editing
4. **Important:** Changes made here are **not persisted** — to save your work, use the GitHub PR or download options below
5. Note: This is a zero-install experience — no local setup required

### Option B: GitHub Pull Request (Recommended)

1. Click **"Create pull request"** in the artifact pane
2. **Sign in to GitHub** when prompted
3. **Select a repository** — Choose an existing repo or create a new one
4. **Select a branch** — Choose the target branch for the PR
5. Azure Copilot creates a new branch with the generated files and opens a PR
6. Review the PR on GitHub as you normally would
7. **Note:** The PR contains the original generated files from the artifact pane, not any edits made in VS Code for the Web. Make further edits via the PR or after cloning locally

### Option C: Download Files

1. Click the **download icon** (next to "Create pull request") to save the generated files locally
2. After downloading, commit them to your own repository and make edits there
3. Initialize Terraform: `terraform init`
4. Plan: `terraform plan`
5. Apply: `terraform apply`

### CI/CD Guidance Prompt Response

When asked about CI/CD, Azure Copilot typically provides guidance for:

- **GitHub Actions** with Terraform workflows
- **Azure DevOps Pipelines** with Terraform tasks
- State management with **Azure Storage backend**
- Environment-specific variable files

### Answer

For **production environments**, the GitHub Pull Request method is recommended because:

- It enables **code review** before deployment
- Integrates with existing **CI/CD pipelines**
- Provides **version control** and audit trail
- Supports **branch protection rules** and approvals

---

## Task 5: Try a Different Architecture

### Steps

1. Start a **new conversation** (click the new chat icon)
2. **Enable agent mode** again
3. Enter the AKS prompt:
   > _"Set up a multitenant SaaS application on AKS using Kubernetes namespaces for isolation, integrate Microsoft Entra for authentication, and centralize logs in Azure Log Analytics."_

### Expected Plan Components

| Component               | Azure Service                                | Purpose                   |
| ----------------------- | -------------------------------------------- | ------------------------- |
| Container Orchestration | Azure Kubernetes Service (AKS)               | Run the SaaS application  |
| Tenant Isolation        | Kubernetes Namespaces + Network Policies     | Separate tenant workloads |
| Identity                | Microsoft Entra ID                           | Authentication and RBAC   |
| Logging                 | Log Analytics Workspace + Container Insights | Centralized monitoring    |
| Networking              | Azure Virtual Network + Azure CNI            | AKS networking            |
| DNS                     | Azure DNS Zone                               | Service discovery         |
| Container Registry      | Azure Container Registry                     | Store container images    |

### Answer

The Deployment Agent fully adapts to different architectures:

- **Flask web app** → App Service-focused, simpler networking
- **Multi-tenant SaaS on AKS** → Kubernetes-focused, complex RBAC, namespace isolation, Microsoft Entra integration

Both plans follow the Well-Architected Framework but prioritize different pillars based on the workload requirements.

---

## Summary

| Skill                                  | Status |
| -------------------------------------- | ------ |
| Enable agent mode                      | ✅     |
| Describe workload in natural language  | ✅     |
| Receive and review infrastructure plan | ✅     |
| Refine plan through conversation       | ✅     |
| Generate Terraform configurations      | ✅     |
| Review and edit generated files        | ✅     |
| Explore deployment options             | ✅     |

You successfully completed challenge 2! 🚀🚀🚀
