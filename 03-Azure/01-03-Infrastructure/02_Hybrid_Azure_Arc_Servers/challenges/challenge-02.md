# Challenge 2 - Azure Monitor integration

[Previous Challenge Solution](challenge-01.md) - **[Home](../Readme.md)** - [Next Challenge Solution](challenge-03.md)

## Goal

In challenge 2 you will onboard your Windows and Linux virtual machines to Azure Monitor using the Azure Monitoring Agent (AMA) to leverage Azure Update Manager, Change Tracking, Inventory and more.

## Actions

- Create all necessary Azure resources
  - Log Analytics workspace (Name: mh-arc-servers-kv-law)
- Configure Data Collection Rules to collect Windows event logs and Linux syslog
- Enable Azure Monitor for Azure Arc-enabled Servers with Azure Policy initiative
- Enable and configure Update Manager
- Enable Change Tracking and Inventory
- Enable VM Insights


## Success criteria

- You have a Log Analytics Workspace
- You successfully linked the necessary Azure Policy initiative to the Azure resource group
- You can query the Log Analytics Workspace for events of your virtual machines
- All virtual machines have the latest Windows and Linux updates installed
- You can browse through the software inventory of your virtual machines
- You can use VM Insights to get a detailed view of your virtual machines

## Learning resources

- [Create a Log Analytics workspace in the Azure portal](https://docs.microsoft.com/azure/azure-monitor/logs/quick-create-workspace)
- [Deployment options for Azure Monitor agent on Azure Arc-enabled servers](https://learn.microsoft.com/azure/azure-arc/servers/concept-log-analytics-extension-deployment)
- [Data collection rules in Azure Monitor](https://learn.microsoft.com/azure/azure-monitor/essentials/data-collection-rule-overview)
- [Azure Policy built-in definitions for Azure Arc-enabled servers](https://docs.microsoft.com/azure/azure-arc/servers/policy-reference)
- [Azure Update Manager](https://learn.microsoft.com/azure/update-manager/overview)
- [Enable Change Tracking and Inventory using Azure Monitoring Agent](https://learn.microsoft.com/azure/automation/change-tracking/enable-vms-monitoring-agent?tabs=singlevm%2Cmultiplevms&pivots=single-portal)
- [Monitor a hybrid machine with VM insights](https://docs.microsoft.com/azure/azure-arc/servers/learn/tutorial-enable-vm-insights)

