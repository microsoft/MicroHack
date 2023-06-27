# Challenge 0 - Create Azure Log Analytics Workspace and explore the lab environment

## Goal

The goal of this challenge is to explore the lab environment and understand the components that have been deployed.

After completing this challenge, you have successfully deployed a Log Analytics workspace.

## Task 1: Explore and ensure successful deployment

- Go to the Azure Portal and navigate to the resource group `rg-microhack`. Look at the resources that have been deployed and think about possbile monitoring scenarios.
    - How would you monitor the resources?
    - What are the different types of resources (IaaS, PaaS etc.)? 
- Ensure Application Gateway `appgw-microhack` and respective Backend Pool respond to port `80`.
- Ensure Virtual Machine `vm-windows` responds to port `80`.

## Task 2: Create Log Analytics workspace

Azure Log Analytics is a tool in the Azure portal that's used to edit and run log queries against data in the Azure Monitor Logs store. You might write a simple query that returns a set of records and then use features of Log Analytics to sort, filter, and analyze them. It is used for collecting and analyzing log data, monitoring availability via web tests, exporting platform logs data from Azure resources, collecting metrics, alerts, and notifications.

- Create a Log Analytics workspace `la-microhack` in the same resource group as the other resources. Use the same Azure region as the other resources.
- Ensure the workspace is created successfully.

## Useful links:
- https://learn.microsoft.com/en-us/azure/azure-monitor/logs/log-analytics-overview
- [Overview of Log Analytics in Azure Monitor - Azure Monitor.](https://learn.microsoft.com/en-us/azure/azure-monitor/logs/log-analytics-overview)
- [Pricing - Azure Monitor | Microsoft Azure.](https://azure.microsoft.com/en-in/pricing/details/monitor/)
