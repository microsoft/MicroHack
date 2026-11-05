# Challenge 7 - Operate the migrated workloads with intelligent observability

[Previous Challenge](challenge-06.md) - **[Home](../Readme.md)** - [Next Challenge](challenge-08.md)

Duration: 90 minutes (allow extra time for first-time agent installation and ingestion)

## Goal

Operate both migrated web workloads through a closed-loop incident exercise. Enable modern OpenTelemetry monitoring, create an alert from the authoritative signal for each workload, induce controlled service failures, investigate the fired alerts with Azure Copilot Observability Agent, restore service under human control, and prove recovery.

## Before you start: understand the agents

Azure Copilot Observability Agent has **two operating models**. Azure SRE Agent is a **separate service**, not a third mode or SKU of Observability Agent.

### Two models for Azure Copilot Observability Agent

| Aspect | On-demand chat and deep investigations | Deployed Observability Agent resource (preview) |
| --- | --- | --- |
| Setup | No agent resource to create. Start from an Azure Monitor alert's **Investigate** action or a supported chat entry point. | Create a `Microsoft.Monitor/observabilityAgents` resource with durable scope and configuration. |
| Identity | Uses the signed-in user's Azure permissions. | Uses the resource's managed identity for autonomous runs. |
| Behavior | Investigates when a user asks; correlates telemetry and recommends next steps. | Can run opted-in background alert correlation, issue creation, and investigations, with persistent custom instructions. |
| VM investigations | Deep investigations support virtual machines, subject to preview availability and telemetry access. | New VM-only scope is **not a supported configuration** in the current preview; the resource currently targets Application Insights. |
| Used in this Hack? | **Yes, in Task 5.** | **No. Do not deploy this resource for Challenge 7.** |

Microsoft notes that existing legacy VM scopes on deployed Observability Agent resources aren't blocked, but aren't a tested path. That exception is not a supported basis for a new VM-only lab deployment.

In **both** Observability Agent models, investigation and recommendations do not mean automatic remediation. Even with autonomous operations enabled, the agent does not restart services, change workload configuration, or resolve the incident on its own. Humans decide and execute recovery.

### How Azure SRE Agent differs

**Azure SRE Agent** is a broader operations teammate. It connects Azure resources, observability data, incident-management tools, source repositories, and runbooks to investigate incidents and automate operational workflows.

Unlike Observability Agent's recommendation-and-handoff model, SRE Agent can **execute permitted mitigations** using configured tools and access. Its permissions and approval controls are separate: in **Review** mode, Azure infrastructure write actions require approval; **Autonomous** mode can execute permitted actions without waiting for per-action approval. RBAC, tool policies, and configured access still constrain what it can do. Autonomous mode does not grant extra permissions or bypass governance.

SRE Agent requires its own setup, access configuration, and cost review. **It is not deployed or required in this Hack.** Using SRE Agent for VM operations would be a separate exercise with its own scoped permissions, tools, and approval design; it does not change the Observability Agent resource's preview limitations.

### What you will use in Challenge 7

Tasks 2-4 prepare telemetry and alerts. Task 5 invokes the **on-demand Observability Agent** from the fired alerts. Task 6 is **human-executed recovery**. If preview access is unavailable, the manual fallback still exercises monitoring and incident analysis, but **does not demonstrate the Observability Agent**.

Do not confuse these AI services with **Azure Monitor Agent (AMA)**, which runs on the VMs to collect telemetry. Likewise, `id-mh-monitor-alerts` authorizes alert queries; it is not an Observability Agent resource or the identity used by on-demand investigations.

## Workloads and authoritative signals

| Workload | Service | Authoritative alert signal |
| --- | --- | --- |
| Windows Server / IIS | `W3SVC` | Windows System event ID 7036 in Log Analytics |
| Ubuntu Linux / Apache | `apache2` | Absence of all matching `process.uptime` OpenTelemetry series |

The Linux alert monitors every process whose `"process.executable.name"` is `apache2`. It becomes true only when all matching Apache worker and parent process series are absent for the configured window. The Windows alert intentionally uses the Service Control Manager event instead of `w3wp.exe`; IIS application-pool idle shutdown can stop a worker process while the web service remains healthy.

The Windows rule detects a service-state transition, not continuous availability: its stopped event can age out and the alert can resolve even while IIS remains stopped. The Apache absence rule can also indicate a VM/telemetry failure. Prove service recovery using service state, local HTTP `200`, and telemetry, not alert status alone.

