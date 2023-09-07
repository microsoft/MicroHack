# Challenge 4: Workbooks

Workbooks provide a flexible canvas for data analysis and the creation of rich visual reports within the Azure portal. They allow you to tap into multiple data sources from across Azure and combine them into unified interactive experiences. Workbooks let you combine multiple kinds of visualizations and analyses, making them great for freeform exploration.

Workbooks combine text, log queries, metrics, and parameters into rich interactive reports.

Workbooks are helpful for scenarios such as:

- Exploring the usage of your virtual machine when you don't know the metrics of interest in advance. You can discover metrics for CPU utilization, disk space, memory, and network dependencies.

- Explaining to your team how a recently provisioned VM is performing. You can show metrics for key counters and other log events.

- Sharing the results of a resizing experiment of your VM with other members of your team. You can explain the goals for the experiment with text. Then you can show each usage metric and the analytics queries used to evaluate the experiment, along with clear call-outs for whether each metric was above or below target.

- Reporting the impact of an outage on the usage of your VM. You can combine data, text explanation, and a discussion of next steps to prevent outages in the future.

## Goal

After completing this challenge you should be able to create a workbook and add tiles to it.

## Actions

### Task 1

Wihtin your workbook, create a "Traffic Light" for your virtual machines `vm-windows` and `vm-linux` and the virtual machine scale set `vmss-linux-nginx`.
Categorize your computers by CPU utilization as cold, warm, or hot and categorize performance as satisfied, tolerated, or frustrated. You can use an indicator or icon that represents the status next to the underlying metric.

![workbook](https://learn.microsoft.com/en-us/azure/azure-monitor/visualize/media/workbooks-commonly-used-components/workbooks-traffic-light-sample.png)

### Task 2

Add the workbook (tiles) to your dashboard `Dashboard Monitoring Microhack`.

### Task 3

Repeat the task 1 and 2 for the virtual machines `vm-windows`.

Since the Windows VMs won't be covered with the query, you need to clone the tile and change the query to the Windows VMs.

**Hint**: You need to change the `Processor` attribute in the query only because it is different to linux (look at the `Perf` table)

### Task 4

In challenge 1 you have created a query to calculate the availability rate of each connected computer.
Set a threshold for the availability rate and add a traffic light icon to the table: green for availability rate > 99%, yellow for availability rate > 95% and red for availability rate < 95%.

### Learning Resources

- [Create a new workbook](https://learn.microsoft.com/en-us/azure/azure-monitor/visualize/workbooks-create-workbook)
- [Add parameters](https://learn.microsoft.com/en-us/azure/azure-monitor/visualize/workbooks-create-workbook#add-parameters)
- [Workbook time parameters](https://learn.microsoft.com/en-us/azure/azure-monitor/visualize/workbooks-time)
- [Traffic light icons](https://learn.microsoft.com/en-us/azure/azure-monitor/visualize/workbooks-commonly-used-components#traffic-light-icons)

## Success Criteria

- A customized workbook was created.
- The grid was added to the dashboard `Dashboard Monitoring Microhack`.

### Congrats :partying_face:

Move on to [Challenge 5 : Collect text logs with Azure Monitor Agent](05_challenge.md).
