# Challenge 7 - Operate the migrated workloads with intelligent observability

[Previous Challenge](challenge-06.md) - **[Home](../Readme.md)** - [Next Challenge](challenge-08.md)

Duration: 70 minutes

## Goal

Operate both migrated web workloads through a closed-loop incident exercise. Enable modern OpenTelemetry monitoring, create an alert from the authoritative signal for each workload, induce controlled service failures, investigate the fired alerts with Azure Copilot Observability Agent, restore service under human control, and prove recovery.

## Workloads and authoritative signals

| Workload | Service | Authoritative alert signal |
| --- | --- | --- |
| Windows Server / IIS | `W3SVC` | Windows System event ID 7036 in Log Analytics |
| Ubuntu Linux / Apache | `apache2` | Absence of all matching `process.uptime` OpenTelemetry series |

The Linux alert monitors every process whose `"process.executable.name"` is `apache2`. It becomes true only when all matching Apache worker and parent process series are absent for the configured window. The Windows alert intentionally uses the Service Control Manager event instead of `w3wp.exe`; IIS application-pool idle shutdown can stop a worker process while the web service remains healthy.

## Prerequisites and access assumptions

* Challenge 5 is complete and both migrated web VMs in `destination-rg` are running.
* You can connect to both VMs through Azure Bastion and each site responds locally.
* You can enable VM monitoring, use the portal-selected regional workspaces, create or edit DCRs and alerts, create or reuse an action group, and assign the alert identity **Monitoring Reader**.
* Azure Copilot access, a supported region, and the required telemetry permissions are available to Hack participants. No Azure OpenAI resource, model deployment, or model quota is required.
* The client network allows WebSocket connections to `https://directline.botframework.com`.

> [!IMPORTANT]
> Azure Copilot Observability Agent, deep investigations, Azure Monitor issues, and query-based metric alerts include preview experiences whose portal labels and availability can vary by region and tenant. A deep investigation can consume Azure Agent Credits. Follow your instructor's lab access and cost guidance.

> [!NOTE]
> On-demand chat and deep investigations use the signed-in user's identity and require no `Microsoft.Monitor/observabilityAgents` resource. Do not provision an autonomous Observability Agent resource for this VM-only Hack. The portal preview scopes that resource to Application Insights, and virtual-machine scope isn't a supported new configuration.

## Monitoring models

| | OpenTelemetry metrics-based | Classic logs-based |
| --- | --- | --- |
| Store | Azure Monitor workspace | Log Analytics workspace |
| Query language | PromQL | KQL |
| Typical latency | Near real-time | 1-3 minutes |
| Cost model | Default metrics are free; added metrics can incur cost | Log ingestion and retention charges |
| Strength | Consistent Windows/Linux schema and low-latency metrics | Multi-VM views and same-workspace metric/log correlation |
| Limitation | Separate queries are required to correlate with logs; built-in multi-VM views are limited | Platform-specific counters and higher ingestion cost |

Enable metrics-based OpenTelemetry monitoring for both VMs. Use classic log collection only on Windows where the authoritative `W3SVC` service event must be delivered to Log Analytics.

## Actions

* Warm and validate both web pages before changing either service.
* Let Infrastructure monitoring select or create the regional default Azure Monitor workspace and generated OpenTelemetry DCR; do not pre-create a custom workspace.
* Enable OpenTelemetry metrics, per-process metrics, built-in Grafana dashboards, and recommended infrastructure alerts.
* Select a managed identity for query-based metric alerts and verify its monitoring read access.
* Locate the Linux VM's generated `MSVMOtel-<region>-<name>` DCR and ensure that `process.uptime` is collected.
* Reuse the portal-selected compatible Log Analytics workspace for Windows events and associate a focused Event DCR.
* Create an Apache PromQL absence alert and an IIS KQL scheduled-query alert.
* Stop Apache and IIS in a controlled manner, prove local HTTP failure, and wait for both alerts.
* Start a deep investigation from each fired alert, evaluate evidence and ruled-out hypotheses, and save useful context as an Azure Monitor issue when available.
* Restore both services manually, validate both pages and telemetry recovery, confirm alert resolution, and request a post-incident summary and runbook improvements.

## Success criteria

* Both VMs send default OpenTelemetry guest metrics to the portal-selected Azure Monitor workspace through their intended generated DCR associations.
* Linux `process.uptime` metrics include one or more `apache2` process series before the incident.
* Windows System event ID 7036 records for `W3SVC` are visible in the portal-selected Log Analytics workspace.
* The Apache PromQL alert and IIS KQL alert are enabled, use the intended signals, and fire after the controlled failures.
* An inactive service and local HTTP failure prove user-visible impact on each VM; process or service telemetry alone isn't treated as a synthetic availability test.
* The AI-assisted or manual investigation distinguishes service failure from VM/platform failure and produces evidence-backed remediation with rollback and prevention guidance.
* A human restores `W3SVC` and `apache2`; both sites return HTTP `200`, service/process telemetry returns, and alerts resolve.
* One recovered workload is selected for Challenge 8.

## Learning resources

* [Metrics experience for virtual machines](https://learn.microsoft.com/azure/azure-monitor/vm/metrics-opentelemetry-guest)
* [Enable enhanced monitoring for an Azure VM](https://learn.microsoft.com/azure/azure-monitor/vm/tutorial-enable-monitoring)
* [Customize OpenTelemetry metrics for VMs](https://learn.microsoft.com/azure/azure-monitor/vm/metrics-opentelemetry-guest-modify)
* [OpenTelemetry guest OS metrics reference](https://learn.microsoft.com/azure/azure-monitor/vm/metrics-guest-reference)
* [PromQL for system and guest OS metrics](https://learn.microsoft.com/azure/azure-monitor/metrics/prometheus-system-metrics-best-practices)
* [Query-based metric alerts](https://learn.microsoft.com/azure/azure-monitor/alerts/alerts-query-based-metric-alerts-overview)
* [Collect Windows events with Azure Monitor Agent](https://learn.microsoft.com/azure/azure-monitor/vm/data-collection-windows-events)
* [Create Azure Monitor log search alert rules](https://learn.microsoft.com/azure/azure-monitor/alerts/alerts-create-log-alert-rule)
* [Azure Copilot Observability Agent overview](https://learn.microsoft.com/azure/azure-monitor/aiops/observability-agent-overview)
* [Deep investigations with Observability Agent](https://learn.microsoft.com/azure/azure-monitor/aiops/observability-agent-deep-investigations)
