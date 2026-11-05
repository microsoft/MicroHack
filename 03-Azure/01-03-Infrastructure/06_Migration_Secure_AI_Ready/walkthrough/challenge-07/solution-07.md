# Walkthrough Challenge 7 - Operate the migrated workloads with intelligent observability

[Previous Challenge Solution](../challenge-06/solution-06.md) - [**Home**](../../Readme.md) - [Next Challenge Solution](../challenge-08/solution-08.md)

Duration: 90 minutes (allow extra time for first-time agent installation and ingestion)

## Task 1: Validate both workloads and complete preflight (10 minutes)

Record both VM names, their region, and their Azure resource IDs in `<YOUR-LAB-RESOURCE-GROUP>`. Use the actual lab group from the platform dashboard throughout. Connect to each VM with Azure Bastion. Monitoring is a learner exercise; it was not preconfigured during Challenge 1.

### Windows/IIS baseline

Run in Windows PowerShell as administrator:

```powershell
$service = Get-Service -Name W3SVC
$response = Invoke-WebRequest -Uri 'http://localhost/' -UseBasicParsing -TimeoutSec 10

$service | Select-Object Name, Status, StartType
$response | Select-Object StatusCode

if ($service.Status -ne 'Running' -or $response.StatusCode -ne 200) {
    throw 'The IIS baseline is not healthy.'
}
```

### Linux/Apache baseline

Run in Bash:

```bash
set -euo pipefail

sudo systemctl is-active apache2
http_status=$(curl --fail --silent --show-error --max-time 10 --output /dev/null \
  --write-out '%{http_code}' http://localhost/)
printf 'HTTP %s\n' "$http_status"
if [[ "$http_status" != 200 ]]; then
  echo "Expected HTTP 200 from the local Apache site." >&2
  exit 1
fi
pgrep -a -x apache2
```

Opening each page before the incident both proves the baseline and warms IIS/Apache. Keep both Bastion sessions available for the recovery task.

### Azure Copilot and permissions

Monitoring setup requires the Owner and identity permissions below in both paths. For the AI-assisted path, also check Copilot, regional availability, and network access. If the preview or credits are unavailable, complete the same monitoring/incident exercise and use the manual fallback in Task 5.

