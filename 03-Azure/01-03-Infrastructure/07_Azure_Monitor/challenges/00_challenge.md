# Challenge 0 - Explore the lab environment, create an Azure Log Analytics Workspace and an empty Dashboard

## **Goal**

The goal of this challenge is to explore the lab environment and understand the components and Azure resources that have been deployed.

After completing this challenge, you have successfully deployed a `Log Analytics Workspace` as a base for the upcoming challenges.

## **Actions**

### Task 1: Explore and ensure successful deployment

Go to the Azure Portal and navigate to the resource group `rg-microhack-monitoring`. Look at the resources that have been deployed and think about possbile monitoring scenarios:

- What kind of resources have been deployed (IaaS, PaaS)?
- How would you monitor the resources?
- What kind of logs and metrics have you in mind to monitor?
- How do I get informed about downtime and failures?

### Task 2: Create Log Analytics workspace

Azure Log Analytics is a tool in the Azure portal that's used to edit and run log queries against data in the Azure Monitor Logs store. You might write a simple query that returns a set of records and then use features of Log Analytics to sort, filter, and analyze them. It is used for collecting and analyzing log data, monitoring availability via web tests, exporting platform logs data from Azure resources, collecting metrics, alerts, and notifications.

- Create a Log Analytics workspace `law-microhack` in the same resource group as the other resources. **Use the same Azure region as the other resources.**
- Ensure the workspace is created successfully.

### Task 3: Create an empty Azure Dashboard

- Create an empty Azure Dashboard `Dashboard Monitoring Microhack`
- We will use this dashboard in the upcoming challenges to visualize our data.
- [***Optional***] Publish it and share it with other users in your organization

Azure Dashboards are customizable workspaces for monitoring your Azure resources. You can monitor the health and status of your Azure resources in a single, customized dashboard. Dashboards are useful for troubleshooting and identifying issues with your Azure resources.

### Taks 4: Create an empty Monitoring Workbook

- Create an empty Monitoring Workbook `Workbook Monitoring Microhack` in the same region as the other resources and save it in the resource group `rg-microhack-monitoring`.

### Learning Resources

- [Overview of Log Analytics in Azure Monitor - Azure Monitor.](https://learn.microsoft.com/en-us/azure/azure-monitor/logs/log-analytics-overview)
- [Pricing - Azure Monitor | Microsoft Azure.](https://azure.microsoft.com/en-in/pricing/details/monitor/)
- [Create a dashboard in the Azure Portal](https://learn.microsoft.com/en-us/azure/azure-portal/azure-portal-dashboards)
- [Share Azure dashboards by using Azure role-based access control](https://learn.microsoft.com/en-us/azure/azure-portal/azure-portal-dashboard-share-access)
- [Create a workbook in Azure Monitor](https://learn.microsoft.com/en-us/azure/azure-monitor/visualize/workbooks-create-workbook)

## Success Criteria

- The lab environment has been succesfully deployed and expolored. You are aware of all virtual machines (`vm-windows`, `vm-linux` and `vmss-linux-nginx`).
- A Log Analytices Workspace was deployed.
- A (shared) dashboard was created in the Azure portal.
- A workbook was created in the Azure portal.
- You are ready and equipped to dive into Azure Monitor.

### Congrats :partying_face:

 Move on to [Challenge 1 : Configure Virtual Machine Logs](01_challenge.md).
