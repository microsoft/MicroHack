# Challenge 6 - Troubleshooting Agent

**[Home](../Readme.md)** - [Previous Challenge](challenge-05.md) - [Next Challenge](challenge-07.md)

## Goal

The Troubleshooting Agent helps you **resolve issues faster** by running diagnostics, identifying root causes, and providing tailored remediation. It can:

- **Diagnose issues** across all Azure resource types
- **Run root cause diagnostics** specific to your environment
- **Provide one-click fixes** for common problems
- Offer **step-by-step remediation instructions** when one-click fixes aren't available
- **Create support requests** when the issue requires Microsoft Support, pre-populating the ticket with diagnostic details

Use the Troubleshooting Agent in Azure Copilot to diagnose resource issues, run root cause analysis, apply one-click fixes, and create support requests when needed.

**Scenario:** You are the platform engineer at Contoso Ltd. Your team's Monday morning starts with several reports: a developer can't connect to a VM, the Cosmos DB (NoSQL API) is returning connection timeouts, and an AKS cluster is showing pod health issues. You need to quickly diagnose and resolve these issues before the business day starts.

By the end of this challenge, you will be able to:

- Use the Troubleshooting Agent to diagnose common Azure resource issues
- Interpret diagnostic results and root cause analysis
- Apply one-click fixes offered by Azure Copilot
- Follow step-by-step remediation instructions
- Create support requests through Azure Copilot when needed
- Troubleshoot across different resource types (VMs, Cosmos DB, AKS)

## Actions

### Pre-Challenge Setup

> **Note:** The workshop deployment scripts have already created resources with deliberate issues. If you ran `lab/Deploy-Lab.ps1`, everything below is ready to use.

#### Workshop Resources (Pre-Deployed)

Resources in **`rg-copilot-<suffix>-ch05`** (in your chosen deployment region):

| Resource               | Name                                          | Deliberate Issue                                                                 |
| ---------------------- | --------------------------------------------- | -------------------------------------------------------------------------------- |
| Virtual Machine        | `vm-copilot-broken`                           | NSG blocks **all** inbound traffic (SSH, RDP, and all other ports denied)        |
| Cosmos DB Account      | `cosmos-copilot-broken-<suffix>` (Serverless) | Restrictive firewall — only allows `127.0.0.1` (blocks all external connections) |
| Network Security Group | `nsg-copilot-broken`                          | DenySSH (priority 100), DenyRDP (priority 101), DenyAllInbound (priority 200)    |

> **Note:** `<suffix>` is a random 4-character string generated during deployment. Check your `rg-copilot-<suffix>-ch05` resource group to find the actual Cosmos DB name.

> **What's broken?** The VM has an NSG that denies all inbound connections — perfect for Task 1 (VM connectivity troubleshooting). The Cosmos DB account has a restrictive IP firewall — ideal for Task 2 (database connection troubleshooting).

#### Option A: Use the Pre-Deployed Resources (Recommended)

1. Navigate to **`rg-copilot-<suffix>-ch05`** in the Azure portal
2. Note the resources: `vm-copilot-broken` and `cosmos-copilot-broken-<suffix>`
3. Proceed to Task 1

#### Option B: Use Your Own Existing Resources

For the best experience, ensure you have at least one of these resources deployed:

- A Virtual Machine (even a stopped/deallocated one)
- An Azure Kubernetes Service cluster (optional)
- A Cosmos DB account (optional)

> If you only have a VM from earlier challenges, you can still complete most tasks. The agent works with all Azure resource types.

### Task 1: Troubleshoot VM Connectivity (10 min)

A developer reports they can't connect to a VM via SSH/RDP. Use the Troubleshooting Agent to diagnose:

1. Open Azure Copilot and **enable agent mode**
2. Describe the problem:

   > _"I can't connect to my VM, can you help me troubleshoot?"_

3. When prompted, **select the VM** from the resource picker (or provide the resource name/ID)
4. Observe the diagnostic process:
   - Azure Copilot checks VM status (running/stopped)
   - Checks NSG rules for SSH/RDP ports
   - Checks if the VM has a public IP
   - Verifies the VM agent status
   - Checks for known platform issues
5. Review the findings and follow the remediation steps

6. Try additional VM troubleshooting prompts:

   > _"Help me investigate why my VM is unhealthy."_
   > _"Why is my VM showing high CPU utilization?"_

**Question to answer:** What diagnostic checks does the agent perform automatically? How do they compare to manual troubleshooting steps?

### Task 2: Troubleshoot a Database Connection Issue (10 min)

Simulate a Cosmos DB connection issue investigation:

1. Start a new conversation with agent mode enabled
2. Describe the scenario:

   > _"I'm trying to connect to my Azure Cosmos DB (NoSQL API) from my local development machine, but I keep getting a timeout. What should I do?"_

