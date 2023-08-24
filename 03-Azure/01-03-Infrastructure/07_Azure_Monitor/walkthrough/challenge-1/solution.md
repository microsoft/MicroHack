# Walkthrough Challenge  1

*Duration: 45 Minutes*

## Task 1 & 2 & 3

- Create a data collection rule

    ![Create DCR](./img/task_01_a.png)

- Add resources and associate resources to the data collection rule.

    ![Create DCR](./img/task_01_b.png)

- On the Collect and deliver tab, select Add data source to add a data source and set a destination. Select a Data source type.

    *Linux*
    ![Create DCR](./img/task_01_c.png)

    *Windows*
    ![Create DCR](./img/task_01_d.png)

- On the Destination tab, add `law-microhack`.

    *You can select multiple destinations of the same or different types. For instance, you can select multiple Log Analytics workspaces, which is also known as multihoming. You can send Windows event and Syslog data sources to Azure Monitor Logs only.*

    ![Create DCR](./img/task_01_e.png)

- Select **Review + create** to review the details of the data collection rule and association with the set of virtual machines. Select **Create** to create the data collection rule.

    ![Create DCR](./img/task_01_f.png)

- Verify Data Collection Rule configuration

    *Data Sources*
    ![Create DCR](./img/task_01_g.png)

    *Resources*
    ![Create DCR](./img/task_01_h.png)

    *VM Extensions + applications*
    ![Create DCR](./img/task_01_i.png)

## Task 4: Validate tables in Log Analytics Workspace

- Which table includes Windows Events?

    ![Windows Events](./img/task_04_a.png)

- Which table includes Linux Logs?

    ![Linux Logs](./img/task_04_b.png)

- Which table shows AMA reporting status?

    ![Heartbeat](./img/task_04_c.png)

## Task 5: Availability rate check

```powershell
Heartbeat
| summarize heartbeatPerHour = count() by bin_at(TimeGenerated, 1h, ago(24h)), Computer
| extend availablePerHour = iff(heartbeatPerHour > 0, true, false)
| summarize totalAvailableHours = countif(availablePerHour == true) by Computer
| extend availabilityRate = totalAvailableHours*100/24
| project-rename Availability_in_Percent=availabilityRate
```

## Links

For detailed information check the [documenation page](https://learn.microsoft.com/en-us/azure/azure-monitor/agents/data-collection-rule-azure-monitor-agent?tabs=portal)
