# Walkthrough Challenge 2

*Duration: 30 Minutes*

## Task 1: Enable VM Insights for `vm-linux`

- Enable VM Insights on monitored machines

    ![Create DCR](./img/task_01_a.png)

- Create a Data Collection Rule and configure to use the Log Analytics Workspace and enable processes and dependencies (Map)

    ![Create DCR](./img/task_01_b.png)

    ![Create DCR](./img/task_01_c.png)

- View Performance tab after successful deployment

    ![Verify DCR](./img/task_01_d.png)

## Task 2: Enable VM Insights on unmonitored `vm-windows`

- From Azure Monitor blade there is a way to enable VM Insights, too.
- From the Monitor menu in the Azure portal, select Virtual Machines > Overview > Not Monitored.
- See [Enable VM insights for Log Analytics agent](https://learn.microsoft.com/en-us/azure/azure-monitor/vm/vminsights-enable-portal#enable-vm-insights-for-log-analytics-agent)

    ![Create DCR](./img/task_02_a.png)

    ![Create DCR](./img/task_02_b.png)

    ![Create DCR](./img/task_02_c.png)

    ![Verify](./img/task_02_d.png)

## Task 3: Enable VM Insights for `vmss-linux-nginx` automatically

> :warning: **RBAC and Permissions Requirement**: Based on the policy definition, it requires managed identity to have “Contributor” and “User Access Administrator” role on **subscription level** to execute the remediation task for Policy `Assign Built-In User-Assigned Managed Identity to Virtual Machine Scale Sets`.

- Enable VM Insights for th VMSS by using Azure Policy
- VM insights policy initiatives install Azure Monitor Agent and the Dependency agent on new virtual machine scale set in your Azure environment.
- Assign these initiatives to the resource group `rg-monitoring-microhack` to install the agents on the virtual machines in the defined scope automatically.



## Task 4: Log search and visualize

- Check for the correct log query

    ![Log Query](./img/task_04_b.png)

- Create a chart with CPU usage trends by computer. Calculate CPU usage patterns over the last hour, chart by percentiles. Add the chart to your dashboard.

    ![Log Query](./img/task_04_a.png)
