# Challenge 2 : Enable Virtual Machine Insights

Azure VM Insights is a service that provides performance and health monitoring for virtual machines (VMs) in Azure. It helps you identify and troubleshoot issues with your VMs by providing metrics, logs, and diagnostics data.

VM insights supports Windows and Linux operating systems on:

- Azure virtual machines.
- Azure virtual machine scale sets.
- Hybrid virtual machines connected with Azure Arc.
- On-premises virtual machines.
- Virtual machines hosted in another cloud environment.

![VM Insights](./../img/vminsights-azmon-directvm.png)

VM insights provides a set of predefined workbooks that allow you to view trending of collected performance data over time. You can view this data in a single VM from the virtual machine directly, or you can use Azure Monitor to deliver an aggregated view of multiple VMs.

## Goal

After completing this challenge you should be able to enable VM Insights on your virtual machines.

VM Insights can be set up in different ways. After the tutorial, you can activate it both manually in the Azure Portal and automatically with Azure Policy.

## Actions

### Task 1: Enable VM Insights for `vm-linux`

- Enable VM Insights on monitored machines
- Create a Data Collection Rule and configure to use the Log Analytics Workspace

### Task 2: Enable VM Insights on unmonitored `vm-windows`

- From Azure Monitor blade there is a way to enable VM Insights, too.
- From the Monitor menu in the Azure portal, select Virtual Machines > Overview > Not Monitored.

### *[Optional]* Task 3: Enable VM Insights for `vmss-linux-nginx` automatically

- Run remmediation task to install the Dependency agent on new virtual machine scale set in your Azure environment.

### Task 4: Log search and visualize

- Create a chart with CPU usage trends by computer. Calculate CPU usage patterns over the last hour, chart by percentiles.

- Add the chart to your dashboard.

### Learning Resources

- [Enable Azure Monitor Agent on monitored machines](https://learn.microsoft.com/en-us/azure/azure-monitor/vm/vminsights-enable-portal#enable-azure-monitor-agent-on-monitored-machines)
- [Enable VM insights for Log Analytics agent](https://learn.microsoft.com/en-us/azure/azure-monitor/vm/vminsights-enable-portal#enable-vm-insights-for-log-analytics-agent)
- [Enable VM insights by using Azure Policy](https://learn.microsoft.com/en-us/azure/azure-monitor/vm/vminsights-enable-policy)
- [How to query logs from VM insights](https://learn.microsoft.com/en-us/azure/azure-monitor/vm/vminsights-log-query)

## Success Criteria

- VM Insights was successfully enabled on all virtual machines.

### Congrats :partying_face:

Move on to [Challenge 3: Create alerts](03_challenge.md).
  