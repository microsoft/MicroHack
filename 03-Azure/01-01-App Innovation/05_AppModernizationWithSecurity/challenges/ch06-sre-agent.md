# Let Azure SRE Agent diagnose an incident

## Goal

Use Azure SRE Agent to investigate a real failure in your modernized catalog app, then
keep the human in control of the fix.

By now your app runs in Azure Container Apps with a managed database and telemetry from
Challenge 4. In this challenge you connect an agent to that telemetry, break the app in a
small and reversible way, and ask the agent to explain what happened before anyone
approves a remediation.

You chose one stack in [Challenge 0](ch00.md). Keep using that stack:

| | .NET / SQL Server | Java / PostgreSQL |
| --- | --- | --- |
| App source | `dotnet/` | `java/` |
| Database | Azure SQL Database | Azure Database for PostgreSQL Flexible Server |
| Local port | `5000` | `8080` |
| Expected database signal | SQL client dependency failures | JDBC/PostgreSQL dependency failures |

## Actions

- Create or open an Azure SRE Agent and give it read access to the resource group that
  contains your Container App, database, Application Insights, and Log Analytics workspace.
- Connect Azure Monitor / Log Analytics telemetry so the agent can query requests,
  exceptions, dependencies, metrics, and resource health.
- Create an incident response plan for your catalog alert and set the autonomy level to
  **Review**, not autonomous execution.
- Break the app safely: for example, route traffic to a new Container Apps revision with a
  wrong database host, bad database credential, or temporarily stopped database.
- Ask the agent to scope the incident, identify the failing revision, compare app and
  database signals, and reject at least two alternative explanations.
- Review the proposed remediation. A human with SRE Agent Administrator rights must approve
  any write; the agent should not change production on its own.
- Verify recovery in the portal and with health checks after the fix.

## Success Criteria

- The agent finds the failure from telemetry and can show the relevant KQL or portal
  observations.
- The diagnosis distinguishes application revision failure from database platform outage.
- The proposed fix is narrow, reversible, and reviewed before execution.
- The catalog works again, `/healthz` and `/readyz` return healthy responses, and the alert
  resolves.
- You can explain what you would automate next and what you would still require a human to
  approve.

## Solution — spoiler warning

[Solution Steps](../walkthrough/ch06-sre-agent/README.md)

---

**Challenge:** [ch06-sre-agent](ch06-sre-agent.md) · **Previous:** [ch05-defender](ch05-defender.md) · **Next:** [ch07-enterprise](ch07-enterprise.md)