## Prerequisites and access assumptions

* Challenge 5 is complete and both migrated web VMs in `<YOUR-LAB-RESOURCE-GROUP>` are running.
* You can connect to both VMs through Azure Bastion and each site responds locally.
* Your learner account has **Owner on the Hack subscription**, not just subscription Reader. This allows provider registration and resource/RBAC creation; it also grants access to other learners' RGs, so work only in your assigned lab group.
* Before opening **Infrastructure monitoring**, create or reuse one user-assigned managed identity in the lab resource group for both migrated VMs. The [walkthrough](../walkthrough/challenge-07/solution-07.md#option-a-create-the-monitoring-foundation-with-code) includes creation commands and a small Bicep template.
* Grant that identity **Monitoring Reader** on the lab resource group for the migrated VMs and monitoring workspace. Do not grant the alert identity a subscription-scoped role.
* This user-assigned identity authorizes OpenTelemetry query-based and recommended alerts. It is separate from the VM's system-assigned identity used by Azure Monitor Agent; the portal doesn't automatically create the user-assigned alert identity.
* For the AI-assisted path, confirm Azure Copilot access, preview region availability, telemetry permissions, and instructor-approved credits. Use the manual investigation fallback if unavailable. No Azure OpenAI resource, model deployment, or model quota is required.
* The client network allows WebSocket connections to `https://directline.botframework.com`.

> [!IMPORTANT]
> Azure Copilot Observability Agent, deep investigations, Azure Monitor issues, and query-based metric alerts include preview experiences whose portal labels and availability can vary by region and tenant. A deep investigation can consume Azure Agent Credits. Follow your instructor's lab access and cost guidance.

> [!NOTE]
> The lab defaults to `swedencentral`, which is not listed on the current [Observability Agent regions page](https://learn.microsoft.com/azure/azure-monitor/aiops/observability-agent-overview#regions). Do not assume preview access or move the lab to work around it. Confirm availability with the instructor; use the walkthrough's manual investigation fallback when unavailable. Query-based metric alerts have a separate supported-region list.

## Monitoring models

| | OpenTelemetry metrics-based | Classic logs-based |
| --- | --- | --- |
| Store | Azure Monitor workspace | Log Analytics workspace |
| Query language | PromQL | KQL |
| Typical latency | Near real-time | 1-3 minutes |
| Cost model | Default metrics are free; added metrics can incur cost | Log ingestion and retention charges |
| Strength | Consistent Windows/Linux schema and low-latency metrics | Multi-VM views and same-workspace metric/log correlation |
| Limitation | Separate queries are required to correlate with logs; built-in multi-VM views are limited | Platform-specific counters and higher ingestion cost |

Enable metrics-based OpenTelemetry monitoring for both VMs. Collect the Windows `W3SVC` event through a separate Windows Event DCR into Log Analytics; classic performance collection is not required.

## Actions

* Warm and validate both web pages before changing either service.
* Create the monitoring foundation using the walkthrough's code or portal path: an Azure Monitor workspace, Log Analytics workspace, alert identity, RG-scoped Monitoring Reader assignment, email action group, and Windows event DCR/association.
* Select the pre-created identity for query-based alert rules and, when offered, recommended-alert setup. This is alert authorization, not a setting in the metrics/DCR customization pane.
* Enable **Use resource or workspace permissions** on the Azure Monitor workspace so VM-resource-scoped PromQL works. Verify the selected VM scope before running queries.
* Keep all user-controlled workspaces, identities, DCRs, alert rules, and action groups in the lab resource group. Verify the proposed scope before enabling monitoring; do not accept resources in another user-controlled group.
* Enable default OpenTelemetry metrics on both VMs, per-process metrics on Linux, and recommended infrastructure alerts; use the built-in Grafana dashboards without creating Azure Managed Grafana.
* Confirm query-based and recommended alerts use the pre-created identity and that it retains the required monitoring read access.
* Locate the Linux VM's generated `MSVMOtel-<region>-<name>` DCR and ensure that `process.uptime` is collected.
* Send Windows events to the Log Analytics workspace through the focused Event DCR. Classic log-based performance collection is optional, not a prerequisite for collecting these events.
* Create an Apache PromQL absence alert and an IIS KQL scheduled-query alert.
* Stop Apache and IIS in a controlled manner, prove local HTTP failure, and wait for both alerts.
* Where preview access and credits are available, start a deep investigation from each fired alert and save useful context as an Azure Monitor issue. Otherwise use the manual fallback; in either path, evaluate evidence and ruled-out hypotheses.
* Restore both services manually, validate both pages and telemetry recovery, confirm alert resolution, and request a post-incident summary and runbook improvements.

## Success criteria

* Both VMs send default OpenTelemetry guest metrics to the explicitly selected Azure Monitor workspace in the lab resource group through their intended generated DCR associations.
* Linux `process.uptime` metrics include one or more `apache2` process series before the incident.
* Windows System event ID 7036 records for `W3SVC` are visible in the selected compatible Log Analytics workspace in the lab resource group.
* The Apache PromQL alert and IIS KQL alert are enabled, use the intended signals, and fire after the controlled failures.
* An inactive service and local HTTP failure prove user-visible impact on each VM; process or service telemetry alone isn't treated as a synthetic availability test.
* The AI-assisted or manual investigation distinguishes service failure from VM/platform failure and produces evidence-backed remediation with rollback and prevention guidance.
* A human restores `W3SVC` and `apache2`; both sites return HTTP `200`, service/process telemetry returns, and alerts resolve.
* Both recovered workloads are available for the path selection at the start of Challenge 8.

> [!NOTE]
> Azure Monitor automatically creates an `MA_<workspace-name>_<location>_managed` resource group for its workspace-managed DCR/DCE. This Azure-managed exception is not another learner-created lab group. Keep user-controlled monitoring resources in your assigned lab group; do not move or separately delete the service-managed internals.

## Learning resources

* [Metrics experience for virtual machines](https://learn.microsoft.com/azure/azure-monitor/vm/metrics-opentelemetry-guest)
* [Enable enhanced monitoring for an Azure VM](https://learn.microsoft.com/azure/azure-monitor/vm/tutorial-enable-monitoring)
* [Manage an Azure Monitor workspace](https://learn.microsoft.com/azure/azure-monitor/metrics/azure-monitor-workspace-manage)
* [Azure Monitor workspace access modes](https://learn.microsoft.com/azure/azure-monitor/metrics/azure-monitor-workspace-manage-access)
* [Enable VM monitoring with CLI, PowerShell, ARM, or Bicep](https://learn.microsoft.com/azure/azure-monitor/vm/vm-enable-monitoring)
* [Customize OpenTelemetry metrics for VMs](https://learn.microsoft.com/azure/azure-monitor/vm/metrics-opentelemetry-guest-modify)
* [OpenTelemetry guest OS metrics reference](https://learn.microsoft.com/azure/azure-monitor/vm/metrics-guest-reference)
* [PromQL for system and guest OS metrics](https://learn.microsoft.com/azure/azure-monitor/metrics/prometheus-system-metrics-best-practices)
* [Query-based metric alerts](https://learn.microsoft.com/azure/azure-monitor/alerts/alerts-query-based-metric-alerts-overview)
* [Create a user-assigned managed identity in the Azure portal](https://learn.microsoft.com/entra/identity/managed-identities-azure-resources/manage-user-assigned-managed-identities-azure-portal)
* [Assign Azure roles using the Azure portal](https://learn.microsoft.com/azure/role-based-access-control/role-assignments-portal)
* [Collect Windows events with Azure Monitor Agent](https://learn.microsoft.com/azure/azure-monitor/vm/data-collection-windows-events)
* [Create Azure Monitor log search alert rules](https://learn.microsoft.com/azure/azure-monitor/alerts/alerts-create-log-alert-rule)
* [Azure Copilot Observability Agent overview](https://learn.microsoft.com/azure/azure-monitor/aiops/observability-agent-overview)
* [Observability Agent resource: operating models and preview limitations](https://learn.microsoft.com/azure/azure-monitor/aiops/observability-agent-resource)
* [Deep investigations with Observability Agent](https://learn.microsoft.com/azure/azure-monitor/aiops/observability-agent-deep-investigations)
* [Azure SRE Agent overview](https://learn.microsoft.com/azure/sre-agent/overview)
* [Azure SRE Agent run modes and approval controls](https://learn.microsoft.com/azure/sre-agent/run-modes)