1. The portal **Copilot** entry opens and the current region is listed in the [Observability Agent regions](https://learn.microsoft.com/azure/azure-monitor/aiops/observability-agent-overview#regions).
2. Your learner account has **Owner on the Hack subscription**, not just subscription Reader. This allows provider registration, monitoring-resource creation, and role assignments, including access to other learners' RGs. Work only in your assigned lab group. Keep the alert identity's **Monitoring Reader** assignments scoped to that group; the identity does not need your subscription-wide access.
3. The client network allows WebSocket connections to `https://directline.botframework.com`.
4. Your account can create or reuse a user-assigned managed identity in the lab group and grant it **Monitoring Reader** on that group for the query-based metric alerts.

> [!IMPORTANT]
> Observability Agent, deep investigations, Azure Monitor issues, and query-based metric alerts include preview experiences. A deep investigation can use up to 300 Azure Agent Credits. Portal labels and availability can vary by tenant and region.

No Azure OpenAI deployment or autonomous Observability Agent resource is required.

The default lab region, `swedencentral`, is not listed on the current Observability Agent regions page. Check whether **Investigate** is available for your lab and confirm access with the instructor. Use the manual fallback in Task 5 if unavailable; do not move VMs or workspaces merely to obtain preview access. Monitoring/alert availability and Observability Agent availability are separate checks.

## Task 2: Enable modern infrastructure monitoring (25 minutes)

Azure Monitor provides two different guest-monitoring models:

| | OpenTelemetry metrics-based | Classic logs-based |
| --- | --- | --- |
| Data store | Azure Monitor workspace | Log Analytics workspace |
| Query | PromQL | KQL |
| Latency | Near real-time | Typically 1-3 minutes |
| Cost | Default metric set is free; additional metrics can incur cost | Standard log ingestion and retention charges |
| Best fit | New deployments and consistent Windows/Linux metrics | Multi-VM views and single-query metric/log correlation |
| Current limitation | Metrics and logs require separate queries; built-in multi-VM views are limited | Platform-specific counters and higher ingestion cost |

Use the recommended OpenTelemetry experience for both VMs. Windows also needs Log Analytics for the authoritative service-control event; this challenge doesn't query classic performance tables.

### What you are creating

| Resource | Purpose |
| --- | --- |
| Azure Monitor workspace `amw-mh-<lab-suffix>` | Stores OpenTelemetry metrics for PromQL; enable resource-context access. |
| Log Analytics workspace `law-mh-monitoring` | Stores Windows events in the `Event` table for KQL. |
| User-assigned identity `id-mh-monitor-alerts` | Lets alert rules read monitoring data independently of your user account. |
| Monitoring Reader assignment on the lab RG | Covers the identity's access to both VMs and the workspaces; never assign Owner to this identity. |
| Action group `ag-mh-operators` | Sends notifications to an inbox you can actually read. A training-account UPN might not receive mail. |
| DCR `dcr-iis-service-events` and its Windows VM association | Collect System event 7036 into Log Analytics. |

Choose **one** foundation setup path below. Both paths still require VM onboarding and service-specific alert creation later. Neither changes Defender plans, grants subscription roles to identities, or creates another learner RG.

Azure Monitor automatically creates an `MA_<workspace-name>_<location>_managed` resource group containing its workspace-managed DCR and DCE. The code uses a stable per-RG workspace suffix to avoid managed-group name collisions between learners in a shared subscription; in the portal, use a unique name such as `amw-mh-0013`. This **Azure-managed** exception is not an extra learner-created lab group. Do not move those internals or delete their group separately.

Logs, additional process metrics, and alert rules can incur charges. Use the instructor-approved budget and keep user-controlled VM collection DCRs in the lab group.

### Option A: Create the monitoring foundation with code

Use **Azure Cloud Shell in PowerShell mode** or PowerShell 7 with Azure CLI. Cloud Shell is already authenticated; locally, run `az login` with the learner account first. Download [monitoring.bicep](monitoring.bicep) from the same Hack version and upload it using Cloud Shell's **Manage files > Upload**, or use the file from your checkout. Run from the folder containing that file. No extra Azure CLI extension or PowerShell module is needed; Azure CLI needs Bicep support.

First select the exact subscription, existing lab RG, and **migrated Azure web VMs**, not the Hyper-V host or the source nested guests:

```powershell
$ErrorActionPreference = 'Stop'
function Invoke-LabAz {
    $result = & az @args
    if ($LASTEXITCODE -ne 0) { throw 'Azure CLI failed; inspect the error above before continuing.' }
    $result
}
$subscriptionId = Read-Host 'Hack subscription ID'
$labRg = Read-Host 'Existing lab resource group'
$windowsVmName = Read-Host 'Migrated Windows web VM name'
$linuxVmName = Read-Host 'Migrated Ubuntu web VM name'
foreach ($value in @($subscriptionId, $labRg, $windowsVmName, $linuxVmName)) {
    if ([string]::IsNullOrWhiteSpace($value) -or $value -match '[<>]') {
        throw 'Use the actual dashboard subscription/RG and migrated Azure VM names.'
    }
}
Invoke-LabAz account set --subscription $subscriptionId
$account = Invoke-LabAz account show --output json | ConvertFrom-Json
if ($account.id -ine $subscriptionId -or $account.user.type -ne 'user') {
    throw 'Sign in with the intended learner account and exact subscription ID.'
}
$groupId = Invoke-LabAz group show --name $labRg --query id --output tsv
$windowsVm = Invoke-LabAz vm show --resource-group $labRg --name $windowsVmName --output json | ConvertFrom-Json
$linuxVm = Invoke-LabAz vm show --resource-group $labRg --name $linuxVmName --output json | ConvertFrom-Json
if ($windowsVm.storageProfile.osDisk.osType -ne 'Windows' -or
    $linuxVm.storageProfile.osDisk.osType -ne 'Linux' -or
    $windowsVm.location -ne $linuxVm.location) {
    throw 'Select the Windows and Linux web VMs in the same migration target region.'
}
$location = $windowsVm.location
$windowsVmId = $windowsVm.id
$linuxVmId = $linuxVm.id
[pscustomobject]@{
    User = $account.user.name; Subscription = $account.id; ResourceGroup = $labRg
    Location = $location; WindowsVM = $windowsVmId; LinuxVM = $linuxVmId
} | Format-List
```

Review the printed scope. The next block registers missing monitoring providers subscription-wide, previews the deployment, and creates the dedicated resources only after confirmation. It refuses to adopt same-named portal-created/shared resources; use Option B for an existing portal setup. Rerunning this template's own setup reuses its resource names and deterministic role assignment. Do not mix the two creation paths for the same resources.

```powershell
$templateFile = (Resolve-Path '.\monitoring.bicep').ProviderPath
$notificationEmail = Read-Host 'Notification email address you can read'
if ($notificationEmail -notmatch '^[^@\s]+@[^@\s]+\.[^@\s]+$') {
    throw 'Supply a usable email address, not an unverified training-account UPN.'
}
$plannedNames = @('law-mh-monitoring', 'id-mh-monitor-alerts',
    'ag-mh-operators', 'dcr-iis-service-events')
$conflicts = @(Invoke-LabAz resource list --resource-group $labRg --output json |
    ConvertFrom-Json | Where-Object {
        ($_.name -in $plannedNames -or
            ($_.type -eq 'Microsoft.Monitor/accounts' -and $_.name -like 'amw-mh-*')) -and
            $_.tags.microhackChallenge -ne '07'
    })
if ($conflicts.Count -gt 0) {
    throw 'A planned resource name already exists outside this template. Use the portal reuse path.'
}
foreach ($provider in @('Microsoft.Monitor', 'Microsoft.OperationalInsights',
    'Microsoft.Insights', 'Microsoft.ManagedIdentity')) {
    $state = Invoke-LabAz provider show --namespace $provider --query registrationState --output tsv
    if ($state -ne 'Registered') {
        Invoke-LabAz provider register --namespace $provider --wait --output none
    }
}
$parameters = @("location=$location", "windowsVmName=$windowsVmName",
    "notificationEmail=$notificationEmail")
Invoke-LabAz deployment group what-if --resource-group $labRg --template-file $templateFile --parameters @parameters
if ((Read-Host 'Review the proposed resources, region and RG; type DEPLOY to continue') -cne 'DEPLOY') {
    throw 'Deployment not confirmed; no template was submitted.'
}
$monitoring = Invoke-LabAz deployment group create --name challenge07-monitoring `
    --resource-group $labRg --mode Incremental --template-file $templateFile `
    --parameters @parameters --query properties.outputs --output json | ConvertFrom-Json
$monitoring | Format-List
```

Record the output resource IDs. The template creates the event DCR and association, **not** the Azure Monitor Agent extension, OpenTelemetry DCRs, recommended alerts, or the two service alerts. Continue with VM onboarding below. Do not interpret ARM success as proof of telemetry ingestion. If region availability, Azure Policy, or private-network requirements block deployment, involve the instructor rather than changing shared policy or disabling network controls.

### Option B: Create or reuse the foundation in the portal

1. In the portal, open **Azure Monitor workspaces**. Select a suitable existing workspace in `<YOUR-LAB-RESOURCE-GROUP>`, or select **Create**, choose the Hack subscription and that exact resource group, and create an Azure Monitor workspace in a supported region for the migrated VMs. Follow [Manage an Azure Monitor workspace](https://learn.microsoft.com/azure/azure-monitor/metrics/azure-monitor-workspace-manage).
2. Open **Log Analytics workspaces** and choose or create a workspace in **the same lab resource group**. Use a regional workspace supported by the Windows Infrastructure monitoring flow, normally in the VM's region. A workspace in another region is usable only if the current portal flow supports it; compatibility is not implied by placing it in the same RG. Azure Monitor workspaces hold metrics; Log Analytics workspaces hold logs and aren't interchangeable.
3. Record both workspace resource IDs. During onboarding, explicitly select these workspaces rather than accepting a default in another resource group. Keep all user-controlled DCRs, alert rules, action groups, and identities in the lab group too.
4. Open the Azure Monitor workspace's **Settings > Properties**, turn on **Enable access using resource permissions**, and apply. This is **Use resource or workspace permissions** access mode; old workspaces can require workspace permissions instead.

> [!IMPORTANT]
> Review every resource-group selection before enabling monitoring. If this preview's wizard cannot select the lab workspaces or keep user-controlled generated resources in the lab group, stop and ask the instructor for a compatible portal configuration. Your subscription Owner access is not a reason to accept an unrelated default group or create another learner group.

### Create the alert-query identity before onboarding

Create the identity before opening **Infrastructure monitoring** on either VM:

If you used Option A, the identity and RG-scoped assignment already exist; verify them instead of creating duplicates.

1. In the Azure portal, search for **Managed Identities**, select **Create**, and create a user-assigned managed identity such as `id-mh-monitor-alerts` in `<YOUR-LAB-RESOURCE-GROUP>` and the same region as the migrated VMs.
2. Open the lab resource group, select **Access control (IAM)** > **Add role assignment**, choose **Monitoring Reader**, and assign it to the new user-assigned managed identity. This lab-scoped assignment covers both migrated VMs and the monitoring workspaces in the group.
3. Confirm the identity's inherited **Monitoring Reader** access on both VMs and the Azure Monitor workspace. No subscription-level role assignment is needed for the alert identity.
4. Reuse this identity for both migrated VMs. The [query-based metric alert identity requirements](https://learn.microsoft.com/azure/azure-monitor/alerts/alerts-query-based-metric-alerts-overview#managed-identities-for-query-based-alerts) require read access to the alert scope.

This user-assigned identity authorizes OpenTelemetry alert queries. It is different from the VM's system-assigned identity that Azure Monitor Agent can use. The Infrastructure monitoring wizard doesn't create the user-assigned alert identity, so create and authorize it before selecting it in the wizard.

RBAC propagation can take a few minutes. If the wizard cannot validate the identity immediately, recheck its **principal ID**, assignment scope, and workspace access mode; do not work around the delay by granting it subscription Owner.

### Continue here after either foundation path

The workspace IDs, alert identity, and its Monitoring Reader assignment must be ready before onboarding. Use the VM resource IDs recorded above for all query/alert filters; for Option B, copy them from each migrated VM's **Properties > Resource ID**.

### Onboard the Windows VM

1. Open the Windows VM and select **Monitor**. If enhanced monitoring isn't enabled, select **Configure**.
2. Select **Customize infrastructure monitoring**.
3. Keep **OpenTelemetry metrics** selected.
4. Optionally select the OpenTelemetry detailed or per-process option to explore the cross-platform schema. The Windows alert doesn't use process metrics, and enabling them can incur ingestion cost.
5. Leave **Classic Log-based metrics** off for this guided path. The separate Windows Event DCR sends service events to Log Analytics without collecting classic performance data. Optionally enable the classic experience for comparison, select the lab Log Analytics workspace explicitly, and accept its additional performance-ingestion cost.
6. Select the Azure Monitor workspace chosen above and confirm the generated user-controlled DCR is placed in `<YOUR-LAB-RESOURCE-GROUP>`. Do not accept a regional default workspace or collection rule in another user-controlled group.
7. Keep **Recommended alerts** selected when offered. Recommended alerts cover infrastructure health; they don't replace the service-specific alerts created in Task 3. Built-in **Dashboards with Grafana** are available without provisioning a separate Azure Managed Grafana resource.
8. In **Identity**, select the pre-created `id-mh-monitor-alerts` user-assigned identity. Confirm its lab-RG **Monitoring Reader** assignment covers the VM and Azure Monitor workspace.
9. Review all user-controlled DCR, alert, and action-group resource-group selections, keep them in the lab group, and enable monitoring.

Before continuing, confirm that the review page names the selected Azure Monitor workspace and generated VM collection DCR **in the lab group**. A Log Analytics selector is expected only if you chose the optional classic experience; its absence does not prevent the separate Windows Event DCR from collecting events. Do not silently accept an out-of-scope default.

The final configuration should show **OpenTelemetry metrics**, your selected Azure Monitor workspace, recommended alerts, and the pre-created user-assigned identity. The Windows Event DCR targets your Log Analytics workspace separately. Portal labels can change; the resource IDs and lab RG are the authoritative checks.

> [!NOTE]
> As part of Azure Monitor Agent installation, Azure can enable a system-assigned identity on the VM. That VM identity is separate from the pre-created user-assigned identity selected for alert queries; the wizard doesn't create the user-assigned alert identity.

### Onboard the Linux VM

Repeat the Infrastructure monitoring flow for the Linux VM:

1. Keep **OpenTelemetry metrics** and its detailed/per-process option selected.
2. Leave **Classic Log-based metrics** off; Apache uses an OpenTelemetry process signal and doesn't require a Log Analytics workspace.
3. Explicitly select the same Azure Monitor workspace in the lab resource group.
4. Keep the generated VM collection DCR and recommended alert/action-group resources in the lab resource group. Use the built-in Grafana dashboard after onboarding.
5. Select the same pre-created user-assigned alert identity and enable monitoring.

The portal installs `AzureMonitorWindowsAgent` or `AzureMonitorLinuxAgent`. Provisioning, DCR association, and the first metric samples take several minutes. An existing agent can collect from multiple DCRs; do not remove policy-managed agents or unrelated DCR associations to make this exercise work.

### Verify and customize the generated OpenTelemetry DCR

1. Open **Monitor** > **Data Collection Rules** > **Resources**.
2. Locate each VM and open its associated DCR whose name follows `MSVMOtel-<region>-<name>`. Confirm that this user-controlled VM collection DCR is in the lab group and targets the selected Azure Monitor workspace; it is not the Azure-managed workspace-internal DCR.
3. For the Linux DCR, open **Data sources** > **OpenTelemetry Performance Counters**.
4. Select **Custom** and confirm that `process.uptime` is included. Add it if it isn't present.
5. Optionally include `process.cpu.utilization` and `process.memory.usage` for richer investigation evidence.
6. Keep the default 60-second sampling interval and save.

Default OpenTelemetry metrics such as `system.uptime`, `system.cpu.time`, and `system.memory.usage` are free. `process.uptime` and other metrics beyond the default set can incur ingestion cost. Remove unneeded additional metrics after the Hack.

### Verify metrics on both VMs

From each VM, open **Metrics** and choose **View AMW metrics in editor** or **Add with editor**. Verify that the editor's **Scope** is that single VM, not the workspace, RG, or subscription. Resource-context access must be enabled on the workspace. The queries below rely on this VM scope; a workspace-wide query can accidentally include other machines and mask an Apache outage.

Run:

```promql
{"system.uptime"}
```

On the Linux VM, also run:

```promql
count({"process.uptime", "process.executable.name"="apache2"})
```

The first query must return recent data for each VM. The Linux query must return a value greater than zero. `process.executable.name` is an enabled per-process resource attribute, and `process.uptime` is a gauge measured in seconds.

> [!NOTE]
> Azure Monitor PromQL uses Prometheus 3 UTF-8 syntax. Metric and label names containing dots are quoted inside braces, for example `{"process.uptime", "process.executable.name"="apache2"}`.

## Task 3: Create service-specific alert paths (20 minutes)

If you used Option A, `ag-mh-operators` already exists. Otherwise, open **Monitor > Alerts > Action groups > Create**, choose the Hack subscription and lab RG, name it `ag-mh-operators`, use display name `MHOperators`, and add an **Email** notification to an inbox you can read. Enable the common alert schema when offered. Select **Review + create**, then use **Test action group** to confirm delivery. Do not rely on an automatically selected training-account email address unless it receives mail.

Save both service-specific alert rules below in the lab group and select this action group on their **Actions** tab. An action-group test checks notification delivery, not VM telemetry or the alert condition.

### Windows/IIS: collect the authoritative service event

Option A already created `dcr-iis-service-events` and associated it with the Windows VM. Verify it rather than creating a second copy. For Option B, create a focused DCR:

1. Open **Monitor** > **Data Collection Rules** and select **Create**.
2. Name it `dcr-iis-service-events`, use `<YOUR-LAB-RESOURCE-GROUP>`, the VM's region, and platform type **Windows**.
3. On **Resources**, add the Windows VM. Leave **Enable Data Collection Endpoints** off unless your network design requires a DCE.
4. Add a **Windows Event Logs** data source.
5. Select **Custom** and enter:

   ```text
   System!*[System[(EventID=7036)]]
   ```

6. Set the destination to **Azure Monitor Logs** and select the Log Analytics workspace from the monitoring foundation, not the Azure Monitor metrics workspace.
7. Create the DCR and verify its VM association.

Confirm that the DCR's **Resources** page shows the Windows VM. You can use the Log Analytics workspace's **Logs** page to inspect any service-control records collected after the association:

```kusto
Event
| where TimeGenerated >= ago(30m)
| where EventLog == "System" and EventID == 7036
| where _ResourceId =~ "<windows-vm-resource-id>"
| project TimeGenerated, Computer, RenderedDescription, _ResourceId
| order by TimeGenerated desc
```

Zero rows are valid when the `Event` table exists but no matching service event has arrived. A missing `Event` table is not the same as zero rows: first verify the AMA extension, event DCR association, and destination. If this is the workspace's first event ingestion, use the controlled IIS stop from Task 4 as the first event and wait for ingestion. Restore IIS using Task 6, finish creating the alert below, then repeat Task 4 with a fresh stop time. This avoids losing the initial event outside the ten-minute alert window while configuring the rule. Do not fabricate events or stop unrelated services.

Create a **Custom log search** scheduled-query alert from the workspace:

```kusto
Event
| where TimeGenerated >= ago(10m)
| where EventLog == "System" and EventID == 7036
| where RenderedDescription has "World Wide Web Publishing Service"
    or RenderedDescription has "W3SVC"
    or ParameterXml has "W3SVC"
| where RenderedDescription has "stopped" or ParameterXml has "stopped"
| where _ResourceId =~ "<windows-vm-resource-id>"
| project TimeGenerated, Computer, RenderedDescription, _ResourceId
```

Configure:

| Setting | Value |
| --- | --- |
| Alert name | `IIS W3SVC stopped` |
| Measure | Table rows |
| Aggregation | Count over 10 minutes |
| Azure Resource ID column | `_ResourceId`, so the fired alert targets the Windows VM rather than just the workspace |
| Condition | Greater than `0` |
| Evaluation frequency | 5 minutes |
| Severity | 2 - Warning |
| Action group | `ag-mh-operators` |
| Enable | Selected |

Enable automatic resolution when offered. If the **Identity** section is shown, select `id-mh-monitor-alerts`; its lab-RG Monitoring Reader assignment includes the Log Analytics workspace. Run the KQL with the actual Windows VM resource ID, select **Continue editing alert**, configure the table above, and check the resource group on **Details** before creating the rule. These service-name/state filters assume the supplied English Windows image; adapt them to the actual SCM event if using a localized image. Do not alert on `w3wp.exe` absence: application-pool idle timeout can remove the worker process while `W3SVC` and the site remain healthy.

This is a **transition alert**: the stopped event eventually leaves the ten-minute window, even if IIS stays stopped. Its automatic resolution is not proof of recovery. The running event, service check, and HTTP `200` in Task 6 provide that proof. A production persistent-outage alert needs a suitable continuous service-state signal or synthetic availability check.

### Linux/Apache: alert only when every Apache process disappears

Open the **Linux VM > Alerts > Create > Alert rule**. Confirm that **Scope** is the Linux VM resource ID. On **Condition**, choose the query-based/PromQL metric condition, not a classic platform-metric condition, and use:

```promql
absent_over_time({"process.uptime", "process.executable.name"="apache2"}[5m]) > 0
```

Configure:

| Setting | Value |
| --- | --- |
| Alert name | `Apache processes absent` |
| Condition | The PromQL expression returns a series; `> 0` is already part of the expression |
| Evaluation frequency | 1 minute |
| Failing period | 1 minute |
| Auto resolution | Enabled |
| Severity | 2 - Warning |
| Managed identity | Pre-created user-assigned identity with **Monitoring Reader** on the lab resource group, covering the Linux VM and Azure Monitor workspace |
| Action group | `ag-mh-operators` |

`apache2` normally has a parent and multiple workers, each with its own `process.uptime` series. `absent_over_time` returns no result while any matching series exists and returns `1` only after all matching series have been absent for the full five-minute window. Allow up to 10 minutes after the stop command for the final sample, absence window, collection, and alert evaluation before treating a missing alert as a configuration problem.

On **Identity**, select `id-mh-monitor-alerts`; on **Actions**, select `ag-mh-operators`; on **Details**, use the lab RG and a query-alert-supported region. Verify the VM scope again on **Review + create**. An AMW-scoped absence query without a VM filter could stay healthy because another VM still runs Apache.

An absence alert also fires when the VM or telemetry pipeline stops reporting; it does not by itself prove a service-only outage. Require the healthy preflight sample, local HTTP failure, and continuing host metrics before making that diagnosis.

## Task 4: Induce and prove both controlled incidents (10 minutes)

Warm both pages once more before stopping either service. Process/service telemetry proves component state, while the local HTTP request proves user-visible impact in this private lab. Neither signal is a substitute for production synthetic availability monitoring.

Record each stop command and its UTC time (`(Get-Date).ToUniversalTime().ToString('o')` on Windows; `date -u +%FT%TZ` on Linux). Azure Activity Log records Azure control-plane operations, not guest `Stop-Service` or `systemctl` commands. Service events/process metrics prove the state change, not which person or command caused it; use your controlled-incident record as ground truth.

### Stop IIS and prove impact

Run in elevated Windows PowerShell:

```powershell
$incidentStart = Get-Date
Stop-Service -Name W3SVC -Force
$service = Get-Service -Name W3SVC

$siteFailed = $false
try {
    Invoke-WebRequest -Uri 'http://localhost/' -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop | Out-Null
}
catch {
    $siteFailed = $true
    Write-Host "Expected local IIS failure: $($_.Exception.Message)"
}

if ($service.Status -ne 'Stopped' -or -not $siteFailed) {
    throw "The controlled IIS incident wasn't proven."
}

Get-WinEvent -FilterHashtable @{
    LogName   = 'System'
    Id        = 7036
    StartTime = $incidentStart
} | Where-Object {
    $_.Message -match 'World Wide Web Publishing Service|W3SVC'
} | Select-Object TimeCreated, Id, Message
```

Wait for the stopped event to appear in the Task 3 KQL query, then wait for `IIS W3SVC stopped` to appear under **Monitor** > **Alerts** > **Alert instances**.

### Stop Apache and prove impact

Run in Bash:

```bash
set -euo pipefail

sudo systemctl stop apache2

if systemctl is-active --quiet apache2 || pgrep -x apache2 >/dev/null; then
  echo "Apache unexpectedly remained active." >&2
  exit 1
fi

if curl --fail --silent --show-error --max-time 10 http://localhost/ >/dev/null; then
  echo "The local Apache site unexpectedly remained available." >&2
  exit 1
else
  echo "Expected local Apache HTTP failure confirmed."
fi
```

In the Linux VM's resource-scoped PromQL editor, compare:

```promql
count({"process.uptime", "process.executable.name"="apache2"})
```

```promql
absent_over_time({"process.uptime", "process.executable.name"="apache2"}[5m])
```

The count disappears after the final process series stops reporting. The absence query becomes `1` only after the complete five-minute gap. Allow up to 10 minutes from the stop command for `Apache processes absent` to fire.

> [!NOTE]
> If either alert doesn't fire, keep the services stopped only long enough to verify DCR association, identity authorization, query scope, ingestion, and alert evaluation. Task 6 contains independent recovery commands and can be run at any time.

## Task 5: Investigate, decide, and preserve context with AI (15 minutes)

Open each fired alert and select **Investigate** when available. Review the Azure Agent Credit notice, verify the resource and incident time window in the temporary chat, and confirm the proposed investigation or provide the prompts below. Some portal versions first show **Start chat**. A deep investigation can consume up to 300 Azure Agent Credits; obtain approval for both investigations before starting. If the entry point, region, tenant access, or credits are unavailable, use the manual fallback below.

### Investigate the IIS alert

```text
Investigate this IIS availability incident on the Windows VM. Build an evidence-backed
timeline from the alert, Windows System event ID 7036 for W3SVC, OpenTelemetry host
metrics, Resource Health, Activity Log, and related alerts. State the user impact and
blast radius. Determine the most likely root cause, list plausible hypotheses that the
evidence rules out, and cite the resource and timestamps used. Recommend the safest
human-executed remediation, rollback, validation steps, and alert-tuning or prevention
improvements. Do not change resources or restart services.
```

### Investigate the Apache alert

```text
Investigate this Apache availability incident on the Ubuntu VM. Confirm that all
process.uptime series with process.executable.name=apache2 disappeared for the alert
window, then correlate that signal with OpenTelemetry host metrics, Resource Health,
Activity Log, and related alerts. State the user impact and blast radius. Determine the
most likely root cause, list hypotheses ruled out by the evidence, and cite resources
and timestamps. Recommend the safest human-executed remediation, rollback, validation,
and alert-tuning or prevention improvements. Do not change resources or start services.
```

For the comparison, provide both VM resource IDs, incident times, and the other investigation's findings, or explicitly add the second VM to the investigation scope. An alert-scoped investigation does not automatically have both incidents' context. Then ask:

```text
Compare the two incidents. Did they share a platform, network, capacity, or regional
failure, or were they independent service-level failures? Separate observed evidence
from inference and identify any telemetry gap that prevents a firm conclusion.
```

Confirm that the report contains impact, scope, chronology, supporting evidence, a likely cause, ruled-out alternatives, safe remediation, rollback, and prevention guidance. Use **Create Issue** when available to preserve the investigation report and conversation as an Azure Monitor issue.

> [!IMPORTANT]
> This lab uses controlled autonomy. The agent can chat, correlate telemetry, run a user-invoked investigation, create issues, and recommend actions. It doesn't restart services, modify production resources, or resolve the incident automatically. The human operator evaluates and executes remediation.

Do not create an autonomous Observability Agent resource. In the current preview, the portal scopes that resource to Application Insights, and new VM-only scope isn't a supported configuration for this Hack.

### Concise manual fallback

If agent output is unavailable, retain the same evidence standard:

1. Use the IIS stopped-event KQL query from Task 3.
2. Use the Linux `count` and `absent_over_time` PromQL queries from Task 4.
3. At each VM's incident time, inspect the default host signals:

   ```promql
   {"system.uptime"}
   ```

   ```promql
   sum by (state) (rate({"system.cpu.time"}[5m]))
   ```

   ```promql
   sum by (state) ({"system.memory.usage"})
   ```

4. Review each VM's **Resource Health**, **Activity log**, and Grafana dashboard for the same window.

Continuing system uptime and normal host signals, combined with a stopped service signal and local HTTP failure, support a service-level diagnosis. Record evidence that rules out VM restart, resource exhaustion, Azure platform impact, or an unrelated configuration change before choosing remediation.

## Task 6: Restore, validate, and improve the runbook (10 minutes)

The operator, not the agent, restores both services.

### Restore IIS

Run in elevated Windows PowerShell:

```powershell
Set-Service -Name W3SVC -StartupType Automatic
Start-Service -Name W3SVC

$service = Get-Service -Name W3SVC
$response = Invoke-WebRequest -Uri 'http://localhost/' -UseBasicParsing -TimeoutSec 10

$service | Select-Object Name, Status, StartType
$response | Select-Object StatusCode

if ($service.Status -ne 'Running' -or $response.StatusCode -ne 200) {
    throw 'IIS recovery validation failed.'
}
```

Verify the running event:

```kusto
Event
| where TimeGenerated >= ago(30m)
| where EventLog == "System" and EventID == 7036
| where RenderedDescription has "World Wide Web Publishing Service"
    or RenderedDescription has "W3SVC"
    or ParameterXml has "W3SVC"
| where RenderedDescription has "running" or ParameterXml has "running"
| where _ResourceId =~ "<windows-vm-resource-id>"
| project TimeGenerated, Computer, RenderedDescription, ParameterXml, _ResourceId
| order by TimeGenerated desc
```

### Restore Apache

Run in Bash:

```bash
set -euo pipefail

sudo systemctl enable --now apache2
systemctl is-active --quiet apache2
pgrep -a -x apache2
http_status=$(curl --fail --silent --show-error --max-time 10 --output /dev/null \
  --write-out '%{http_code}' http://localhost/)
printf 'HTTP %s\n' "$http_status"
if [[ "$http_status" != 200 ]]; then
  echo "Expected HTTP 200 after Apache recovery." >&2
  exit 1
fi
```

Verify that process telemetry returns:

```promql
count({"process.uptime", "process.executable.name"="apache2"})
```

The value must again be greater than zero. Use Bastion to validate both web pages and confirm their hostname, platform, and web-server details remain correct.

The Apache alert can resolve after process samples return. The IIS transition alert can auto-resolve after the stopped event leaves its query window, regardless of actual service recovery. Require the running event and HTTP `200` before calling IIS recovered. Review both alert timelines rather than forcing closure.

If agent access is available, ask in the saved investigation or issue. Otherwise, write the same summary from your manual evidence:

```text
Create a concise post-incident summary for both service failures. Include impact,
timeline, authoritative evidence, root cause, remediation and validation, rollback,
alert behavior, remaining telemetry gaps, and three prioritized runbook or alert-tuning
improvements. Clearly state that local HTTP validation isn't continuous synthetic
availability monitoring.
```

### Cleanup and handoff

Keep monitoring while completing Challenge 8. After the Hack:

* Remove the two lab service alerts, their action-group links, and the Windows service-event DCR if they aren't shared.
* Remove additional per-process metrics if they were enabled only for this lab and their ongoing cost isn't justified.
* Don't delete portal-created Azure Monitor or Log Analytics workspaces, generated DCRs, dashboards, or action groups until you confirm no other resources use them.
* Don't delete the shared user-assigned alert identity until you confirm no other alert rules use it; remove its lab-specific RG role assignment when it is no longer needed.

Continue to Challenge 8, where you select either recovered workload for the guided replatforming exercise.

You successfully completed Challenge 7.
