# Challenge 1 - install Azure Monitoring Agent (AMA) for virtual machines

First of all and before we start, it's important to understand that monitoring IaaS (e.g. Virtual Machines) and PaaS (e.g. Application Gateway) works differently because of the way you can control the unterlaying infrastrucuture and the shared responsibilty model. In this challenge, we will focus on IaaS monitoring.

![Architecture](https://www.artifakt.com/content/uploads/2021/07/Blog-Image-CirclesGraph-1200x627-%E2%80%93-1.png)

The AMA we are targets the IaaS where you have the control to install somehting. But what is the AMA doing then? 

Azure Monitor Agent (AMA) collects monitoring data from the guest operating system of Azure and hybrid virtual machines and delivers it to Azure Monitor for use by features, insights, and other services, such as Microsoft Sentinel and Microsoft Defender for Cloud. Azure Monitor Agent replaces all of Azure Monitor's legacy monitoring agents. This article provides an overview of Azure Monitor Agent's capabilities and supported use cases.

![](https://learn.microsoft.com/de-de/azure/azure-monitor/agents/media/azure-monitor-agent-overview/azure-monitor-agent-benefits.png)


Therefore the AMA is a key component to collect data from your infrasracture (IaaS) like virtual machines, on-premises servers (Arc enabled servers).

**NOTE**: The Log Anayltic agent will be replaced by the AMA in the future. Therefore, we will not cover the Log Anayltic agent in this MicroHack.

It´s totally worth it to read more about the AMA and it`s benefits [here](https://docs.microsoft.com/en-us/azure/azure-monitor/agents/azure-monitor-agent-overview).


## Goal 

- AMA is installed on both virtual machines (Windows and Linux).

- Logs and metrics are collected from both virtual machines (Windows and Linux) and are available in the `Log Analytics Workspace`.

Can you answer the following questions?
- What are the different ways to install the `AMA`?
- What are the different ways to configure the `AMA`?
- What is a `Data Collection Rule`?
- What is the relation between the `AMA` and the `Data Collection Rule`?

## Task 1: Install Azure Monitoring Agent (AMA) on Windows VM

## Taks 2: Install Azure Monitoring Agent (AMA) on Linux VM

## FAQ
- How much log data is being produced by a single VM? About 1 to 3 GB per month.
