# Walkthrough Challenge 3 - Observability Agent

**[Home](../Readme.md)** - [Previous Challenge Solution](solution-02.md) - [Next Challenge Solution](solution-04.md)

**Estimated Duration:** 45 minutes

> 💡 **Objective:** Learn to investigate alerts and diagnose issues using the Observability Agent in Azure Copilot — from alert investigation to integrating Copilot into an on-call workflow.

---

## Task 1: Investigate an Alert Using Its ID

### Steps

1. **Open Azure Copilot** and click the **agent mode icon** to enable it
2. **Find the alert resource ID:**
   - Navigate to **Azure Monitor** → **Alerts**
   - Click on an active alert
   - In the alert details pane, go to **Properties** or **Essentials**
   - Copy the full resource ID — it follows this format:
     ```text
     /subscriptions/{subscription-id}/resourcegroups/{resource-group}/providers/microsoft.insights/components/{component-name}/providers/Microsoft.AlertsManagement/alerts/{alert-id}
     ```
3. **Enter the investigation prompt:**

   > _"Start an investigation for my alert: `/subscriptions/aaaa0a0a-bb1b-cc2c-dd3d-eeeeee4e4e4e/resourcegroups/rg-copilot-<suffix>-ch02/providers/microsoft.insights/components/ai-copilot-ch02/providers/Microsoft.AlertsManagement/alerts/12345678-abcd-efgh-ijkl-123456789012`"_

4. **Click "Show activity"** to observe the reasoning steps:
   - Azure Copilot identifies the alert type and affected resource
   - It creates an Azure Monitor issue
   - It starts an automated investigation
   - It analyzes related telemetry (logs, metrics, dependencies)

### Expected Investigation Summary

The summary typically includes:

```text
📋 Investigation Summary

Issue: High server response time detected on myapp-webapp

Findings:
1. Average response time increased from 200ms to 3500ms starting at 02:15 UTC
2. The increase correlates with a spike in database dependency call duration
3. PostgreSQL connection pool appears to be exhausted (max connections reached)
4. No deployment or configuration changes detected in the timeframe

Root Cause: Database connection pool exhaustion causing cascading latency

Recommended Remediation Steps:
1. ✅ Increase the max_connections parameter on the PostgreSQL Flexible Server
2. ✅ Implement connection pooling in the application (e.g., PgBouncer)
3. ✅ Review application code for connection leaks
4. ✅ Set up an alert for database connection count approaching the limit

🔗 View full investigation: [Azure Monitor Issue Link]
```

### Answer

The investigation summary includes:

- **Issue identification** — What alert was triggered
- **Detailed findings** — Correlated data from multiple telemetry sources
- **Root cause analysis** — The probable underlying cause
- **Remediation steps** — Specific, ordered actions to resolve the issue
- **Link to full investigation** — For deeper review in Azure Monitor

---

## Task 2: Investigate an Alert from Portal Context

### Steps

1. **Navigate to the alert:**
   - Go to **Azure Monitor** → **Alerts**
   - Click on a specific alert instance to open its detail page
2. **With the alert page visible**, open Azure Copilot pane
3. **Enable agent mode** if not already active
4. **Enter the prompt:** _"Can you help investigate this alert?"_

### Expected Behavior

Azure Copilot:

1. **Detects the current context** — It knows you're viewing a specific alert
2. **Automatically identifies the alert** — No need to provide the alert ID
3. **Proceeds with the investigation** — Same process as providing the ID manually
4. **Returns the same quality of investigation summary**

### Alternative Prompts That Work

| Prompt                                               | Behavior                                      |
| ---------------------------------------------------- | --------------------------------------------- |
| _"Can you help investigate this alert?"_             | Full investigation                            |
| _"Can you help troubleshoot this?"_                  | Full investigation with troubleshooting focus |
| _"What's causing this alert to fire?"_               | Investigation with root cause focus           |
| _"Explain this alert and what I should do about it"_ | Investigation with emphasis on remediation    |

### Answer

Azure Copilot **correctly identifies the alert** from the portal context. The contextual approach is **simpler and faster** than providing an alert ID, making it ideal when you're already browsing alerts in the portal. Both methods produce equivalent investigation quality.

---

## Task 3: Interpret Investigation Results

### How to Read the Investigation

**1. Summary Section**

- A high-level description of the identified problem
- The severity and impact assessment

