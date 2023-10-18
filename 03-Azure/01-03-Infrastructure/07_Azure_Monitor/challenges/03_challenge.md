# Challenge 3 : Create alerts

Alerts help you identify and fix problems before users notice them by proactively notifying you when Azure Monitor data indicates a problem with your infrastructure or application.

You can create alerts for any metric or log data source in the Azure Monitor data platform.

This diagram shows you how alerts work:

![Alerts](https://learn.microsoft.com/en-us/azure/azure-monitor/alerts/media/alerts-overview/alerts.png)

## Goal

Every monitoring solution needs to have a way to notify the user about issues. Azure Monitor provides a way to create alerts based on metrics and logs. In this challenge, you will create an alert for, e.g, unresponsive virtual machines.

Important here are the different types of alert types that can be created:

- Metric alerts
- Log alerts
- Activity log alerts
    - Service Health alerts
    - Resource Health alerts
- Prometheus alerts

Alerts are configured in the same way, but the alert condition is different. Metric alerts are based on metrics and log alerts are based on log queries.

## Action

### Task 1: Create an alert for not reporting virtual machines

Create an alert for unresponsive virtual machines. The alert should be triggered when the virtual machine is not reporting for 5 minutes.

Test the alert by stopping one of the virtual machines.

> **Note**
> After that, start the machine again.

### Task 2: Create a Service Health Alert

Create a Service Health alert for the services `Virtual Machines` and `Virtual Machine Scale Sets`. The alert should be triggered when the service in the region `West Europe` is not available or has issues (Service Issues).

### Task 3: Create a Resource Health Alert

Create a Resource Health alert for all resources within your resource group.

### Task 4: Create an alert which notifies you when the `vm-linux` gets restarted

Create an Activity log alert to track the reboot activity of the linux vm.

### Task 5: Knowledge Questions

- Can you explain the difference between a metric alert and a log alert?
- Can you explain the difference between a Service Health alert and a Resource Health alert?
- On which official Microsoft website can you find information about Azure Service Health for every single region worldwide?

### Learning Resources

- [Azure Monitor Alerts](https://learn.microsoft.com/en-us/azure/azure-monitor/alerts/alerts-overview)
- [Create or edit an alert rule](https://learn.microsoft.com/en-us/azure/azure-monitor/alerts/alerts-create-new-alert-rule?tabs=metric)
- [Get started with log queries in Azure Monitor](https://learn.microsoft.com/en-us/azure/azure-monitor/logs/get-started-queries)
- [Azure Service Health](https://learn.microsoft.com/en-us/azure/service-health/overview)

## Success Criteria

- Create alert rules for the signal types listed above.
- Understand and explain the differences of the alert types to your team members and coaches.

### Congrats :partying_face:

Move on to [Challenge 4 : Create Workbooks](04_challenge.md).
  