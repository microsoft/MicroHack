# Challenge 3 - Observability Agent

**[Home](../Readme.md)** - [Previous Challenge](challenge-02.md) - [Next Challenge](challenge-04.md)

## Goal

The Observability Agent helps you **investigate Azure Monitor alerts** by creating Azure Monitor issues and running automated investigations. It can:

- Investigate **all types of Azure Monitor alerts** for any resource type
- Create **Azure Monitor issues** and start automated **investigations**
- Provide a **summary of findings** with possible explanations
- Suggest **remediation steps** to resolve the identified problem
- Link to detailed **Azure Monitor issue** pages for further analysis

Use the Observability Agent in Azure Copilot to investigate Azure Monitor alerts, understand root causes, and get guided remediation steps — all through conversational AI.

**Scenario:** You are the on-call engineer at Contoso Ltd. Your team's web application — deployed on Azure App Service with Application Insights — has been triggering alerts overnight. Users have reported slow response times and occasional errors. You need to investigate the alerts, understand the root cause, and determine the remediation steps.

By the end of this challenge, you will be able to:

- Use the Observability Agent to investigate Azure Monitor alerts
- Provide alert IDs or navigate to alerts in the portal for investigation
- Interpret investigation summaries provided by Azure Copilot
- Follow remediation steps suggested by the agent
- Navigate to Azure Monitor issues for deeper analysis
- Understand the relationship between alerts, issues, and investigations

## Actions

### Pre-Challenge Setup

> **Note:** The workshop deployment scripts have already created a test environment for you. If you ran `lab/Deploy-Lab.ps1`, everything below is ready to use.

#### Workshop Resources (Pre-Deployed)

Resources in **`rg-copilot-<suffix>-ch02`** (in your chosen deployment region):

| Resource                | Name                           | Purpose                                         |
| ----------------------- | ------------------------------ | ----------------------------------------------- |
| App Service             | `app-copilot-buggy-<suffix>`   | Intentionally buggy Flask app generating errors |
| Application Insights    | `ai-copilot-ch02`              | Collects telemetry from the app                 |
| Log Analytics Workspace | `law-copilot-ch02`             | Backing store for App Insights                  |
| App Service Plan        | `plan-copilot-ch02` (B1 Linux) | Hosts the web app                               |

> **Note:** `<suffix>` is a random 4-character string generated during deployment. Check your `rg-copilot-<suffix>-ch02` resource group or the deployment output to find the actual app name.

**App URL:** `https://app-copilot-buggy-<suffix>.azurewebsites.net`

**Buggy endpoints (for generating alerts):**

| Endpoint      | Behavior                                               |
| ------------- | ------------------------------------------------------ |
| `/`           | Returns 200 OK (healthy)                               |
| `/health`     | Returns 200 OK (health check endpoint)                 |
| `/crash`      | Throws `RuntimeError` → 500 Internal Server Error      |
| `/slow`       | 5-second delay before responding                       |
| `/api/orders` | Simulates a database connection failure → 500 after 2s |
| `/leak`       | Allocates memory on each call (memory leak simulation) |

The buggy Flask app source code is located at `../app/`.

**Pre-configured alert rules:**

| Alert                 | Condition                           |
| --------------------- | ----------------------------------- |
| `alert-http-5xx`      | Any HTTP 5xx errors in 5 min        |
| `alert-slow-response` | Avg response time > 3s in 5 min     |
| `alert-http-4xx`      | HTTP 4xx client errors > 5 in 5 min |

> **To generate fresh alerts**, run: `.\scripts\Send-CopilotTraffic.ps1`

#### Option A: Use the Pre-Deployed Environment (Recommended)

1. Navigate to **Azure Monitor** → **Alerts** in the portal
2. Filter by resource group **`rg-copilot-<suffix>-ch02`** to find active alerts
3. Note the **alert ID** (resource ID) of an active alert
4. Proceed to Task 1

#### Option B: Use Your Own Existing Alerts

If you have your own Azure resources with Application Insights and active alerts:

1. Navigate to **Azure Monitor** → **Alerts** in the portal
2. Note the **alert ID** (resource ID) of an active alert
3. Skip to Task 1

#### Required Permissions

You must have one of these roles on the Azure Monitor Workspace:

- **Contributor**
- **Monitoring Contributor**
- **Issue Contributor**

### Task 1: Investigate an Alert Using Its ID (10 min)

