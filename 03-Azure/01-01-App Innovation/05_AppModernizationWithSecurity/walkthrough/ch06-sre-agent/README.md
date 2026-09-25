# Challenge 6 solution: reviewed SRE Agent recovery

There are several valid ways to complete this challenge. This version uses the Azure Portal, KQL, and GitHub Copilot prompts. The point is simple: let Azure SRE Agent correlate signals quickly, but keep production-changing action behind human approval.

## Before you start

- Your catalog app runs in Azure Container Apps with a managed database.
- Challenge 4 telemetry is active in Application Insights and Log Analytics.
- Container Apps multiple revisions are enabled, as in [Challenge 3](../../challenges/ch03.md).
- You can configure Azure SRE Agent, or a facilitator can configure it while you drive the investigation.

| | .NET / SQL Server | Java / PostgreSQL |
| --- | --- | --- |
| App folder | [`dotnet/`](../../dotnet/README.md) | [`java/`](../../java/README.md) |
| Database | Azure SQL Database | Azure Database for PostgreSQL Flexible Server |
| Failure clue | SQL dependency failures | JDBC/PostgreSQL dependency failures |
| Healthy state | database is Online | server is Ready |

## Step 1: Create the agent and scope

Create an **Azure SRE Agent** resource in the Azure Portal. Use a managed identity and start
with **Review** mode. Review mode lets the agent propose Azure infrastructure actions, but
an SRE Agent Administrator must approve them before execution.

Give the agent access to the resource group that contains the Container App, database,
Application Insights, and Log Analytics workspace. Start with read-first roles:

- Reader
- Log Analytics Reader
- Monitoring Reader
- Monitoring Contributor if the agent will manage alert lifecycle state

If you want the approved remediation to be executed by the agent, add only the narrow
Container Apps permission needed for revision traffic on the catalog app or its resource
group. Avoid broad Owner or Contributor assignments for a drill.

## Step 2: Connect telemetry

In the SRE Agent resource, open **Builder** and add Azure Monitor as the incident source, the Log Analytics workspace used by Application Insights, and resource visibility for the Container App and selected database.

Test the connection by asking:

```text
List recent failed requests, exceptions, and failed dependencies for my catalog app.
Show the KQL you ran and the workspace you queried.
```

Fix workspace permissions before continuing if the agent cannot query logs.

## Step 3: Create the catalog investigator

Create a custom agent, or update the default agent instructions:

```text
You are the SRE investigator for the LEGO catalog app.
Correlate Container Apps revisions, request failures, exceptions, dependency failures,
database health, and recent deployment changes.
Show the KQL or portal observation behind each claim.
Compare database platform outage, app image regression, and revision configuration failure.
In Review mode, propose only the smallest reversible remediation and do not execute writes
until an SRE Agent Administrator approves them.
```

Create an incident response plan in **Builder → Incident response plans**:

- Source: Azure Monitor.
- Severity: the severity your catalog alert uses.
- Title contains: a catalog-specific word if needed.
- Response custom agent: the catalog investigator.
- Agent autonomy level: **Review**.

If another plan also matches the same alert, turn it off or narrow its filter.

## Step 4: Create a safe incident

Use one reversible fault. The wrong-host revision is usually best because it does not touch
real data.

| Fault | Create it | Recover by |
| --- | --- | --- |
| Wrong database host | New revision with `CATALOG_DATABASE_HOST=bad-host.invalid` | Route traffic back |
| Bad credential | New revision with a bad database secret/value | Restore the previous value or revision |
| Stopped database | Stop the PostgreSQL server, or disconnect/pause if your database supports it | Start it again |

You can do this in the portal, or ask Copilot for stack-specific commands:

```text
Generate Azure CLI commands to create a new Azure Container Apps revision for my catalog
app with the same image and settings as the current revision, except set
CATALOG_DATABASE_HOST to bad-host.invalid. Put the app in multiple revision mode, route
100 percent of traffic to the bad revision, then show the command to route 100 percent
back to the previous healthy revision. Do not change secrets, image, scale, or ingress.
```

