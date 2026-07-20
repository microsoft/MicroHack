# Walkthrough Challenge 7 - Capstone Multi-Agent Scenario

**[Home](../Readme.md)** - [Previous Challenge Solution](solution-06.md)

**Estimated Duration:** 90 minutes

> 💡 **Objective:** Complete an end-to-end e-commerce platform scenario using all five Azure Copilot agents — Deployment, Observability, Optimization, Resiliency, and Troubleshooting — demonstrating mastery of the full cloud operations lifecycle.

---

## Phase 1: Deploy the Infrastructure — Deployment Agent

### Step-by-Step

1. **Enable agent mode** in Azure Copilot
2. **Enter the full workload description:**

   > _"Using the Deployment Agent, plan a 3-tier web application in East US 2 that includes: App Service (Standard S1) for the frontend, Azure Cosmos DB (NoSQL API, serverless) for the product catalog, Azure Cache for Redis (Basic C0), Application Insights, Key Vault, and a Virtual Network with separate subnets for App, Data, and Cache tiers. After the plan is shown, open the plan canvas (look for a button such as View plan / Open plan canvas / View workload)."_

### Expected Infrastructure Plan

- Azure Copilot proposes a greenfield 3-tier architecture with the requested core services and supporting platform components.
- The answer should call out security, networking, monitoring, and cost-conscious defaults at a high level.
- Optional enhancements such as Key Vault, Front Door, Application Insights, or private networking may be suggested.
- This phase is successful if participants get a coherent architecture blueprint rather than a deployed or fully optimized design package.

### Plan Approval

After reviewing the infrastructure plan and completing any refinements:

1. **Review the final plan summary** — Confirm all components, SKUs, and networking match your requirements
2. **Click "I approve the plan"** to proceed to Terraform generation, **or** click **"Review the plan and make edits"** to iterate
3. Azure Copilot generates the Terraform configurations only after you explicitly approve

### Refinement: Adding Azure Front Door

**Prompt:** _"Add Azure Front Door instead of CDN for global load balancing and WAF protection."_

> Azure Copilot replaces Azure CDN with Azure Front Door and adds:
>
> - WAF policy with managed rule sets (OWASP)
> - SSL termination at the edge
> - Global load balancing
> - Health probes for both App Services

### Generated Terraform Structure

```text
├── main.tf              # Resources: App Service, Cosmos DB, Redis, etc.
├── networking.tf        # VNet, subnets, NSGs, private endpoints
├── frontdoor.tf         # Azure Front Door + WAF policy
├── monitoring.tf        # Application Insights, Log Analytics
├── keyvault.tf          # Key Vault + access policies
├── variables.tf         # Input variables
├── outputs.tf           # Endpoints, connection strings
├── providers.tf         # azurerm provider configuration
└── terraform.tfvars     # Default values
```

### Deployment

Export via **GitHub PR** for team review, or **VS Code Web** for immediate editing.

---

## Phase 2: Set Up Monitoring — Observability Agent

### Recommended Alerts

When asked about alerts, Azure Copilot suggests:

| Service                | Alert                     | Threshold        | Severity |
| ---------------------- | ------------------------- | ---------------- | -------- |
| App Service (Frontend) | Response time             | > 3 seconds      | Warning  |
| App Service (Backend)  | HTTP 5xx errors           | > 5 in 5 minutes | Critical |
| App Service (Backend)  | Response time             | > 1 second       | Warning  |
| Cosmos DB              | Normalized RU consumption | > 80%            | Warning  |
| Cosmos DB              | Server-side latency       | > 100ms          | Warning  |
| Redis Cache            | Server load               | > 80%            | Warning  |
| Redis Cache            | Cache miss ratio          | > 50%            | Warning  |
| Front Door             | Origin health             | < 80%            | Critical |
| Key Vault              | Availability              | < 99%            | Critical |

### Investigation Workflow

When asked to walk through an investigation process:

```text
Complete Investigation Process for Slow Response Time:

1. 📨 Alert fires: "App Service backend response time > 1 second"

2. 🔍 Azure Copilot investigation:
   a. Check Application Insights for slow requests
   b. Analyze dependency calls (Cosmos DB, Redis, external APIs)
   c. Check CPU and memory metrics on the App Service plan
   d. Look for deployment changes in the timeframe
   e. Check for correlated alerts on dependent services

3. 📋 Findings delivered:
   - Root cause identified with evidence
   - Timeline of events
   - Impact assessment

4. 🔧 Remediation steps:
   - Ordered by impact
   - Specific to the identified root cause
   - Include links and commands

5. ✅ Verification:
   - Confirm alert resolves
   - Monitor for recurrence
```

