# Walkthrough Challenge 7 - Operate the migrated workload with intelligent observability

[Previous Challenge Solution](../challenge-06/solution-06.md) - **[Home](../../Readme.md)** - [Next Challenge Solution](../challenge-08/solution-08.md)

Duration: 40 minutes

## Task 1: Select a track and complete the preflight (5 minutes)

Select one migrated VM in `destination-rg` and follow the same track through Challenges 7 and 8:

| Track | VM | Web service | Service-event table |
| --- | --- | --- | --- |
| A | Windows Server | IIS `W3SVC` | `Event` |
| B | Ubuntu Linux | Apache `apache2` | `Syslog` |

Record the VM name and region. Connect with Azure Bastion and verify the selected service and local website.

### Track A - Windows

Run in Windows PowerShell as administrator:

```powershell
Get-Service -Name W3SVC
(Invoke-WebRequest -Uri 'http://localhost/' -UseBasicParsing -TimeoutSec 10).StatusCode
```

The service must be `Running` and HTTP must return `200`.

### Track B - Linux

Run in Bash:

```bash
sudo systemctl is-active apache2
curl --fail --silent --show-error --output /dev/null \
  --write-out 'HTTP %{http_code}\n' http://localhost/
```

The service must be `active` and HTTP must return `200`.

### Common Azure Copilot preflight