3. If you have a Cosmos DB account, select it when prompted. Otherwise, observe the general guidance provided
4. Review the diagnostic steps:
   - Connection string validation
   - Firewall rules check
   - Network connectivity analysis
   - Request unit (RU) throttling check
   - Regional availability check

5. Ask follow-up questions:

   > _"Could this be a firewall issue?"_
   > _"How do I check if my IP is whitelisted?"_
   > _"What are the common causes of Cosmos DB timeouts?"_

**Question to answer:** How does the Troubleshooting Agent handle issues where it can't access the resource directly? Does it still provide useful guidance?

### Task 3: Troubleshoot AKS Cluster Issues (10 min)

Investigate Kubernetes cluster problems:

1. Start a new conversation with agent mode enabled
2. Try these troubleshooting prompts (select your AKS cluster when prompted, or get general guidance):

   > _"Investigate the health of my pods."_

   > _"Investigate networking issues causing pod connectivity failures."_

   > _"Identify reasons for high CPU or memory usage in my AKS cluster."_

3. For each prompt, review:
   - What diagnostics does Azure Copilot run?
   - What data does it analyze (pod logs, node status, resource metrics)?
   - What remediation steps does it provide?

4. Try a scenario that might require escalation:

   > _"My AKS cluster nodes are in NotReady state and I've tried restarting them. What else can I do?"_

**Question to answer:** When the troubleshooting agent encounters an issue it can't auto-remediate, what alternatives does it offer?

### Task 4: Experience One-Click Fixes (10 min)

The Troubleshooting Agent can sometimes provide one-click fixes:

1. Navigate to a resource that has a known issue (or simulate one):
   - Stop a VM and then ask Azure Copilot why you can't connect to it
   - Configure an NSG rule that blocks all traffic, then ask Azure Copilot to troubleshoot connectivity

2. Ask Azure Copilot for help:

   > _"My VM `vm-copilot-broken` isn't responding. Help me troubleshoot."_

3. If Azure Copilot identifies a simple fix (e.g., the VM is stopped):
   - It will offer a **one-click fix** button
   - Click the fix to apply it (e.g., "Start the VM")
   - **Confirm** when prompted — no actions are taken without your approval

4. If the fix is more complex, Azure Copilot provides:
   - Detailed step-by-step instructions
   - Portal navigation links
   - Scripts you can run to resolve the issue

**Question to answer:** What types of issues support one-click fixes? When does the agent fall back to detailed instructions?

### Task 5: Create a Support Request (5 min)

When the Troubleshooting Agent can't resolve an issue, it can create a support request:

1. Present a complex problem:

   > _"My application is experiencing intermittent failures that I can't diagnose. Can you create a support request?"_

   Or more directly:

   > _"Create a support request."_
   > _"Open a support ticket for my problem."_

2. Azure Copilot will:
   - Gather necessary details for the support request
   - Pre-populate the request with diagnostic information
   - Ask you to review and confirm before submission

3. **Review** the pre-populated support request:
   - Is the problem description accurate?
   - Is the impact assessment correct?
   - Are the diagnostic details included?

4. You can either **submit** the request or **cancel** if you were just testing

**Question to answer:** How does having Azure Copilot pre-populate the support request improve the support experience compared to manually creating one?

## Success criteria

- You used the Troubleshooting Agent to diagnose at least one VM issue
- You investigated a database or application connectivity issue
- You explored AKS or another resource type troubleshooting
- You experienced or understood the one-click fix capability
- You explored the support request creation flow
- You understand when the agent escalates from self-service to support

## Learning resources

- The Troubleshooting Agent **automates diagnostic workflows** — it runs the same checks an experienced engineer would, but faster
- **Root cause diagnostics** are environment-specific — the agent analyzes your actual resource configuration and metrics
- **One-click fixes** are available for common, well-understood issues — they require your confirmation before applying
- When self-service resolution isn't possible, **support request creation** is seamless with pre-populated diagnostic data
- The agent is especially effective for **Cosmos DB, VMs, and AKS** but works with all resource types
- [Troubleshooting Agent documentation](https://learn.microsoft.com/en-us/azure/copilot/troubleshooting-agent)

**Limitations to Note:**

- One-click (automatic) fixes **aren't available for all issues or resource types** — AKS issues, for example, typically get detailed instructions instead
- Troubleshooting is based on **currently available diagnostic data** and predefined checks
- The agent can **diagnose and recommend** but some remediations require manual intervention
- For novel or unprecedented issues, the agent may guide you to create a support request

## Solution

> [!TIP]
> We encourage you to try solving the challenge on your own before looking at the solution. This will help you learn and understand the concepts better.

<details>
<summary>Click here to view the solution</summary>

[Solution for Challenge 6](../walkthrough/solution-06.md)

</details>
