# Challenge 7 - Operate the migrated workload with intelligent observability

[Previous Challenge](challenge-06.md) - **[Home](../Readme.md)** - [Next Challenge](challenge-08.md)

Duration: 40 minutes

## Goal

Operate one migrated web workload by combining Azure Monitor telemetry, an actionable alert, and an AI-assisted investigation. You will create a safe service-level incident, determine its scope, restore service, and prove recovery.

## Select one track

At the start of this challenge, select one track. Follow the same VM and track through Challenge 8. Teams do not need to complete both.

| Track | Migrated workload | Service | Incident telemetry |
| --- | --- | --- | --- |
| A | Windows Server / IIS | `W3SVC` | Windows System event ID 7036 in `Event` |
| B | Ubuntu Linux / Apache | `apache2` | Tagged `daemon.warning` record in `Syslog` |

## Prerequisites and preflight

* Challenge 5 is complete and the selected migrated web VM in `destination-rg` is running.
* The selected IIS or Apache site responds locally and through its existing endpoint.
* You can create or reuse a Log Analytics workspace, install VM extensions, create data collection rules (DCRs), create alert rules, and create or reuse an action group.
* Use a Log Analytics workspace in the same region as the selected VM for this lab.
* Confirm that the workspace region is listed in the current [Azure Copilot Observability Agent regions](https://learn.microsoft.com/en-us/azure/azure-monitor/aiops/observability-agent-overview#regions).
* In the Azure portal, confirm that you can open Azure Copilot and that **Observability Agent** appears on the Log Analytics workspace **Logs** page.
* If tenant access is restricted, an administrator must grant the **Copilot for Azure User** role. Your account must also be able to read the VM and its monitoring data; **Monitoring Reader** and **Log Analytics Reader** are suitable least-privilege starting points.
* The client network must allow WebSocket connections to `https://directline.botframework.com`.

> [!IMPORTANT]
> Azure Copilot availability is tenant-, user-, region-, and policy-dependent. No Azure OpenAI resource, model deployment, or model quota is required. If the preflight fails, complete the clearly labeled KQL and VM insights fallback. The monitoring, incident, remediation, and recovery outcomes remain the same.

> [!NOTE]
> On-demand chat and investigation do not require an Azure Copilot Observability Agent resource. Creating that preview resource is outside the required path.

## Actions

### Common actions

* Create or reuse a Log Analytics workspace.
* Enable enhanced monitoring/VM insights on the selected VM with Azure Monitor Agent.
* Verify heartbeat and performance telemetry.
* Create or reuse an action group and create an actionable log search alert.
* Use Azure Copilot Observability Agent chat, or the KQL/VM insights fallback, to distinguish a service outage from a VM outage.
* Restore the selected service and verify local, external, and telemetry recovery.
* Decide which lab monitoring resources should remain after the MicroHack.

### Track A - Windows Server / IIS

* Associate a Windows event DCR that collects System event ID 7036.
* Alert on `W3SVC` stopping, safely stop IIS, and prove the local outage.
* Investigate `Event`, `Heartbeat`, and `InsightsMetrics`, then restore `W3SVC`.

### Track B - Ubuntu Linux / Apache

* Associate a Linux Syslog DCR that collects the `daemon` facility at `Warning` or higher.
* Stop `apache2` and emit an explicit tagged Syslog event that records the controlled lab action.
* Alert on the exact tag/message, investigate `Syslog`, `Heartbeat`, and `InsightsMetrics`, then restore `apache2`.

> [!NOTE]
> The explicit Linux Syslog event makes lab ingestion deterministic without relying only on distribution-dependent systemd journal forwarding.

## Success criteria

* `AzureMonitorWindowsAgent` or `AzureMonitorLinuxAgent` is healthy and the VM has the intended DCR associations.
* `Heartbeat`, `InsightsMetrics`, and the selected track's `Event` or `Syslog` record are visible in the Log Analytics workspace.
* An enabled alert rule monitors the selected service-stop event and has an action group.
* The incident is proven by local HTTP failure, an inactive service, and the selected track's ingested event.
* The investigation shows whether the VM remained online and produces a safe service-level remediation.
* `W3SVC` or `apache2` is running again and the site responds successfully.

> [!NOTE]
> Log ingestion and alert evaluation are asynchronous. The walkthrough uses the ingested event query, not a notification arrival time, as the deterministic success gate. Alert notification delivery is still reviewed as an operational outcome.

## Optional stretch - autonomous operations (preview)

Only if your instructor has prepared the required resources and permissions, explore an [Azure Copilot Observability Agent resource](https://learn.microsoft.com/en-us/azure/azure-monitor/aiops/observability-agent-resource) for autonomous alert correlation, issue creation, and custom instructions. The resource, autonomous operations, Azure Monitor issues, and custom-instruction experience are preview capabilities. They are not required for this challenge.

## Learning resources

* [Azure Copilot Observability Agent overview](https://learn.microsoft.com/en-us/azure/azure-monitor/aiops/observability-agent-overview)
* [Chat with observability data](https://learn.microsoft.com/en-us/azure/azure-monitor/aiops/observability-agent-chat)
* [Manage access to Azure Copilot](https://learn.microsoft.com/en-us/azure/copilot/manage-access)
* [Enable VM monitoring in Azure Monitor](https://learn.microsoft.com/en-us/azure/azure-monitor/vm/vm-enable-monitoring)
* [Install and manage Azure Monitor Agent](https://learn.microsoft.com/en-us/azure/azure-monitor/agents/azure-monitor-agent-manage)
* [Collect Windows events with Azure Monitor Agent](https://learn.microsoft.com/en-us/azure/azure-monitor/vm/data-collection-windows-events)
* [Collect Syslog events with Azure Monitor Agent](https://learn.microsoft.com/en-us/azure/azure-monitor/vm/data-collection-syslog)
* [Create Azure Monitor log search alert rules](https://learn.microsoft.com/en-us/azure/azure-monitor/alerts/alerts-create-log-alert-rule)