Browse the catalog after routing traffic to the bad revision. Wait until the alert fires or
until you can see failures in Application Insights.

## Step 5: Drive the investigation

Open the incident thread and make the agent prove scope first:

```text
Scope this incident. Identify the Container App, active revision, previous healthy
revision, time window, failed request count, and current traffic split. Show the KQL or
portal source for each value.
```

Then ask for correlation:

```text
Correlate failed requests, exceptions, failed database dependencies, Container Apps
revision history, and live database health for the same time window. Separate signals from
Application Insights, Azure Resource Manager, and the database resource.
```

Run these one at a time in Logs to verify the agent's claims:

```kusto
requests
| where timestamp > ago(30m) and success == false
| summarize failedRequests=count() by cloud_RoleName, operation_Name
dependencies
| where timestamp > ago(30m) and success == false
| summarize failedDependencies=count() by type, target, resultCode
exceptions
| where timestamp > ago(30m)
| summarize exceptions=count() by type, outerMessage
```

Check database health in the portal. A healthy database plus failed dependencies from only
the bad revision points to revision configuration, not a platform outage.

## Step 6: Challenge the answer

Ask the agent to argue against its first explanation:

```text
State the most likely root cause, then challenge it. What signals would support a
database platform outage? What signals would support an application image regression?
What signals do we actually have? Do not propose remediation until both alternatives are
addressed.
```

A good answer should show:

- the bad revision receives traffic;
- failures start when that revision receives traffic;
- database dependencies fail against the wrong host or bad authentication;
- the selected database resource is healthy;
- the previous revision, or the same image with previous configuration, still works.

Deny any proposal that skips these observations.

## Step 7: Review and approve remediation

Now ask for the smallest safe fix:

```text
Propose the smallest safe remediation. Prefer routing traffic back to the last healthy
Container Apps revision. Show the target resource, before and after traffic weights, blast
radius, verification steps, and whether any secret, image, scale, ingress, or role
assignment would change. Do not execute until approved.
```

For the wrong-host drill, the proposal should be only:

```text
healthy revision: 100 percent traffic
bad revision: 0 percent traffic
```

Only an SRE Agent Administrator approves the write. If you are not that person, hand the
proposal to the facilitator. The approval gate is part of the lesson.

## Step 8: Verify recovery

After approval, check traffic and health:

```bash
az containerapp revision list \
  --resource-group <resource-group> \
  --name <container-app-name> \
  --query "[].{name:name,active:properties.active,traffic:properties.trafficWeight}" \
  --output table

curl -i https://<your-app-url>/healthz
curl -i https://<your-app-url>/readyz
```

Confirm the Azure Monitor alert resolves. It can take a few minutes after the app is
healthy. Record when the alert fired, when the agent investigated, when approval happened,
when the alert resolved, and what prevention you would add next.

A good prevention is a pre-traffic smoke test that calls `/readyz` on a new revision before
assigning production traffic.

## If it goes wrong

| Symptom | Likely cause | Fix |
| --- | --- | --- |
| Agent cannot query logs | Missing workspace role | Add Log Analytics Reader on the workspace or resource group |
| Incident opens twice | Two plans match | Turn off or narrow one plan |
| Agent wants to restart or redeploy everything | Prompt is too broad | Ask for the smallest reversible traffic change |
| Database outage and bad revision look identical | You only checked requests | Add dependencies, revision history, and database health |
| Alert remains fired | Monitor has not re-evaluated | Wait for the next evaluation cycle |

## What you proved

Azure SRE Agent can gather the same signals an on-call engineer would collect by hand:
requests, exceptions, dependencies, revisions, database health, and alert state. More
importantly, the production write stayed behind a human approval gate.

That is the model to take home: fast machine investigation, narrow proposed action, human
accountability for remediation.

---

**Challenge:** [ch06-sre-agent](../../challenges/ch06-sre-agent.md) · **Previous:** [ch05-defender](../ch05-defender/README.md) · **Next:** [ch07-enterprise](../../challenges/ch07-enterprise.md)
