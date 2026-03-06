# Optional: Challenge 8 - Monitoring and Alerting for BCDR Operations

[Previous Challenge Solution](../challenge-07/solution-07.md) - **[Home](../../Readme.md)** - [Congratulations](../../challenges/finish.md)

⏰ Duration: 45 minutes

## Solution Overview

This challenge focuses on implementing comprehensive monitoring and alerting for your Azure Backup and Azure Site Recovery operations. You will configure diagnostic settings, explore monitoring dashboards, and leverage Azure Business Continuity Center for unified BCDR reporting across your environment.

## Prerequisites

Ensure previous challenges are completed with:
- Recovery Services Vaults in both Germany West Central and Sweden Central
- Backup Vaults configured
- Log Analytics workspace deployed in your infrastructure
- Protected VMs with Azure Backup and Azure Site Recovery configured

## Part 1: Configure Azure Backup Monitoring & Reporting

### Configure Diagnostic Settings for Recovery Services Vault

1. Navigate to the **Recovery Services Vault** in Germany West Central
2. In the left menu, go to **Diagnostic settings**
3. Click **+ Add diagnostic setting**
4. Configure the diagnostic setting:
   - **Name**: Enter a descriptive name (e.g., `backup-diagnostics`)
   - **Logs**: Select **All logs** (this includes both Azure Backup and Azure Site Recovery logs)
     - Or select specific categories like:
       - `AzureBackupReport`
       - `CoreAzureBackup`
       - `AddonAzureBackupJobs`
       - `AddonAzureBackupAlerts`
       - `AddonAzureBackupPolicy`
       - `AddonAzureBackupStorage`
       - `AddonAzureBackupProtectedInstance`
   - **Destination details**: Check **Send to Log Analytics workspace**
   - Select your Log Analytics workspace
5. Click **Save**

> **Note:** Repeat this configuration for the Recovery Services Vault in Sweden Central if you want comprehensive monitoring across both regions.

> **Important:** After configuration, it takes up to 24 hours for initial data to populate in Log Analytics and reports.

### Explore Recovery Services Vault Monitoring

1. In the Recovery Services Vault, navigate to **Monitoring** section
2. Explore the **Backup Jobs** blade:
   - View all backup jobs (in-progress, completed, failed)
   - Filter by date range, job type, and status
   - Click on individual jobs to view detailed information
3. Navigate to **Backup Alerts**:
   - View active alerts and warnings
   - Configure alert notifications
   - Review historical alerts
4. Check **Backup Items**:
   - View all protected items and their backup status
   - Verify last successful backup time
   - Check backup health status

### Configure Azure Monitor Alerts for Backup

Azure Backup provides built-in Azure Monitor alerts that can be enabled for specific scenarios:

1. In the Recovery Services Vault, go to **Monitoring** > **Alerts**
2. Review the built-in alert types available:
   - Backup job failures
   - Restore job failures
   - Backup health issues
3. To enable alerts, go to **Monitoring** > **Alerts** > **View + Set up**
4. Configure action groups for notifications:
   - Click **+ Create** > **Action group**
   - Configure notification channels (email, SMS, webhook, Logic App, etc.)
   - Assign the action group to alert rules
5. Enable specific built-in alerts:
   - Select the scenarios you want to be alerted on
   - Associate with your action group
   - Set severity levels as appropriate

> **Note:** Azure Backup uses built-in alerts that are pre-configured. You enable them and configure where notifications should be sent via action groups.

### Access Azure Business Continuity Center (Resiliency)

1. In the Azure Portal, search for **Azure Business Continuity Center** (or **Resiliency**)
2. Navigate to the service
3. Explore the **Overview** dashboard:
   - View protected resources across subscriptions
   - See backup health summary
   - Review recent jobs and alerts
4. Go to **Reports** section:
   - **Backup Summary**: Overview of all protected items
   - **Backup Jobs**: Detailed job history and trends
   - **Backup Items**: List of all backed-up resources
   - **Backup Policies**: Policy assignment and compliance
   - **Backup Storage**: Storage consumption trends
5. Filter reports by:
   - Subscription
   - Resource group
   - Location
   - Time range

> **Note:** Reports require data to be sent to Log Analytics. Initial data may take 24+ hours to appear.

### Explore Built-in Backup Dashboards

Backup reports are accessed through Azure Business Continuity Center (configured with Log Analytics workspace):

1. Navigate to **Azure Business Continuity Center** or **Backup Center**
2. Go to **Reports** (requires diagnostic settings configured to Log Analytics)
3. View pre-built reports:
   - **Backup Summary**: High-level overview of backup operations
   - **Jobs**: Detailed job execution history
   - **Alerts**: Alert trends and patterns
   - **Backup Items**: Protected resource inventory
   - **Usage**: Storage consumption analysis
   - **Policy**: Policy compliance and coverage

Alternatively, in the Recovery Services Vault:
1. Navigate to **Monitoring** section to view:
   - **Backup Jobs**: Real-time job monitoring
   - **Backup Alerts**: Active alerts and notifications
   - **Backup Items**: Protected items status

## Part 2: Configure Azure Site Recovery (ASR) Monitoring

### Verify ASR Diagnostic Settings

1. Navigate to the **Recovery Services Vault** in Sweden Central (or Germany West Central)
2. Go to **Diagnostic settings**
3. If you selected **All logs** in Part 1, ASR logs are already configured
4. If not, add or edit diagnostic setting:
   - Select ASR-specific log categories:
     - `AzureSiteRecoveryJobs`
     - `AzureSiteRecoveryEvents`
     - `AzureSiteRecoveryReplicatedItems`
     - `AzureSiteRecoveryReplicationStats`
     - `AzureSiteRecoveryRecoveryPoints`
     - `AzureSiteRecoveryReplicationDataUploadRate`
     - `AzureSiteRecoveryProtectedDiskDataChurn`
   - Send to the same Log Analytics workspace