---

## Phase 3: Optimize for Cost — Optimization Agent

### Cost Assessment

Azure Copilot analyzes your resources and may find:

```text
Cost Optimization Summary:

1. App Service (Frontend): Standard S1 → Consider Basic B2
   Savings: ~$45/month (low traffic expected initially)

2. App Service (Backend): Standard S2 → Standard S1
   Savings: ~$80/month (if traffic < 500 req/min)

3. Cosmos DB: Provisioned 800 RU/s → Serverless
   Savings: ~$60/month (for variable/unpredictable traffic)

4. Redis Cache: Standard C1 → Basic C0
   Savings: ~$30/month (if no replication needed initially)

Total Potential Savings: ~$215/month ($2,580/year)
```

### Reserved Capacity Analysis

```text
Reserved Instance Analysis:

App Service (assuming 1-year commitment):
  Pay-as-you-go: $146/month → Reserved: $89/month
  Savings: $57/month (39% reduction)

Redis Cache (1-year reserved):
  Pay-as-you-go: $54/month → Reserved: $37/month
  Savings: $17/month (31% reduction)

Recommendation: Wait 3-6 months to understand actual usage
patterns before committing to reserved pricing.
```

### Optimization Script

Azure Copilot generates PowerShell/CLI scripts for any VM or VMSS rightsizing recommendations.

---

## Phase 4: Ensure Resiliency — Resiliency Agent

### Zone Resiliency Assessment

```text
Non-Zone-Resilient Resources:

1. ⚠️ App Service Plan → Enable zone redundancy
   Required: Premium v3 or Isolated v2 plan
   Impact: Plan upgrade cost increase

2. ⚠️ Redis Cache → Enable zone redundancy
   Required: Premium tier
   Impact: Significant cost increase

3. ✅ Cosmos DB → Multi-region writes available
   Currently single-region; add West US 2 for failover

4. ✅ Key Vault → Inherently zone-resilient
```

### Backup Configuration

Cosmos DB continuous backup (point-in-time restore):

```text
Cosmos DB Backup Configuration:

Recommended:
  - Continuous backup mode (point-in-time restore)
  - Retention: 30 days
  - RPO: As recent as the last write
  - Supported for NoSQL API ✅

Steps:
1. Navigate to Cosmos DB → Backup policy
2. Select "Continuous (30 days)" or "Continuous (7 days)"
3. Save — applies immediately
```

### Disaster Recovery Plan

```text
DR Plan: E-Commerce Platform

Primary Region: East US 2
Secondary Region: West US 2

Components:
1. Azure Front Door: Automatic failover to secondary origin
2. App Service: Deploy secondary instances in West US 2
3. Cosmos DB: Enable multi-region writes (East US 2 + West US 2)
4. Redis: Configure geo-replication (Premium tier)
5. Key Vault: Create secondary vault in West US 2

RTO Target: < 15 minutes
RPO Target: < 5 minutes

DR Drill Schedule: Quarterly
```

---

## Phase 5: Respond to an Incident — Troubleshooting Agent

### Checkout Failure Investigation

**Prompt:** _"Users are reporting that the checkout process is failing with timeout errors."_

```text
🔍 Investigating Checkout Timeout Errors

Step 1: Checking App Service (Backend API)
  → Status: Running
  → HTTP errors: 504 Gateway Timeout spike at 14:35 UTC
  → App Service CPU: 92% (HIGH)

Step 2: Checking Dependencies
  → Cosmos DB: 429 Too Many Requests (RU throttling)
  → Redis Cache: Connection refused (service unavailable)

Step 3: Root Cause Analysis
  → Redis Cache became unavailable at 14:30 UTC
  → Without cache, all requests hit Cosmos DB directly
  → Cosmos DB RU limit exceeded causing 429 errors
  → API timeouts cascade to checkout failures

Resolution Priority:
1. 🔧 Restore Redis Cache (check instance health)
2. 📈 Temporarily increase Cosmos DB RU/s
3. 🔍 Investigate why Redis became unavailable
4. 🛡️ Add circuit breaker pattern to handle cache failures gracefully
```

