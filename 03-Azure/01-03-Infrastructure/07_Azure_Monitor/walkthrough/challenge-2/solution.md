# Walkthrough Challenge 2

*Duration: 30 Minutes*

- [Walkthrough Challenge 2](#walkthrough-challenge-2)
  - [Task 1: Enable VM Insights for `vm-linux`](#task-1-enable-vm-insights-for-vm-linux)
  - [Task 2: Enable VM Insights on unmonitored `vm-windows`](#task-2-enable-vm-insights-on-unmonitored-vm-windows)
  - [*\[Optional\]* Task 3: Enable VM Insights for `vmss-linux-nginx` automatically](#optional-task-3-enable-vm-insights-for-vmss-linux-nginx-automatically)
  - [Task 4: Log search and visualize](#task-4-log-search-and-visualize)

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

## *[Optional]* Task 3: Enable VM Insights for `vmss-linux-nginx` automatically

- Run remmediation task to install the Dependency agent on new virtual machine scale set in your Azure environment.

    ![Create Remmediation Task](./img/task_03_a.png)

## Task 4: Log search and visualize

- Check for the correct log query

    ![Log Query](./img/task_04_b.png)

- Create a chart with CPU usage trends by computer. Calculate CPU usage patterns over the last hour, chart by percentiles. Add the chart to your dashboard.

    ![Log Query](./img/task_04_a.png)