5. Save the configuration

> **Tip:** Replicate the same diagnostic settings configuration to both Recovery Services Vaults (primary and secondary regions) for comprehensive monitoring.

### Explore Azure Site Recovery Dashboard

1. In the Recovery Services Vault, go to **Site Recovery** section
2. Navigate to **Site Recovery dashboard**:
   - View replication health overview
   - Check replicated items status
   - Monitor test failover readiness
3. Explore **Replicated items**:
   - View all replicated VMs
   - Check replication health (Healthy, Warning, Critical)
   - Verify RPO (Recovery Point Objective) compliance
   - Review last recovery point time
4. Check **Site Recovery jobs**:
   - View ongoing and historical ASR jobs
   - Monitor replication, failover, and test failover jobs
   - Investigate failed jobs for troubleshooting

### Review Infrastructure View

1. In the Recovery Services Vault, go to **Site Recovery infrastructure**
2. Navigate to **Azure virtual machines**:
   - View replication topology
   - See source and target regions
   - Check Azure Site Recovery components (cache storage accounts, target networks)
3. Review **Recovery Plans**:
   - View configured recovery plans
   - Check protected VMs in each plan
   - Verify recovery plan health

> **Note:** For Azure VM to Azure VM replication, configuration servers and process servers are not used. These components are only for VMware/physical server to Azure scenarios.

### Understand Built-in Azure Monitor Alerts for ASR

Azure Site Recovery has several built-in alerts that automatically monitor your replication health:

**Key ASR Alert Types:**
1. **Replication health critical**: Triggered when VM replication health is critical
2. **Test failover not performed**: Alert when test failover is overdue
3. **RPO threshold breached**: When RPO exceeds configured threshold
4. **High data change rate**: When source VM data churn is unusually high
5. **Site Recovery job failed**: Triggered on replication, failover, or failback job failures

### Review Azure Monitor Alerts for ASR

1. Navigate to **Azure Monitor** in the Azure Portal
2. Go to **Alerts**
3. Filter by:
   - **Resource type**: Recovery Services vaults
   - **Subscription**: Your subscription
4. Review existing ASR alerts:
   - Check alert rules created automatically by ASR
   - Review alert severity levels
   - Examine action groups configured for notifications
5. Explore alert history:
   - View fired alerts
   - Check resolution status
   - Analyze alert patterns and trends

### Query ASR Data in Log Analytics (Optional)

1. Navigate to your **Log Analytics workspace**
2. Go to **Logs**
3. Run sample queries to analyze ASR data:

```kusto
// View all Site Recovery jobs in the last 7 days
AzureDiagnostics
| where Category == "AzureSiteRecoveryJobs"
| where TimeGenerated > ago(7d)
| project TimeGenerated, OperationName, ResultType, JobId_g, JobStatus_s
| order by TimeGenerated desc
```

```kusto
// Check replication health for protected VMs
AzureDiagnostics
| where Category == "AzureSiteRecoveryReplicatedItems"
| where TimeGenerated > ago(1d)
| project TimeGenerated, replicationHealth_s, ProtectedItemName_s, FailoverHealth_s
| order by TimeGenerated desc
```

```kusto
// View RPO for replicated items
AzureDiagnostics
| where Category == "AzureSiteRecoveryReplicatedItems"
| where TimeGenerated > ago(1h)
| project TimeGenerated, ProtectedItemName_s, Rpo_s
| order by TimeGenerated desc
```

## Success Criteria Validation ✅

Confirm you have completed:
- ✅ Configured diagnostic settings for Recovery Services Vault(s) to send logs to Log Analytics
- ✅ Explored backup job monitoring and alert interfaces in the Recovery Services Vault
- ✅ Accessed Azure Business Continuity Center and reviewed backup reports
- ✅ Configured Azure Monitor alerts for backup job failures
- ✅ Verified ASR diagnostic settings are enabled and sending logs to Log Analytics
- ✅ Explored Azure Site Recovery dashboard including replication health and infrastructure view
- ✅ Reviewed built-in Azure Monitor alerts for Azure Site Recovery
- ✅ Understood the types of events monitored by ASR alerts
- ✅ (Optional) Queried ASR data in Log Analytics for custom insights

You have successfully completed Challenge 8! 🚀

## Additional Notes

**Monitoring Best Practices:**
- Configure diagnostic settings for all Recovery Services Vaults
- Use a centralized Log Analytics workspace for unified monitoring
- Set up action groups for critical alerts (email, SMS, webhook)
- Review monitoring dashboards regularly
- Leverage Azure Business Continuity Center for cross-subscription visibility
- Create custom Log Analytics queries for specific insights
- Schedule regular reviews of backup and replication health

**Alert Configuration Tips:**
- Configure multiple notification channels for critical alerts
- Set appropriate severity levels based on business impact
- Use action groups to route alerts to the right teams
- Test alert notifications to ensure they're working
- Document alert response procedures
- Review and tune alert thresholds based on operational experience

**Reporting Considerations:**
- Initial data population takes 24+ hours after diagnostic configuration
- Reports show data with a slight delay (not real-time)
- Use Azure Business Continuity Center for comprehensive cross-resource reporting
- Custom Log Analytics queries provide the most flexibility
- Consider exporting reports to Power BI for advanced visualizations
- Schedule regular report reviews with stakeholders

**Log Analytics Retention:**
- Default retention is 30 days (configurable up to 730 days)
- Balance retention needs with storage costs
- Archive older logs if long-term retention is required
- Use log queries efficiently to minimize query costs
- Consider data export for long-term archival needs
