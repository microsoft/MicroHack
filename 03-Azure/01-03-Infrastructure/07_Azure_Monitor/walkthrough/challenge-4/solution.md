# Walkthrough Challenge 4

*Duration: 45 Minutes*

- [Walkthrough Challenge 4](#walkthrough-challenge-4)
  - [Task 1](#task-1)
  - [Task 2](#task-2)
  - [Task 3](#task-3)

## Task 1

- Create a new Monitoring Workbook named `Monitor Microhack`

![Task1](./img/task_01_a.png)

## Task 2

- Add an Parameter names `Time Range` of type `Time Range Picker`

![Task1](./img/task_01_b.png)

![Task1](./img/task_01_c.png)

- Add a Query to the workbook and write the following query:

```kusto
Perf
| where ObjectName == 'Processor' and CounterName == '% Processor Time'
| summarize Cpu = percentile(CounterValue, 95) by Computer
| join kind = inner (Perf
    | where ObjectName == 'Processor' and CounterName == '% Processor Time'
    | make-series Trend = percentile(CounterValue, 95) default = 0 on TimeGenerated from {TimeRange:start} to {TimeRange:end} step {TimeRange:grain} by Computer
    ) on Computer
| project-away Computer1, TimeGenerated
| order by Cpu desc
```

![Task1](./img/task_01_e.png)

In the **Columns Settings**, set:

Cpu

- Column renderer: Thresholds
- Custom number formatting: checked
- Units: Percentage
- Threshold settings (last two need to be in order):
- Icon: Success, Operator: Default
- Icon: Critical, Operator: >, Value: 80
- Icon: Warning, Operator: >, Value: 60

Trend

- Column renderer: Spark line
- Color palette: Green to Red
- Minimum value: 60
- Maximum value: 80

Click **Save and close** to commit the changes.

## Task 3

- Pin the workbook to the dashboard. Choose **Pin All** to pin all the tiles to the dashboard.

![Task1](./img/task_01_g.png)

- Choose your Dashboard and verify that the workbook is pinned.

![Task1](./img/task_01_f.png)

- End result

![Task3](./img/task_3_dashboard.png)

## Task 4

- Add the query to the workbook

![Task3](./img/task_4_a.png)

- Configure the columns under **Column Settings**

![Task3](./img/task_4_b.png)
