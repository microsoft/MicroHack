# Challenge 7 - Capstone Multi-Agent Scenario

**[Home](../Readme.md)** - [Previous Challenge](challenge-06.md)

## Goal

This capstone challenge simulates a **real-world day in the life** of a cloud engineer, touching all five agents in a single continuous workflow. Azure Copilot's orchestration layer automatically surfaces the right agent for each task — you just describe what you need.

Combine all five Azure Copilot agents in a realistic end-to-end scenario — deploy infrastructure, monitor it, optimize costs, ensure resiliency, and troubleshoot issues — demonstrating the full power of Azure Copilot's orchestration.

**Scenario — Contoso E-Commerce Platform:** Contoso Ltd. is launching a new e-commerce platform. As the lead cloud engineer, you are responsible for the **entire lifecycle**: deployment, monitoring, cost optimization, disaster recovery, and incident response. You have **one day** (this 90-minute challenge) to set everything up, and things will go wrong along the way.

By the end of this challenge, you will be able to:

- Use multiple agents seamlessly in a single workflow
- Understand how Azure Copilot orchestrates between agents automatically
- Apply all five agents to a real-world scenario
- Make informed decisions using agent recommendations
- Build a complete operational runbook for a cloud workload

## Actions

### Phase 1: Deploy the Infrastructure (20 min) — Deployment Agent

**Background:** The e-commerce platform requires:

- A frontend web application (React, hosted on App Service)
- A backend API (Node.js, hosted on App Service)
- A database (Azure Cosmos DB for product catalog)
- A cache layer (Azure Cache for Redis)
- A CDN for static assets
- Application Insights for monitoring
- Azure Key Vault for secrets

**Tasks:**

1. Open Azure Copilot with **agent mode enabled**
2. Describe the full workload:

   > _"I need to deploy an e-commerce platform with the following components: a React frontend on App Service, a Node.js backend API on App Service, Azure Cosmos DB for the product catalog, Azure Cache for Redis for session management, Azure CDN for static assets, Application Insights for monitoring, and Azure Key Vault for secrets. All resources should be in East US 2 with a Virtual Network."_

3. **Review** the workload plan Azure Copilot generates:
   - Does it include all requested components?
   - Are there recommendations you didn't think of (e.g., WAF, DDoS protection)?
   - What trade-offs does it identify?

4. Ask for refinements:

   > _"Add Azure Front Door instead of CDN for global load balancing and WAF protection."_

5. **Approve the plan** before Terraform generation begins:
   - Review the plan summary — verify all components, SKUs, networking, and security settings
   - Click **"I approve the plan"** to trigger Terraform code generation, **or** click **"Review the plan and make edits"** to iterate further
   - Azure Copilot will **not** generate IaC until you explicitly approve (see [Challenge 2 — Plan → Approve → Generate workflow](challenge-02.md) for the full diagram)
6. **Review the generated files** in the artifact pane
7. **Export** via your preferred method (VS Code Web, GitHub PR, or download)

**Checkpoint:**

- [ ] Infrastructure plan accepted
- [ ] Terraform configurations generated and reviewed
- [ ] Files exported for deployment

### Phase 2: Set Up Monitoring and Observability (15 min) — Observability Agent

**Background:** Now that the infrastructure plan is ready, you need to ensure proper monitoring is in place. Azure Copilot's observability capabilities will help you investigate any issues that arise.

**Tasks:**

1. In the **same or new conversation** (agent mode), ask about monitoring setup:

   > _"What alerts should I configure for my e-commerce platform? I need to monitor the App Service, Cosmos DB, Redis Cache, and CDN."_

2. Review the suggested alert rules:
   - Response time thresholds
   - Error rate thresholds
   - Database RU consumption
   - Cache hit/miss ratios
   - CDN origin health

3. Simulate an alert investigation. If you have Application Insights with alerts:

   > _"Start an investigation for my most recent alert."_

   If you don't have active alerts, ask for general guidance:

   > _"If my e-commerce app starts showing HTTP 500 errors, how would I use Azure Copilot to investigate?"_

4. Understand the investigation workflow:

   > _"Walk me through your complete investigation process for a slow response time alert on my App Service."_

**Checkpoint:**

- [ ] Monitoring alert recommendations reviewed
- [ ] Alert investigation process understood
- [ ] Investigation workflow documented

### Phase 3: Optimize for Cost (15 min) — Optimization Agent

**Background:** After the initial deployment, your CFO wants to ensure you're not overspending. The Optimization Agent can help identify savings across the platform.

**Tasks:**

1. Ask for a cost assessment:

   > _"Show me cost-saving opportunities across my subscription. Focus on compute and database resources."_

2. Explore specific recommendations:

   > _"What is the most cost-effective App Service tier for a Node.js API that handles 1000 requests per minute with an average response time under 200ms?"_

3. Ask about reserved capacity:

   > _"Should I consider reserved instances for any of my e-commerce platform resources? What would the savings be?"_

4. Generate a cost optimization report:

   > _"Generate a script to right-size any over-provisioned VMs in my subscription."_

5. Explore carbon impact:

   > _"Summarize the potential carbon reduction if I apply all recommended optimizations."_

**Checkpoint:**

- [ ] Cost savings identified
- [ ] Right-sizing recommendations reviewed
- [ ] Reserved capacity evaluated
- [ ] Optimization scripts generated