1. In the portal, select **Copilot**. If an unauthorized message appears, ask a tenant administrator to follow [Manage access to Azure Copilot](https://learn.microsoft.com/en-us/azure/copilot/manage-access). In a restricted tenant, the user or a group containing the user needs the **Copilot for Azure User** role.
2. Confirm the client network allows WebSocket connections to `https://directline.botframework.com`.
3. Open the [Observability Agent overview](https://learn.microsoft.com/en-us/azure/azure-monitor/aiops/observability-agent-overview#regions) and confirm that the intended Log Analytics workspace region is supported.
4. Confirm your signed-in account can read the VM and its monitoring data and create the required monitoring resources. The MicroHack's Contributor or Owner prerequisite is sufficient. For least privilege, review **Monitoring Reader**, **Log Analytics Reader**, and the specific write roles required for DCRs and alerts.

> [!IMPORTANT]
> If Azure Copilot, the **Observability Agent** button, the selected region, or tenant access is unavailable, continue with Tasks 2 through 4 and use the fallback in Task 5. Do not provision an Azure OpenAI resource or model. Do not create an Observability Agent resource for the required path.

## Task 2: Enable monitoring and collect the selected service event (10 minutes)

### Common workspace and VM insights setup

1. Search for **Log Analytics workspaces** in the Azure portal.
2. Reuse a workspace in the selected VM's region, or create one in `destination-rg` with a unique name such as `law-mh-migration-<suffix>`.
3. Open the selected VM and go to **Monitoring** > **Insights**. Select **Enable**, **Configure**, or **Configure monitoring**, depending on the current portal blade.
4. Select the Log Analytics workspace and enable the logs-based VM insights metrics option so performance data is available in `InsightsMetrics`.
5. Apply the configuration.
6. On the VM, open **Extensions + applications** and confirm the selected track's extension is provisioned successfully:
   * Track A: `AzureMonitorWindowsAgent`
   * Track B: `AzureMonitorLinuxAgent`
7. Open **Monitor** > **Data Collection Rules** and confirm that the VM insights DCR is associated with the selected VM.

> [!NOTE]
> Azure Monitor supports associating multiple DCRs with one Azure Monitor Agent. Keep the VM insights DCR and add the selected track's focused event DCR.

### Track A - Create the Windows service-event DCR

1. In **Monitor** > **Data Collection Rules**, select **Create**.
2. Use rule name `dcr-iis-service-events`, resource group `destination-rg`, the VM's region, and platform type **Windows**.
3. On **Resources**, add the selected VM. Leave **Enable Data Collection Endpoints** off unless your network design requires a DCE.
4. On **Collect and deliver**, select **Add data source** > **Windows Event Logs**.
5. Select **Custom** and enter:

   ```text
   System!*[System[(EventID=7036)]]
   ```

6. Add a destination of **Azure Monitor Logs**, select the Log Analytics workspace, and create the DCR.
7. Return to the DCR **Resources** page and verify the VM association.

### Track B - Create the Linux Syslog DCR

1. In **Monitor** > **Data Collection Rules**, select **Create**.
2. Use rule name `dcr-apache-incident-syslog`, resource group `destination-rg`, the VM's region, and platform type **Linux**.
3. On **Resources**, add the selected VM. Leave **Enable Data Collection Endpoints** off unless your network design requires a DCE.
4. On **Collect and deliver**, select **Add data source** > **Linux Syslog**.
5. Set the `daemon` facility to minimum log level **Warning**. Set all other facilities to **NONE**.
6. Add a destination of **Azure Monitor Logs**, select the Log Analytics workspace, and create the DCR.
7. Return to the DCR **Resources** page and verify the VM association.
8. After the association is ready, emit a focused preflight record:

   ```bash
   logger -p daemon.warning -t microhack \
     "MicroHack Syslog preflight for apache2 monitoring"
   ```

The DCR collects `daemon.warning` and higher-severity records. The tag and exact message let the queries ignore unrelated daemon messages.

### Verify telemetry before the incident

Open the Log Analytics workspace **Logs** page, set the time range to **Last 30 minutes**, and run:

```kusto
Heartbeat
| summarize LastHeartbeat=max(TimeGenerated) by Computer, _ResourceId
| order by LastHeartbeat desc
```

```kusto
InsightsMetrics
| where Origin == "vm.azm.ms"
| summarize LastMetric=max(TimeGenerated), Samples=count() by Computer, _ResourceId
| order by LastMetric desc
```

The selected VM must appear in both queries.

Copy the selected VM's `_ResourceId` from the results. Replace `<selected-vm-resource-id>` in the track-specific queries below with that exact value.

Track B also verifies the preflight event:

```kusto
Syslog
| where TimeGenerated >= ago(30m)
| where Facility =~ "daemon" and SeverityLevel =~ "warning"
| where ProcessName =~ "microhack"
| where SyslogMessage == "MicroHack Syslog preflight for apache2 monitoring"
| where _ResourceId =~ "<selected-vm-resource-id>"
| project TimeGenerated, Computer, ProcessName, Facility, SeverityLevel, SyslogMessage, _ResourceId
| order by TimeGenerated desc
```

> [!NOTE]
> Agent installation, DCR association, and ingestion are asynchronous. Refresh until the required records appear; do not assume a fixed ingestion time.

## Task 3: Create an actionable service alert (8 minutes)

### Create or reuse an action group

1. In **Monitor** > **Alerts**, select **Action groups** > **Create**.
2. Create `ag-mh-operators` in `destination-rg`, or reuse it if another team already created it.
3. Add an **Email/SMS message/Push/Voice** notification and send email to an address you can check. Name the receiver `LabOperator`.
4. Review and create the action group.

### Create the selected track's log search alert

Open the Log Analytics workspace, select **Alerts** > **Create** > **Alert rule**, and choose **Custom log search**.

Track A query:

```kusto
Event
| where TimeGenerated >= ago(10m)
| where EventLog == "System" and EventID == 7036
| where RenderedDescription has "World Wide Web Publishing Service"
    or RenderedDescription has "W3SVC"
    or ParameterXml has "W3SVC"
| where RenderedDescription has "stopped" or ParameterXml has "stopped"
| where _ResourceId =~ "<selected-vm-resource-id>"
| project TimeGenerated, Computer, RenderedDescription, _ResourceId
```

Track B query:

```kusto
Syslog
| where TimeGenerated >= ago(10m)
| where Facility =~ "daemon" and SeverityLevel =~ "warning"
| where ProcessName =~ "microhack"
| where SyslogMessage == "apache2 service stopped for MicroHack incident"
| where _ResourceId =~ "<selected-vm-resource-id>"
| project TimeGenerated, Computer, ProcessName, SyslogMessage, _ResourceId
```

Select **Run**. A zero-row result is expected before the incident. Configure:

| Setting | Value |
| --- | --- |
| Measure | Table rows |
| Aggregation type | Count |
| Aggregation granularity | 10 minutes |
| Operator | Greater than |
| Threshold value | `0` |
| Frequency of evaluation | 5 minutes |
| Action group | `ag-mh-operators` |
| Severity | 2 - Warning |
| Enable upon creation | Selected |

Use the selected track's alert details:

| Track | Alert rule name | Description |
| --- | --- | --- |
| A | `IIS W3SVC stopped` | `W3SVC stopped. Validate VM heartbeat, start W3SVC, and test HTTP.` |
| B | `Apache apache2 stopped` | `Controlled apache2 stop event detected. Validate VM heartbeat, start apache2, and test HTTP.` |

If the portal offers automatic resolution, enable it. Create the rule and verify it is enabled.

## Task 4: Induce and prove a safe incident (5 minutes)

### Track A - Windows

Run in elevated Windows PowerShell:

```powershell
$incidentStart = Get-Date
Stop-Service -Name W3SVC -Force
Get-Service -Name W3SVC

$siteFailed = $false
try {
    Invoke-WebRequest -Uri 'http://localhost/' -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop | Out-Null
}
catch {
    $siteFailed = $true
    Write-Host "Expected local IIS failure: $($_.Exception.Message)"
}
if (-not $siteFailed) {
    throw 'The local site unexpectedly remained available.'
}

Get-WinEvent -FilterHashtable @{
    LogName = 'System'
    Id = 7036
    StartTime = $incidentStart
} | Where-Object {
    $_.Message -match 'World Wide Web Publishing Service|W3SVC'
} | Select-Object TimeCreated, Id, Message
```

### Track B - Linux

Run in Bash:

```bash
sudo systemctl stop apache2

if sudo systemctl is-active --quiet apache2; then
  echo "apache2 unexpectedly remained active." >&2
  exit 1
else
  sudo systemctl is-active apache2 || true
fi

if curl --fail --silent --show-error --max-time 10 http://localhost/ >/dev/null; then
  echo "The local site unexpectedly remained available." >&2
  exit 1
else
  echo "Expected local Apache HTTP failure confirmed."
fi

logger -p daemon.warning -t microhack \
  "apache2 service stopped for MicroHack incident"
```

The `logger` command explicitly records the controlled stop action. This avoids depending solely on whether the Ubuntu systemd journal is forwarded to Syslog.

### Verify the ingested incident

Run the selected track's query.

Track A:

```kusto
Event
| where TimeGenerated >= ago(30m)
| where EventLog == "System" and EventID == 7036
| where RenderedDescription has "World Wide Web Publishing Service"
    or RenderedDescription has "W3SVC"
    or ParameterXml has "W3SVC"
| where RenderedDescription has "stopped" or ParameterXml has "stopped"
| where _ResourceId =~ "<selected-vm-resource-id>"
| project TimeGenerated, Computer, RenderedDescription, ParameterXml, _ResourceId
| order by TimeGenerated desc
```

Track B:

```kusto
Syslog
| where TimeGenerated >= ago(30m)
| where Facility =~ "daemon" and SeverityLevel =~ "warning"
| where ProcessName =~ "microhack"
| where SyslogMessage == "apache2 service stopped for MicroHack incident"
| where _ResourceId =~ "<selected-vm-resource-id>"
| project TimeGenerated, Computer, ProcessName, Facility, SeverityLevel, SyslogMessage, _ResourceId
| order by TimeGenerated desc
```

Refresh until the stop event appears. This record is the deterministic incident gate. Then review **Monitor** > **Alerts** > **Alert instances** and the action-group destination. Ingestion, evaluation, and notification are separate asynchronous stages.

## Task 5: Investigate with Azure Copilot Observability Agent (7 minutes)

On the Log Analytics workspace **Logs** page, select **Observability Agent** and use the prompt for your track.

### Track A prompt

```text
Investigate the IIS availability incident on Windows VM <vm-name> during the last
30 minutes. Use Event, Heartbeat, and InsightsMetrics. Determine whether W3SVC
stopped, whether the VM stayed online, and whether host performance suggests a
broader failure. Cite the resource and timestamps, recommend the safest
remediation, and do not make changes.
```

### Track B prompt

```text
Investigate the Apache availability incident on Ubuntu VM <vm-name> during the
last 30 minutes. Use the microhack-tagged daemon.warning record in Syslog,
Heartbeat, and InsightsMetrics. Determine whether apache2 stopped, whether the VM
stayed online, and whether host performance suggests a broader failure. Cite the
resource and timestamps, recommend the safest remediation, and do not make changes.
```

For either track, ask:

```text
Correlate the service-stop event with heartbeat and CPU or memory signals.
Explain why this is a service-level or VM-level outage and provide recovery
verification steps.
```

Confirm that the response identifies the selected event, checks whether heartbeat continued, reviews performance telemetry, and recommends starting the selected web service and testing HTTP. If the portal offers **Start investigation** from the fired alert, you may compare it with workspace-scoped chat. Saving an issue is optional.

> [!NOTE]
> On-demand chat and investigation work without provisioning a `Microsoft.Monitor/observabilityAgents` resource. Chat context is temporary.

### Fallback - KQL and VM insights when Azure Copilot is blocked

Use the selected track's event query to identify the incident's UTC `TimeGenerated`.

Track A:

```kusto
Event
| where TimeGenerated >= ago(2h)
| where EventLog == "System" and EventID == 7036
| where RenderedDescription has "World Wide Web Publishing Service"
    or RenderedDescription has "W3SVC"
    or ParameterXml has "W3SVC"
| where RenderedDescription has "stopped" or ParameterXml has "stopped"
| where _ResourceId =~ "<selected-vm-resource-id>"
| project TimeGenerated, Computer, RenderedDescription, _ResourceId
| order by TimeGenerated desc
```

Track B:

```kusto
Syslog
| where TimeGenerated >= ago(2h)
| where Facility =~ "daemon" and SeverityLevel =~ "warning"
| where ProcessName =~ "microhack"
| where SyslogMessage == "apache2 service stopped for MicroHack incident"
| where _ResourceId =~ "<selected-vm-resource-id>"
| project TimeGenerated, Computer, SyslogMessage, _ResourceId
| order by TimeGenerated desc
```

Replace the placeholder below with that UTC timestamp and run the common correlation queries:

```kusto
let IncidentTime = datetime(<incident-time-UTC>);
Heartbeat
| where TimeGenerated between ((IncidentTime - 15m) .. (IncidentTime + 15m))
| summarize Heartbeats=count(), LastHeartbeat=max(TimeGenerated)
    by Computer, bin(TimeGenerated, 5m)
| order by TimeGenerated asc
```

```kusto
let IncidentTime = datetime(<incident-time-UTC>);
InsightsMetrics
| where TimeGenerated between ((IncidentTime - 15m) .. (IncidentTime + 15m))
| where Origin == "vm.azm.ms"
| summarize Samples=count()
    by Computer, Namespace, Name, bin(TimeGenerated, 5m)
| order by TimeGenerated asc
```

Open the VM's **Monitoring** > **Insights** performance view for the same time range. Continuing heartbeat and performance samples show the VM remained available while the web service stopped, so service restoration is the first remediation.

## Task 6: Restore service and verify recovery (5 minutes)

### Track A - Windows

```powershell
Set-Service -Name W3SVC -StartupType Automatic
Start-Service -Name W3SVC
$service = Get-Service -Name W3SVC
$response = Invoke-WebRequest -Uri 'http://localhost/' -UseBasicParsing -TimeoutSec 10

$service | Select-Object Name, Status, StartType
$response | Select-Object StatusCode
```

Verify `Running`, `Automatic`, and HTTP `200`. In Log Analytics, the latest matching event ID 7036 record should show the service returning to the running state.

```kusto
Event
| where TimeGenerated >= ago(30m)
| where EventLog == "System" and EventID == 7036
| where RenderedDescription has "World Wide Web Publishing Service"
    or RenderedDescription has "W3SVC"
    or ParameterXml has "W3SVC"
| where RenderedDescription has "running" or ParameterXml has "running"
| where _ResourceId =~ "<selected-vm-resource-id>"
| project TimeGenerated, Computer, RenderedDescription, ParameterXml, _ResourceId
| order by TimeGenerated desc
```

### Track B - Linux

```bash
sudo systemctl enable apache2
sudo systemctl start apache2
sudo systemctl is-active apache2

curl --fail --silent --show-error --output /dev/null \
  --write-out 'HTTP %{http_code}\n' http://localhost/

logger -p daemon.warning -t microhack \
  "apache2 service restored after MicroHack incident"
```

Verify `active` and HTTP `200`. Then verify the recovery record:

```kusto
Syslog
| where TimeGenerated >= ago(30m)
| where Facility =~ "daemon" and SeverityLevel =~ "warning"
| where ProcessName =~ "microhack"
| where SyslogMessage == "apache2 service restored after MicroHack incident"
| where _ResourceId =~ "<selected-vm-resource-id>"
| project TimeGenerated, Computer, SyslogMessage, _ResourceId
| order by TimeGenerated desc
```

For either track, test the existing external endpoint. If automatic alert resolution is enabled, resolution occurs only after the stop event leaves the query window and a later evaluation completes; you do not need to wait for it.

### Cleanup

Keep VM monitoring for Challenge 8 unless your instructor asks you to remove it. After the MicroHack, you may independently remove the alert rule, action group, selected event DCR association/DCR, and Log Analytics workspace if they were created only for this lab. Do not delete shared resources.

### Optional stretch - autonomous operations (preview)

If your instructor has prepared an Azure Monitor workspace, an eligible monitored application, and the documented roles, review [Create an Azure Copilot Observability Agent resource](https://learn.microsoft.com/en-us/azure/azure-monitor/aiops/observability-agent-resource-create-portal). The resource enables preview autonomous correlation, issue creation, investigations, and custom instructions. It is intentionally excluded from the required lab path.

You successfully completed Challenge 7. Continue to Challenge 8 with the same selected track.