1. Open Azure Copilot and **enable agent mode**
2. Navigate to **Azure Monitor** → **Alerts** and find an active alert
3. Copy the alert's **resource ID** (found in the alert's properties/essentials section)
4. Use this prompt (replace the ID with your actual alert ID):

   > _"If there are active Application Insights alerts in this subscription, investigate the most recent one and summarize the likely root cause. If there are no active alerts, explain how you would investigate one in this lab and what data you would analyze."_

5. Click **"Show activity"** to watch the investigation progress in real time
6. Review the investigation summary when complete

**Question to answer:** What information does the investigation summary include? How detailed is the root cause analysis?

### Task 2: Investigate an Alert from the Portal Context (10 min)

1. In the Azure portal, navigate to a **specific alert instance** (Azure Monitor → Alerts → click on an alert)
2. With the alert page open, open Azure Copilot (agent mode enabled)
3. Ask a contextual question without providing the alert ID:

   > _"Can you help investigate this alert?"_

4. Observe how Azure Copilot picks up context from the current page
5. Review the findings and steps provided

**Alternative prompts to try:**

- _"Can you help troubleshoot this?"_
- _"What's causing this alert to fire?"_
- _"Explain this alert and what I should do about it"_

**Question to answer:** Does Azure Copilot correctly identify the alert you're viewing? How does contextual investigation differ from providing an alert ID explicitly?

### Task 3: Interpret Investigation Results (10 min)

After the investigation completes, carefully review the results:

1. **Read the summary** — What is the identified issue?
2. **Review the findings** — What data did the agent analyze?
3. **Examine the remediation steps** — Are they actionable?
4. **Follow the link** to the Azure Monitor issue for the full investigation details
5. Ask follow-up questions:

   > _"For the alert we just discussed (or for a typical App Insights alert if none exist), tell me what data you analyze, what findings you look for, and what remediation steps you would recommend."_
   > _"What would happen if I don't address this issue?"_
   > _"Are there any related alerts I should be aware of?"_

**Question to answer:** How useful are the suggested remediation steps? Could you follow them without additional research?

### Task 4: Explore Azure Monitor Issues (10 min)

1. Click the link to the **Azure Monitor issue** that was created during the investigation
2. In the Azure Monitor issues page, explore:
   - The issue timeline
   - The investigation details and evidence
   - Related alerts grouped under the same issue
3. Return to Azure Copilot and ask:

   > _"Show me recent alerts for my Application Insights resource"_
   > _"Are there any patterns in my alerts from the past 24 hours?"_

**Question to answer:** How do Azure Monitor issues help you understand patterns across multiple alerts?

### Task 5: Practice the Investigation Workflow (5 min)

Run through the complete workflow one more time with a different alert or a hypothetical scenario:

1. Ask: _"Summarize any Application Insights alerts raised in the past 24 hours. If none are present, say so clearly and tell me what traffic or failure signal I should generate for this lab."_
2. Ask: _"Investigate the most important recent Application Insights alert. If there are no recent alerts, walk me through how I would investigate the next one and what remediation evidence I should capture."_  (if the first prompt returned no alerts, use this follow-up)
3. Pick an alert from the list and ask for an investigation
4. Review the results concisely
5. Identify the remediation steps

**Question to answer:** How would you integrate this investigation workflow into your daily on-call routine?

## Success criteria

- You used the Observability Agent to investigate at least one alert by ID
- You used contextual investigation (from an alert page in the portal)
- You reviewed an investigation summary with findings and remediation steps
- You navigated to an Azure Monitor issue for deeper analysis
- You asked follow-up questions to refine your understanding

## Learning resources

- The Observability Agent **automates alert investigation** — it analyzes diagnostics, logs, and metrics to identify root causes
- You can trigger investigations by **providing an alert ID** or by **viewing an alert in the portal** and asking contextual questions
- Azure Copilot creates **Azure Monitor issues** as part of the investigation, which persist for further review
- Investigation results include **specific, actionable remediation steps**
- This agent is most effective for **Application Insights alerts** currently
- [Observability Agent documentation](https://learn.microsoft.com/en-us/azure/copilot/observability-agent)

**Limitations to Note:**

- Agent capabilities currently support only alerts from **Application Insights components** — support for other alert types is limited
- The agent **can investigate and recommend** but **cannot perform remediation** actions directly
- You need the **Contributor**, **Monitoring Contributor**, or **Issue Contributor** role on the Azure Monitor Workspace
- If no default Azure Monitor Workspace is configured, Azure Copilot will attempt to configure one for you

## Solution

> [!TIP]
> We encourage you to try solving the challenge on your own before looking at the solution. This will help you learn and understand the concepts better.

<details>
<summary>Click here to view the solution</summary>

[Solution for Challenge 3](../walkthrough/solution-03.md)

</details>