### Phase 4: Ensure Resiliency (15 min) — Resiliency Agent

**Background:** The platform is business-critical — any downtime directly impacts revenue. You need to ensure disaster recovery is configured.

**Tasks:**

1. Assess the resiliency posture:

   > _"Which of my e-commerce platform resources aren't zone-resilient?"_

2. Configure backup:

   > _"Help me set up backup for my Cosmos DB database with point-in-time restore enabled."_

3. Plan disaster recovery:

   > _"How can I define a recovery plan for my e-commerce platform? If East US 2 goes down, I need to failover to West US 2."_

4. Generate resiliency scripts:

   > _"Configure zone resiliency for my App Service resources."_

5. Prepare for a DR drill:

   > _"What are the steps to define a disaster recovery drill for my e-commerce platform?"_

**Checkpoint:**

- [ ] Zone resiliency gaps identified and addressed
- [ ] Backup configured for critical data
- [ ] DR plan documented
- [ ] DR drill steps prepared

### Phase 5: Respond to an Incident (15 min) — Troubleshooting Agent

**Background:** It's launch day and things go wrong! Users report that the checkout process is failing. The Troubleshooting Agent is your first responder.

**Tasks:**

1. Report the issue:

   > _"Users are reporting that the checkout process on our e-commerce platform is failing with timeout errors. Help me troubleshoot."_

2. Follow the diagnostic process:
   - Which resource does Azure Copilot investigate first?
   - What checks does it perform?
   - How does it narrow down the root cause?

3. Simulate a database issue:

   > _"My Cosmos DB is returning rate-limiting errors (429). Help me troubleshoot why my API calls are being throttled."_

4. Explore cascading failure analysis:

   > _"If my Redis Cache becomes unavailable, what impact would that have on my e-commerce platform? How can I mitigate this?"_

5. If the issue can't be resolved:

   > _"This issue is beyond what I can fix. Create a support request with all the diagnostic details."_

**Checkpoint:**

- [ ] Incident diagnosed using the Troubleshooting Agent
- [ ] Root cause identified and remediation steps provided
- [ ] Cascading failure analysis done
- [ ] Support request creation process understood

### Phase 6: Build the Operational Runbook (10 min) — All Agents

**Background:** Bring everything together into an operational runbook for your team.

**Tasks:**

1. Ask Azure Copilot to help create a runbook:

   > _"Based on everything we've discussed about our e-commerce platform, help me create a daily operational runbook that covers monitoring, cost management, resiliency checks, and incident response."_

2. Review and refine the runbook with follow-up questions:

   > _"Add a weekly resiliency review section to the runbook."_
   > _"Include escalation procedures for P1 incidents."_

3. Ask for a summary of all agents used:

   > _"Summarize which Azure Copilot capabilities I used today and how they helped manage my cloud environment."_

**Checkpoint:**

- [ ] Operational runbook created
- [ ] All five agents used in the workflow
- [ ] End-to-end scenario completed

## Success criteria

- **Phase 1:** Infrastructure plan generated and Terraform reviewed
- **Phase 2:** Monitoring strategy defined and investigation workflow understood
- **Phase 3:** Cost optimization opportunities identified with scripts
- **Phase 4:** Resiliency gaps addressed and DR plan created
- **Phase 5:** Incident diagnosed and remediation steps followed
- **Phase 6:** Operational runbook assembled

## Learning resources

- **Agent Orchestration is Seamless** — Azure Copilot automatically routes your request to the right agent. You don't need to select agents manually.
- **Agents Complement Each Other** — The Deployment Agent creates infrastructure; the Resiliency Agent hardens it; the Optimization Agent right-sizes it; the Observability Agent monitors it; the Troubleshooting Agent fixes it.
- **Real-World Workflow** — The lifecycle of a cloud workload naturally touches all five agents. Azure Copilot enables a single-pane-of-glass experience.
- **Human-in-the-Loop** — All agents provide recommendations and plans, but you confirm every action. No changes are made without your approval.
- **Continuous Improvement** — Use the agents regularly, not just at deployment. Regular optimization, resiliency reviews, and observability checks keep your environment healthy.
- [Azure Copilot overview](https://learn.microsoft.com/en-us/azure/copilot/overview)

**Agent Orchestration Summary:**

| Phase      | Primary Agent         | What It Did                               |
| ---------- | --------------------- | ----------------------------------------- |
| Deployment | Deployment Agent      | Planned architecture, generated Terraform |
| Monitoring | Observability Agent   | Investigated alerts, created issues       |
| Cost       | Optimization Agent    | Identified savings, generated scripts     |
| Resiliency | Resiliency Agent      | Assessed gaps, configured backup/DR       |
| Incident   | Troubleshooting Agent | Diagnosed issues, offered fixes           |
| Runbook    | All Agents            | Compiled operational knowledge            |

**Congratulations!** You've completed the Azure Copilot Demo Workshop. You now have hands-on experience with:

- Azure Copilot core capabilities
- All five specialized agents (preview)
- End-to-end cloud operations workflow
- Best practices for effective AI-assisted cloud management

## Solution

> [!TIP]
> We encourage you to try solving the challenge on your own before looking at the solution. This will help you learn and understand the concepts better.

<details>
<summary>Click here to view the solution</summary>

[Solution for Challenge 7](../walkthrough/solution-07.md)

</details>