### Cascading Failure Mitigation

```text
Redis Cache Failure Impact Analysis:

If Redis is unavailable:
├── Session data lost → Users logged out
├── Cart data lost → Shopping carts reset
├── All requests hit Cosmos DB → 3x RU consumption
├── Cosmos DB throttling → API errors
└── Frontend receives 5xx → Checkout fails

Mitigation Strategies:
1. Implement circuit breaker pattern in the API
2. Add local memory cache as fallback (short-lived)
3. Pre-scale Cosmos DB RU for cache-miss scenarios
4. Configure Redis geo-replication for failover
5. Add health check endpoint that includes Redis status
```

---

## Phase 6: Operational Runbook — All Agents

### Generated Runbook

```markdown
# E-Commerce Platform Operational Runbook

## Daily Checks (Morning)

1. Open Azure Copilot → "What are the key alerts from the last 24 hours?"
2. Review Application Insights → "Show me error trends for the past day"
3. Check costs → "Any cost anomalies in the past 24 hours?"

## Weekly Checks (Monday)

1. Optimization → "Show me top 5 cost-saving opportunities"
2. Resiliency → "Are all my resources zone-resilient?"
3. Backup → "How many backup jobs failed in the last 7 days?"
4. Performance → "Show me performance trends for the past week"

## Monthly Checks (First Monday)

1. Full cost review → "Summarize my spending trends for the past month"
2. Resiliency audit → "Generate a resiliency report for compliance"
3. Capacity planning → "Do I need to scale any resources based on trends?"

## Incident Response

1. Alert received → "Start an investigation for [alert ID]"
2. Diagnosis → Follow investigation results
3. Remediation → Apply fixes (one-click or manual)
4. Escalation → "Create a support request" if unresolved
5. Post-mortem → Document findings and prevention steps

## Escalation Matrix

| Severity      | Response Time     | Escalation                    |
| ------------- | ----------------- | ----------------------------- |
| P1 (Critical) | 15 min            | On-call → Team lead → Manager |
| P2 (High)     | 1 hour            | On-call → Team lead           |
| P3 (Medium)   | 4 hours           | On-call                       |
| P4 (Low)      | Next business day | Backlog                       |
```

### Agent Summary

```text
Azure Copilot Agents Used Today:

1. 🏗️ Deployment Agent
   - Planned e-commerce architecture
   - Generated Terraform for 10+ Azure resources
   - Integrated with GitHub for team review

2. 👁️ Observability Agent
   - Defined monitoring strategy with 9 alert rules
   - Investigated alerts and provided root cause analysis
   - Created Azure Monitor issues for tracking

3. 💰 Optimization Agent
   - Identified $215/month in potential savings
   - Analyzed reserved capacity opportunities
   - Generated rightsizing scripts

4. 🛡️ Resiliency Agent
   - Found 3 zone-resiliency gaps
   - Configured Cosmos DB continuous backup
   - Created multi-region DR plan with RTO < 15 min

5. 🔧 Troubleshooting Agent
   - Diagnosed checkout failure (Redis → Cosmos DB cascade)
   - Provided cascading failure analysis
   - Demonstrated support request creation

Combined Value: Reduced cloud operations setup time from
days to hours. All grounded in Azure Well-Architected
Framework best practices.
```

---

## Summary

| Phase                     | Agent           | Completed |
| ------------------------- | --------------- | --------- |
| Infrastructure Deployment | Deployment      | ✅        |
| Monitoring Setup          | Observability   | ✅        |
| Cost Optimization         | Optimization    | ✅        |
| Resiliency Configuration  | Resiliency      | ✅        |
| Incident Response         | Troubleshooting | ✅        |
| Operational Runbook       | All Agents      | ✅        |

---

## Workshop Complete

You've demonstrated mastery of Azure Copilot and all five of its specialized agents. You can now:

- Use natural language to manage complex cloud environments
- Leverage AI-driven agents for every phase of the cloud lifecycle
- Build operational practices that integrate Azure Copilot into daily workflows
- Make informed decisions using agent-provided analysis and recommendations

You successfully completed challenge 7! 🚀🚀🚀

---

[**Back to Workshop Home**](../Readme.md)
