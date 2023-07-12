# Challenge 1 - Configure Virtual Machine Logs

First of all and before we start, it's important to understand that monitoring IaaS (e.g. Virtual Machines) and PaaS (e.g. Application Gateway) works differently because of the way you can control the unterlaying infrastrucuture and the shared responsibilty model. In this challenge, we will focus on IaaS monitoring.

![Architecture](https://www.artifakt.com/content/uploads/2021/07/Blog-Image-CirclesGraph-1200x627-%E2%80%93-1.png)

The Azure Monitor Agent (AMA) targets the IaaS where you have the control to install the agent. But what is the AMA doing then? 

Azure Monitor Agent (AMA) collects monitoring data from the guest operating system of Azure and hybrid virtual machines and delivers it to Azure Monitor for use by features, insights, and other services, such as Microsoft Sentinel and Microsoft Defender for Cloud. Azure Monitor Agent replaces all of Azure Monitor's legacy monitoring agents. This article provides an overview of `Azure Monitor Agent's` capabilities and supported use cases.

![AMA Benefits](https://learn.microsoft.com/de-de/azure/azure-monitor/agents/media/azure-monitor-agent-overview/azure-monitor-agent-benefits.png)


Therefore the AMA is a key component to collect data from your infrasracture (IaaS) like virtual machines and on-premises servers (Arc enabled servers).

**Note**: The Log Anayltic agent will be replaced by the AMA in the future. Therefore, we will not cover the Log Anayltic agent in this MicroHack.

It´s totally worth it to read more about the AMA and it`s benefits [here](https://docs.microsoft.com/en-us/azure/azure-monitor/agents/azure-monitor-agent-overview).

## **Goal**

The goal of the first exercise is for you to familiarise yourself with the `AMA` and collect your logs. You should then be able to query these in your `Log Analytics workspace`. It is also important that you keep track of your VMs and are notified if something goes wrong.

After the challenge you should be able to answer the following questions:

- What are the different ways to install the `AMA`?
- What are the different ways to configure the `AMA`?
- What is a `Data Collection Rule`?
- What is the relation between the `AMA` and the `Data Collection Rule`?

**Hint**: There are different ways to install the `AMA` on a virtual machine. We recommand deploying the AMA through a DCR (Data Collection Rule) because it is the most flexible way to configure the `AMA` and it is the future of the `AMA` deployment. Consider this while working on the challenge.

## Actions

Before you start working on the `Tasks 1, 2, 3`, you should have a look at the following resources:

- [Data collection rules in Azure Monitor](https://learn.microsoft.com/en-us/azure/azure-monitor/essentials/data-collection-rule-overview)
- [Collect events and performance counters from virtual machines with Azure Monitor Agent](https://learn.microsoft.com/en-us/azure/azure-monitor/agents/data-collection-rule-azure-monitor-agent?tabs=portal)

### Task 1: Install Azure Monitoring Agent (AMA) on Windows VM

Check if the `AMA` was installed  on the virtal machine blade under "Extensions & applications"

### Taks 2: Install Azure Monitoring Agent (AMA) on Linux VM

Check if the `AMA` was installed  on the virtal machine blade under "Extensions & applications"

### Taks 3: Install Azure Monitoring Agent (AMA) on Linux Vitual Machine Scale Set

Check if the `AMA` was installed  on the virtal machine blade under "Extensions & applications"

### Task 4: Create an alert for not reporting virtual machines

Create an alert for unresponsive virtual machines. The alert should be triggered when the virtual machine is not reporting for 5 minutes.

Test the alert by stopping one of the virtual machines.

> **Note**
> After that, start the machine again.

- [Azure Monitor Alerts](https://learn.microsoft.com/en-us/azure/azure-monitor/alerts/alerts-overview)
- [Create or edit an alert rule](https://learn.microsoft.com/en-us/azure/azure-monitor/alerts/alerts-create-new-alert-rule?tabs=metric)
- [Get started with log queries in Azure Monitor](https://learn.microsoft.com/en-us/azure/azure-monitor/logs/get-started-queries)

### Task 5: Availability rate check: calculation of the availability rate of each connected computer

Create a query inside log analytics and excute the query to see the results.

- [Get started with log queries in Azure Monitor](https://learn.microsoft.com/en-us/azure/azure-monitor/logs/get-started-queries)
- [Kusto Query Language](https://learn.microsoft.com/en-us/azure/data-explorer/kusto/query/tutorials/learn-common-operators)

## Success Criteria

- Windows Events and Syslog from all virtual machines (`vm-windows`, `vm-linux` and `vmss-linux-nginx`) are collected in your Log Analytics Workspace.
- An alert for non reporting VMs has been created and triggered at least once for a machine that was shut down.
- You may have written and run your first Kusto Query and have an overview of the availability rate of your virtual machines.

### :partying_face: Congrats

 Move on to [Challenge 2 : Enable Virtual Machine Insights](02_challenge.md).
