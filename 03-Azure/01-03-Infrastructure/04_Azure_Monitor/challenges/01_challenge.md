# Challenge 1 - Configure Virtual Machine Logs

First of all and before we start, it's important to understand that monitoring IaaS (e.g. Virtual Machines) and PaaS (e.g. Application Gateway) works differently because of the way you can control the unterlaying infrastrucuture and the shared responsibilty model. In this challenge, we will focus on IaaS monitoring.

![Architecture](https://www.artifakt.com/content/uploads/2021/07/Blog-Image-CirclesGraph-1200x627-%E2%80%93-1.png)

The AMA targets the IaaS where you have the control to install the agent. But what is the AMA doing then? 

Azure Monitor Agent (AMA) collects monitoring data from the guest operating system of Azure and hybrid virtual machines and delivers it to Azure Monitor for use by features, insights, and other services, such as Microsoft Sentinel and Microsoft Defender for Cloud. Azure Monitor Agent replaces all of Azure Monitor's legacy monitoring agents. This article provides an overview of `Azure Monitor Agent's` capabilities and supported use cases.

![AMA Benefits](https://learn.microsoft.com/de-de/azure/azure-monitor/agents/media/azure-monitor-agent-overview/azure-monitor-agent-benefits.png)


Therefore the AMA is a key component to collect data from your infrasracture (IaaS) like virtual machines and on-premises servers (Arc enabled servers).

**Note**: The Log Anayltic agent will be replaced by the AMA in the future. Therefore, we will not cover the Log Anayltic agent in this MicroHack.

It´s totally worth it to read more about the AMA and it`s benefits [here](https://docs.microsoft.com/en-us/azure/azure-monitor/agents/azure-monitor-agent-overview).

## **Goal**

- AMA is installed on both virtual machines (Windows and Linux).

- Logs and metrics are collected from both virtual machines (Windows and Linux) and are available in the `Log Analytics Workspace`.

After the challenge you should be able to answer the following questions:

- What are the different ways to install the `AMA`?
- What are the different ways to configure the `AMA`?
- What is a `Data Collection Rule`?
- What is the relation between the `AMA` and the `Data Collection Rule`?

**Hint**: There are different ways to install the `AMA` on a virtual machine. We recommand deploying the AMA through a DCR (Data Collection Rule) because it is the most flexible way to configure the `AMA` and it is the future of the `AMA` deployment. Consider this while working on the challenge.

Before working on the tasks have a look at the following resources: https://learn.microsoft.com/en-us/azure/azure-monitor/essentials/data-collection-rule-overview

## **Tasks**

### Task 1: Install Azure Monitoring Agent (AMA) on Windows VM

Check if the `AMA` was installed  on the virtal machine blade under "Extensions & applications"

### Taks 2: Install Azure Monitoring Agent (AMA) on Linux VM

Check if the `AMA` was installed  on the virtal machine blade under "Extensions & applications"

### Taks 3: Install Azure Monitoring Agent (AMA) on Linux Vitual Machine Scale Set

Check if the `AMA` was installed  on the virtal machine blade under "Extensions & applications"

### Task 4: Create an alert for not responding virtual machines

Create an alert for not responding virtual machines. The alert should be triggered if the virtual machine is not responding for 5 minutes.

Test the alert by stopping one of the virtual machines.

**Important**: Start the machine aftewards again.

### Task 5: Write a Log Kusto Query which counts the heartbeat events grouped by the VM name

## **Learning Resources**

- [Manage Azure Monitor Agent](https://learn.microsoft.com/en-us/azure/azure-monitor/agents/azure-monitor-agent-manage?tabs=azure-portal)
- [Data collection rules in Azure Monitor](https://learn.microsoft.com/en-us/azure/azure-monitor/essentials/data-collection-rule-overview)
- [Collect events and performance counters from virtual machines with Azure Monitor Agent](https://learn.microsoft.com/en-us/azure/azure-monitor/agents/data-collection-rule-azure-monitor-agent?tabs=portal)
- [Get started with log queries in Azure Monitor](https://learn.microsoft.com/en-us/azure/azure-monitor/logs/get-started-queries)

## **FAQ**

- How much log data is being produced by a single VM? About 1 to 3 GB per month.
