# Walkthrough Challenge 5 - Monitor with the Azure SRE Agent

**[Home](../../Readme.md)** - [Previous Challenge Solution](../challenge-04/solution-04.md) - [Next Challenge Solution](../challenge-06/solution-06.md)

Duration: 30 minutes

## Prerequisites

Complete [Challenge 4](../challenge-04/solution-04.md) — you need a **reachable deployment**. No deploy? Pair with another team or use a shared reference environment so you can still practise the loop. Confirm the **Azure SRE Agent** is available in your region/subscription and accessible to you.

## Approach

Move from build to operate. The learning is in the **detect → diagnose → remediate** loop — get the agent connected fast so there's time to actually reach the diagnosis step.

Suggested pacing:

```
Enable/confirm observability             ~7 min
Connect the SRE Agent                    ~7 min
Simulate a fault                         ~5 min
Investigate with the agent               ~7 min
Remediate + confirm healthy              ~4 min
```

### Task 1: Enable/confirm observability

- Confirm the deployed app emits logs, metrics, and health/readiness signals. If it lacks health/readiness endpoints, add them and confirm logging/metrics are enabled on the Azure resources.

### Task 2: Connect the SRE Agent

- Connect the Azure SRE Agent to the **correct deployed resources / resource group** so it can observe application health and report status. Permissions errors usually mean the agent needs extra roles on the monitored resources.

### Task 3: Simulate a clear fault

- 💡 Pick a fault that clearly affects health — a **failing dependency** (e.g. break a connection string) or a **bad deploy** — rather than a subtle one that won't surface.

### Task 4: Investigate with the agent

- 🔑 Let the **agent** surface and diagnose the issue and suggest remediation — the goal is agent-assisted diagnosis, not you spotting it manually. Capture **what the agent surfaced vs. what you had to investigate yourself**.

### Task 5: Remediate and confirm

- Apply the fix and confirm the agent reports healthy again. Note reliability gaps as backlog items — a natural feed into Challenge 6.

> No optional stretch. Fast finishers should document agent-caught vs. manually-investigated findings and turn reliability gaps into backlog items.

You successfully completed challenge 5! 🚀🚀🚀
