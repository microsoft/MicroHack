# Challenge 6 - Monitor the deployed app with the Azure SRE Agent

**[Home](../Readme.md)** - [Previous Challenge](challenge-05.md) - [Next Challenge](challenge-07.md)

## Goal

Use agents to monitor the deployed Octocat Supply application and improve its reliability, leveraging the **Azure SRE Agent**. Now that the app is deployed, the team wants agentic monitoring — detect, diagnose, and help remediate issues.

> This challenge depends on a reachable deployment from Challenge 5. If your team doesn't have one, pair with another team or use a shared reference deployment so you can still practise the loop.

## Actions

* **Enable observability** — Confirm the deployed app emits the telemetry needed for monitoring (logs, metrics, health checks). Add health/readiness endpoints if it doesn't already expose them.
* **Set up the SRE Agent** — Connect the Azure SRE Agent to the deployed resources so it can observe application health.
* **Simulate an issue** — Introduce or trigger a fault (e.g. a failing dependency or a bad deploy) that clearly affects health.
* **Investigate with the agent** — Use the SRE Agent to identify root cause and suggest remediation.
* **Remediate** — Apply the fix and confirm the agent reports healthy status.

## Success criteria

* The deployed application emits usable telemetry for monitoring.
* The Azure SRE Agent is monitoring the application.
* An induced issue is detected and diagnosed with agent assistance (not just noticed manually).
* The issue is remediated and health is restored.

> Capture **what the agent surfaced vs. what you had to investigate manually**, and note reliability improvements to feed back into the backlog.

## Learning resources

* [Azure SRE Agent documentation](https://learn.microsoft.com/en-us/azure/sre-agent/)
* [Azure Monitor overview](https://learn.microsoft.com/en-us/azure/azure-monitor/overview)
* [Health probes in Azure Container Apps](https://learn.microsoft.com/en-us/azure/container-apps/health-probes)
