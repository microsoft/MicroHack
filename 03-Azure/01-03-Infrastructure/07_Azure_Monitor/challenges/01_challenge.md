# Challenge 1 - Configure Virtual Machine Logs

First of all and before we start, it's important to understand that monitoring IaaS (e.g. Virtual Machines) and PaaS (e.g. Application Gateway) works differently because of the way you can control the unterlaying infrastrucuture and the shared responsibilty model. In this challenge, we will focus on IaaS monitoring.

![Architecture](https://www.artifakt.com/content/uploads/2021/07/Blog-Image-CirclesGraph-1200x627-%E2%80%93-1.png)

The Azure Monitor Agent (AMA) targets the IaaS where you have the control to install the agent. But what is the AMA doing then?

Azure Monitor Agent (AMA) collects monitoring data from the guest operating system of Azure and hybrid virtual machines and delivers it to Azure Monitor for use by features and insights, and other services, such as Change Tracking and Inventory & Best Practice Assessment. Azure Monitor Agent replaces all of Azure Monitor's legacy monitoring agents. This article provides an overview of `Azure Monitor Agent's` capabilities and supported use cases.

Benefits of the new `Azure Monitor Agent` are

- Single agent for all monitoring data
- Simplified configuration
- Simplified management
- Simplified troubleshooting
- Cost reduction

Therefore the AMA is a key component to collect data from your infrasracture (IaaS) like virtual machines and on-premises servers (Arc enabled servers).

> **Note**
> The Log Analytic agent will be replaced by the AMA in the future. Therefore, we will not cover the Log Anayltic agent in this MicroHack.

It´s totally worth it to read more about the AMA and it`s benefits [here](https://docs.microsoft.com/en-us/azure/azure-monitor/agents/azure-monitor-agent-overview).

## **Goal**

The goal of the first exercise is for you to familiarise yourself with the `AMA` and collect your logs. You should then be able to query these in your `Log Analytics workspace`. It is also important that you keep track of your VMs and are notified if something goes wrong.

After the challenge you should be able to answer the following questions:

- What are the different ways to install the `AMA`?
- What are the different ways to configure the `AMA`?
- What is a `Data Collection Rule`?
- What is the relation between the `AMA` and the `Data Collection Rule`?

> **Hint**
> 
> There are different ways to install the `AMA` on a virtual machine. We recommand deploying the AMA through a DCR (Data Collection Rule) because it is the most flexible way to configure the `AMA` and it is the future of the `AMA` deployment. Consider this while working on the challenge.
> 
> If `AMA` is already installed in your environment. Don't worry, there are several automatic ways to get the agent onto a machine - e.g. with [Microsoft Defender for Cloud](https://learn.microsoft.com/en-us/azure/defender-for-cloud/auto-deploy-azure-monitoring-agent#deploy-the-azure-monitor-agent-with-defender-for-cloud) or with `Azure Policy` which we will cover later.

## Actions

Before you start working on the `Tasks 1 and 2`, you should have a look at the following resources:

- [Data collection rules in Azure Monitor](https://learn.microsoft.com/en-us/azure/azure-monitor/essentials/data-collection-rule-overview)
- [Collect events and performance counters from virtual machines with Azure Monitor Agent](https://learn.microsoft.com/en-us/azure/azure-monitor/agents/data-collection-rule-azure-monitor-agent?tabs=portal)

>**Hint**
>
> When creating the Data Collection rule for the VMs **only add Events and Syslog** to the rule. You will add **Performance Counters** later.

### Task 1: Install Azure Monitoring Agent (AMA) on Windows VM

Check if the `AMA` was installed  on the virtal machine blade under "Extensions & applications"

### Task 2: Install Azure Monitoring Agent (AMA) on Linux VM

Check if the `AMA` was installed  on the virtal machine blade under "Extensions & applications"

### *[Optional]* Taks 3: Install Azure Monitoring Agent (AMA) on Linux Vitual Machine Scale Set automatically with Azure Policy

> :warning: **RBAC and Permissions Requirement**: Based on the policy definition, it requires managed identity to have “Contributor” and “User Access Administrator” role on **subscription level** to execute the remediation task for Policy `Assign Built-In User-Assigned Managed Identity to Virtual Machine Scale Sets`.

- Enable Azure Monitor for VMSS with Azure Monitoring Agent(AMA) on new virtual machine scale set in your Azure environment.
- Assign the initiative to the resource group `rg-monitoring-microhack` to install the agents on the virtual machines in the defined scope automatically.
- Please be patient, it takes a while for the policies to synchronise all dependencies and show resources in the remmediation section.

> :warning:
> Check if you VMSS istances running on the latest model. If not, update the model to the latest version manually. Otherwise no logs will be pushed to the Log Analytics Workspace.

### Task 4: Validate tables in Log Analytics Workspace

- Which table includes Windows Events?
- Which table includes Linux Logs?
- Which table shows AMA reporting status?

### Task 5: Availability rate check

- Calculuate the availability rate of each connected computer. Create a query inside log analytics and excute the query to see the results

- Pin the tile (table) to your dashboard `Dashboard Monitoring Microhack`

### Learning Resources

- [Azure Monitor Logs table reference organized by category](https://learn.microsoft.com/en-us/azure/azure-monitor/reference/tables/tables-category)
- [Get started with log queries in Azure Monitor](https://learn.microsoft.com/en-us/azure/azure-monitor/logs/get-started-queries)
- [Kusto Query Language](https://learn.microsoft.com/en-us/azure/data-explorer/kusto/query/tutorials/learn-common-operators)

## Success Criteria

- Windows Events and Syslog from all virtual machines (`vm-windows`, `vm-linux` and `vmss-linux-nginx`) are collected in your Log Analytics Workspace.
- You may have written and run your first Kusto Query and have an overview of the availability rate of your virtual machines.

### Congrats :partying_face:

 Move on to [Challenge 2 : Enable Virtual Machine Insights](02_challenge.md).