**2. Findings Section**

- Numbered findings, each with supporting evidence
- Correlations between different telemetry signals (metrics, logs, traces)
- Timeline of events leading to the alert

**3. Remediation Steps**

- Ordered from most impactful to least
- Each step includes:
  - What to do
  - Why it helps
  - Where to do it (links to portal pages when applicable)

### Follow-Up Questions

**Prompt:** _"Can you explain more about finding #1?"_

> **Expected:** Azure Copilot expands on the specific finding with more detailed data, such as exact metric values, log entries, or dependency traces.

**Prompt:** _"What would happen if I don't address this issue?"_

> **Expected:** Azure Copilot explains the potential impact — e.g., continued degraded performance, possible cascading failures, user impact.

**Prompt:** _"Are there any related alerts I should be aware of?"_

> **Expected:** Azure Copilot checks for correlated alerts from the same or related resources.

### Answer

The remediation steps are **highly actionable** and specific to the identified root cause. In most cases, you can follow them directly without extensive additional research. They include specific Azure service settings to change, code patterns to implement, and monitoring configurations to add.

---

## Task 4: Explore Azure Monitor Issues

### Steps

1. **Click the issue link** from the investigation summary
2. In the Azure Monitor issues page:

   **Issue Timeline:**
   - Shows when the issue was detected
   - Lists all correlated alerts under the same issue
   - Shows investigation start and completion times

   **Investigation Details:**
   - Evidence collected during the investigation
   - Data sources analyzed (Application Insights, Log Analytics, Metrics)
   - Reasoning chain from symptoms to root cause

   **Related Alerts:**
   - Multiple alerts may be grouped under one issue
   - Helps identify patterns across alerts

3. **Return to Azure Copilot** and ask about alert patterns:

   > _"Show me recent alerts for my Application Insights resource"_
   > **Expected:** A list of recent alerts with severity, type, and status

   > _"Are there any patterns in my alerts from the past 24 hours?"_
   > **Expected:** Pattern analysis showing recurring issues, peak times, or correlation between different alert types

### Answer

Azure Monitor issues provide a **holistic view** across multiple alerts:

- They group related alerts so you don't investigate the same root cause multiple times
- They show temporal patterns (e.g., the issue recurs every night during batch processing)
- They preserve investigation history for future reference and incident review

---

## Task 5: Practice the Investigation Workflow

### Quick Investigation Workflow

```text
Step 1: "What are the key alerts raised since the past 24 hours?"
         → Get a list of recent alerts

Step 2: "Investigate alert [select from list or paste ID]"
         → Start automated investigation

Step 3: Review summary → Read findings and root cause

Step 4: "Generate a remediation plan for this issue"
         → Get ordered remediation steps

Step 5: Apply remediations → Follow the steps

Step 6: "Verify this alert hasn't recurred in the last hour"
         → Confirm resolution
```

### Daily On-Call Integration

| Time               | Action                  | Copilot Prompt                                                      |
| ------------------ | ----------------------- | ------------------------------------------------------------------- |
| Start of shift     | Review overnight alerts | _"What are the key alerts raised since the past 24 hours?"_         |
| Alert received     | Investigate immediately | _"Start an investigation for this alert"_                           |
| Post-investigation | Document findings       | Copy the investigation summary to your incident management tool     |
| After remediation  | Verify fix              | _"Have there been any new alerts for [resource] in the past hour?"_ |
| End of shift       | Handoff summary         | _"Summarize all investigations from today's alerts"_                |

### Answer

The Observability Agent integrates naturally into an on-call workflow by:

1. **Reducing mean-time-to-detect (MTTD)** — Automated investigation starts immediately
2. **Reducing mean-time-to-resolve (MTTR)** — Specific remediation steps eliminate guesswork
3. **Improving handoffs** — Investigation summaries serve as incident documentation
4. **Identifying patterns** — Pattern analysis helps prevent recurring issues

---

## Summary

| Skill                                 | Status |
| ------------------------------------- | ------ |
| Investigate alert by ID               | ✅     |
| Investigate alert from portal context | ✅     |
| Interpret investigation summaries     | ✅     |
| Follow remediation steps              | ✅     |
| Navigate Azure Monitor issues         | ✅     |
| Use follow-up questions               | ✅     |
| Integrate into on-call workflow       | ✅     |

You successfully completed challenge 3! 🚀🚀🚀
